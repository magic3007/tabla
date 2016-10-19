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
        #d["srcs"] = [src.toDict() for src in self.srcs] if self.srcs is not None else None
        if self.srcs is not None:
            s = []
            for src in self.srcs:
                if src is not None:
                    s.append(src.toDict())
                else:
                    emptysrc = Source('NL', 0)
                    s.append(emptysrc.toDict())
            d["srcs"] = s
        else:
            d["srcs"] = None
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


def generate_inst(node_graph, pe_per_pu):
    '''
    For each node in dfg, generate an instruction.
    An instruction consists of opcode, dests, and srcs.
    Each dest and src consists of namespace id and index.
    This function calls the multicast function; when a node sends
    data to mutliple chidlren, target nodes with same namespace
    can't be sent at the same time, so those have to be done 
    in different cycles.
    When destination PE is in a different PU, it has to go through
    multiple steps: first send to it's own representative PE, 
    then send to the representative PE in the target PU, then finally
    send to the target PE.
    '''
    cycl = 0
    nodes = node_graph.get_nodes_in_cycle(cycl)
    while len(nodes) > 0:
        for node in nodes:
            if node.parents == ["Source"]: # initial data nodes
                inst = Inst()
                dests = []
                if node.pe is None: # constants without pe assignment
                    namespace_id = data_type_to_ns[node.outDataType]
                    for child in node.children:
                        namespace = child.pe.namespace_map[namespace_id]
                        index = namespace.tail
                        namespace.insert(namespace.tail, Ns_entry())
                        dests.append(Dest(namespace_id, str(index), child.id))
                    inst.dests = dests
                    node.inst.append(inst)
                else:
                    namespace_id = data_type_to_ns[node.outDataType]
                    namespace = node.pe.namespace_map[namespace_id]
                    index = namespace.tail
                    namespace.insert(namespace.tail, Ns_entry())
                    for child in node.children:
                        dests.append(Dest(namespace_id, str(index), child.id))
                    inst.dests = dests
                    node.inst.append(inst)
            else: # non-source nodes
                if len(node.children) > 1: # multiple target PEs
                    #multicast(node, pe_per_pu)
                    dest_pes = [c.pe for c in node.children]
                    src_pes = [p.pe for p in node.parents]
                    source = None
                    for p in node.parents:
                        if p.pe.id == node.pe.id:
                            source = get_src(node, p, 8)
                    multicast(node.pe, dest_pes, src_pes, node.op, source)
                    # continue to next iteration
                else: # single target PE
                    srcs = []
                    for parent_node in node.parents:
                        # TODO: kind of a quick fix...
                        if len(parent_node.children) > 1 and parent_node.parents != ['Source']: # multicasting happend
                            src = get_src_multicast(node.pe, parent_node.pe)
                        else:
                            src = get_src(node, parent_node, pe_per_pu)
                        srcs.append(src)
                    fill_null(srcs, isdst=False)
                    if node.children == ["Sink"]: # if child is sink, set child to model(w) node
                        for p in node.parents:
                            if p.outDataType == "model":
                                child_node = p
                                model_parent = p
                                break
                        #dst = get_dest(node.pe, child_node.pe, pe_per_pu, node)
                        index = model_parent.inst[0].dests[0].index
                        dst = Dest("NW", str(index))
                        dests = []
                        dests.append(dst)
                        fill_null(dests, isdst=True)
                        inst = Inst(node.op, dests, srcs)
                        node.pe.add_inst(inst)
                        node.inst.append(inst)
                        continue # move on to next node instr generation
                    else:
                        childnode = node.children[0] # children is always type list
                        targetns = determine_target_ns(node.pe, childnode.pe, node)
                        if targetns == "NB1" or targetns == 'NN1': # e.g. a PE in some PU to another PE in different PU - 3 steps needed
                            headpe = node.pe.pu.head_pe
                            # STEP 1: send to representative pe
                            if node.pe != headpe:
                                dst = get_dest(node.pe, headpe, pe_per_pu)
                                dsts = []
                                dsts.append(dst)
                                fill_null(dsts, isdst=True)
                                inst = Inst(node.op, dsts, srcs)
                                node.pe.add_inst(inst)
                                node.inst.append(inst)
                                parentpe_imm = node.pe

                            # STEP 2: send from src repr PE to target repr PE
                            target_headpe = childnode.pe.pu.head_pe
                            ''' Fix: Inter-PU communication needs PU ID instead of PE ID
                            dst = get_dest(headpe, target_headpe, pe_per_pu) # first need to send to repr target pe
                            '''
                            if headpe.pu.next_pu.id == target_headpe.pu.id:
                                namespace = headpe.namespace_map["NB0_out"]
                                namespace.insert(namespace.tail, Ns_entry())
                                dst = Dest("NN", str(target_headpe.pu.id) + "1")
                            else:
                                namespace = headpe.namespace_map["NB1_out"]
                                namespace.insert(namespace.tail, Ns_entry())
                                dst = Dest("NB", str(target_headpe.pu.id) + "1")
                            
                            dst.dest_node_id = childnode.id if childnode.pe.id == target_headpe.id else None
                            dsts = []
                            dsts.append(dst)
                            fill_null(dsts, isdst=True)
                            if headpe.id != node.pe.id: # if data already has been sent from original pe to repr pe
                                if headpe.id == node.pe.next.id:
                                    src = Source(namespace="NN", index=str(parentpe_imm.id) + "0") # id of pe where data originally came from
                                else:
                                    src = Source(namespace="NB", index=str(parentpe_imm.id) + "0") # id of pe where data originally came from
                                srcs = []
                                srcs.append(src)
                                fill_null(srcs, isdst=False)
                                inst = Inst("pass", dsts, srcs)
                                headpe.add_inst(inst)
                                node.inst.append(inst)
                                parentpu = headpe.pu
                            else:
                                inst = Inst(node.op, dsts, srcs)
                                headpe.add_inst(inst)
                                node.inst.append(inst)
                                parentpe_imm = headpe
                                '''
                                fix: need PU ID
                                '''
                                parentpu = parentpe_imm.pu

                            # STEP 3: send from repr pe to target pe
                            if childnode.pe != target_headpe:
                                dst = get_dest(target_headpe, childnode.pe, pe_per_pu)
                                dst.dest_node_id = childnode.id
                                dsts  = []
                                dsts.append(dst)
                                fill_null(dsts, isdst=True)
                                if parentpu.next_pu.id == childnode.pe.pu.id:
                                    src = Source(namespace="NB", index=str(parentpu.id) + "0")
                                else:
                                    src = Source(namespace="NB", index=str(parentpu.id) + "1") # id of pe where data originally came from
                                srcs = []
                                srcs.append(src)
                                fill_null(srcs, isdst=False)
                                inst = Inst("pass", dsts, srcs)
                                target_headpe.add_inst(inst)
                                node.inst.append(inst)
                        else: # No inter-PU communication invovled
                            if targetns == "NB0" or targetns == "NN0":
                                dst = get_dest(node.pe, childnode.pe, pe_per_pu)
                            else:
                                dst = get_dest(node.pe, childnode.pe, pe_per_pu, node)
                            dst.dest_node_id = childnode.id
                            dsts = []
                            dsts.append(dst)
                            fill_null(dsts, isdst=True)
                            inst = Inst(node.op, dsts, srcs)
                            node.pe.add_inst(inst)
                            node.inst.append(inst)

        cycl += 1
        nodes = node_graph.get_nodes_in_cycle(cycl)


