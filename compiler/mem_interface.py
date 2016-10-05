# these two variables determine how many read instructions are required
m = 700 # model size - basically total number of data read in each iteration
axi_size = 64 # number of data elements read by each AXI
axi_read_cycl = 4 # number of data elements read in one cycle


def gen_read_inst():
    pass

def gen_shift_inst():
    pass
    
def init_data(m):
    return list(range(m))


class AXI:
    size = axi_size
    #cycle = 0
    
    def __init__(self):
        self.lanes = []
        self.data = []
        self.data_by_cycle = []


axi0 = AXI()
axi1 = AXI()
axi2 = AXI()
axi3 = AXI()

axi_list = [axi0, axi1, axi2, axi3]


def assign_axi(data, axi_list):
    q = m // axi_size
    r = m % axi_size
    #print("q = {:d}, r = {:d}".format(q, r))
    for i in range(q):
        #print(i % 4)
        axi_list[i % 4].data.extend(data[i * axi_size : i * axi_size + axi_size])
    if r > 0:
        if q == 0:
            axi_list[0].data.extend(data[:])
        else:
            i += 1
            axi_list[i % 4].data.extend(data[i * axi_size :])


def divide_axidata_by_cycle(axi_list):
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
    alldata = []
    for axi in axi_list:
        if cycl >= len(axi.data_by_cycle):
            alldata.append([])
        else:
            alldata.append(axi.data_by_cycle[cycl])
    return alldata


def get_maxcycle(axi_list):
    maxcycle = 0
    for axi in axi_list:
        if len(axi.data_by_cycle) > maxcycle:
            maxcycle = len(axi.data_by_cycle)
    return maxcycle


def get_data_allaxi(maxcycle, axi_list):
    data = []
    for i in range(maxcycle):
        alldata_cycle = get_data_allaxi_cycle(i, axi_list)
        data.append(alldata_cycle)
        print("cycle ", i, ": ", alldata_cycle)
    return data

            
if __name__ == '__main__':
    data = init_data(m) # data set in one iteration (e.g. x[0] ... x[63])
    assign_axi(data, axi_list)
    divide_axidata_by_cycle(axi_list)
    maxcycle = get_maxcycle(axi_list)
    alldata = get_data_allaxi(maxcycle, axi_list)
    
    
    
