#!/usr/bin/env python3

"""
Instruction Format

<Function Type >
< DEST0 N ID > < DEST0 INDEX > 
< DEST1 N ID > < DEST1 INDEX >   
< DEST2 N ID > < DEST2 INDEX > 
< SRC0 N ID > < SRC0 INDEX >
< SRC1 N ID > < SRC1 INDEX >
< SRC2 N ID > < SRC2 INDEX >

------------------------------
<Function Type> can be of the type:
FN_PASS : 0
FN_ADD : 1
FN_SUB : 2
FN_MUL : 3
FN_MAC ; 4
FN_DIV : 5
FN_SQR : 6
FN_SIG : 7
FN_GAU : 8

------------------------------
<N ID> is Namespace ID. It can be of the type:
NAMESPACE_NULL : 0
NAMESPACE_WEIGHT : 1
NAMESPACE_DATA : 2
NAMESPACE_GRADIENT : 3
NAMESPACE_INTERIM : 4
NAMESPACE_META : 5
NAMESPACE_NEIGHBOR : 6    # [0] = PE_NEIGHBOR, [1] = PU_NEIGHBOR
NAMESPACE_BUS : 7    # [0] = PE_BUS, [1] = PU_BUS

------------------------------
<INDEX> means different things:
When N ID is weight, data, gradient, meta, interim: INDEX is the actual index in the namespace
When N ID is neighbor: INDEX [0] is neighboring PE id, or INDEX [1] is neighboring PU id
When N ID is bus: INDEX [0] is PE id using the pe bus, or INDEX [1] is PU id and PE id

"""
import json
from os import listdir
from os.path import isfile, join

from pe import Pe
from pu import Pu
from inst import Inst
from namespace import Ns_entry
from binary import get_peid

import sys
sys.path.insert(0, 'include')
import code


pe_objects = []
cycle = 1
max_cycle = 1
num_pes = 0
pes_per_pu = 0
op_bit = 0
ns_bit = 0
index_bit = 0
nn_nb_bit = 0

def read_config(path):
    print("reading config file...", end='')
    with open(path, 'r') as f:
        config = f.read()
    f.close()
    config = json.loads(config)
    global num_pes, pes_per_pu, op_bit, ns_bit, index_bit, nn_nb_bit
    num_pes = config["num_pes"]
    pes_per_pu = config["pes_per_pu"]
    ns_size = config["namespace_size"]
    ns_int_size = config["namespace_interim_size"]
    op_bit = config["op_bit"]
    ns_bit = config["ns_bit"]
    index_bit = config["index_bit"]
    nn_nb_bit = config["nn_nb_bit"]
    for pe_id in range(num_pes):
        pe = Pe(id=pe_id, ns_size=ns_size, ns_int_size=ns_int_size)
        pe_objects.append(pe)
    for pe_id, pe in enumerate(pe_objects):
        if pe_id != len(pe_objects) - 1:
            pe.prev = pe_objects[pe_id + 1]
        else:
            pe.prev = pe_objects[0]
    print("done")

def init_namespace():
    """ Fills in namespace buffer with initial data. 
    This function won't be needed once memory interface instructions are working.
    It fills in dummy data for linear regression.
    """
    print("initializing pe namespace...", end='')
    pe0 = pe_objects[0]
    pe1 = pe_objects[1]
    pe2 = pe_objects[2]
    pe3 = pe_objects[3]

    pe0.nw.insert(0, Ns_entry(data=1))
    pe0.nd.insert(0, Ns_entry(data=3))
    pe1.nw.insert(0, Ns_entry(data=2))
    pe1.nd.insert(0, Ns_entry(data=4))
    pe2.nw.insert(0, Ns_entry(data=3))
    pe2.nd.insert(0, Ns_entry(data=5))
    pe3.nd.insert(0, Ns_entry(data=4))

    pe0.nw.insert(1, Ns_entry(data=1))
    pe0.nd.insert(1, Ns_entry(data=3))
    pe1.nw.insert(1, Ns_entry(data=2))
    pe1.nd.insert(1, Ns_entry(data=4))
    pe2.nw.insert(1, Ns_entry(data=3))
    pe2.nd.insert(1, Ns_entry(data=5))

    pe0.nm.insert(0, Ns_entry(data=1))
    pe1.nm.insert(0, Ns_entry(data=1))
    pe2.nm.insert(0, Ns_entry(data=1))
    print("done")

def load_inst(bin_files):
    print("loading instructions...", end='')
    for bin_file in bin_files:
        with open(bin_file, 'r') as f:
            binary_stream = f.read()
        binary_lines = separate_stream(binary_stream)
        inst_list = []
        for line in binary_lines:
            inst = bin_decode(line)
            inst_list.append(inst)
        peid = get_peid(bin_file)
        pe = pe_objects[peid]
        pe.inst = inst_list
    print("done")

def set_maxcycle():
    global max_cycle
    pe0 = pe_objects[0]
    max_cycle = len(pe0.inst)

