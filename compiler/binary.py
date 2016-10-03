import json
import sys
import os
import node_ir
import inst as instruc 

sys.path.insert(0, 'include')
import code

class Binary:
    num_dest = 3
    num_src = 3
    
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
            
    def generate_binary(self, fn):
        with open(fn, 'r') as f:
            content_str = f.read()
            if content_str == '':
                return ''
        f.close()
        inst_list = json.loads(content_str)
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
    

    def writeToPeFile(self, fn_list, inst_dict):
        for pe in inst_dict:
            pe_file_name = fn_list[pe]
            inst_list = inst_dict[pe]
            with open(pe_file_name, 'a') as f:
                f.write(json.dumps(inst_list, sort_keys=False, indent=2))


    def setMetaPes(self, nodes): # this is useless
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

op_bit = 4
ns_bit = 3
index_bit = 4
    
def generate_bin(insts):
    bin_lines = []
    op_format_str = '0' + str(op_bit) + 'b'
    ns_format_str = '0' + str(ns_bit) + 'b'
    index_format_str = '0' + str(index_bit) + 'b'
    for inst in insts:
        instruction = inst["inst"]
        op = instruction.op
        dests = instruction.dests
        srcs = instruction.srcs
        if op == 'NOP':
            bin_op = code.op[op]
            bin_op = format(bin_op, op_format_str)
            dest = '0' * (ns_bit + index_bit + 1) * 3
            src = '0' * (ns_bit + index_bit + 1) * 3
            binary = str(bin_op) + dest + src
        else:
            bin_op = code.op[op]
            bin_op = format(bin_op, op_format_str)
            bin_dests = ""
            for dest in dests:
                ns = code.namespace[dest.namespace]
                if dest.namespace == "NN":
                    pe_index = dest.index[:-1]
                    ind = format(int(pe_index), '0'+ str(index_bit - 1) + 'b')
                    bin_dests += (format(ns, ns_format_str) + ind + dest.index[-1])
                elif dest.namespace == "NB":
                    if dest.index[-1] == '0':
                        pe_index = dest.index[:-1]
                        ind = format(int(pe_index), '0'+ str(index_bit - 1) + 'b')
                        bin_dests += (format(ns, ns_format_str) + ind + dest.index[-1])
                    elif dest.index[-1] == '1':
                        pe_index = dest.index[:-1]
                        ind = format(int(pe_index), '0'+ str(index_bit - 1) + 'b')
                        bin_dests += (format(ns, ns_format_str) + ind + dest.index[-1])
                    else:
                        raise Exception()
                else:
                    bin_dests += (format(ns, ns_format_str) + format(int(dest.index), index_format_str))
            bin_srcs = ""
            for src in srcs:
                if src.namespace is None:
                    src.namespace = 'NL'
                if src.index is None:
                    src.index = 0
                ns = code.namespace[src.namespace]
                if src.namespace == "NN":
                    pe_index = src.index[:-1]
                    ind = format(int(pe_index), '0'+ str(index_bit - 1) + 'b')
                    bin_srcs += (format(ns, ns_format_str) + ind + src.index[-1])
                elif src.namespace == "NB":
                    if src.index[-1] == '0':
                        pe_index = src.index[:-1]
                        ind = format(int(pe_index), '0'+ str(index_bit - 1) + 'b')
                        bin_srcs += (format(ns, ns_format_str) + ind + src.index[-1])
                    elif src.index[-1] == '1':
                        pe_index = src.index[:-1]
                        ind = format(int(pe_index), '0'+ str(index_bit - 1) + 'b')
                        bin_srcs += (format(ns, ns_format_str) + ind + src.index[-1])
                    else:
                        print(src)
                        raise Exception()
                else:
                    bin_srcs += (format(ns, ns_format_str) + format(int(src.index), index_format_str))
            binary = str(bin_op) + bin_dests + bin_srcs
        bin_lines.append(binary)
    return bin_lines

def readFrom(path):
    with open(path, 'r') as f:
        contents = f.read()
    insts = json.loads(contents)
    for inst in insts:
        instruction = instruc.Inst()
        instruction.fromDict(inst)
        inst["inst"] = instruction
    return insts

def writeTo(inst_file, binary, hex_out):
    pe_id = get_peid(inst_file)
    if not os.path.exists("./bin/"):
        os.makedirs("./bin/")
    filename = "./bin/pe{:s}.txt".format(str(pe_id).zfill(2))
    with open(filename, 'w') as f:
        for bin_line in binary:
            f.write(bin_line + '\n')
    f.close()
    if hex_out:
        if not os.path.exists("./hex/"):
            os.makedirs("./hex")
        hex_filename = "./hex/pe{:d}.hex".format(pe_id)
        with open(hex_filename, 'w') as f:
            for bin_line in binary:
                f.write(format(int(bin_line, 2), '0x') + '\n')
    return filename

def get_peid(filename):
    pe_id = ""
    for char in filename:
        if char in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']:
            pe_id += char
    return int(pe_id)
            
if __name__ == "__main__":
    pe_per_pu = 4
    node_graph = instruc.readFrom("nodes_ir.json")
    instruc.generate_inst(node_graph, pe_per_pu)
    pe_to_inst = node_graph.separate_inst_by_pe()
    instruc.add_nop(pe_to_inst)
    filenames = instruc.writeTo(pe_to_inst)

    for f in filenames:
        insts = readFrom(f)
        binary = generate_bin(insts)
        writeTo(f, binary, True)
