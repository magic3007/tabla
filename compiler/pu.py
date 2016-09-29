import json
from pe import Pe

class Pu:
    def __init__(self, id=None, head_pe=None, next_pu=None):
        self.id = id
        self.head_pe = head_pe
        self.next_pu = next_pu
        self.num_pes = self.get_numpes()
        #self.all_pes

    def get_numpes(self):
        count = 0
        if self.head_pe is not None:
            count += 1
            curr = self.head_pe.next
            while curr is not self.head_pe:
                count += 1
                curr = curr.next
        return count
        
    def __str__(self):
        s = '<<PU' + str(self.id) + '>>\n'
        s += self.head_pe.__str__() + '\n'
        curr = self.head_pe.next
        while curr is not self.head_pe:
            s += curr.__str__() + '\n'
            curr = curr.next
        return s

    def toDict(self):
        d = {
            "pu_id": self.id,
            "num_pes": self.num_pes,
            "head_pe": self.head_pe.toDict()
            }
        return d

def writeTo(path, pu):
    with open(path, 'w') as f:
        f.write(json.dumps(pu.toDict(), sort_keys=False, indent=2))
    
if __name__ == '__main__':
    pe0 = Pe(0)
    pe1 = Pe(1)
    pe2 = Pe(2)
    pe3 = Pe(3)

    pe0.next = pe3
    pe1.next = pe0
    pe2.next = pe1
    pe3.next = pe2
    pu0 = Pu(0, pe0)
    print(pu0)
    writeTo('./pu.json', pu0)
