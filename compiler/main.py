#!/usr/bin/env python3

from antlr4 import *

import sys
sys.path.insert(0, 'include')
import os
import argparse
import json

from TablaLexer import TablaLexer
from TablaParser import TablaParser
#from treewalker import ProgramPrinter
from DFGGenerator import DFGGenerator
from DotGenerator import DotGenerator
from Scheduler import Scheduler
#from binaryGenerator import *

import node_ir, inst, binary
from pu import Pu
from pe import Pe

def main(argv):
    config = read_config("./config.json")
    
    argparser = argparse.ArgumentParser()
    argparser.add_argument("filename", help="file name")
    args = argparser.parse_args()
    
    input_file = FileStream(args.filename)
    lexer = TablaLexer(input_file)
    stream = CommonTokenStream(lexer)
    parser = TablaParser(stream)
    tree = parser.program()   ### 'program' is the starting rule. The parser is invoked by calling the starting rule.
    
    '''
    printer = ProgramPrinter()
    walker = ParseTreeWalker()
    walker.walk(printer, tree) ## after this, we have SSA parse tree
    '''

    # graph creation should happen here
    print('\n\n================================')
    dfg_file = 'artifacts/dfg.json'
    dfgGenerator = DFGGenerator()
    dfg = dfgGenerator.create(tree)
    dfgGenerator.writeTo(dfg, dfg_file)

    num_pes = config["num_pes"]
    schedule_file = 'artifacts/schedule.json'
    scheduler = Scheduler()
    newDfg = scheduler.readFrom(dfg_file)
    scheduler.createSchedule(newDfg, num_pes)
    scheduler.writeTo(schedule_file)

    dot_file = 'artifacts/tabla.dot'
    dotGenerator = DotGenerator()
    newDfg = dotGenerator.readFrom(dfg_file)
    cycle2id = dotGenerator.readSched(schedule_file)
    dotCode = dotGenerator.generateDot(newDfg, cycle2id)
    dotGenerator.writeTo(dotCode, dot_file)

    pes_per_pu = config["pes_per_pu"]
    ns_size = config["namespace_size"]
    ns_int_size = config["namespace_interim_size"]

    # generate PU's and PE's based on config valeus
    pu_list = []
    num_pus = num_pes // pes_per_pu # assum num_pes is a power of 2 for now
    for i in range(num_pus):
        pu_list.append(Pu(i))
    pe_list = []
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
            pe.next = pe_list[i * pu_count + pes_per_pu - 1]
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
        
    pu_pe = (pu_list, pe_list)

    schedule = node_ir.readFrom("./artifacts/schedule.json")
    node_graph = node_ir.generate_node_graph(schedule)
    node_graph.set_parents_and_children()
    node_ir.assign_pes(node_graph, num_pes, schedule, ns_size, ns_int_size, pu_pe)
    node_graph.writeTo("./artifacts/nodes_ir.json")

    #node_graph = inst.readFrom("./artifacts/nodes_ir.json")
    inst.generate_inst(node_graph, pes_per_pu, pe_list)
    for pe in pe_list:
        print(pe.id)
        pe.print_inst()
    '''
    pe_to_inst = node_graph.separate_inst_by_pe()
    inst.add_nop(pe_to_inst)
    filenames = inst.writeTo(pe_to_inst)
    '''

    binary.op_bit = config["op_bit"]
    binary.ns_bit = config["ns_bit"]
    binary.index_bit = config["index_bit"]
    inst_files = [f for f in os.listdir("./inst/") if os.path.isfile(os.path.join("./inst/", f))]
    for f in inst_files:
        insts = binary.readFrom("./inst/" + f)
        b = binary.generate_bin(insts)
        binary.writeTo(f, b, config["hex"])
    
            
def read_config(filename):
    with open(filename, 'r') as f:
        contents = f.read()
    return json.loads(contents)
    
        
if __name__ == '__main__':
    main(sys.argv)
