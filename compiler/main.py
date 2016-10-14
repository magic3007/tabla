#!/usr/bin/env python3
from antlr4 import *
import sys
sys.path.insert(0, 'include')
import os
import argparse
import json
import math
from TablaLexer import TablaLexer
from TablaParser import TablaParser
from DFGGenerator import DFGGenerator
from DotGenerator import DotGenerator
from Scheduler import Scheduler
import node_ir, inst, binary
from pu import Pu
from pe import Pe
import fileformat
import mem_interface


def read_config(filename):
    with open(filename, 'r') as f:
        contents = f.read()
    return json.loads(contents)


def genpus(num_pes, pes_per_pu, ns_size, ns_int_size):
    '''
    Instantiates both PU's and PE's, based on the config file.
    '''
    pu_list = []
    pe_list = []
    num_pus = num_pes // pes_per_pu

    for i in range(num_pus):
        pu_list.append(Pu(i))
    for i in range(num_pes):
        pe = Pe(id=i, ns_size=ns_size, ns_int_size=ns_int_size)
        pu_id = i // pes_per_pu
        pu = pu_list[pu_id]
        pe.pu = pu
        pe_list.append(pe)
        if i % pes_per_pu == 0:
            pu.head_pe = pe

    pu_list[0].next_pu = pu_list[-1]
    for i, pu in enumerate(pu_list[1:]): # kind of hacky
        pu.next_pu = pu_list[i]

    pe_count = 0 # index of PE in PU
    pu_count = 0
    for i, pe in enumerate(pe_list):
        if i % pes_per_pu == 0:
            pe.next = pe_list[pes_per_pu * pu_count + pes_per_pu - 1]
            pe.prev = pe_list[i + 1]
            pe_count += 1
            continue
        if pe_count == pes_per_pu - 1:
            pe.next = pe_list[i - 1]
            pe_count = 0
            pu_count += 1
            continue
        if i != num_pes - 1:
            pe.prev = pe_list[i + 1]
            pe.next = pe_list[i - 1]
            pe_count += 1

    return (pu_list, pe_list)