def get_src_multicast(curr_pe, parent_pe):
    '''
    Get source instruction for one of the target nodes from 
    a multicast
    '''
    if curr_pe.pu.id == parent_pe.pu.id:
        namespace = get_ns(parent_pe, curr_pe)
        index = str(parent_pe.id) + namespace[-1]
    elif curr_pe.isrepr():
        latest_inst = curr_pe.inst[-1]
        for src in latest_inst.srcs:
            if src.namespace == 'NI':
                return src
        # parent_repr = parent_pe.pu.head_pe
        # namespace = get_ns(parent_repr, curr_pe)
        # index = str(parent_repr.pu.id) + namespace[-1]
    else:
        namespace = get_ns(curr_pe.pu.head_pe, curr_pe)
        index = str(curr_pe.pu.head_pe.id) + namespace[-1]

    return Source(namespace[:-1], index)


def multicast(curr_pe, dest_pes, src_pes, op, source):
    grouped = group_pes_to_pus(dest_pes) # PU to PE mapping

    need_interpu = False
    if len(grouped) > 1 or len(grouped) == 1 and curr_pe.pu not in grouped:
        need_interpu = True

    repr_src = src_pes
    # first, send data to the PE's in this PU
    if curr_pe.pu in grouped:
        repr_src = within_pu(curr_pe, grouped[curr_pe.pu], src_pes, need_interpu, op, source)
        op = 'pass'
    elif need_interpu and not curr_pe.isrepr:
        repr_src = within_pu(curr_pe, [curr_pe.pu.head_pe], src_pes, need_interpu, op, source)
        op = 'pass'

    # send from repr PE to other repr PE's in other PU's
    if need_interpu:
        repr_pe = curr_pe.pu.head_pe
        target_repr_pus = list(grouped.keys()) # keys() are PU id's
        target_repr_pes = [pu.head_pe for pu in target_repr_pus]

        inter_pu(repr_pe, target_repr_pes, repr_src, op, source)

        # at each repr PE, send to target PE's in its own PU
        for pu in grouped:
            if curr_pe.pu.id == pu.id:
                continue
            within_pu(pu.head_pe, grouped[pu], [repr_pe], False, 'pass', peid_to_puid=True)


