import json
import sys

class Lane:
    def __init__(self, laneid, peids):
        self.laneid = laneid
        self.peids = peids

    def get_relpeid(self, peid):
        if peid in self.peids:
            return self.peids.index(peid)
        else:
            raise Exception("PE ID {:d} not in this lane!".format(peid))

    def toDict(self):
        d = {
            "laneid": self.laneid,
            "peids": self.peids
        }
        return d


class Meminst:
    def __init__(self, op=None, shiftamount=0, nlanes=16):
        self.op = op
        self.shiftamount = shiftamount
        self.lanes = self.init_laneinst(nlanes)

    def init_laneinst(self, nlanes):
        lanes = []
        for i in range(nlanes):
            lanes.append({
                "laneid": i,
                "relpe": 0,
                "valid": 0
            })
        return lanes

    def set_laneinst_at(self, laneid, relpeid):
        d = self.lanes[laneid]
        d["relpe"] = relpeid
        d["valid"] = 1

    def toDict(self):
        d = {
            "op": self.op,
            "shift": self.shiftamount,
            "lanes": self.lanes
        }
        return d

    def __str__(self):
        return json.dumps(self.toDict(), sort_keys=False, indent=2)

        
nlanes = 16
pes_per_lane = 4
shiftleft = True


def init_lanes(nlanes, pes_per_lane):
    lanes = []
    for base_peid in range(nlanes):
        lanes.append(Lane(base_peid, [base_peid + nlanes * i for i in range(pes_per_lane)]))
    return lanes


def get_lanesbyshift(read_vals):
    lanesbyshift = {}
    for curr_pos, data in enumerate(read_vals):
        dest_peid = data % 64
        dest_laneid = get_dest_laneid(dest_peid)
        shiftamount = get_shiftamount(curr_pos, dest_laneid)
        if shiftamount in lanesbyshift:
            lanesbyshift[shiftamount].append((dest_laneid, dest_peid))
        else:
            lanesbyshift[shiftamount] = [(dest_laneid, dest_peid)]
        #print("pos: {:d}, dest_laneid: {:d}, shift to left: {:d}".format(curr_pos, dest_laneid, shiftamount))
    return lanesbyshift


def get_shiftamount(pos, laneid):
    if pos >= laneid:
        shift = pos - laneid
    else:
        shift = nlanes - (laneid - pos)
    return shift

    
def get_dest_laneid(peid):
    return peid % nlanes


def get_laneobject(lanes, laneid):
    return lanes[laneid]


def gen_shift_inst(shiftamount, affectedlanes, lanes):
    inst = Meminst("shift", shiftamount)
    for lane in affectedlanes:
        laneid = lane[0]
        peid = lane[1]
        laneobj = get_laneobject(lanes, laneid)
        relpeid = laneobj.get_relpeid(peid)
        inst.set_laneinst_at(laneid, relpeid)
    return inst


def gen_read_inst():
    return Meminst("read")


def gen_wfi_inst():
    return Meminst("wfi")


def gen_loop_inst():
    return Meminst("loop")

def writeTo(path, s):
    with open(path, 'w') as f:
        f.write(s)


peid_bits = 2
valid_bits = 1
opcode_bits = 2
shift_bits = 4
namespace_bits = 2

nsbin = {
    "instructions": 0,
    "data": 1,
    "weight": 2,
    "meta": 3
    }

opbin = {
    "read": 0,
    "shift": 1,
    "wfi": 2,
    "loop": 3
    }


def gen_singlelane_bin(lane):
    peid = lane["relpe"]
    valid = lane["valid"]
    bin_str = format(peid, '0' + str(peid_bits) + 'b') + format(valid, '0' + str(valid_bits) + 'b')
    return bin_str


def gen_lanes_bin(lanes):
    bin = ''
    for lane in reversed(lanes):
        bin += gen_singlelane_bin(lane)
    bin += gen_ns_bin("data")
    return bin


def gen_ns_bin(ns):
    return format(nsbin[ns], '0' + str(namespace_bits) + 'b')


def gen_opcode_bin(op):
    return format(opbin[op], '0' + str(opcode_bits) + 'b')


def gen_shift_bin(shift):
    return format(shift, '0' + str(shift_bits) + 'b')


# these two variables determine how many read instructions are required
#m = 200 # model size - basically total number of data read in each iteration
axi_size = 64 # number of data elements read by each AXI
axi_read_cycl = 4 # number of data elements read in one cycle


def init_data(m):
    return list(range(m))


class AXI:
    size = axi_size
    
    def __init__(self):
        self.lanes = []
        self.data = [] # all data
        self.data_by_cycle = [] # all data grouped by cycle (4 per cycle)


