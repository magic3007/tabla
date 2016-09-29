import json
import os
from node_ir import Node, NodeGraph
from pe import Pe
from namespace import Ns_entry

class Dest:
    def __init__(self, namespace=None, index=None, dest_node_id=None):
        self.namespace = namespace
        self.index = index
        self.dest_node_id = dest_node_id

    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)

    def toDict(self):
        d = {}
        d["dest_nid"] = self.namespace
        d["dest_index"] = self.index
        return d

    def fromDict(self, d):
        self.namespace = d["dest_nid"]
        self.index = d["dest_index"]

    
class Source:
    def __init__(self, namespace=None, index=None):
        self.namespace = namespace
        self.index = index

    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)

    def toDict(self):
        d = {}
        d["src_nid"] = self.namespace
        d["src_index"] = self.index
        return d

    def fromDict(self, d):
        self.namespace = d["src_nid"]
        self.index = d["src_index"]

class Inst:
    def __init__(self, op=None, dests=None, srcs=None):
        self.op = op
        self.dests = dests
        self.srcs = srcs

    def writeTo(self, path):
        with open(path, 'w') as f:
            f.write(self.__str__())
        f.close()

    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)
        
    def toDict(self):
        d = {}
        d["op"] = self.op
        d["dests"] = [dest.toDict() for dest in self.dests] if self.dests is not None else None
        print("DEBUG ", self.srcs)
        d["srcs"] = [src.toDict() for src in self.srcs] if self.srcs is not None else None
        return d

    def fromDict(self, d):
        self.op = d["op"]
        if self.op == 'NOP':
            self.dests = None
            self.srcs = None
        else:
            dests = []
            for dest_d in d["dests"]:
                dest = Dest()
                dest.fromDict(dest_d)
                dests.append(dest)
            self.dests = dests
            srcs = []
            if d["srcs"] is not None:
                for src_d in d["srcs"]:
                    src = Source()
                    src.fromDict(src_d)
                    srcs.append(src)
            self.srcs = srcs

data_type_to_ns = {
    "model_input": "ND",
    "model_output": "ND",
    "model": "NW",
    "constant": "NM",
    "gradient": "NG",
    None: "NI"
}

