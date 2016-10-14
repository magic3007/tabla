from serial.DataFlowGraph import *

class DFGGenerator:

    def __init__(self):
        self.symTable = {}
        self.iterTable = {}
        self.constTable = {}
        self.linkTable = {}
        self.gradientTable = {}
        self.dfg = DataFlowGraph()
        self.funcTypeTable = {}
        self.parseTree = None

    def create(self, tree):
        self.parseTree = tree
        self.dfg = DataFlowGraph()
        self.funcTypeTable = {}

        # Create source and sink nodes first.
        source = DFGNode()
        source.operation = 'source'
        self.dfg.add(source)

        sink = DFGNode()
        sink.operation = 'sink'
        sink.dist2sink = 0
        self.dfg.add(sink)

        # Create hash tables for Data_Declarations
        # print("******Before DFG******")
        self.constTable = self.createConstTable()
        self.iterTable = self.createIterTable(self.constTable)
        self.symTable, self.gradientTable = self.createSymbolTable(self.constTable)
        self.funcTypeTable = self.createFuncTypeTable()
        # print('const table',self.constTable)
        # print('iter table',self.iterTable)
        # print('symTable',self.symTable)
        # print('funcTypeTable',self.funcTypeTable)
        # print('gradientTable', self.gradientTable)

        # print("================================\n\n")
        # Get statList for all Stats
        statList = self.parseTree.getChild(1)

        # Creation of DFG.
        if statList.children is not None:
            for stat in statList.children:
                resultNodes = self.statTraversal(stat)

        # Append SGD
        for g in self.linkTable:
            leftBound = g.find("[") + 1
            rightBound = g.rfind("]")
            iterList = g[leftBound:rightBound].split('][')
            for i in range(len(iterList)):
                if not iterList[i].isdigit():
                    iterList[i] = self.constTable[iterList[i]]
            if len(iterList) is 0:
                mult = DFGNode()
                mult.operation = "*"
                #mult.dataType = 'gradient'
                mult.dataType = None
                self.dfg.add(mult)
                self.connectNode(self.symTable[g], mult)
                self.connectNode(symTable["mu"], mult)
                sub = DFGNode()
                sub.operation = "-"
                sub.dataType = 'model'
                self.dfg.add(sub)
                self.connectNode(mult, sub)
                self.connectNode(self.symTable[self.linkTable[g]], sub)
                self.symTable[self.symTable[self.linkTable[g]]] = sub
            else:
                for i in range(iterList[0]):
                    if len(iterList) is 1:
                        gSym = g[0:g.find('[')] + '[' + str(i) + ']'
                        #print(gSym)
                        if gSym in self.symTable:
                            mult = DFGNode()
                            mult.operation = "*"
                            #mult.dataType = 'gradient'
                            mult.dataType = None
                            self.dfg.add(mult)
                            self.connectNode(self.symTable[gSym], mult)
                            self.connectNode(self.symTable["mu"], mult)
                            sub = DFGNode()
                            sub.operation = "-"
                            sub.dataType = 'model'
                            self.dfg.add(sub)
                            wSym = self.linkTable[g] + '[' + str(i) + ']'
                            self.connectNode(mult, sub)
                            self.connectNode(self.symTable[wSym], sub)
                            self.symTable[wSym] = sub
                    else:
                        for j in range(iterList[1]):
                            gSym = g[0:g.find('[')] + '[' + str(i) + '][' + str(j) + ']'
                            if gSym in self.symTable:
                                mult = DFGNode()
                                mult.operation = "*"
                                #mult.dataType = 'gradient'
                                mult.dataType = None
                                self.dfg.add(mult)
                                self.connectNode(self.symTable[gSym], mult)
                                self.connectNode(self.symTable["mu"], mult)
                                sub = DFGNode()
                                sub.operation = "-"
                                sub.dataType = 'model'
                                self.dfg.add(sub)
                                wSym = self.linkTable[g] + '[' + str(i) + '][' + str(j) + ']'
                                self.connectNode(mult, sub)
                                self.connectNode(self.symTable[wSym], sub)
                                self.symTable[wSym] = sub
                
        # Needs to connect correct outputs to the sink node
        for node in self.symTable.values():       # Connect outputs
            if len(node.children) is 0 and len(node.parents) is not 1:
                self.connectNode(node, self.dfg.get(1))

        # Calculates all the distances to sink
        self.setDist2sink(sink)

        # Remove useless nodes
        # self.dfg.updateId()
        removedNodes = []
        for node in self.dfg.nodes:
            if node.dist2sink is None:
                for child in node.children:
                    child.parents.remove(node)
                for parent in node.parents:
                    parent.children.remove(node)
                removedNodes.append(node)
        for node in removedNodes:
            self.dfg.remove(node)

        # Print and save
        self.dfg.updateId()
        # for val in self.dfg.nodes:
            # print(val)
        # print("******After DFG******")
        # print('const table',self.constTable)
        # print('iter table',self.iterTable)
        # print('symTable',self.symTable)

