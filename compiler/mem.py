import json

class DataIn:
    def __init__(self, peid):
        self.peid = peid

class Lane:
    def __init__(self, laneid, peids):
        self.laneid = laneid
        self.peids = peids

    def get_relpeid(self, peid):
        if peid in self.peids:
            if self.laneid == 0:
                return peid
            else:
                return peid % self.laneid
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

    def set_laneinst(self, laneid, relpeid):
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

''' manually set for now '''
def read_ddr():
    read_vals = [DataIn(1), DataIn(3), DataIn(5), DataIn(7), DataIn(9), DataIn(11), DataIn(13), DataIn(15), DataIn(2), DataIn(4), DataIn(6), DataIn(8), DataIn(10), DataIn(12), DataIn(14), DataIn(0)]
    return read_vals

def get_shiftamount(laneid, pos):
    if pos >= laneid:
        shift = pos - laneid
    else:
        shift = nlanes - (laneidp - pos)
    return shift
    
def getlane(peid):
    return peid // pes_per_lane

def get_laneobject(lanes, laneid):
    return lanes[laneid]

def gen_shift_inst(shiftamount, affectedlanes, lanes):
    inst = Meminst("shift", shiftamount)
    for lane in affectedlanes:
        laneid = lane[0]
        peid = lane[1]
        laneobj = get_laneobject(lanes, laneid)
        relpeid = laneobj.get_relpeid(peid)
        inst.set_laneinst(laneid, relpeid)
    return inst

def gen_read_inst():
    return Meminst("read")

def writeTo(path, s):
    with open(path, 'w') as f:
        f.write(s)

def init_lanes(nlanes, pes_per_lane):
    lanes = []
    for i in range(nlanes):
        pid = i * pes_per_lane
        lanes.append(Lane(i, [pid + offset for offset in range(pes_per_lane)]))
    return lanes

def get_lanesbyshift(read_vals):
    lanesbyshift = {}
    for pos, data in enumerate(read_vals):
        laneid = getlane(data.peid)
        shiftamount = get_shiftamount(laneid, pos)
        if shiftamount in lanesbyshift:
            lanesbyshift[shiftamount].append((laneid, data.peid))
        else:
            lanesbyshift[shiftamount] = [(laneid, data.peid)]
        #print("pos: {:d}, laneid: {:d}, shift to left: {:d}".format(pos, laneid, shiftamount))
    return lanesbyshift


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


def gen_ns_bin(ns):
    return format(nsbin[ns], '0' + str(namespace_bits) + 'b')

def gen_singlelane_bin(lane):
    peid = lane["relpe"]
    valid = lane["valid"]
    bin_str = format(peid, '0' + str(peid_bits) + 'b') + format(valid, '0' + str(valid_bits) + 'b')
    return bin_str

def gen_lanes_bin(lanes):
    bin = ''
    for lane in lanes:
        bin += gen_singlelane_bin(lane)
    bin += gen_ns_bin("data")
    return bin

def gen_opcode_bin(op):
    return format(opbin[op], '0' + str(opcode_bits) + 'b')

def gen_shift_bin(shift):
    return format(shift, '0' + str(shift_bits) + 'b')



if __name__ == "__main__":
    lanes = init_lanes(nlanes, pes_per_lane)
    read_vals = read_ddr()
    instrs = []
    while read_vals is not None:
        lanesbyshift = get_lanesbyshift(read_vals)
        print("lanes by shift: ", lanesbyshift)
        instrs.append(gen_read_inst())
        for shiftamount in lanesbyshift:
            affectedlanes = lanesbyshift[shiftamount]
            inst = gen_shift_inst(shiftamount, affectedlanes, lanes)
            instrs.append(inst)
        read_vals = read_ddr()
        break # for now

    writeTo("./meminst.json", json.dumps([i.toDict() for i in instrs], sort_keys=False, indent=2))

    binary = ''
    for inst in instrs:
        b = gen_lanes_bin(inst.lanes) + gen_opcode_bin(inst.op) + gen_shift_bin(inst.shiftamount)
        binary += b + '\n'
    writeTo('./meminst.txt', binary)