def generate_inst(node_graph, pe_per_pu, pe_list):
    cycl = 0
    nodes = node_graph.get_nodes_in_cycle(cycl)
    while len(nodes) > 0:
        for node in nodes:
            if node.parents == ["Source"]:
                inst = Inst()
                dests = []
                if node.pe is None: # constants without pe assignment
                    for child in node.children:
                        namespace_id = data_type_to_ns[node.outDataType]
                        namespace = child.pe.namespace_map[namespace_id]
                        index = namespace.tail
                        namespace.insert(namespace.tail, Ns_entry())
                        dests.append(Dest(namespace_id, str(index), child.id))
                    inst.dests = dests
                    node.inst.append(inst)
                    #child.pe.add_inst(inst)
                else:
                    for child in node.children:
                        namespace_id = data_type_to_ns[node.outDataType]
                        namespace = node.pe.namespace_map[namespace_id]
                        index = namespace.tail
                        namespace.insert(namespace.tail, Ns_entry())
                        dests.append(Dest(namespace_id, str(index), child.id))
                    inst.dests = dests
                    node.inst.append(inst)
                    #node.pe.add_inst(inst)
            else:
                if len(node.children) > 1:
                    multicast(node, pe_per_pu)
                else:
                    srcs = []
                    for parent_node in node.parents:
                        src = get_src(node, parent_node, pe_per_pu)
                        srcs.append(src)
                    for i in range(3 - len(srcs)):
                        srcs.append(Source(namespace='NL', index='0'))
                    # if node.id == 14:
                    #     print(srcs[0])
                    #inst.srcs = srcs
                    if node.children == ["Sink"]:
                        for p in node.parents:
                            if p.outDataType == "model":
                                child_node = p
                                break
                        dst = get_dest(node.pe, child_node.pe, pe_per_pu, node)
                        #dst.dest_node_id = child_node.id # doesn't really matter here
                        dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                        #dests.append(dst)
                        # for i in range(3 - len(dests)):
                        #     dests.append(Dest(namespace='NL', index='0'))
                        inst = Inst(node.op, dsts, srcs)
                        #inst.dests = dsts
                        #inst.srcs = srcs
                        #inst.op = node.op
                        node.pe.add_inst(inst)
                        node.inst.append(inst)
                        continue
                    else:
                        childnode = node.children[0] # because children's always a list
                        targetns = determine_target_ns(node.pe, childnode.pe, node)
                        if targetns == "NB1":
                            headpe = node.pe.pu.head_pe
                            # STEP 1: send to representative pe
                            if node.pe != headpe:
                                dst = get_dest(node.pe, headpe, pe_per_pu)
                                dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                                inst = Inst(node.op, dsts, srcs)
                                node.pe.add_inst(inst)
                                node.inst.append(inst)
                                parentpe_rightbefore = node.pe
                            # STEP 2: send from src repr to target repr pe
                            target_headpe = childnode.pe.pu.head_pe
                            dst = get_dest(headpe, target_headpe, pe_per_pu) # first need to send to repr target pe
                            dst.dest_node_id = childnode.id if childnode.pe == target_headpe else None
                            dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                            if headpe != node.pe: # if data already has been sent from original pe to repr pe
                                if headpe == node.pe.next:
                                    src = Source(namespace="NN", index=str(parentpe_rightbefore.id) + "0") # id of pe where data originally came from
                                else:
                                    src = Source(namespace="NB", index=str(parentpe_rightbefore.id) + "0") # id of pe where data originally came from
                                srcs = [src, Source(namespace="NL", index='0'), Source(namespace="NL", index='0')]
                                inst = Inst("pass", dsts, srcs)
                                headpe.add_inst(inst)
                                node.inst.append(inst)
                            else:
                                inst = Inst(node.op, dsts, srcs)
                                headpe.add_inst(inst)
                                node.inst.append(inst)
                                parentpe_rightbefore = headpe
                            # STEP 3: send from repr pe to target repr
                            if childnode.pe != target_headpe:
                                dst = get_dest(target_headpe, childnode.pe, pe_per_pu)
                                dst.dest_node_id = childnode.id
                                dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                                src = Source(namespace="NB", index=str(parentpe_rightbefore.id) + "1") # id of pe where data originally came from
                                srcs = [src, Source(namespace="NL", index='0'), Source(namespace="NL", index='0')]
                                inst = Inst("pass", dsts, srcs)
                                target_headpe.add_inst(inst)
                                node.inst.append(inst)
                        else: # No PU bus invovled
                            if targetns == "NB0" or targetns == "NN0":
                                dst = get_dest(node.pe, childnode.pe, pe_per_pu)
                            else:
                                dst = get_dest(node.pe, childnode.pe, pe_per_pu, node)
                            dst.dest_node_id = childnode.id
                            dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                            inst = Inst(node.op, dsts, srcs)
                            node.pe.add_inst(inst)
                            node.inst.append(inst)
            #print("DEBUG ", node.id, " ", pe_list[3])
        cycl += 1
        nodes = node_graph.get_nodes_in_cycle(cycl)
        

def determine_target_ns(curr_pe, target_pe, node=None):
    if curr_pe == target_pe:
        return data_type_to_ns[node.outDataType]
    elif curr_pe.next == target_pe:
        return "NN0" # PE Neighbor
    elif curr_pe.pu == target_pe.pu:
        return "NB0" # PE bus
    #elif curr_pe.pu.next == target_pe.pu:
        #return "NN1" # PU neighbor
    else:
        return "NB1" # PU bus
    
    
def find_internal_dest(first_dests):
    for dest in first_dests:
        if dest.namespace != "NN" and dest.namespace != "NB":
            return dest
                
