import os
import json
from namespace import *

class Pe:
    def __init__(self, id=None, next=None, prev=None, init_data=None, inst=None, ns_size=32, ns_int_size=4, pu=None):
        self.id = id
        self.next = next
        self.prev = prev
        self.inst = []
        self.cycle = 0
        self.pu = pu # PU to which this PE belongs
        self.nw = Namespace("NW", ns_size)
        self.nd = Namespace("ND", ns_size)
        self.ng = Namespace("NG", ns_size)
        self.ni = Namespace("NI", ns_int_size)
        self.nm = Namespace("NM", ns_size)
        self.nn0_in = Namespace("NN0_in", 1)
        self.nn0_out = Namespace("NN0_out", 1)
        self.nn1_in = Namespace("NN1_in", 1)
        self.nn1_out = Namespace("NN1_out", 1)
        self.nb0_in = Namespace("NB0_in", 1)
        self.nb0_out = Namespace("NB0_out", 1)
        self.nb1_in = Namespace("NB1_in", 1)
        self.nb1_out = Namespace("NB1_out", 1)
        self.nl = Namespace("NL", ns_size)
        self.namespace_map = {
            'NW'  : self.nw,
            'ND'  : self.nd,
            'NG'  : self.ng,
            'NI'  : self.ni,
            'NM'  : self.nm,
            'NN0_in'  : self.nn0_in,
            'NN0_out'  : self.nn0_out,
            'NN1_in'  : self.nn1_in,
            'NN1_out'  : self.nn1_out,
            'NB0_in'  : self.nb0_in,
            'NB0_out'  : self.nb0_out,
            'NB1_in'  : self.nb1_in,
            'NB1_out'  : self.nb1_out,
            'NL'  : self.nl,
        }
        self.nslist = [self.nw, self.nd, self.ng, self.ni, self.nm, self.nn0_in, self.nn0_out, self.nn1_in, self.nn1_out, self.nb0_in, self.nb0_out, self.nb1_in, self.nb1_out, self.nl] ## this is so that a loop can be used to print
        self.initialize_namespace(init_data)

    def initialize_namespace(self, init_data):
        pass

    def add_inst(self, new_inst):
        self.inst.append(new_inst)

    def get_inst(self, index=-1):
        return self.inst[index]

    def print_inst(self):
        if not os.path.exists("./inst/"):
            os.makedirs("./inst/")
        filename = "./inst/pe{:s}inst.json".format(str(self.id).zfill(2))
        with open(filename, 'w') as f:
            s = [i.toDict() for i in self.inst]
            f.write(json.dumps(s, sort_keys=True, indent=2))
            
    def exec_inst(self, inst):
        """ Execution step: 1) Get the operands; 2) Do the operation; 3) Store results """
        op = inst.op
        dests = inst.dests
        srcs = inst.srcs

        if op == "NOP":
            self.cycle += 1
            return
        src_values = self.sync(srcs)
        if op == "+":
            src0 = src_values[0]
            src1 = src_values[1]
            out = self.add(src0, src1)
            out_entry = Ns_entry(data=out)
        elif op == "-":
            src0 = src_values[0]
            src1 = src_values[1]
            out = self.sub(src0, src1)
            out_entry = Ns_entry(data=out)            
        elif op == '*':
            src0 = src_values[0]
            src1 = src_values[1]
            out = self.mul(src0, src1)
            out_entry = Ns_entry(data=out)
        elif op == "pass":
            src0 = src_values[0]
            out_entry = Ns_entry(data=src0)

        for dest in dests:
            dest_ns = dest.namespace
            dest_index = dest.index
            out_copy = Ns_entry(out_entry.valid, out_entry.data)
            if dest_ns[:2] == "NN" or dest_ns[:2] == "NB":
                dest_namespace = self.namespace_map[dest_ns]
                while not dest_namespace.insert(0, out_copy):
                    pass
            elif dest_ns == "NL":
                continue
            else:
                dest_namespace = self.namespace_map[dest_ns]
                while not dest_namespace.insert(dest_index, out_copy):
                    pass
        self.cycle += 1
        
    def sync(self, sources):
        """ Returns the source operand values. 
        If a source is not ready, wait until it does. 
        """
        src_values = []
        for src in sources:
            namespace = src.namespace
            ## The main difference between NN_in and NB_in: NN_in knows for sure to get the data from the previous PE, whereas NB_in goes through the circualr linked list to find the PE to copy data from. However, NN_in can follow the same pattern - this would shorten the code.
            if namespace == "NN0_in":
                ns_buf = self.namespace_map[namespace]
                prev_pe = self.prev  ## no need to use pe index
                #print(prev_pe)
                copy_from = prev_pe.namespace_map["NN0_out"]
                #print(copy_from)
                copied = copy_from.get(0)
                while copied is None:  ## get index is 0 because the out buffer is size 1
                    copied = copy_from.get(0)
                ns_buf.insert(0, copied) ## index 0 for same reason
                ns_entry = ns_buf.get(0)
                src_values.append(ns_entry.data) ## index 0 for same reason
            elif namespace == "NB0_in":
                ns_buf = self.namespace_map[namespace]
                pe_id = src.index
                #curr_id = self.id
                curr_pe = self
                #while curr_id != pe_id:
                while curr_pe.id != pe_id:
                    #next_pe = self.next
                    #curr_id = next_pe.id
                    prev_pe = curr_pe.prev
                    curr_pe = prev_pe
                #copy_from = next_pe.namespace_map["NB0_out"]
                copy_from = curr_pe.namespace_map["NB0_out"]
                copied = copy_from.get(0)
                while copied is None:
                    copied = copy_from.get(0)
                ns_buf.insert(0, copied)
                ns_entry = ns_buf.get(0)
                src_values.append(ns_entry.data)
            elif namespace == "NL":
                continue
            else:
                ns_buf = self.namespace_map[namespace]
                buf_index = src.index
                copied = ns_buf.get(buf_index)
                while copied is None:
                    copied = ns_buf.get(buf_index)
                src_values.append(copied.data)
        return src_values

    def __str__(self):
        s = '<PE' + str(self.id) + '>\n'
        for namespace in self.nslist:
            s += namespace.__str__()
        s += '-' * 15
        return s

    def toDict(self):
        d = {
            "pe_id": self.id,
            "ns_size": self.nw.size, # no particular reason for choosing nw
            "ns_int_size": self.ni.size,
        }
        return d

    def decode_bin(self, binary):
        pass
    
    ### Operations supported in every PE ###
    def add(self, op0, op1):
        return op0 + op1

    def sub(self, op0, op1):
        return op0 - op1

    def mul(self, op0, op1):
        return op0 * op1

    def mac(self, op0, op1):
        pass

    def div(self, op0, op1):
        return op0 / op1

    def sqr(self, op):
        return op ** 2

    def sigmoid(self, op):
        pass

    def gaussian(self, op):
        pass
    #######################################

    
    
