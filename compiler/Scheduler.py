# For now, I assume a predecessor is done only if it is in previous cycles

from serial.DataFlowGraph import *
import copy
import json
import collections

class Scheduler:

    def __init__(self):
        self.schedule = []  # a list of list
        originalDfg = None
        dfg = None

    def createSchedule(self, originalDfg, constraints):   # constraints is number of PEs for now
        self.originalDfg = originalDfg
        dfg = copy.copy(originalDfg)
        self.dfg = dfg
        cycle = 0
        self.schedule.append([])
        source = dfg.get(0)
        sink = dfg.get(1)
        dfg.remove(source)
        dfg.remove(sink)
        for node in source.children:
            self.schedule[cycle].append(node.id)
            dfg.remove(node)
        self.sortDFGByDist2sink(dfg)
        # source = dfg.get(dfg.getSize() - 1)
        # sink = dfg.get(0)
        count = dfg.getSize() - 1
        while not dfg.isEmpty():
            #print(dfg.size)
            #print(count)
            #print(self.schedule[0])
            node = dfg.get(count)
            if self.isReady(node, cycle):
                # print(node)
                self.schedule[cycle].append(node.id)
                dfg.remove(node)
                count = dfg.getSize() - 1
                if len(self.schedule[cycle]) == constraints:
                    cycle += 1
                    self.schedule.append([])
            else:
                count -= 1
                if (count < 0): # Even if resources are not used up, we have to start a new cycle
                    cycle += 1
                    self.schedule.append([])
                    count = dfg.getSize() - 1

        # Print schedule
        #print("*********************")
        #for i in range(len(self.schedule)):
            #print("\n*****cycle " + str(i) + "*****\n")
            #for node in self.schedule[i]:
                #print(node)
        return self.schedule


    '''
    def isScheduled(self, node, currCycle):
        for cycle in self.schedule[0:currCycle]:
            # print (node)
            #print (cycle)
            if node.id in cycle:
                return True
        return False
    '''

    def isReady(self, node, currCycle):
        for parent in node.parents:
            # if parent.parents[0].id is not 0 and not self.isScheduled(parent, currCycle):
            if parent in self.dfg.nodes or parent.id in self.schedule[currCycle]:
                #print (parent)
                #print (self.isScheduled(parent, currCycle))
                return False
        return True

    def sortDFGByDist2sink(self, dfg):
        dfg.nodes = sorted(dfg.nodes, key = lambda node: node.dist2sink)

    '''
       These functions read a dfg json file and sets the originalDFG instance variable.
    '''
    def readFrom(self, path):
        return self.load(path)

    def load(self, path):
        with open(path, 'r') as f:
            return self.fromStr(f.read())

    def fromStr(self, s):
        return self.fromList(json.loads(s))
    
    def fromList(self, l):
        dfg = DataFlowGraph()
        for nodeDict in l:
            node = DFGNode()
            node.fromDict(nodeDict)
            dfg.nodes.insert(node.id, node)

        for node in dfg.nodes:
            children = node.children
            for index,childId in enumerate(children):
                children[index] = dfg.get(childId)

            parents = node.parents
            for index,parentId in enumerate(parents):
                parents[index] = dfg.get(parentId)
            
        return dfg

    '''
       These functions write a scheduled graph to a json file.
    '''
    def toList(self, cycleList):
        list = []
        #print("cycleList in toList",cycleList)
        for index, nodeId in enumerate(cycleList):
            #print("nodeId in toList: ",nodeId)
            node = self.originalDfg.get(nodeId)
            #print("node in toList: ", node)
            list.append(node.toDict())
        #print(list)
        return list
        
    def toDict(self):
        CYCLE = 'cycle'
        d = collections.OrderedDict()
        for index, cycleList in enumerate(self.schedule):
            d[CYCLE + str(index)] = self.toList(cycleList)
        #print(type(d))
        return d

    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)

    def save(self, path):
        with open(path, 'w') as f:
            f.write(self.__str__())

    def writeTo(self, path):
        self.save(path)