def within_pu(curr_pe, dest_pes, src_pes, need_interpu, op, source=None, peid_to_puid=False):
    '''
    Handles multicasting within a single PU.
    Returns namespace and index of source for repr PE.
    '''
    cycle = 0
    dests = [] # PEs

    # send to repr PE, if necessary
    repr_src = None
    # repr_src is the source instruction for representative PE
    if need_interpu and not curr_pe.isrepr():
        dests.append(curr_pe.pu.head_pe)
        if curr_pe.pu.head_pe in dest_pes: # if repr PE already in target PE
            dest_pes.remove(curr_pe.pu.head_pe)
        s = gen_src_insts([curr_pe], curr_pe.pu.head_pe, None, None, 0)
        repr_src = s[0]
        #d = gen_dest_insts(dests, curr_pe)
        #repr_src = d[0]

    # send to interim namesapce, if necessary
    if curr_pe in dest_pes:
        #dests.append(curr_pe)
        dest_pes.remove(curr_pe)
        ni = curr_pe.namespace_map['NI']
        dests.append(Dest('NI', ni.tail))
        ni.insert(ni.tail, Ns_entry())

    while True:
        # fill dests
        select_dests(dest_pes, curr_pe, dests, 'NI', cycle)
        dest_insts = gen_dest_insts(dests, curr_pe)
        if cycle == 0:
            interim = get_interim(dest_insts)
        src_insts = gen_src_insts(src_pes, curr_pe, interim, source, cycle)
        if peid_to_puid:
            format_peid_to_puid(src_insts)

        if cycle == 0:
            opcode = op
        else:
            opcode = 'pass'
        inst = Inst(opcode, dest_insts, src_insts)
        curr_pe.add_inst(inst)
        cycle += 1
        dests = []
        
        if not len(dest_pes) > 0:
            break

    return repr_src


