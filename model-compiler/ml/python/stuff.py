import sys

filename = sys.argv[1]
f = open(filename, 'r')
datafile = open('somedata.json', 'w')

model_input = ''
model_output = ''
for line in f:
    nums = line.split(',')
    #model_input += '[' + nums[0] + ', '  + nums[1] + '], '
    model_input += nums[0] + ', '
    #out = nums[2]
    out = nums[1]
    #model_output += out[:-4] + ', '
    model_output += out[:-1] + ', '    

json_template = '{"model_input" : [' + model_input[:-2] + '], "model_output" : [' + model_output[:-2] + ']}'
datafile.write(json_template)
f.close()
datafile.close()
