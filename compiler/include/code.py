NAMESPACE_NULL=0
NAMESPACE_WEIGHT=1 # NAMESPACE_DATA[0]         # NAMESPACE_WEIGHT[0]
NAMESPACE_DATA=2
NAMESPACE_GRADIENT=3
NAMESPACE_INTERIM=4
NAMESPACE_META=5
NAMESPACE_NEIGHBOR=6 # [0] = PE_NEIGHBOR, [1] = PU_NEIGHBOR
NAMESPACE_BUS=7

FN_PASS=0
FN_ADD=1
FN_SUB=2
FN_MUL=3
FN_MAC=4
FN_DIV=5
FN_SQR=6
FN_SIG=7
FN_GAU=8
FN_LT=9
FN_GT=10
NOP=11

op = {
    'pass' : FN_PASS,
    '+'  : FN_ADD,
    '-'  : FN_SUB,
    '*'  : FN_MUL,
    '*+' : FN_MAC,
    '/'  : FN_DIV,
    '#'  : FN_SQR,
    #'&'  : FN_SIG,
    'sigmoid' : FN_SIG,
    '$'  : FN_GAU,
    '>'  : FN_GT,
    '<'  : FN_LT,
    'NOP' : NOP
}

op_inv = {
    0: 'pass',
    1: '+',
    2: '-',
    3: '*',
    4: '*+',
    5: '/',
    6: '#',
    7: '&',
    8: '$',
    9: '>',
    10: '<',
    11: 'NOP'
    }

ns_inv = {
    0: 'NL',
    1: 'NW',
    2: 'ND',
    3: 'NG',
    4: 'NI',
    5: 'NM',
    6: 'NN',
    7: 'NB'
    }

namespace = {
    'NW'  : NAMESPACE_WEIGHT,
    'ND'  : NAMESPACE_DATA,
    'NG'  : NAMESPACE_GRADIENT,
    'NI'  : NAMESPACE_INTERIM,
    'NM'  : NAMESPACE_META,
    'NN'  : NAMESPACE_NEIGHBOR,
    'NB'  : NAMESPACE_BUS,
    'NL'  : NAMESPACE_NULL,
}