def inter_pu(repr_pe, dest_pes, src_pes, op, source):
    '''
    Handles multicasting among different PU's through repr PE's
    '''
    dests = [] # PU's
    cycle = 0

    if repr_pe in dest_pes:
        dest_pes.remove(repr_pe)
        ni = repr_pe.namespace_map['NI']
        dests.append(Dest('NI', ni.tail))
        ni.insert(ni.tail, Ns_entry())

    while len(dest_pes) > 0:
        select_dests(dest_pes, repr_pe, dests, 'NI', cycle)
        dest_insts = gen_dest_insts(dests, repr_pe)
        format_peid_to_puid(dest_insts)
        interim = get_interim(dest_insts)
        if type(src_pes) == Source:
            src_insts = []
            ns = src_pes.namespace
            index = src_pes.index
            src_insts.append(Source(ns, index))
            fill_null(src_insts, isdst=False)
        else:
            src_insts = gen_src_insts(src_pes, repr_pe, interim, source, cycle)
        if op != 'pass' and cycle == 0:
            opcode = op
        else:
            opcode = 'pass'
        inst = Inst(opcode, dest_insts, src_insts)
        repr_pe.add_inst(inst)
        cycle += 1
        dests = []
    return


def format_peid_to_puid(dest_or_src):
    for entry in dest_or_src:
        if (entry.namespace == 'NN' or entry.namespace == 'NB') and entry.index[-1] == '1':
            peid = int(entry.index[:-1])
            puid = peid // 8
            entry.index = str(puid) + entry.index[-1]
    

def select_dests(dest_pes, src_pe, dests, localns, cycle):
    '''
    From the given target PE's, select up to 3 and fill up
    dests array.
    '''
    if cycle == 0:
        # saves to interim only if necessary
        save_to_interim(dest_pes, src_pe, dests)

    ns_used = []
    for dest_pe in dest_pes[:]:
        ns = get_ns(src_pe, dest_pe)
        if ns not in ns_used:
            ns_used.append(ns)
            dests.append(dest_pe)
            dest_pes.remove(dest_pe)
        if len(dests) == 2:
            if len(dest_pes) == 1 and get_ns(src_pe, dest_pe) not in ns_used:
                dests.append(dest_pe)
                dest_pes.remove(dest_pe)
                break
        if len(dests) == 3:
            break


def save_to_interim(dest_pes, src_pe, dests):
    '''
    Saves data to interim namespace, if necessary.
    '''
    for d in dests:
        if type(d) == Dest:
            return
    #if src_pe in dests:
        #return
    nsmap = {}
    for dest_pe in dest_pes:
        ns = get_ns(src_pe, dest_pe)
        if ns not in nsmap:
            nsmap[ns] = [dest_pe]
        else:
            nsmap[ns].append(dest_pe)

    mult_cycles = False
    for nskey in nsmap:
        if len(nsmap[nskey]) > 1:
            mult_cycles = True

    if len(nsmap) > 3 or mult_cycles:
        interim = src_pe.namespace_map['NI']
        dests.append(Dest('NI', interim.tail))
        interim.insert(interim.tail, Ns_entry())
    return
    

def gen_dest_insts(dests, curr_pe):
    dest_insts = []
    for dest in dests:
        if type(dest) == Dest:
            dest_insts.append(dest)
        else:
            dest_insts.append(get_dest(curr_pe, dest, 8))
    fill_null(dest_insts, isdst=True)
    return dest_insts


def get_interim(dest_insts):
    for dest in dest_insts:
        if dest.namespace == 'NI':
            return dest


def gen_src_insts(src_pes, curr_pe, interim, source, cycle):
    src_insts = []
    if cycle == 0:
        for src_pe in src_pes:
            if src_pe.id == curr_pe.id:
                src_insts.append(source)
            else:
                ns = get_ns(src_pe, curr_pe)
                index = str(src_pe.id) + str(ns[-1])
                src_insts.append(Source(ns[:-1], index))
    else:
        src_insts.append(Source(interim.namespace, interim.index))

    fill_null(src_insts, isdst=False)
    return src_insts


