import json
from collections import OrderedDict
from pe import Pe

class Node:
    def __init__(self, id=None, op=None, cycle=None, pe=None, parents=None,
                 children=None, parent_pes=None, children_pes=None, inDataType=None,
                 outDataType=None, inst=None):
        self.id = id
        self.op = op
        self.cycle = cycle
        self.pe = pe
        self.parents = []
        self.children = []
        self.parent_pes = []
        self.children_pes = []
        self.inDataType = []
        self.outDataType = []
        #self.inst = inst
        self.inst = []
        self.cycle_offset = 0

    def writeTo(self, path):
        with open(path, 'w') as f:
            f.write(self.__str__())

    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)
    
    def toDict(self):
        d = {}
        d["id"] = self.id
        d["op"] = self.op
        d["cycle"] = self.cycle
        d["inDataType"] = self.inDataType
        d["outDataType"] = self.outDataType
        d["parents"] = self.toList(self.parents)
        d["children"] = self.toList(self.children)
        if self.inst is not None:
            d["inst"] = [i.toDict() for i in self.inst]
        else:
            d["inst"] = None
        if self.pe is not None:
            d["pe"] = self.pe.toDict()
        else:
            d["pe"] = None
        return d

    def toList(self, neighbor_nodes):
        neighbor_list = []
        for node in neighbor_nodes:
            if type(node) is int or type(node) is str:
                neighbor_list.append(node)
            else:
                d = {
                    "id": node.id,
                    "op": node.op,
                    "outDataType": node.outDataType
                }
                if node.pe is not None:
                    d["pe"] = node.pe.toDict()
                else:
                    d["pe"] = None
                neighbor_list.append(d)
        return neighbor_list
    
    def inherit_parent_pe(self):
        priority = {
            "model_input": 5,
            "model_output": 5,
            "model": 5,
            None: 3,
            "gradient": 4,
            "constant": 2
        }
        parents = self.parents
        if len(parents) == 1:
            self.pe = parents[0].pe
            return
        parent0 = parents[0]
        parent1 = parents[1]
        parent0_priority = priority[parent0.outDataType]
        parent1_priority = priority[parent1.outDataType]
        if parent0_priority == parent1_priority:
            if parent0.pe.id <= parent1.pe.id:
                self.pe = parent0.pe
            else:
                self.pe = parent1.pe
        else:
            if parent0_priority > parent1_priority:
                self.pe = parent0.pe                
            else:
                self.pe = parent1.pe
        
    def set_parent_pes(self, node, nodes):
        parents_node = []    # list of parent nodes
        parent_pes = []

        parents_node = self.searchParentsFrom(node, nodes)
        for parent in parents_node:
            parent_pes.append(parent.pe)
        return parent_pes

    def set_children_pes(nodes):    # can't find out until second pass
        for node in nodes:
            children = node.child
            for child_id in children:
                for child_node in nodes:
                    if child_id == child_node.id:
                        child_pe = child_node.pe
                        node.children_pes.append(child_pe)
    

class NodeGraph:
    def __init__(self):
        self.nodes = {}
        self.size = 0

    def add(self, node):
        self.nodes[node.id] = node
        self.size += 1

    def get(self, node_id):
        if node_id in self.nodes:
            return self.nodes[node_id]
        else:
            return None

    def get_max_cycle(self):
        max_cycle = 0
        for node_id in self.nodes:
            node = self.nodes[node_id]
            if node.cycle > max_cycle:
                max_cycle = node.cycle
        return max_cycle

    def set_parents_and_children(self):
        """
        For each node, sets the parents to reference to the actual node object,
        instead of id number. Same for children.
        """
        for node_id in self.nodes:
            node = self.nodes[node_id]
            parent_nodes = []
            for parent_id in node.parents:
                if self.get(parent_id) is not None:
                    parent_node = self.get(parent_id)
                else:
                    parent_node = "Source"
                parent_nodes.append(parent_node)
            node.parents = parent_nodes
            children_nodes = []
            for children_id in node.children:
                if self.get(children_id) is not None:
                    children_node = self.get(children_id)
                else:
                    children_node = "Sink"
                children_nodes.append(children_node)
            node.children = children_nodes

    def separate_inst_by_pe(self):
        pe_to_inst = {} # pe-id to instruction list map
        max_cycle = self.get_max_cycle()
        print("deb",max_cycle)
        for c in range(max_cycle):
            nodes = self.get_nodes_in_cycle(c + 1)
            for node in nodes:
                pe_id = node.pe.id
                if pe_id in pe_to_inst:
                    inst_list = pe_to_inst[pe_id]
                    if type(node.inst) == list:
                        for cycle_offset, single_inst in enumerate(node.inst):
                            #node.cycle += cycle_offset
                            node_c_temp = node.cycle + cycle_offset
                            '''
                            inst_list.append({"cycle": node.cycle,
                                              "inst": single_inst})
                            '''
                            inst_list.append({"cycle": node_c_temp,
                                              "inst": single_inst})
                    else:
                        inst_list.append({"cycle": node.cycle, "inst": node.inst})
                else:
                    if type(node.inst) == list:
                        pe_to_inst[pe_id] = []
                        for cycle_offset, single_inst in enumerate(node.inst):
                            #node.cycle += cycle_offset
                            node_c_temp = node.cycle + cycle_offset
                            '''
                            pe_to_inst[pe_id].append({"cycle": node.cycle,
                                              "inst": single_inst})
                            '''
                            pe_to_inst[pe_id].append({"cycle": node_c_temp,
                                              "inst": single_inst})
                    else:
                        pe_to_inst[pe_id] = [{"cycle": node.cycle, "inst": node.inst}]
        return pe_to_inst

    def get_nodes_in_cycle(self, cycle):
        nodes = []
        for node_id in self.nodes:
            node = self.nodes[node_id]
            if node.cycle == cycle:
                nodes.append(node)
        return nodes
        
    def writeTo(self, path):
        with open(path, 'w') as f:
            f.write(self.__str__())
        
    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)

    def toDict(self):
        d = {}
        for node_id in self.nodes:
            node = self.nodes[node_id]
            d[node_id] = node.toDict()
        return d

    
