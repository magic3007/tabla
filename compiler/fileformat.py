import os
import math


#ninst_max = 0
ninst = 0
EXTRA_ZERO = 1


def get_ninst(s):
    '''
    Gets the number of instructions
    '''
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


def readFrom(path):
    with open(path, 'r') as f:
        s = f.read()
    return s


def writeTo(path, string):
    with open(path, 'w') as f:
        f.write(string)


def get_maxinst(bin_files):
    ninst_max = 0
    for bf in bin_files:
        s = readFrom(bf)
        ninst = get_ninst(s)
        if ninst > ninst_max:
            ninst_max = ninst
    return ninst_max


def get_maxsize(bin_files):
    maxsize = 0
    for bf in bin_files:
        size = os.path.getsize(bf)
        if size > maxsize:
            maxsize = size
    return maxsize


def formatf(ninst_max, bin_files):
    depth = getdepth(ninst_max)
    for bf in bin_files:
        s = readFrom(bf)
        ninst = get_ninst(s)
        numzeros = 2 ** depth
        diff = numzeros - ninst
        s = appendzeros(s, diff)
        writeTo(bf, s)