#        self.dfg.save('./dfg.json')

        return self.dfg


    def writeTo(self, dfg, path):
        dfg.save(path)

    def statTraversal(self, statNode):
        # print(statNode.getText())
        leftHS = statNode.getChild(0).getText()
        var = leftHS[0:leftHS.find("[")]
        dimensions = statNode.getChild(0).getChild(0).getChild(1).getText()[1:-1].split("][")

        arr = []
        # Single Assignment
        if dimensions[0] is '' or dimensions[0].isdigit():
            iterDict = {}
            resultNode = self.exprTraversal(statNode.getChild(2), iterDict)
            self.symTable[leftHS] = resultNode
            arr.append(resultNode)
        else:
            # Currently only handles 2-d arrays
            iter0 = self.iterTable[dimensions[0]]
            iter1 = self.iterTable[dimensions[1]] if len(dimensions) > 1 else None

            for i in range(iter0[0], iter0[1]):
                iterDict = {dimensions[0]: i}
                if iter1 is not None: # result is two dimensional array
                    for j in range(iter1[0], iter1[1]):
                        iterDict[dimensions[1]] = j
                        resultNode = self.exprTraversal(statNode.getChild(2), iterDict)
                        # color
                        if var in self.gradientTable:
                            resultNode.dataType = 'gradient'
                        self.symTable[var + '[' + str(i) + '][' + str(j) + ']'] = resultNode
                        arr.append(resultNode)
                else:
                    resultNode = self.exprTraversal(statNode.getChild(2), iterDict)

                    # color
                    print('debug...statTraversal...var is: ', var)
                    print('debug...statTraversal...var type is: ', type(var))
                    print('debug...statTraversal...gradientTable is: ', self.gradientTable)
                    if var in self.gradientTable:
                        #resultNode.dataType = 'gradient'
                        resultNode.dataType = None
                    
                    self.symTable[var + '[' + str(i) + ']'] = resultNode
                    arr.append(resultNode)

        return arr



    def exprTraversal(self, exprNode, iterDict):
        # print('exprTraversal ' + exprNode.getText())
        if exprNode.getChild(1).children is not None:
            node = self.term2TailTraversal(exprNode.getChild(1), iterDict)   # Go into term2Tail
            leftParent = self.term2Traversal(exprNode.getChild(0), iterDict)
            self.connectNode(leftParent, node)
        else:
            node = self.term2Traversal(exprNode.getChild(0), iterDict)

        return node


    def term2TailTraversal(self, currTerm2Tail, iterDict):
        # print('term2TailTraversal ' + currTerm2Tail.getText())
        node = DFGNode()
        node.operation = currTerm2Tail.getChild(0).getText()

        if currTerm2Tail.getChild(2).children is not None:
            rightParent = self.term2TailTraversal(currTerm2Tail.getChild(2), iterDict)
            rightLeftParent = self.term2Traversal(currTerm2Tail.getChild(1), iterDict)
            self.connectNode(rightLeftParent, rightParent)
        else:
            rightParent = self.term2Traversal(currTerm2Tail.getChild(1), iterDict)
        
        self.dfg.add(node)
        self.connectNode(rightParent, node)

        return node

    def term2Traversal(self, term2Node, iterDict):
        # print('term2Traversal ' + term2Node.getText())
        if term2Node.getChild(1).children is not None:
            node = self.term1TailTraversal(term2Node.getChild(1), iterDict)
            leftParent = self.term1Traversal(term2Node.getChild(0), iterDict)
            self.connectNode(leftParent, node)
        else:
            node = self.term1Traversal(term2Node.getChild(0), iterDict)

        return node


    def term1TailTraversal(self, currTerm1Tail, iterDict):
        # print('term1TailTraversal ' + currTerm1Tail.getText())
        node = DFGNode()
        node.operation = currTerm1Tail.getChild(0).getText()

        if currTerm1Tail.getChild(2).children is not None:
            rightParent = self.term1TailTraversal(currTerm1Tail.getChild(2), iterDict)
            rightLeftParent = self.term1Traversal(currTerm1Tail.getChild(1), iterDict)
            self.connectNode(rightLeftParent, rightParent)
        else:
            rightParent = self.term1Traversal(currTerm1Tail.getChild(1), iterDict)

        self.dfg.add(node)
        self.connectNode(rightParent, node)

        return node

    def term1Traversal(self, term1Node, iterDict):
        # print('term1Traversal ' + term1Node.getText())
        if term1Node.getChild(1).children is not None:
            node = self.term0TailTraversal(term1Node.getChild(1), iterDict)
            leftParent = self.term0Traversal(term1Node.getChild(0), iterDict)
            self.connectNode(leftParent, node)
        else:
            node = self.term0Traversal(term1Node.getChild(0), iterDict)

        return node


    def term0TailTraversal(self, currTerm0Tail, iterDict):
        # print('term0TailTraversal ' + currTerm0Tail.getText())
        node = DFGNode()
        node.operation = currTerm0Tail.getChild(0).getText()
      
        if currTerm0Tail.getChild(2).children is not None:
            rightParent = self.term0TailTraversal(currTerm0Tail.getChild(2), iterDict)
            rightLeftParent = self.term0Traversal(currTerm0Tail.getChild(1), iterDict)
            self.connectNode(rightLeftParent, rightParent)
        else:
            rightParent = self.term0Traversal(currTerm0Tail.getChild(1), iterDict)

        self.dfg.add(node)
        self.connectNode(rightParent, node)

        return node

    def term0Traversal(self, currTerm0, iterDict):
        # print('term0Traversal ' + currTerm0.getText())
        if len(currTerm0.children) == 3:                                # expr child
            return self.exprTraversal(currTerm0.getChild(1), iterDict)
        elif len(currTerm0.children) == 2:                              # func child
            return self.funcTraversal(currTerm0, iterDict)
        elif currTerm0.getChild(0).getText().isdigit():                 # INTLIT
            digit = currTerm0.getChild(0).getText()
            int(currTerm0.getChild(0).getText())

            # Create seperate node for numerical values that are connected to the src.
            if digit in self.symTable:
                return self.symTable[digit]
            else:
                node = DFGNode()
                node.operation = digit
                node.dataType = 'constant'
                self.dfg.add(node)
                self.connectNode(self.dfg.get(0), node)
                self.symTable[digit] = node
                return node
        else:                                                           # ID
            var = currTerm0.getText()
            leftBound = var.find("[") + 1
            rightBound = var.rfind("]")
            if rightBound == -1:    # Weird Mathematical constant symbols like lambda
                return self.symTable[var]

            # Getting exact iteration instance.  ie. a[0][2]
            iterList = var[leftBound:rightBound].split('][')
            key = var[:var.find('[')]
            for it in iterList:         # replace [i] with iteration value
                key = key + '[' + str(iterDict[it]) + ']'
            return self.symTable[key]


    def funcTraversal(self, currTerm0, iterDict):
        # print('funcTraversal ' + currTerm0.getText())
        numParents = int(self.funcTypeTable[currTerm0.getChild(0).getText()])
        if numParents == 1 :
            return self.funcSingleParentTraversal(currTerm0, iterDict)
        else:
            return self.funcMultiParentTraversal(currTerm0, iterDict)

    def funcSingleParentTraversal(self, currTerm0, iterDict):
        node = DFGNode()
        node.operation = currTerm0.getChild(0).getText()
        parent = self.exprTraversal(currTerm0.getChild(1).getChild(1), iterDict)
        self.dfg.add(node)
        self.connectNode(parent, node)
        return node

    def funcMultiParentTraversal(self, currTerm0, iterDict):
        funcArgs = currTerm0.getChild(1)
        funcRangeIterator = funcArgs.getChild(1).getText()
        funcIterations = self.iterTable[funcRangeIterator]
        funcVals = []
        funcDict = iterDict

        # Calculates all expressions
        for i in range(funcIterations[0], funcIterations[1]):
            funcDict[funcRangeIterator] = i
            funcVals.append(self.exprTraversal(funcArgs.getChild(4), funcDict))

        functionType = currTerm0.getChild(0).getText()
        operator = '+' if (functionType == 'sum' or functionType == 'norm') else (
                   '*' if (functionType == 'pi') else 
                   '')

        if functionType == 'norm':      # We square the output expression and sum
            x = []
            for val in funcVals:
                node = DFGNode()
                node.operation = '*'
                self.dfg.add(node)
                self.connectNode(val, node)
                self.connectNode(val, node)
                x.append(node)
            funcVals = x

        # Combines nodes in list with operator node
        #   and inserts operator node back in list
        while (len(funcVals) > 1):
            # print(len(funcVals))
            left = funcVals.pop(0)
            right = funcVals.pop(0)
            node = DFGNode()
            node.operation = operator
            self.dfg.add(node)
            self.connectNode(right, node)
            self.connectNode(left, node)
            funcVals.append(node)

        return funcVals.pop(0)


    def createConstTable(self):
        constTable = {}

        dataDecList = self.parseTree.getChild(0)
        for dataDec in dataDecList.getChildren():
            dataType = dataDec.getChild(0)
            if dataType.ASSIGN() is not None:
                x = int(dataType.INTLIT().getText())
                constTable[dataType.ID().getText()] = x

        return constTable

    def createIterTable(self, constTable):
        iterTable = {}

        dataDecList = self.parseTree.getChild(0)
        for dataDec in dataDecList.getChildren():
            dataType = dataDec.getChild(0)
            if dataType.ASSIGN() is None and dataType.getChild(0).getText() == 'iterator':
                key = dataType.getChild(1).getChild(0).getText()
                val1 = dataType.getChild(1).getChild(2).getText()
                val2 = dataType.getChild(1).getChild(4).getText()
                if val1.isdigit():
                    val1 = int(val1)
                else:
                    val1 = constTable[val1]
                if val2.isdigit():
                    val2 = int(val2)
                else:
                    val2 = constTable[val2]
                iterTable[key] = (val1, val2);

        return iterTable
                
    def createSymbolTable(self, constTable):
        symTable = {}
        gradientTable = {} # color
        for const in constTable.keys():
            node = DFGNode()
            node.operation = const
            node.dataType = 'constant'
            self.dfg.add(node)
            self.connectNode(self.dfg.get(0), node)
            symTable[const] = node
        dataDecList = self.parseTree.getChild(0)
        for dataDec in dataDecList.getChildren():
            dataType = dataDec.getChild(0)
            if dataType.getChild(0).getText() != 'iterator' and dataType.ASSIGN() is None: # means non_iterator (like model_input)
                x = dataType.getChild(1).getText().strip().split(",")
                if dataType.GRADIENT() is not None:
                    for d in x:
                        link = dataType.getChild(1).getText().strip().split('->')
                        gradVar = link[0]
                        modelVar = link[1]
                        self.linkTable[gradVar] = modelVar
                        gradKey = gradVar[:gradVar.find('[')] #color
                        #print(gradKey)
                        gradientTable[gradKey] = True #color
                        #print('debug', gradientTable)
                else: # means either model_input, model_output, or model
                    # Array of vars.  ex. ['#1[#0]', '#2[#0]']
                    for d in x:
                        if (d.find("[") is -1): # a single variable
                            symTable[d] = 0;
                            node = DFGNode()
                            node.operation = d
                            node.dataType = dataType.getChild(0).getText()
                            self.dfg.add(node)
                            self.connectNode(self.dfg.get(0), node)
                            symTable[d] = node
                        else:
                            iterList = d[d.find("[")+1:-1].split('][')  # gets id within brackets
                            if iterList[0].isdigit():
                                iter0 = int(iterList[0])
                            else:
                                iter0 = constTable[iterList[0]]
                            for i in range(iter0): # statically just one dimension
                                stringKey = '' + d[:d.find("[")] + '[' + str(i) + ']'
                                if len(iterList) > 1:
                                    if iterList[1].isdigit():
                                        iter1 = int(iterList[1])
                                    else:
                                        iter1 = constTable[iterList[1]]
                                    for j in range(iter1):
                                        stringKeyTwo = stringKey + '[' + str(j) + ']'
                                        node = DFGNode()
                                        node.operation = stringKeyTwo
                                        node.dataType = dataType.getChild(0).getText()
                                        self.dfg.add(node)
                                        self.connectNode(self.dfg.get(0), node)
                                        symTable[stringKeyTwo] = node

                                else:
                                    node = DFGNode()
                                    node.operation = stringKey
                                    node.dataType = dataType.getChild(0).getText()
                                    self.dfg.add(node)
                                    self.connectNode(self.dfg.get(0), node)
                                    symTable[stringKey] = node
        print('after createSymbolTable()...', gradientTable)
        return (symTable, gradientTable)

    def createFuncTypeTable(self):
        x = {}
        # 2 = multi parents
        # 1 = 1 parent
        x['pi'] = 2
        x['sum'] = 2
        x['norm'] = 2
        x['gaussian'] = 1
        x['sigmoid'] = 1
        x['sig_sym'] = 1
        x['log'] = 1
        return x

    def connectNode(self, parent, child):
        child.parents.insert(0, parent)
        parent.children.append(child)

    def setDist2sink(self, currNode):
        for parent in currNode.parents:
            if parent.dist2sink is None or parent.dist2sink < currNode.dist2sink + 1:
                parent.dist2sink = currNode.dist2sink + 1
            self.setDist2sink(parent)

