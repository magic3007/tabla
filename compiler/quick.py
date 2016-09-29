import os
import math

def readFrom(path):
    with open(path, 'r') as f:
        s = f.read()
    return s

def get_ninst(s):
    ninst = 0
    for c in s:
        if c == '\n':
            ninst += 1
    return ninst

def getdepth(maxinst):
    return math.ceil(math.log2(maxinst + EXTRA_ZERO))

def appendzeros(string, numzeros):
    zeros = '0\n' * numzeros
    return string + zeros

def writeTo(path, string):
    with open(path, 'w') as f:
        f.write(string)

bin_files = [os.path.join("./bin/", f) for f in os.listdir("./bin/")]
ninst_max = 0
ninst = 0
EXTRA_ZERO = 1

for bf in bin_files:
    s = readFrom(bf)
    #print(s)
    ninst = get_ninst(s)
    if ninst > ninst_max:
        ninst_max = ninst

depth = getdepth(ninst_max)
#print("max num of inst: ", ninst_max)
#print("depth: ", depth)

for bf in bin_files:
    print(bf)
    s = readFrom(bf)
    ninst = get_ninst(s)
    numzeros = 2 ** depth
    diff = numzeros - ninst
    s = appendzeros(s, diff)
    #print(s)
    writeTo(bf, s)
