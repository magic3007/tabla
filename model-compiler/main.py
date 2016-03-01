from antlr4 import *

import sys, os

from TablaLexer import TablaLexer
from TablaParser import TablaParser
from DFGGenerator import DFGGenerator
from DotGenerator import DotGenerator
from Scheduler import Scheduler

def main(argv):
    input = FileStream(argv)
    lexer = TablaLexer(input)
    stream = CommonTokenStream(lexer)
    parser = TablaParser(stream)
    tree = parser.program()   ### program is the starting rule. The parser is invoked by calling the starting rule.
    
    # graph creation should happen here
    print('\n\n================================')
    dfgGenerator = DFGGenerator()
    dfg = dfgGenerator.create(tree)
    dfg_file = './dfg_' + os.path.basename(argv)[:-2] + '.json'
    dfgGenerator.writeTo(dfg, dfg_file)

    scheduler = Scheduler()
    newDfg = scheduler.readFrom(dfg_file)
    scheduler.createSchedule(newDfg, 16)
    schedule_file = './schedule_' + os.path.basename(argv)[:-2] + '.json'
    scheduler.writeTo(schedule_file)

    dotGenerator = DotGenerator()
    newDfg = dotGenerator.readFrom(dfg_file)
    cycle2id = dotGenerator.readSched(schedule_file)
    dotCode = dotGenerator.generateDot(newDfg, cycle2id)
    dot_file = './dot_' + os.path.basename(argv)[:-2] + '_cycle.dot'
    dotGenerator.writeTo(dotCode, dot_file)


if __name__ == '__main__':
    for filename in sys.argv[1:]:
        main(filename)