def multicast(node, pe_per_pu):
    cycle = 0
    curr_pe = node.pe
    pool = [(child_node.pe, child_node) for child_node in node.children]
    dests_by_cycle = []
    internal_dest = None
    while len(pool) > 0:
        used_ns = []
        for entry in pool: # FIRST, build up the first 3 dests
            target_pe = entry[0]
            ns = determine_target_ns(curr_pe, target_pe)
            if ns in used_ns:
                continue
            if len(dests_by_cycle) < 3:
                if len(dests_by_cycle) == 2:
                    if len(pool) == 1:
                        dests_by_cycle.append(entry)
                        pool.remove(entry)
                else:
                    dests_by_cycle.append(entry)
                    pool.remove(entry)
        if len(pool) > 0:
            out_data_type = node.outDataType
            namespace_id = data_type_to_ns[out_data_type]
            namespace = node.pe.namespace_map[namespace_id]
            if namespace.tail >= 0:
                index = namespace.tail
            else:
                raise Exception("namespace full")
            namespace.insert(namespace.tail, Ns_entry()) # dummy insertion to keep track of the free index in the namespace
            d = Dest(namespace_id, str(index), node.id)
            dests_by_cycle.append(d)
            internal_dest = d
        for i in range(3 - len(dests_by_cycle)):
            dests_by_cycle.append(Dest(namespace='NL', index='0'))

        # print("DEBUG")
        # for d in dests_by_cycle:
        #     if not isinstance(d, Dest):
        #         print(d[0].id)
        #     else:
        #         print(d)
        # print("***")

        pu_pu_comm = False # initializing it to false
        for entry in dests_by_cycle: # THEN, see if there's any pu-pu communication
            if not isinstance(entry, Dest):
                target_pe = entry[0]
                target_node = entry[1]
                ns = determine_target_ns(curr_pe, target_pe)
                if ns == "NB1": # there is a pu-pu communication
                    pu_pu_comm = True
                    target = target_pe
                    break
        if pu_pu_comm:
            if cycle == 0:
                srcs = []
                for parent_node in node.parents:
                    src = get_src(node, parent_node, pe_per_pu)
                    srcs.append(src)
                for i in range(3 - len(srcs)):
                    srcs.append(Source(namespace='NL', index='0'))
            else:
                srcs = [Source(namespace=d.namespace, index=d.index), Source(namespace='NL', index='0'), Source(namespace='NL', index='0')]
            headpe = curr_pe.pu.head_pe
            # first send to representative pe
            if curr_pe != headpe:
                for i, entry in enumerate(dests_by_cycle):
                    if not isinstance(entry, Dest):
                        dst = entry[0] # pe
                        ns = determine_target_ns(curr_pe, dst)
                        if ns == "NB1":
                            dst = get_dest(curr_pe, headpe, pe_per_pu)
                            #dst.dest_node_id = entry[1].id
                            dests_by_cycle[i] = dst
                            parentpe_rightbefore = curr_pe
                            #print(dests_by_cycle[i])
                        elif ns == "NB0" or ns == "NN0":
                            # if dst == headpe: # if already taken care of
                            #     dests_by_cycle[i] = Dest(namespace='NL', index='0')
                            #     continue
                            dst = get_dest(curr_pe, dst, pe_per_pu)
                            dst.dest_node_id = entry[1].id
                            dests_by_cycle[i] = dst
                            #print(dests_by_cycle[i])
                        else:
                            dst = get_dest(curr_pe, dst, pe_per_pu, node)
                            dst.dest_node_id = entry[1].id
                            dests_by_cycle[i] = dst
                if cycle == 0:
                    inst = Inst(node.op, dests_by_cycle, srcs)
                else:
                    inst = Inst("pass", dests_by_cycle, srcs)
                node.pe.add_inst(inst)
                node.inst.append(inst)
                #dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                # if cycle > 0:
                #     inst = Inst(node.op, dests_by_cycle, srcs)
                #     node.pe.add_inst(inst)
                #     node.inst.append(inst)
                # else:
                #     srcs = []
                #     for parent_node in node.parents:
                #         src = get_src(node, parent_node, pe_per_pu)
                #         srcs.append(src)
                #     for i in range(3 - len(srcs)):
                #         srcs.append(Source(namespace='NL', index='0'))
                #     inst = Inst("pass", dests_by_cycle, srcs)
                #     node.pe.add_inst(inst)
                #     node.inst.append(inst)
            # send from src repr to target repr pe
            target_headpe = target.pu.head_pe
            
            if headpe != curr_pe: # if data already has been sent from original pe to repr pe
                if headpe == curr_pe.next:
                    src = Source(namespace="NN", index=str(parentpe_rightbefore.id) + "0") # id of pe where data originally came from
                else:
                    src = Source(namespace="NB", index=str(parentpe_rightbefore.id) + "0") # id of pe where data originally came from
                srcs = [src, Source(namespace="NL", index='0'), Source(namespace="NL", index='0')]
                dst = get_dest(headpe, target_headpe, pe_per_pu) # first need to send to repr target pe
                dst.dest_node_id = target_node.id if target == target_headpe else None
                dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                inst = Inst("pass", dsts, srcs)
                headpe.add_inst(inst)
                node.inst.append(inst)
                parentpe_rightbefore = headpe
            else:
                for entry in dests_by_cycle:
                    if not isinstance(entry, Dest):
                        dst = entry[0]
                        ns = determine_target_ns(curr_pe, dst)
                        if ns == "NB1":
                            dst = get_dest(curr_pe, headpe, pe_per_pu)
                            dst.dest_node_id = target_node.id if target == target_headpe else None
                            dests_by_cycle[i] = dst
                            parentpe_rightbefore = headpe
                        elif ns == "NB0" or ns == "NN0":
                            dst = get_dest(curr_pe, dst, pe_per_pu)
                            dst.dest_node_id = target_node.id if target == target_headpe else None
                            dests_by_cycle[i] = dst
                        else:
                            dst = get_dest(curr_pe, dst, pe_per_pu, node)
                            dst.dest_node_id = target_node.id if target == target_headpe else None
                            dests_by_cycle[i] = dst
                inst = Inst(node.op, dests_by_cycle, srcs)
                headpe.add_inst(inst)
                node.inst.append(inst)
            # if cycle == 0:
            #     print(headpe.id)
            #     print(inst)
            # send from repr pe to target repr
            if target != target_headpe:
                dst = get_dest(target_headpe, target, pe_per_pu)
                dst.dest_node_id = target_node.id
                dsts = [dst, Dest(namespace="NL", index='0'), Dest(namespace="NL", index='0')]
                src = Source(namespace="NB", index=str(parentpe_rightbefore.id) + "1") # id of pe where data originally came from
                srcs = [src, Source(namespace="NL", index='0'), Source(namespace="NL", index='0')]
                inst = Inst("pass", dsts, srcs)
                target_headpe.add_inst(inst)
                node.inst.append(inst)
            cycle += 1
            dests_by_cycle = []
            continue # back to while loop
        else: # no pu-pu communication - NEED to be fixed
            srcs = []
            dests = []
            if cycle > 0:
                op = "pass"
                latest_inst = curr_pe.get_inst()
                internal_dest = find_internal_dest(latest_inst.dests)
                src_for_pass = Source(internal_dest.namespace, internal_dest.index)
                srcs = [src_for_pass, Source(namespace='NL', index='0'), Source(namespace='NL', index='0')]
            else:
                op = node.op
                for parent_node in node.parents:
                    src = get_src(node, parent_node, pe_per_pu)
                    srcs.append(src)
                for i in range(3 - len(srcs)):
                    srcs.append(Source(namespace='NL', index='0'))
            for entry in dests_by_cycle:
                if isinstance(entry, Dest):
                    dst = entry
                else:
                    dst_pe = entry[0]
                    dst = get_dest(curr_pe, dst_pe, pe_per_pu)
                    dst.dest_node_id = entry[1].id
                dests.append(dst)
            inst = Inst(op, dests, srcs)
            curr_pe.add_inst(inst)
            node.inst.append(inst)
            cycle += 1
            dests_by_cycle = []
    return