def get_ns(src_pe, dest_pe):
    '''
    assuming two pe's are different
    '''
    if src_pe.next.id == dest_pe.id:
        return 'NN0'
    elif src_pe.pu.id == dest_pe.pu.id:
        return 'NB0'
    elif src_pe.pu.next_pu.id == dest_pe.pu.id:
        return 'NN1'
    else:
        return 'NB1'
    

def group_pes_to_pus(pes):
    '''
    Given a list of PE's, group them by their respective PUs.
    Returns a dict of pu to pe id list.
    '''
    pus = {}
    for pe in pes:
        pu = pe.pu
        if pu not in pus:
            pus[pu] = [pe]
        else:
            pus[pu].append(pe)
    return pus

        
def fill_null(dst_or_src, isdst):
    if isdst:
        for i in range(3 - len(dst_or_src)):
            dst_or_src.append(Dest(namespace='NL', index='0'))
    else:
        for i in range(3 - len(dst_or_src)):
            dst_or_src.append(Source(namespace='NL', index='0'))    

    
def determine_target_ns(curr_pe, target_pe, node):
    if curr_pe.id == target_pe.id:
        return data_type_to_ns[node.outDataType] # same PE
    elif curr_pe.next.id == target_pe.id:
        return "NN0" # PE Neighbor
    elif curr_pe.pu.id == target_pe.pu.id:
        return "NB0" # PE bus
    elif curr_pe.pu.next_pu == target_pe.pu:
        return "NN1" # PU neighbor
    else:
        return "NB1" # PU bus
    
    
def find_internal_dest(first_dests):
    for dest in first_dests:
        if type(dest) != tuple:
            if dest.namespace != "NN" and dest.namespace != "NB":
                return dest


def in_used_pu(pe, dests):
    for dest in dests:
        dest_pe = dest[0] # because it's a tuple
        if dest_pe.pu.id == pe.pu.id:
            return True
    return False
    
                
# def multicast(node, pe_per_pu):
#     '''
#     This function generates instructions for nodes with multiple chidlren.
#     The issue is that currently the hardware doesn't allow two of the same
#     namespace data to be sent over the bus. In this case, there needs to be 
#     multiple cycles of instructions generated. For instance, if PE0 is sending
#     data to PE4 and PE5 (both via PE bus), it chooses PE4 first, followed by 
#     PE5 in the next cycle.
#     '''
#     cycle = 0
#     curr_pe = node.pe
#     pool = [(child_node.pe, child_node) for child_node in node.children]
#     dests_by_cycle = []
#     internal_dest = None
#     while len(pool) > 0:
#         used_ns = []
#         for entry in pool: # FIRST, build up the first 3 dests
#             target_pe = entry[0]
#             print("cycle: ", cycle, "target pe: ", target_pe.id)
#             print("in_used_pu({:d}) returns: ".format(target_pe.id), in_used_pu(target_pe, dests_by_cycle))
#             ns = determine_target_ns(curr_pe, target_pe, node)
#             print("target ns: ", ns)
#             if ns in used_ns:
#                 continue
#             if in_used_pu(target_pe, dests_by_cycle):
#                 continue
#             if len(dests_by_cycle) < 3:
#                 if len(dests_by_cycle) == 2:
#                     if len(pool) == 1: # if there's only one target left, just put it here
#                         dests_by_cycle.append(entry)
#                         pool.remove(entry)
#                 else:
#                     dests_by_cycle.append(entry)
#                     pool.remove(entry)
#         print("dest by cycle")
#         # for d in dests_by_cycle:
#         #     print(d[0].id)
#         if len(pool) > 0 and cycle == 0: # if there are more targets left, we need to save the data locally so that it can be used again
#             out_data_type = node.outDataType
#             namespace_id = data_type_to_ns[out_data_type]
#             namespace = node.pe.namespace_map[namespace_id]
#             if namespace.tail >= 0:
#                 index = namespace.tail
#             else:
#                 raise Exception("namespace full")
#             namespace.insert(namespace.tail, Ns_entry()) # dummy insertion to keep track of the free index in the namespace
#             d = Dest(namespace_id, str(index), node.id)
#             dests_by_cycle.append(d)
#             internal_dest = d
#         fill_null(dests_by_cycle, isdst=True)
        

