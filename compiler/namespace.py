class Ns_entry:
    """ Namespace entry - a single entry to a namespace buffer. """
    
    def __init__(self, valid=True, data=None):
        self.valid = valid
        self.data = data

    def __str__(self):
        return 'valid: ' + str(self.valid) + ', data: ' + str(self.data)
    
class Namespace:
    """ 
    Buffer consisting of one or more namespace entries. An entry is retrieved
    by passing an index to the buffer. 
    """
    def __init__(self, nstype, size=32):
        self.nstype = nstype
        self.buf = [None] * size
        self.tail = 0 # index of the next free spot
        self.size = len(self.buf)

    def get(self, i):
        """ Returns None if trying to get garbage or None."""
        if i >= 0 and i < len(self.buf):
            entry = self.buf[i]
            if entry is not None and entry.valid is True:
                entry_copy = Ns_entry(data=entry.data)
                entry.valid = False
                return entry_copy

    def insert(self, i, ns_entry):
        status = False  # return status
        if i >= 0 and i < len(self.buf):
            if self.buf[i] is None or self.buf[i].valid is False:
                self.buf[i] = ns_entry
                status = True
                self.update_tail()
                if self.tail == -1:
                    status = False
        return status

    def update_tail(self):
        if self.isfull():
            self.tail = -1
            return
        start_pos = self.tail
        for i in range(self.tail, len(self.buf)):
            if self.buf[i] is None or self.buf[i].valid is False:
                self.tail = i
                return
        for i in range(0, start_pos):
            if self.buf[i].valid is False:
                self.tail = i
                return
    
    def isfull(self):
        for entry in self.buf:
            if entry is None or entry.valid is False:
                return False
        return True

    def __str__(self):
        s = '[' + self.nstype + ']' + '\n'
        for i, entry in enumerate(self.buf):
            if (entry != None):
                s += str(i) + ': ' + entry.__str__() + '\n'
        return s
