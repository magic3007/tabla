from serial.DataFlowGraph import *

import json
import sys
from collections import OrderedDict

sys.path.insert(0, 'include')

import code
import util

'''TESTING
import math
def num_bits(n):
    return int(math.log(n, 2)) + 1

#the format of the binary is <operation_type><destinations><sources>

#each PE will have separate instructions generated

schedule_file = sys.argv[1]

num_dest = 3
num_src = 3

lg_num_pe = 3
num_pe = 1 << lg_num_pe

lg_num_pe_per_pu = 3
num_pe_per_pu = 1 << lg_num_pe_per_pu
'''
'''
class Inst:
    def __init__(self):
        self.op = None
        self.destType = []
        self.destIndex = dict()
        self.srcType = []
        self.srcIndex = dict()
'''
class Inst:
    def __init__(self, op = None, dest = [], src = []):
        self.op = op
        self.dest = dest
        self.src = src

    def toDict(self):
        d = {"op": self.op, "dest": self.dest, "src": self.src}
        return d

class Node:
    def __init__(self):
        self.id = None
        self.op = None
        self.cycle = None
        self.pe = None
        self.parent = []
        self.child = []
        self.parentPe = []
        self.childPe = []
        self.inDataType = []
        self.outDataType = []
        #self.inst = Inst()
        self.namespace_index = 0 ## This saves the index of the namesapce where output is stored

        