#         interpu_comm = False
#         for entry in dests_by_cycle: # THEN, see if there's any pu-pu communication
#             if type(entry) == tuple:
#                 target_pe = entry[0]
#                 target_node = entry[1]
#                 ns = determine_target_ns(curr_pe, target_pe, node)
#                 if ns == "NB1": # there is a pu-pu communication
#                     interpu_comm = True
#                     target = target_pe
#                     break

#         if interpu_comm:
#             srcs = []
#             if cycle == 0:
#                 for parent_node in node.parents:
#                     src = get_src(node, parent_node, pe_per_pu)
#                     srcs.append(src)
#                 fill_null(srcs, isdst=False)
#             else:
#                 #print(d)
#                 srcs.append(Source(namespace=d.namespace, index=d.index))
#                 fill_null(srcs, isdst=False)

#             headpe = curr_pe.pu.head_pe
#             # FIRST, send to representative pe
#             if curr_pe.id != headpe.id:
#                 for i, entry in enumerate(dests_by_cycle):
#                     if type(entry) == tuple:
#                         dst = entry[0] # pe
#                         ns = determine_target_ns(curr_pe, dst, node)
#                         if ns == "NB1" or ns == "NN1":
#                             dst = get_dest(curr_pe, headpe, pe_per_pu)
#                             dests_by_cycle[i] = dst
#                             parentpe_imm = curr_pe
#                         elif ns == "NB0" or ns == "NN0":
#                             dst = get_dest(curr_pe, dst, pe_per_pu)
#                             dst.dest_node_id = entry[1].id
#                             dests_by_cycle[i] = dst
#                             parentpe_imm = curr_pe
#                         else:
#                             dst = get_dest(curr_pe, dst, pe_per_pu, node)
#                             dst.dest_node_id = entry[1].id
#                             dests_by_cycle[i] = dst
#                 if cycle == 0:
#                     inst = Inst(node.op, dests_by_cycle, srcs)
#                 else:
#                     inst = Inst("pass", dests_by_cycle, srcs)
#                 node.pe.add_inst(inst)
#                 node.inst.append(inst)

#             # SECOND, send from src repr to target repr pe
#             target_headpe = target.pu.head_pe
#             if headpe.id != curr_pe.id: # if data already has been sent from original pe to repr pe
#                 if headpe.id == curr_pe.next.id:
#                     src = Source(namespace="NN", index=str(parentpe_imm.id) + "0") # id of pe where data originally came from
#                 else:
#                     src = Source(namespace="NB", index=str(parentpe_imm.id) + "0") # id of pe where data originally came from
#                 srcs = []
#                 srcs.append(src)
#                 fill_null(srcs, isdst=False)

#                 '''
#                 fix: dest id should be PU ID
#                 '''
#                 #dst = get_dest(headpe, target_headpe, pe_per_pu) # first need to send to repr target pe
#                 if headpe.pu.next_pu.id == target_headpe.pu.id:
#                     namespace = headpe.namespace_map["NB0_out"]
#                     namespace.insert(namespace.tail, Ns_entry())
#                     dst = Dest("NN", str(target_headpe.pu.id) + "1")
#                 else:
#                     namespace = headpe.namespace_map["NB1_out"]
#                     namespace.insert(namespace.tail, Ns_entry())
#                     dst = Dest("NB", str(target_headpe.pu.id) + "1")
#                 dst.dest_node_id = target_node.id if target == target_headpe else None
#                 dsts = []
#                 dsts.append(dst)
#                 fill_null(dsts, isdst=True)