axi0 = AXI()
axi1 = AXI()
axi2 = AXI()
axi3 = AXI()

axi_list = [axi0, axi1, axi2, axi3]


def assign_axi(data, axi_list, m):
    q = m // axi_size
    r = m % axi_size
    for i in range(q):
        axi_list[i % 4].data.extend(data[i * axi_size : i * axi_size + axi_size])
    if r > 0:
        if q == 0:
            axi_list[0].data.extend(data[:])
        else:
            i += 1
            axi_list[i % 4].data.extend(data[i * axi_size :])


def divide_axidata_by_cycle(axi_list):
    '''
    Every AXI reads 4 data sets at a time.
    '''
    for axi in axi_list:
        cycls = len(axi.data) // axi_read_cycl
        r = len(axi.data) % axi_read_cycl
        for i in range(cycls):
            axi.data_by_cycle.append(axi.data[i * axi_read_cycl : i * axi_read_cycl + axi_read_cycl])
        if r > 0:
            if cycls == 0:
                axi.data_by_cycle.append(axi.data[:])
            else:
                i += 1
                axi.data_by_cycle.append(axi.data[i * axi_read_cycl :])


def get_data_allaxi_cycle(cycl, axi_list):
    '''
    This function reads all data from every axi in the given cycle.
    '''
    alldata = []
    for axi in axi_list:
        if cycl >= len(axi.data_by_cycle):
            #alldata.append([])
            continue
        else:
            #alldata.append(axi.data_by_cycle[cycl])
            alldata.extend(axi.data_by_cycle[cycl])
    return alldata


def get_maxcycle(axi_list):
    maxcycle = 0
    for axi in axi_list:
        if len(axi.data_by_cycle) > maxcycle:
            maxcycle = len(axi.data_by_cycle)
    return maxcycle


def gen_meminst(m):
    '''
    This function gets called by the main compiler routine.
    '''
    data = init_data(m) # data set in one iteration (e.g. x[0] ... x[63])
    assign_axi(data, axi_list, m)
    divide_axidata_by_cycle(axi_list)
    maxcycle = get_maxcycle(axi_list)

    lanes = init_lanes(nlanes, pes_per_lane)
    instrs = []

    for i in range(maxcycle):
        instrs.append(gen_read_inst())
        data_read = get_data_allaxi_cycle(i, axi_list)
        #print("cycle ", i, ": ", data_read)
        lanesbyshift = get_lanesbyshift(data_read)
        #print("lanes by shift: ", lanesbyshift)
        for shiftamount in lanesbyshift:
            affectedlanes = lanesbyshift[shiftamount]
            inst = gen_shift_inst(shiftamount, affectedlanes, lanes)
            instrs.append(inst)
    instrs.append(gen_wfi_inst())
    instrs.append(gen_loop_inst())
    writeTo("./meminst.json", json.dumps([i.toDict() for i in instrs], sort_keys=False, indent=2))

    binary = ''
    for inst in instrs:
        b = gen_lanes_bin(inst.lanes) + gen_opcode_bin(inst.op) + gen_shift_bin(inst.shiftamount)
        binary += b + '\n'
    writeTo('./meminst.txt', binary)


if __name__ == "__main__":
    m = int(sys.argv[1])
    data = init_data(m) # data set in one iteration (e.g. x[0] ... x[63])
    assign_axi(data, axi_list, m)
    divide_axidata_by_cycle(axi_list)
    maxcycle = get_maxcycle(axi_list)

    lanes = init_lanes(nlanes, pes_per_lane)
    instrs = []

    for i in range(maxcycle):
        instrs.append(gen_read_inst())
        data_read = get_data_allaxi_cycle(i, axi_list)
        print("cycle ", i, ": ", data_read)
        lanesbyshift = get_lanesbyshift(data_read)
        #print("lanes by shift: ", lanesbyshift)
        for shiftamount in lanesbyshift:
            affectedlanes = lanesbyshift[shiftamount]
            inst = gen_shift_inst(shiftamount, affectedlanes, lanes)
            instrs.append(inst)
    instrs.append(gen_wfi_inst())
    instrs.append(gen_loop_inst())
    writeTo("./meminst.json", json.dumps([i.toDict() for i in instrs], sort_keys=False, indent=2))

    binary = ''
    for inst in instrs:
        b = gen_lanes_bin(inst.lanes) + gen_opcode_bin(inst.op) + gen_shift_bin(inst.shiftamount)
        binary += b + '\n'
    writeTo('./meminst.txt', binary)