def in_use(entry, dests):
    ns = entry.namespace
    for dest in dests:
        if ns == "NN" or ns == "NB":
            if dest.namespace == ns and entry.index[-1] == dest.index[-1]:
                return True
        else:
            if dest.namespace == ns:
                return True
    return False

#def get_dest(node, child_node, pe_per_pu):
def get_dest(curr_pe, child_pe, pe_per_pu, node=None):
    #curr_pe = node.pe
    #child_pe = child_node.pe
    if curr_pe.id == child_pe.id:
        out_data_type = node.outDataType
        namespace_id = data_type_to_ns[out_data_type]
        namespace = curr_pe.namespace_map[namespace_id]
        if namespace.tail >= 0:
            index = namespace.tail
        else:
            raise Exception("namespace full")
        namespace.insert(namespace.tail, Ns_entry()) # dummy insertion just to keep track of the free index in the namespace
        return Dest(namespace_id, str(index))
    elif curr_pe.pu == child_pe.pu:
        if curr_pe.next == child_pe:
            namespace = curr_pe.namespace_map["NN0_out"]
            namespace.insert(namespace.tail, Ns_entry())
            return Dest("NN", str(child_pe.id) + "0")  # Neighbor PE: NN[0]
        else:  # non-immediate neighbors in the same PU
            namespace = curr_pe.namespace_map["NB0_out"]
            namespace.insert(namespace.tail, Ns_entry())
            return Dest("NB", str(child_pe.id) + "0") # PE bus: NB[0]
    else:
        namespace = curr_pe.namespace_map["NB1_out"]
        namespace.insert(namespace.tail, Ns_entry())
        return Dest("NB", str(child_pe.id) + "1")