#                 inst = Inst("pass", dsts, srcs)
#                 headpe.add_inst(inst)
#                 node.inst.append(inst)
#                 parentpe_imm = headpe
#                 parentpu = parentpe_imm.pu
#             else:
#                 for i, entry in enumerate(dests_by_cycle):
#                     if type(entry) == tuple:
#                         dst = entry[0]
#                         ns = determine_target_ns(curr_pe, dst, node)
#                         print("dest pe: {:d}, ns: ".format(dst.id), ns)
#                         if ns == "NB1" or "NN1":
#                             '''
#                             fix: dest ID should be PU ID
#                             '''
#                             #dst = get_dest(curr_pe, headpe, pe_per_pu, node)
#                             #if dst.pu.next_pu.id == target_headpe.pu.id:
#                             '''
#                             if curr_pe.pu.next_pu.id == target_headpe.pu.id:
#                                 namespace = dst.namespace_map["NB0_out"]
#                                 namespace.insert(namespace.tail, Ns_entry())
#                                 dst = Dest("NB", str(target_headpe.pu.id) + "0")
#                             else:
#                                 namespace = dst.namespace_map["NB1_out"]
#                                 namespace.insert(namespace.tail, Ns_entry())
#                                 dst = Dest("NB", str(target_headpe.pu.id) + "1")
#                             '''
#                             dst = Dest(ns[:-1], str(dst.pu.id) + ns[-1])
                            
#                             dst.dest_node_id = target_node.id if target == target_headpe else None
#                             dests_by_cycle[i] = dst
#                             parentpe_imm = headpe
#                             parentpu = parentpe_imm.pu
#                         elif ns == "NB0" or ns == "NN0":
#                             dst = get_dest(curr_pe, dst, pe_per_pu, node)
#                             dst.dest_node_id = target_node.id if target == target_headpe else None
#                             dests_by_cycle[i] = dst
#                         else:
#                             dst = get_dest(curr_pe, dst, pe_per_pu, node)
#                             dst.dest_node_id = target_node.id if target == target_headpe else None
#                             dests_by_cycle[i] = dst
#                 if cycle > 0:
#                     inst = Inst("pass", dests_by_cycle, srcs)
#                 else:
#                     inst = Inst(node.op, dests_by_cycle, srcs)
#                 headpe.add_inst(inst)
#                 node.inst.append(inst)

#             # THIRD
#             if target != target_headpe:
#                 dst = get_dest(target_headpe, target, pe_per_pu)
#                 dst.dest_node_id = target_node.id
#                 dsts = []
#                 dsts.append(dst)
#                 fill_null(dsts, isdst=True)

#                 if parentpu.next_pu.id == target_headpe.pu.id:
#                     src = Source(namespace="NB", index=str(parentpu.id) + "0")
#                 else:
#                     src = Source(namespace="NB", index=str(parentpu.id) + "1") # id of pe where data originally came from
#                 srcs = []
#                 srcs.append(src)
#                 fill_null(srcs, isdst=False)

#                 inst = Inst("pass", dsts, srcs)
#                 target_headpe.add_inst(inst)
#                 node.inst.append(inst)
#             cycle += 1
#             dests_by_cycle = []
#             continue # back to while loop

#         else: # no pu-pu communication - need to be fixed?
#             srcs = []
#             dests = []
#             if cycle > 0:
#                 op = "pass"
#                 latest_inst = curr_pe.get_inst()
#                 internal_dest = find_internal_dest(latest_inst.dests)
#                 src_for_pass = Source(internal_dest.namespace, internal_dest.index)
#                 srcs = []
#                 srcs.append(src_for_pass)
#                 fill_null(srcs, isdst=False)
#             else:
#                 op = node.op
#                 for parent_node in node.parents:
#                     src = get_src(node, parent_node, pe_per_pu)
#                     srcs.append(src)
#                 fill_null(srcs, isdst=False)
#             for entry in dests_by_cycle:
#                 if isinstance(entry, Dest):
#                     dst = entry
#                 else:
#                     dst_pe = entry[0]
#                     dst = get_dest(curr_pe, dst_pe, pe_per_pu, node)
#                     dst.dest_node_id = entry[1].id
#                 dests.append(dst)
#             inst = Inst(op, dests, srcs)
#             curr_pe.add_inst(inst)
#             node.inst.append(inst)

