from antlr4 import *

import sys

from TablaLexer import TablaLexer
from TablaParser import TablaParser
from treewalker import ProgramPrinter
from DFGGenerator import DFGGenerator
from DotGenerator import DotGenerator
from Scheduler import Scheduler

def main(argv):
    input = FileStream(argv[1])
    lexer = TablaLexer(input)
    stream = CommonTokenStream(lexer)
    parser = TablaParser(stream)
    tree = parser.program()   ### program is the starting rule. The parser is invoked by calling the starting rule.
    
    '''
    printer = ProgramPrinter()
    walker = ParseTreeWalker()
    walker.walk(printer, tree) ## after this, we have SSA parse tree
    '''

    # graph creation should happen here
    print('\n\n================================')
    dfgGenerator = DFGGenerator()
    dfg = dfgGenerator.create(tree)
    dfgGenerator.writeTo(dfg, './dfg.json')

    # scheduler = Scheduler(dfg)
    # schedule = scheduler.createSchedule(16)
    scheduler = Scheduler()
    newDfg = scheduler.readFrom('./dfg.json')
    scheduler.createSchedule(newDfg, 16)
    scheduler.writeTo('./schedule.json')

    dotGenerator = DotGenerator()
    newDfg = dotGenerator.readFrom('./dfg.json')
    cycle2id = dotGenerator.readSched('./schedule.json')
    dotCode = dotGenerator.generateDot(newDfg, cycle2id)
    dotGenerator.writeTo(dotCode, './tabla.dot')


if __name__ == '__main__':
    main(sys.argv)