def get_src(node, parent_node, pe_per_pu):
    node_insts = parent_node.inst
    for inst in node_insts:
        set_of_dests = inst.dests
        for dest in set_of_dests:
            if dest.dest_node_id == node.id:
                # if node.id == 17:
                #     print(dest)
                #     print("***")
                ns = dest.namespace
                if ns == "NB" or ns == "NN":
                    if node.id == 14:
                        print(parent_node.pe.id)
                    src_pe = find_src_pe(node.pe, parent_node.pe)
                    #return Source(dest.namespace, str(parent_node.pe.id) + dest.index[-1]) # NEED TO FIX INDEX
                    return Source(dest.namespace, str(src_pe.id) + dest.index[-1])
                else:
                    if dest.namespace == "NM":
                        ns = node.pe.namespace_map[dest.namespace]
                    else:
                        ns = parent_node.pe.namespace_map[dest.namespace]
                    ns.get(int(dest.index)) # dummy get() to free up space
                    return Source(dest.namespace, dest.index)

def find_src_pe(node_pe, parent_node_pe):
    # assuming these are different pes
    if node_pe.pu != parent_node_pe.pu:
        if node_pe == node_pe.pu.head_pe:
            return parent_node_pe.pu.head_pe
        else:
            return node_pe.pu.head_pe
    else:
        return parent_node_pe
    

pe_used = {}

def readFrom(path):
    with open(path, 'r') as f:
        contents = f.read()
    f.close()
    id2node = json.loads(contents)
    node_graph = NodeGraph()
    for id in id2node:
        node = id2node[id]
        new_node = Node(
            id = node["id"],
            op = node["op"],
            cycle = node["cycle"],
            outDataType = node["outDataType"]
        )
        if node["parents"] != ["Source"]:
            new_node.parents = [parent["id"] for parent in node["parents"]]
        else:
            new_node.parents = node["parents"]
        if node["children"] != ["Sink"]:
            new_node.children = [children["id"] for children in node["children"]]
        else:
            new_node.children = node["children"]
        if node["pe"] is not None:
            pe_id = node["pe"]["pe_id"]
            ns_size = node["pe"]["ns_size"]
            ns_int_size = node["pe"]["ns_int_size"]
            if pe_id in pe_used:
                new_node.pe = pe_used[pe_id]
            else:
                pe = Pe(id=pe_id, ns_size=ns_size, ns_int_size=ns_int_size)
                pe_used[pe_id] = pe
                new_node.pe = pe
        else:
            new_node.pe = node["pe"]
        node_graph.add(new_node)
    node_graph.set_parents_and_children()
    return node_graph

def writeTo(pe_to_inst):
    filenames = []
    for pe_id in pe_to_inst:
        insts = pe_to_inst[pe_id]
        inst_list = []
        for inst in insts:
            inst_list.append({"cycle": inst["cycle"], "inst": inst["inst"].toDict()})
        if not os.path.exists("./inst/"):
            os.makedirs("./inst/")
        filename = "./inst/pe{:d}inst.json".format(pe_id)
        with open(filename, 'w') as f:
            f.write(json.dumps(inst_list, sort_keys=True, indent=2))
        f.close()
        filenames.append(filename)
    return filenames


# WON'T be needing this anymore
def add_nop(pe_to_inst):
    max_cycle = 0
    for pe_id in pe_to_inst:
        insts = pe_to_inst[pe_id]
        pe_max_cycle = 0
        for inst in insts:
            if inst["cycle"] > pe_max_cycle:
                pe_max_cycle = inst["cycle"]
        if pe_max_cycle > max_cycle:
            max_cycle = pe_max_cycle
    for pe_id in pe_to_inst:
        insts_with_nop = [None] * max_cycle
        insts = pe_to_inst[pe_id]
        for inst in insts:
            cycle = inst["cycle"]
            insts_with_nop[cycle - 1] = inst
        for curr_cycle in range(max_cycle):
            if insts_with_nop[curr_cycle] is None:
                nop = Inst(op="NOP")
                insts_with_nop[curr_cycle] = {"cycle": curr_cycle + 1, "inst": nop}
        pe_to_inst[pe_id] = insts_with_nop
    return pe_to_inst


if __name__ == "__main__":
    pe_per_pu = 4
    node_graph = readFrom("nodes_ir.json")
    generate_inst(node_graph, pe_per_pu)
    pe_to_inst = node_graph.separate_inst_by_pe()
    add_nop(pe_to_inst)
    writeTo(pe_to_inst)