#             cycle += 1
#             dests_by_cycle = []
#     return


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
    '''
    This function returns a Dest object required in a valid instruction.
    Given current PE id and target PE id, it determines the namespace id
    and the index in the namespace.
    '''
    if curr_pe.id == child_pe.id: # no inter-PE communication required
        namespace_id = data_type_to_ns[node.outDataType]
        namespace = curr_pe.namespace_map[namespace_id]
        #if namespace.tail >= 0:
        if namespace.isfull():
            raise Exception("namespace full")
        else:
            index = namespace.tail
        namespace.insert(namespace.tail, Ns_entry()) # dummy insertion just to keep track of the free index in the namespace
        return Dest(namespace_id, str(index))
    elif curr_pe.pu.id == child_pe.pu.id: # inter-PE communication
        if curr_pe.next.id == child_pe.id:
            namespace = curr_pe.namespace_map["NN0_out"]
            namespace.insert(namespace.tail, Ns_entry())
            return Dest("NN", str(child_pe.id) + "0")  # Neighbor PE: NN[0]
        else:  # non-immediate neighbors in the same PU
            namespace = curr_pe.namespace_map["NB0_out"]
            namespace.insert(namespace.tail, Ns_entry())
            return Dest("NB", str(child_pe.id) + "0") # PE bus: NB[0]
    else: # inter-PU communication - only time this is called is sending between two representative PEs
        if curr_pe.pu.next_pu.id == child_pe.pu.id:
            namespace = curr_pe.namespace_map["NB0_out"]
            namespace.insert(namespace.tail, Ns_entry())
            return Dest("NN", str(child_pe.id) + "1")
        else:
            namespace = curr_pe.namespace_map["NB1_out"]
            namespace.insert(namespace.tail, Ns_entry())
            return Dest("NB", str(child_pe.id) + "1")


def get_src(node, parent_node, pe_per_pu):
    node_insts = parent_node.inst
    for inst in node_insts:
        for dest in inst.dests:
            if type(dest) == tuple:
                continue
            if dest.dest_node_id == node.id:
                ns = dest.namespace
                if ns == "NB" or ns == "NN":
                    if dest.index[-1] == '1':
                        src_pu = find_src_pe(node.pe, parent_node.pe)
                        return Source(dest.namespace, str(src_pu.id) + dest.index[-1])
                    elif dest.index[-1] == '0':
                        src_pe = find_src_pe(node.pe, parent_node.pe)
                        return Source(dest.namespace, str(src_pe.id) + dest.index[-1])
                else:
                    if dest.namespace == "NM":
                        ns = node.pe.namespace_map[dest.namespace]
                    else:
                        ns = parent_node.pe.namespace_map[dest.namespace]
                    #ns.get(int(dest.index)) # dummy get() to free up space
                    return Source(dest.namespace, dest.index)


def find_src_pe(node_pe, parent_node_pe):
    # assuming these are different pes
    if node_pe.pu != parent_node_pe.pu:
        if node_pe == node_pe.pu.head_pe:
            #return parent_node_pe.pu.head_pe
            return parent_node_pe.pu
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


if __name__ == "__main__":
    pe_per_pu = 4
    node_graph = readFrom("nodes_ir.json")
    generate_inst(node_graph, pe_per_pu)
    pe_to_inst = node_graph.separate_inst_by_pe()
    add_nop(pe_to_inst)
    writeTo(pe_to_inst)