class Binary:
    pe_q = []
    pe_q_index = 0
    dataTypeDict = {
        "model_input" : 'ND',
        "model_output" : 'ND',
        "model" : 'NW',
        "constant" : 'NM',
        "gradient" : 'NG',
        None : 'NI'
    }
    xynodes = []
    wnodes = []
    inodes = []
    num_pes = 0
        
    def __init__(self, num_pes, pe_per_pu):
        self.binary = []
        self.ir = []
        '''
        self.num_pe = num_pe
        self.num_pe_per_pu = num_pe_per_pu
        self.num_dest = num_dest
        self.num_src = num_src
        '''
        Binary.pe_q = list(range(num_pes))
        Binary.num_pes = num_pes
        self.pe_per_pu = pe_per_pu
            

    ########################################################################################################
    def generateBinary(self, fn):
        with open(fn, 'r') as f:
            content_str = f.read()
            if content_str == '':
                return ''
        f.close()
        inst_list = json.loads(content_str)
        #print(inst_list)
        bin = ''

        for inst in inst_list:
            #print(inst)
            op = code.op[inst["op"]]
            dest = ''
            src = ''
            
            for child in inst["dest"]:
                nid = code.namespace[child["dest_nid"]]
                index = child["dest_index"]
                dest += str(nid) + str(index)
            dest += '0' * (6 - len(dest))
            for parent in inst["src"]:
                nid = code.namespace[parent["src_nid"]]
                index = parent["src_index"]
                src += str(nid) + str(index)
            src += '0' * (6 - len(src))            
            bin_line = str(op) + dest + src
            bin += bin_line + '\n'
        return bin
    
    def pop_q(self):
        if not (Binary.pe_q_index < Binary.num_pes):
            Binary.pe_q_index = 0
        pe = Binary.pe_q[Binary.pe_q_index]
        Binary.pe_q_index += 1
        #print('[DEBUG] ', pe)
        return pe

    ### TODO ###
    def write_bin_files(self):
        fn_list = []
        file_templ = "pe{:d}bin.txt"
        pes = list(range(Binary.num_pes))
        for pe in pes:
            fn = file_templ.format(pe)
            with open(fn, 'w') as f:
                f.write('')
            fn_list.append(fn)
        return fn_list
    
    def write_pe_files(self):
        fn_list = []
        file_templ = "pe{:d}inst.json"
        pes = list(range(Binary.num_pes))
        for pe in pes:
            fn = file_templ.format(pe)
            with open(fn, 'w') as f:
                f.write('')
            fn_list.append(fn)
        return fn_list
    
    def generateInst(self, nodes_file):
        inst_dict = {}
        nodes_dict = self.readFrom(nodes_file)
        for node_id in nodes_dict:
            node = nodes_dict[node_id]
            if node["parents"] == "Source":
                continue
            pe = node["pe"]
            op = node["op"]
            #dest_nid = node["outDataType"]
            children = node["children"]
            dest = []
            if node["children"] == "Sink":
                parents = node["parents"]
                dest_index = None
                for p in parents:
                    if p["outDataType"] == "NW":
                        dest_node = p
                        break
                nid_and_index = util.get_dest_nid_and_index(node, dest_node, self.pe_per_pu)
                d = {"dest_nid": "NW", "dest_index": nid_and_index[1]}
                dest.append(d)
            else:
                for c in children:
                    nid_and_index = util.get_dest_nid_and_index(node, c, self.pe_per_pu)
                    d = {"dest_nid": nid_and_index[0], "dest_index": nid_and_index[1]}
                    dest.append(d)
            parents = node["parents"]
            src = []
            for p in parents:
                if p["id"] == 2: ## mu:
                    nid_and_index = util.get_src_nid_and_index(node, p, self.pe_per_pu)
                else:
                    pid =  p["id"]
                    parent_node = nodes_dict[str(pid)]
                    nid_and_index = util.get_src_nid_and_index(node, parent_node, self.pe_per_pu)
                d = {"src_nid": nid_and_index[0], "src_index": nid_and_index[1]}
                src.append(d)
            inst = Inst(op, dest, src)
            if pe not in inst_dict:
                inst_dict[pe] = [inst.toDict()]
            else:
                inst_dict[pe].append(inst.toDict())
        return inst_dict

    def writeToPeFile(self, fn_list, inst_dict):
        for pe in inst_dict:
            pe_file_name = fn_list[pe]
            inst_list = inst_dict[pe]
            with open(pe_file_name, 'a') as f:
                f.write(json.dumps(inst_list, sort_keys=False, indent=2))
    ######
    
    def convertJsonToIR(self, schedule_file):
        nodes = self.generateNodesFromJSON(schedule_file)    # nodes is a list of Node's
        self.setChildrenPes(nodes)    # children pe's can't be determined in the first pass.
        #self.setMetaPes(nodes)
        self.writeTo('./nodes_for_binary.json', nodes)

    def generateNodesFromJSON(self, schedule_file):
        cycle2nodes = self.readFrom(schedule_file)
        nodes = []
        init_data = cycle2nodes["cycle0"]
        for data in init_data:
            node = Node()
            node.id = data["id"]
            node.op = data["operation"]
            node.cycle = 0
            node.parent = [0]    # id of source node is 0
            node.child = data["children"]
            node.inDataType = "null"    # data type of source is null
            node.outDataType = Binary.translate(data["dataType"])
            #node.pe = self.mapPe2initialData(node)
            self.decideNodeType(node)
            node.parentPe = None    # parent in this case is source node
            nodes.append(node)
        self.mapPe2initialData()
        cycle2nodes.pop("cycle0", None)
        for i, cycle in enumerate(cycle2nodes):
            nodes_in_cycle = cycle2nodes[cycle]
            for single_node in nodes_in_cycle:
                node = Node()
                node.id = single_node["id"]
                node.op = single_node["operation"]
                node.cycle = i + 1    # i starts from 0, but we want the first cycle to be 1
                node.parent = single_node["parents"]    # list of node id's
                node.child = single_node["children"]
                node.inDataType = self.getInDataType(node.parent)
                node.outDataType = Binary.translate(single_node["dataType"])    # outDataType is basically dataType of node
                node.pe = self.mapPe(node, nodes)
                node.parentPe = self.getParentPes(node, nodes)
                nodes.append(node)
        return nodes

    def decideNodeType(self, node):
        if node.outDataType == 'ND':
            Binary.xynodes.append(node)
        elif node.outDataType == 'NW':
            Binary.wnodes.append(node)

    #    This is to anchor both x y's and w's in the beginning
    def mapPe2initialData(self):
        if len(Binary.wnodes) and len(Binary.xynodes):    # just a sanity chcek
            i = 0
            for wnode in Binary.wnodes:
                pe = self.pop_q()
                wnode.pe = pe
                Binary.xynodes[i].pe = pe
                i += 1
            for xynode in Binary.xynodes[i:]:
                pe = self.pop_q()
                xynode.pe = pe
                
    def getParentPes(self, node, nodes):
        parents_node = []    # list of parent nodes
        parent_pes = []

        parents_node = self.searchParentsFrom(node, nodes)
        for parent in parents_node:
            parent_pes.append(parent.pe)
        return parent_pes

    def setChildrenPes(self, nodes):    # can't find out until second pass
        for node in nodes:
            children = node.child
            for child_id in children:
                for child_node in nodes:
                    if child_id == child_node.id:
                        child_pe = child_node.pe
                        node.childPe.append(child_pe)

    def setMetaPes(self, nodes):
        for node in nodes:
            if node.parent == [0]:
                continue
            p_nodes = self.searchParentsFrom(node, nodes)
            m_candidate = p_nodes[0]
            if m_candidate.outDataType == "NM":
                p_other = p_nodes[1]
                m_candidate.pe = p_other.pe
                return
        return
                    
    
    def mapPe(self, node, nodes):
        pe = None
        parents_id = node.parent    # list of parent id's
        '''
        if parents_id == 0:
            if node.outDataType == 'ND': # anchor only the x's and y's, not w's.
                pe = Binary.pe_q.pop_q()
                return pe
            else:
                return pe
        '''
        parents_node = []    # list of parent nodes. This is because we have a list of parent id's, but we want node objects instead
        parents_node = self.searchParentsFrom(node, nodes)
        if self.all_parents_have_pe(parents_node):
            pe = self.select_pe_from_parents(parents_node)
        else:    # assuming it's impossible to have NO parent pe's
            pe = self.inherit_parent_pe(parents_node)
        return pe

    def searchParentsFrom(self, node, nodes):
        parents_node = []
        for p_id in node.parent:    # node.parent is a list of parent id's
            for parent in nodes:
                if p_id == parent.id:
                    parents_node.append(parent)
        return parents_node

    def all_parents_have_pe(self, parents_node):
        for parent in parents_node:
            if parent.pe is None:
                return False
        return True

    def select_pe_from_parents(self, parents_node):
        parent_pes = []
        parent_pes_ni = []
        parent_pes_nm = []
        for parent in parents_node:
            if parent.outDataType in ['NW', 'ND']:
                parent_pes.append(parent.pe)
            elif parent.outDataType is 'NI':
                parent_pes_ni.append(parent.pe)
            elif parent.outDataType is 'NM':
                parent_pes_nm.append(parent.pe)
        if parent_pes:
            return min(parent_pes)
        elif parent_pes_ni:
            return min(parent_pes_ni)
        else:
            return min(parent_pes_nm)
        
    def inherit_parent_pe(self, parents_node):
        nd = []
        nw = []
        ni = []
        ng = []
        nm = []
        for parent in parents_node:
            if parent.outDataType == 'ND':
                nd.append(parent)
            elif parent.outDataType == 'NW':
                nw.append(parent)
            elif parent.outDataType == 'NI':
                ni.append(parent)
            elif parent.outDataType == 'NG':
                ng.append(parent)
            elif parent.outDataType == 'NM':
                nm.append(parent)
        if len(nw) and len(nd):
            return nd[0].pe
        elif len(nw) and len(ng):
            return nw[0].pe
        elif len(nd) and len(ni):
            return nd[0].pe
        elif len(ng) and len(nm):
            return ng[0].pe
        else:
            return ni[0].pe

    def readFrom(self, path):
        with open(path, 'r') as f:
            contentString = f.read()
        f.close()
        cycle2nodes = json.loads(contentString, object_pairs_hook=OrderedDict)
        return cycle2nodes

    def getInDataType(self, parent_node_ids):
        parent_datatype_list = []
        for parent_node in parent_node_ids:
            node = self.searchFromDFG(parent_node)
            datatype = Binary.translate(node["dataType"])
            parent_datatype_list.append(datatype)
        return parent_datatype_list

    ''' This returns a node object from DFG by using node id as index '''
    def searchFromDFG(self, node_id, path="./artifacts/dfg.json"):
        with open(path, 'r') as f:
            contentString = f.read()
        f.close()
        nodes = json.loads(contentString)
        for node in nodes:
            if node["id"] == node_id:
                return node

    def save(self, path, nodes):
        with open(path, 'w') as f:
            f.write(self.__str__(nodes))

    def writeTo(self, path, nodes):
        self.save(path, nodes)

    def __str__(self, nodes):
        return json.dumps(self.toDict(nodes), sort_keys=False, indent=2)
    
    def toDict(self, nodes):
        d = {}
        for node in nodes:
            info = {}
            info["op"] = node.op
            info["cycle"] = node.cycle
            info["pe"] = node.pe
            info["inDataType"] = node.inDataType
            info["outDataType"] = node.outDataType
            info["parents"] = self.getParentsInfo(node.parent, nodes)
            info["children"] = self.getChildrenInfo(node.child, nodes)
            info["namespace_index"] = node.namespace_index
            
            d[node.id] = info            
        return d

    def getParentsInfo(self, parent_ids, nodes):
        parents = []
        if 0 in parent_ids:
            return "Source"
        for p_candidate in nodes:
            if p_candidate.id in parent_ids:
                d = {}
                d["id"] = p_candidate.id
                d["cycle"] = p_candidate.cycle
                d["outDataType"] = p_candidate.outDataType
                d["namespace_index"] = p_candidate.namespace_index
                if p_candidate.outDataType == "NM":
                    p_other = self.searchFromNodes(parent_ids[1], nodes)
                    d["pe"] = p_other.pe
                else:
                    d["pe"] = p_candidate.pe
                parents.append(d)
        return parents

    def searchFromNodes(self, n_id, nodes):
        for n in nodes:
            if n_id == n.id:
                return n

    def getChildrenInfo(self, child_ids, nodes):
        children = []
        if 1 in child_ids:
            return "Sink"
        for potential_child in nodes:
            if potential_child.id in child_ids:
                d = {}
                cid = potential_child.id
                cycle = potential_child.cycle
                pe = potential_child.pe
                outDataType = potential_child.outDataType

                d["id"] = cid
                d["cycle"] = cycle
                d["pe"] = pe
                d["outDataType"] = outDataType
                d["namespace_index"] = potential_child.namespace_index
                children.append(d)
        return children
    
    '''
    def getChildrenInfo(self, children_ids):
        children_list = []
        children = []
        
        for pid in children_ids:
            children.append(self.searchFromDFG(pid))
        for c in children:
            node_id = c.id
            node_pe = c.pe
            node_cycle = c.cycle
            node_outDataType = c.outDataType
            value_pair = (node_id, node_pe, node_outDataType, node_cycle)
            children_list.append(value_pair)
        return children_list
    '''
    
    def translate(dataType):
        return Binary.dataTypeDict[dataType]

    ########################################################################################################
    
    
    ########################################################################################################
    ''' TESTING
    def create_dest(self, node, i, indexes):
        puChild = node.childPe[i]/num_pe_per_pu
        puSelf = node.pe/num_pe_per_pu
        
        neighbour_pe = ((node.childPe[i] - node.pe) == 1)
        neighbour_pu = (float(node.childPe[i])/num_pe_per_pu - float(node.pe)/num_pe_per_pu) == 1
        
        outDataT = node.outDataType[i]
        
        destType = None
        destIndex = None
        
        if(outDataT == 'NI' and neighbour_pe):
            destType = code.namespace('NN')
            destIndex = 0
        
        elif(outDataT == 'NI' and neighbour_pu):
            destType = code.namespace('NN')
            destIndex = 1
        
        elif(outDataT == 'NI' and puChild == puSelf and ~neighbour_pe and node.childPe[i] != node.pe):
            destType = code.namespace('NB')
            destIndex = node.childPe[i]%num_pe_per_pu
        
        elif(outDataT == 'NI' and puChild != puSelf and ~neighbour_pu):
            destType = code.namespace('NB')
            pe_index = node.childPe[i]%num_pe_per_pu
            pu_index = node.childPe[i]/num_pe_per_pu
            index  = (1 << (lg_num_pe + lg_num_pe_per_pu)) + (pu_index << lg_num_pe_per_pu) + pe_index
            destIndex = index
        
        elif(outDataT == 'NI' and  node.childPe[i] == node.pe):
            destType = code.namespace(outDataT)
            destIndex = indexes[destType]
            indexes[destType] = indexes[node.pe][destType] + 1
        
        elif(outDataT == 'NW'):
            destType = code.namespace(outDataT)
            destIndex = indexes[destType]
            indexes[destType] = indexes[node.pe][destType] + 1
        
        elif(outDataT == 'ND'):
            destType = code.namespace(outDataT)
            destIndex = indexes[destType]
            indexes[destType] = indexes[node.pe][destType] + 1
        
        elif(outDataT == 'NM'):
            destType = code.namespace(outDataT)
            destIndex = indexes[destType]
            indexes[destType] = indexes[node.pe][destType] + 1
        
        return destType
        return destIndex
    ########################################################################################################
    
    ########################################################################################################
    def create_src(self, node, i, indexes):
        puParent = node.parentPe[i]/num_pe_per_pu
        puSelf = node.pe/num_pe_per_pu
        
        neighbour_pe = ((node.parentPe[i] - node.pe) == 1)
        neighbour_pu = (float(node.parentPe[i])/num_pe_per_pu - float(node.pe)/num_pe_per_pu) == 1
        
        inDataT = node.inDataType[i]
        
        srcType = None
        srcIndex = None
        
        if(inDataT == 'NI' and neighbour_pe):
            srcType = code.namespace('NN')
            srcIndex = 0
        
        elif(inDataT == 'NI' and neighbour_pu):
            srcType = code.namespace('NN')
            srcIndex = 1
        
        elif(inDataT == 'NI' and puChild == puSelf and ~neighbour_pe):
            srcType = code.namespace('NB')
            srcIndex = node.parentPe[i]%num_pe_per_pu
        
        elif(inDataT == 'NI' and puChild != puSelf and ~neighbour_pu):
            srcType = code.namespace('NB')
            pe_index = node.parentPe[i]%num_pe_per_pu
            pu_index = node.parentPe[i]/num_pe_per_pu
            index  = (1 << (lg_num_pe + lg_num_pe_per_pu)) + (pu_index << lg_num_pe_per_pu) + pe_index
            srcIndex = index
        
        elif(inDataT == 'NI' and  node.childPe[i] == node.pe):
            srcType = code.namespace(inDataT)
            for matchNode in self.ir:
                if (matchNode == node.parent[i]):
                    srcIndex = matchNode.destIndex(node.id)
        
        elif(inDataT == 'NW'):
            srcType = code.namespace(outDataT)
            for matchNode in self.ir:
                if (matchNode == node.parent[i]):
                    srcIndex = matchNode.destIndex(node.id)

        elif(inDataT == 'ND'):
            srcType = code.namespace(outDataT)
            for matchNode in self.ir:
                if (matchNode == node.parent[i]):
                    srcIndex = matchNode.destIndex(node.id)

        elif(inDataT == 'NM'):
            srcType = code.namespace(outDataT)
            for matchNode in self.ir:
                if (matchNode == node.parent[i]):
                    srcIndex = matchNode.destIndex(node.id)

        return srcType
        return srcIndex
    ########################################################################################################


    ########################################################################################################
    def create_inst(self, node, indexes):
        
        curr_inst = inst()
            
        curr_inst.operation = code.op(node.op)
    
        for i in range(0, len(node.outDataType)):
            type, index = create_dest(node, i, indexes)
            curr_inst.destType.append(type)
            curr_inst.destIndex(node.child[i]) = append(index)
    
        for i in range(0, len(node.inDataType)):
            type, index = create_src(node, i, indexes)
            curr_inst.srcType.append(type)
            curr_inst.srcIndex(node.parent[i]) = append(index)
        
        return curr_inst
            
    ########################################################################################################
    

    ########################################################################################################
    def create_binary(self):
        indexes = dict()
        
        maxIndex = dict()
        
        for j in range (0,num_pe):
            imm = dict()
            for key in code.namespace:
                if(key != NL or key != NB or key != NN ):
                    imm[key] = 0
            indexes(j) = imm

        for node in self.ir:
            node.inst = self.create_inst(node, indexes)

        for key in code.namespace:
            if (key != NL or key != NB or key != NN ):
                maxIndex[key] = indexes[0][key]
                
        for j in range (1,num_pe):
            for key in code.namespace:
                if(key != NL or key != NB or key != NN ):
                    if(maxIndex[key] < indexes[j][key]):
                        maxIndex[key] = indexes[j][key]

    ########################################################################################################
    
    
    ########################################################################################################
    def generateBinary(self):
        ir_cpy = self.ir
        curr_cycle = 0
        curr_pe = 0
        inst = None
        for node in ir_cpy:
            if(node.cycle == curr_cycle):
                curr_inst = inst()
                inst = create_inst(node)

    ########################################################################################################



bin = Binary()

#print(bin.schedule)
    '''
if __name__ == '__main__':
    bin = Binary(4)
    bin.convertJsonToIR('./schedule.json')
    fn_list = bin.write_pe_files()
    inst_dict = bin.generateInst('./nodes_for_binary.json')
    bin.writeToPeFile(fn_list, inst_dict)

    bin_list = bin.write_bin_files()
    for pe, fn in enumerate(fn_list):
        binary = bin.generateBinary(fn)
        with open(bin_list[pe], 'w') as f:
            f.write(binary)