def separate_stream(binary_stream):
    binary_lines = []
    bin_line = ''
    for char in binary_stream:
        if char != '\n':
            bin_line += char
        else:
            binary_lines.append(bin_line)
            bin_line = ''
    return binary_lines

def bin_decode(bin_line):
    op_bits = bin_line[:op_bit]
    dests = []
    srcs = []

    op = code.op_inv[int(op_bits, 2)]
    start_point = op_bit
    for i in range(3):
        ns_bits = bin_line[start_point:start_point + ns_bit]
        ns = code.ns_inv[int(ns_bits, 2)]
        if ns == "NN":
            pe_pu_bit = bin_line[start_point + ns_bit + index_bit + nn_nb_bit - 1]
            if pe_pu_bit == '0':
                ns = "NN0_out"
            else:
                ns = "NN1_out"
        elif ns == "NB":
            pe_pu_bit = bin_line[start_point + ns_bit + index_bit + nn_nb_bit - 1]
            if pe_pu_bit == '0':
                ns = "NB0_out"
            else:
                ns = "NB1_out"
        index_bits = bin_line[start_point + ns_bit:start_point + ns_bit + index_bit]
        index = int(index_bits, 2)
        dest = {
            "dest_nid": ns,
            "dest_index": index
            }
        dests.append(dest)
        start_point += (ns_bit + index_bit + nn_nb_bit)
    for i in range(3):
        ns_bits = bin_line[start_point:start_point + ns_bit]
        ns = code.ns_inv[int(ns_bits, 2)]
        if ns == "NN":
            pe_pu_bit = bin_line[start_point + ns_bit + index_bit + nn_nb_bit - 1]
            if pe_pu_bit == '0':
                ns = "NN0_in"
            else:
                ns = "NN1_in"
        elif ns == "NB":
            pe_pu_bit = bin_line[start_point + ns_bit + index_bit + nn_nb_bit - 1]
            if pe_pu_bit == '0':
                ns = "NB0_in"
            else:
                ns = "NB1_in"
        index_bits = bin_line[start_point + ns_bit:start_point + ns_bit + index_bit]
        index = int(index_bits, 2)
        src = {
            "src_nid": ns,
            "src_index": index
            }
        srcs.append(src)
        start_point += (ns_bit + index_bit + nn_nb_bit)
    inst = Inst()
    d = {
        "op": op,
        "dests": dests,
        "srcs": srcs
        }
    inst.fromDict(d)
    return inst        

def print_welcome():
    print()
    print("Welcome to TABLA Simulator!")
    print()

def print_help():
    print("***** HELP MENU *****")
    print("Enter 'r' to run instructions in the next cycle.")
    print("Enter 'p' to print the status of PEs and PUs.")
    print("Enter 'h' for this help message.")
    print("Enter 'q' to quit.")

def print_exit():
    print("Simulator exited.")

def print_stat(pe_pu_list=None):
    print("***** STATUS *****")
    global num_pes, pes_per_pu, pe_objects, cycle, max_cycle
    if pe_pu_list is None or len(pe_pu_list) == 0:
        print("Number of PE's:", num_pes)
        print("Number of PE's-per-PU:", pes_per_pu)
        print("Next cycle:", cycle)
        print("Total cycles:", max_cycle)
    elif pe_pu_list is not None:
        for pe_pu in pe_pu_list:
            if pe_pu[:2] == "pe":
                if pe_pu[2:].isdigit():
                    pe_id = int(pe_pu[2:])
                    pe = pe_objects[pe_id]
                    print(pe)
            elif pe_pu[:2] == "pu":
                pass
            else:
                raise Exception("Invalid pe pu arguments. Enter either pe or pu.")

def run():
    """ Runs one instruction in each PE in a specific cycle. """
    global cycle
    print("Running cycle {:d} instructions...".format(cycle), end='')
    for pe in pe_objects:
        inst_ptr = cycle - 1
        inst = pe.inst[inst_ptr]
        #print(pe.id)
        #print(inst)
        pe.exec_inst(inst)
    cycle += 1
    print("done!")


bin_path = "./bin/"
prompt = ">> "
config_path = "./config.json"

if __name__ == '__main__':
    bin_files = [join(bin_path, f) for f in listdir(bin_path) if isfile(join(bin_path, f))]
    read_config(config_path)
    init_namespace()
    load_inst(bin_files)
    set_maxcycle()
    print_welcome()
    print_stat()
    print()
    print_help()
    kbd_in = input(prompt)
    while kbd_in != 'q':
        if kbd_in == '':
            pass
        elif kbd_in == 'h':
            print_help()
        elif kbd_in == 'r':
            if cycle > max_cycle:
                print("[WARNING] All instructions complete.")
                kbd_in = input(prompt)
                continue
            else:
                run()
        elif kbd_in[0] == 'p':
            pe_pu_ids = kbd_in.split()
            print_stat(pe_pu_ids[1:])
        else:
            print("[ERROR] Invalid option.")
            print_help()
        kbd_in = input(prompt)
    print_exit()
