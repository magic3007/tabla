#!/usr/bin/env python3
from antlr4 import *
import sys
sys.path.insert(0, 'include')
import os
import argparse
import json
from TablaLexer import TablaLexer
from TablaParser import TablaParser
from DFGGenerator import DFGGenerator
from DotGenerator import DotGenerator
from Scheduler import Scheduler
import node_ir, inst, binary
from pu import Pu
from pe import Pe


def read_config(filename):
    with open(filename, 'r') as f:
        contents = f.read()
    return json.loads(contents)

def genpus(num_pes, pes_per_pu, ns_size, ns_int_size):
    pu_list = []
    pe_list = []
    num_pus = num_pes // pes_per_pu # assum num_pes is a power of 2 for now

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

    pe_count = 0
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
    print('\n\n================================')
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

    # generate PU's and PE's based on config valeuse
    print('*' * 20)
    pu_list, pe_list = genpus(num_pes, pes_per_pu, ns_size, ns_int_size)
    pu_pe = (pu_list, pe_list)

    # assign pes to every node
    schedule = node_ir.readFrom("./artifacts/schedule.json")
    dfg = node_ir.generate_node_graph(schedule)
    dfg.set_parents_and_children()
    node_ir.assign_pes(dfg, num_pes, schedule, ns_size, ns_int_size, pu_pe)
    dfg.writeTo("./artifacts/nodes_ir.json")

    # record active pe's
    writeTo('./active_pes.json', node_ir.pe_used)

    # get SIG, DIV stuff
    special_modules = ['sigmoid', '/', '#', '*+', '$']
    mods = node_ir.get_special_modules(dfg, special_modules)
    writeTo('./special_modules.json', mods)

    #dfg = inst.readFrom("./artifacts/nodes_ir.json")
    inst.generate_inst(dfg, pes_per_pu)
    for pe in pe_list:
        print(pe.id)
        pe.print_inst()

    binary.op_bit = config["op_bit"]
    binary.ns_bit = config["ns_bit"]
    binary.index_bit = config["index_bit"]
    inst_files = [f for f in os.listdir("./inst/") if os.path.isfile(os.path.join("./inst/", f))]
    for f in inst_files:
        insts = binary.readFrom("./inst/" + f)
        b = binary.generate_bin(insts)
        binary.writeTo(f, b, config["hex"])


def writeTo(path, s):
    with open(path, 'w') as f:
        f.write(json.dumps(s, sort_keys=False, indent=2))
            
if __name__ == '__main__':
    main(sys.argv)
