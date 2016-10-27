from collections import deque

header = 'digraph G {' + '\n'
footer = '}' + '\n'


def gendot(dfg, cycle2id):
    #dfg = copy.copy(importedDFG)
    strList = []
    strList.append(header)
    
    bfs(dfg, strList)
    
    # append rank here
    rank = genrank(cycle2id)
    strList.append(rank)

    strList.append(footer)
    dotCode = ''.join(strList)
    return dotCode


def bfs(dfg, strList):
    initnodes = dfg.get_nodes_in_cycle(0)
    queue = deque(initnodes)
    visitedList = set([])

    idDict = {}
    for node in initnodes:
        idDict[node] = genlabel(node)
    idDict['Sink'] = '"sink"'
    
    while len(queue) > 0:
        currNode = queue.popleft()

        # Connecting currNode with children
        left = idDict[currNode]
        for child in currNode.children:
            if child not in visitedList and child != 'Sink':
                queue.append(child)
                visitedList.add(child)

            # Child node doesn't have operation label
            if child not in idDict:
                idDict[child] = genlabel(child)
            right = idDict[child]

            # flow is a line
            flow = str.format('{} -> {};\n', left, right)
            strList.append(flow)

        visitedList.add(currNode)


def genlabel(node):
    if node.pe is not None:
        label = '{"' + str(node.id) + '" [label="' + node.op + ' ' + str(node.pe.id) +'"]' + '}'
    else:
        label = '{"' + str(node.id) + '" [label="' + node.op +'"]' + '}'
    return label


def genrank(cycle2id):
    rankCode = ''
    rankSink = '{rank = sink; "sink";};\n'

    # cycle2id is a dictionary of cycle to node id list
    for cycle in cycle2id:
        rankTempl = '{rank = same; '
        idList = cycle2id[cycle]
        sameRankIds = ''
        for id in idList:
            sameRankIds += '"' + str(id) + '"' + '; '
        rankTempl += sameRankIds + '};\n'
        rankCode += rankTempl
    rankCode += rankSink
    return rankCode