def main(argv):
    config = read_config("./config.json")
    
    argparser = argparse.ArgumentParser()
    argparser.add_argument("filename", help="file name")
    args = argparser.parse_args()
    
    input_file = FileStream(args.filename)
    lexer = TablaLexer(input_file)
    stream = CommonTokenStream(lexer)
    parser = TablaParser(stream)
    tree = parser.program()   # 'program' is the starting rule. The parser is invoked by calling the starting rule.
    
    # graph creation should happen here
    #print('\n\n================================')
    dfg_file = 'artifacts/dfg.json'
    dfgGenerator = DFGGenerator()
    dfg = dfgGenerator.create(tree)
    dfgGenerator.writeTo(dfg, dfg_file)

    num_pes = config["num_pes"]
    schedule_file = 'artifacts/schedule.json'
    scheduler = Scheduler()
    #newDfg = scheduler.readFrom(dfg_file)
    #scheduler.createSchedule(newDfg, num_pes)
    scheduler.createSchedule(dfg, num_pes)
    scheduler.writeTo(schedule_file)

    dot_file = 'artifacts/tabla.dot'
    dotGenerator = DotGenerator()
    #newDfg = dotGenerator.readFrom(dfg_file)
    cycle2id = dotGenerator.readSched(schedule_file)
    #dotCode = dotGenerator.generateDot(newDfg, cycle2id)
    dotCode = dotGenerator.generateDot(dfg, cycle2id)
    dotGenerator.writeTo(dotCode, dot_file)

    pes_per_pu = config["pes_per_pu"]
    ns_size = config["namespace_size"]
    ns_int_size = config["namespace_interim_size"]

    # generate PU's and PE's based on config values
    #print('*' * 20)
    pu_list, pe_list = genpus(num_pes, pes_per_pu, ns_size, ns_int_size)
    pu_pe = (pu_list, pe_list)

    # assign pes to every node
    schedule = node_ir.readFrom("./artifacts/schedule.json")
    dfg = node_ir.generate_node_graph(schedule)
    dfg.set_parents_and_children()
    node_ir.assign_pes(dfg, num_pes, schedule, ns_size, ns_int_size, pu_pe)
    dfg.writeTo("./artifacts/nodes_ir.json")

    #dfg = inst.readFrom("./artifacts/nodes_ir.json")
    # instruction generation
    inst.generate_inst(dfg, pes_per_pu)

    for pe in pe_list:
        #print("pe id: ", pe.id)
        if len(pe.inst) > 0:
            #print("pe inst len: ", len(pe.inst))
            pe.print_inst()

    binary.op_bit = config["op_bit"]
    binary.ns_bit = config["ns_bit"]
    binary.index_bit = config["index_bit"]
    inst_files = [f for f in os.listdir("./inst/") if os.path.isfile(os.path.join("./inst/", f))]
    for f in inst_files:
        insts = binary.readFrom("./inst/" + f)
        b = binary.generate_bin(insts)
        binary.writeTo(f, b, config["hex"])

    # append zeros to each binary file
    bin_files = [os.path.join("./bin/", f) for f in os.listdir("./bin/")]
    ninst_max = fileformat.get_maxinst(bin_files)
    fileformat.formatf(ninst_max, bin_files)

    # get the file with max number of instructions and its size
    with open('inst_info.txt', 'w') as f:
        f.write('MAX_INST_NUM: ' + str(fileformat.get_maxinst(bin_files)))
        f.write('\n')
        f.write('MAX_FILE_SIZE: ' + str(fileformat.get_maxsize(bin_files)))
    
    # needed for config.list file
    bits = {
        'NUM_PE_VALID': 0,
        'INDEX_INST': 0,
        'INDEX_DATA': 0,
        'INDEX_WEIGHT': 0,
        'INDEX_META': 0,
        'INDEX_INTERIM': 0,
        'INDEX_IN_INST': 0
    }
    bits['NUM_PE_VALID'] = len(node_ir.pe_used)
    bits['INDEX_INST'] = fileformat.getdepth(ninst_max)
    bits['INDEX_DATA'] = get_maxns(pe_list, 'ND')
    bits['INDEX_WEIGHT'] = get_maxns(pe_list, 'NW')
    bits['INDEX_META'] = get_maxns(pe_list, 'NM')
    bits['INDEX_INTERIM'] = get_maxns(pe_list, 'NI')
    bits['INDEX_IN_INST'] = config['index_bit']
    
    gen_configfile('config.list', bits)
    
    # record active pe's
    writeTo('./artifacts/active_pes.json', node_ir.pe_used)

    # get SIG, DIV stuff
    special_modules = ['sigmoid', '/', '#', '*+', '$']
    mods = node_ir.get_special_modules(dfg, special_modules)
    writeTo('./artifacts/special_modules.json', mods)
    with open('config.list', 'a') as f:
        for special_mod in mods:
            f.write('\n' + special_mod)

    # generate memory instructions
    # m = dfgGenerator.constTable['m']
    # modelout = count_modeloutput(dfgGenerator.symTable)
    xy_nodes, w_nodes = node_ir.classify_initial_nodes(dfg)
    #print('model_input and model_output count: {:d}'.format(len(xy_nodes)))
    #print('model output count: {:d}'.format(modelout))
    # m += modelout
    #mem_interface.gen_meminst(m)
    mem_interface.gen_meminst(len(xy_nodes))



def count_modeloutput(sym_table):
    model_output_count = 0
    for sym in sym_table:
        dfgnode = sym_table[sym]
        if dfgnode.dataType == 'model_output':
            model_output_count += 1
    return model_output_count


def get_maxns(pe_list, namespace):
    maxns = 0
    for pe in pe_list:
        ns = pe.namespace_map[namespace]
        #print(ns.tail, maxns)
        if ns.tail > maxns:
            maxns = ns.tail
    if maxns == 1:
        maxns += 1 # hacky way to make log2 greater than 0
    return math.ceil(math.log2(maxns))


def gen_configfile(path, bits):
    #print(bits)
    num_pe_valid = 'NUM_PE_VALID {:d}'.format(bits['NUM_PE_VALID'])
    index_inst = 'INDEX_INST {:d}'.format(bits['INDEX_INST'])
    index_data = 'INDEX_DATA {:d}'.format(bits['INDEX_DATA'])
    index_weight = 'INDEX_WEIGHT {:d}'.format(bits['INDEX_WEIGHT'])
    index_meta = 'INDEX_META {:d}'.format(bits['INDEX_META'])
    index_interim = 'INDEX_INTERIM {:d}'.format(bits['INDEX_INTERIM'])
    index_in_inst = 'INDEX_IN_INST {:d}'.format(bits['INDEX_IN_INST'])

    templ = num_pe_valid + '\n' + \
            index_inst + '\n' + \
            index_data + '\n' + \
            index_weight + '\n' + \
            index_meta + '\n' + \
            index_interim + '\n' + \
            index_in_inst
    with open(path, 'w') as f:
        f.write(templ)
    

def writeTo(path, s):
    with open(path, 'w') as f:
        f.write(json.dumps(s, sort_keys=False, indent=2))


            
if __name__ == '__main__':
    main(sys.argv)
