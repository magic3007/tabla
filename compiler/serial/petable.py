import json

class Petable:
    def __init__(self, num_pes):
        self.num_pes = num_pes

    def readFrom(self, file):
        with open(file, 'r') as f:
            contents = f.read()
        f.close()
        d = json.loads(contents)
        return d

    def get_num_cycle(self, schedule_file):
        cycle2nodes = self.readFrom(schedule_file)
        return len(cycle2nodes)

    def classify_nodes_namespace(self, nodes_file):
        id2nodes = self.readFrom(nodes_file)
        nd = {}
        nw = {}
        nm = {}
        ng = {}
        ni = {}
        for node_id in id2nodes:
            node = id2nodes[node_id]
            ns = node["outDataType"]
            if ns == "ND":
                nd[node_id] = node
            elif ns == "NW":
                nw[node_id] = node
            elif ns == "NM":
                nm[node_id] = node
            elif ns == "NG":
                ng[node_id] = node
            elif ns == "NI":
                ni[node_id] = node
        self.writeTo('nd.json', json.dumps(nd, sort_keys=False, indent=2))
        self.writeTo('nw.json', json.dumps(nw, sort_keys=False, indent=2))
        self.writeTo('nm.json', json.dumps(nm, sort_keys=False, indent=2))
        self.writeTo('ng.json', json.dumps(ng, sort_keys=False, indent=2))
        self.writeTo('ni.json', json.dumps(ni, sort_keys=False, indent=2))
    
    def build_pes_template(self):
        pe_str = "PE"
        str_build = ""
        pes = range(self.num_pes)
        for pe in pes[:-1]:
            row_element = pe_str + str(pe) + ", "
            str_build += row_element
        row_element = pe_str + str(pes[-1])
        str_build += row_element
        blank = " " * len("cycles") + "  "
        pes_template = blank + str_build
        return pes_template

    def initialize_table(self, cycles):
        table = []
        entry = "    "
        cols = self.num_pes
        rows = cycles
        for row in range(rows):
            row_entry = []
            for pe_num, col in enumerate(range(cols)):
                if pe_num <10:
                    row_entry.append(entry)
                else:
                    row_entry.append(entry + " ")
            table.append(row_entry)
        return table

    def matrix2str(self, arr):
        rows = len(arr)
        cols = len(arr[0])
        lines = ""
        for row in range(rows):
            line = ""
            for col in range(cols):
                line += arr[row][col] + ','
            line = line[:-1] + "\n"
            lines += line
        return lines

    def insert_cycles(self, arr):
        cycle_str = "cycle"
        str_build = ""
        for cycle_num, row in enumerate(arr):
            cycle = cycle_str + str(cycle_num)
            row = row.insert(0, cycle)
        return arr
        
    def fill_table(self, table, nodes_file):
        id2node = self.readFrom(nodes_file)
        for node_id in id2node:
            node = id2node[node_id]
            node_cycle = node["cycle"]
            node_op = node["op"]
            node_pe = node["pe"]
            entry = '\"' + str(node_id) + ":" + node_op + '\"'
            if node_pe is not None:
                original_entry = table[node_cycle][node_pe]
                if original_entry == "    ":
                    new_entry = entry
                else:
                    new_entry = original_entry + '~' + entry
                table[node_cycle][node_pe] = new_entry
        return table

    def writeTo(self, path, csv):
        self.save(path, csv)

    def save(self, path, csv):
        with open(path, 'w') as f:
            f.write(csv)
        
if __name__ == '__main__':
    pt = Petable(16)
    cycles = pt.get_num_cycle('./schedule.json')
    pt.classify_nodes_namespace('./nodes_for_binary.json')
    for json_file in ['nd.json', 'nw.json' , 'nm.json', 'ng.json', 'ni.json']:
        pes_template = pt.build_pes_template()
        table = pt.initialize_table(cycles)
        table = pt.fill_table(table, json_file)
        table = pt.insert_cycles(table)
        table = pt.matrix2str(table)
        petable = pes_template + '\n' + table
        pt.writeTo(json_file[:2] + '.csv', petable)
    # combined csv
    pes_template = pt.build_pes_template()
    table = pt.initialize_table(cycles)
    table = pt.fill_table(table, './nodes_for_binary.json')
    table = pt.insert_cycles(table)
    table = pt.matrix2str(table)
    petable = pes_template + '\n' + table
    pt.writeTo('combined.csv', petable)

    