def generate_node_graph(schedule):
    node_graph = NodeGraph()
    for i, cycle in enumerate(schedule):
        nodes_in_cycle = schedule[cycle]
        for node in nodes_in_cycle:
            new_node = Node()
            new_node.id = node["id"]
            new_node.op = node["operation"]
            new_node.cycle = i
            new_node.outDataType = node["dataType"]
            new_node.parents = node["parents"]  ## at this point, this is a list of id's
            new_node.children = node["children"] ## also a list of id's
            node_graph.add(new_node)
    return node_graph

def assign_pes(node_graph, num_pes, cycle2nodes, ns_size, ns_int_size, pu_pe):
    xy_nodes, w_nodes = classify_initial_nodes(node_graph)
    assign_pe_initial(xy_nodes, w_nodes, num_pes, ns_size, ns_int_size, pu_pe)
    for cycle in cycle2nodes:
        if cycle == "cycle0":
            continue
        per_cycle = [node["id"] for node in cycle2nodes[cycle]]
        for node_id in per_cycle:
            node = node_graph.get(node_id)
            node.inherit_parent_pe()
    #set_children_pes()

def classify_initial_nodes(node_graph):
    xy_nodes = []
    w_nodes = []
    for node_id in node_graph.nodes:
        node = node_graph.get(node_id)
        if node.parents == ["Source"]:
            if node.outDataType == "model_input" or node.outDataType == "model_output":
                xy_nodes.append(node)
            elif node.outDataType == "model":
                w_nodes.append(node)
    return xy_nodes, w_nodes


pe_used = []

def assign_pe_initial(xy_nodes, w_nodes, num_pes, ns_size, ns_int_size, pu_pe):
    """ 
    This anchors pe's to both x y's and w's in the beginning.
    Also returns a list of PE id's that are used ("active")
    """
    
    pe_list = pu_pe[1]
    if len(w_nodes) and len(xy_nodes):
        fill_ynodes = True
        i = 0
        for wnode in w_nodes:
            pe_id = i % num_pes
            pe = pe_list[pe_id]
            if pe.id not in pe_used:
                pe_used.append(pe.id)
            wnode.pe = pe
            if i < len(xy_nodes):
                xy_nodes[i].pe = pe
            else:
                fill_ynodes = False
            i += 1
        if fill_ynodes:
            for ynode in xy_nodes[i:]:
                pe_id = i % num_pes
                pe = pe_list[pe_id]
                if pe.id not in pe_used:
                    pe_used.append(pe.id)
                ynode.pe = pe
    return pe_used

def get_special_modules(dfg, special_modules):
    mod = []
    translate = {
        'sigmoid': 'SIG',
        '/': 'DIV',
        '#': 'SQR',
        '*+': 'MACC',
        '$': 'GAU'
        }
    for nodeid in dfg.nodes:
        node = dfg.nodes[nodeid]
        if node.op in special_modules:
            mod_entry = translate[node.op]
            if mod_entry not in mod:
                mod.append(mod_entry)
    return mod


def readFrom(schedule_file):
    with open(schedule_file, 'r') as f:
        contents = f.read()
    f.close()
    cycle2nodes = json.loads(contents, object_pairs_hook=OrderedDict)
    return cycle2nodes

    
        
if __name__ == "__main__":
    num_pes = 4
    schedule = readFrom("./schedule.json")
    node_graph = generate_node_graph(schedule)
    node_graph.set_parents_and_children()
    assign_pes(node_graph, num_pes)
    node_graph.writeTo("./nodes_ir.json")
