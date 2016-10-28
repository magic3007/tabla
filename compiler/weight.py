npes = 64 # number of PEs
nlanes = 16 # number of lanes
npe_lane = 4 # number of PEs per lane


def gen_weightconf(wnodes):
    '''
    Generates weight config file, based on the wnodes from DFG.
    '''
    lc = [[0 for col in range(npe_lane)] for row in range(nlanes)]
    for wnode in wnodes:
        peid = wnode.pe.id
        laneid = peid % nlanes
        pe_offset = peid // nlanes
        lc[laneid][pe_offset] += 1
    s = gen_templ(lc)
    return s


def gen_templ(lc):
    define = '`define'
    wcpe = 'WEIGHT_COUNT_PE_'
    wcl = 'WEIGHT_COUNT_LANE_'
    count = "16'h"
    WEIGHT_COUNT = '//WEIGHT_COUNT'
    LANE = '//LANE{:d}'

    linef_pe = define + ' ' + wcpe + '{:d}' + ' ' + count + '{:d}'
    linef_lane = define + ' ' + wcl + '{:d}' + ' ' + count + '{:d}'

    s = ''
    s += WEIGHT_COUNT
    s += '\n'
    for lid, lane in enumerate(lc):
        lane_count = 0
        s += LANE.format(lid)
        s += '\n'
        for pe_offset, pe_count in enumerate(lane):
            peid = pe_offset * nlanes + lid
            s += linef_pe.format(peid, pe_count)
            s += '\n'
            lane_count += pe_count
        s += linef_lane.format(lid, lane_count)
        s += '\n'

    return s


def writeTo(path, s):
    with open(path, 'w') as f:
        f.write(s)



