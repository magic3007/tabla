#!/usr/bin/python

# Author Divya Mahajan
# divya_mahajan@gatech.edu

import subprocess

config_file = "../fpga/hw-imp/config/config.list" 

file_read = "../fpga/hw-imp/config/config.tmp" 
file_write = "../fpga/hw-imp/include/config.vh"

#####################################################################################
#FUNCTION TO PARSE THE CONFIG FILE
#####################################################################################
def parse_config_file(config_file):

    config_file_read = open(config_file, 'r')

    compute_modules = {'SIG': 0,'GAU': 0 , 'DIV': 0, 'SQRT': 0}
    
    indexes = {'INDEX_INST': 0,'INDEX_WEIGHT': 0 , 'INDEX_DATA': 0, 'INDEX_META': 0, 'INDEX_INTERIM': 0}
 
    for line in config_file_read:
        if(line.split()[0] == 'NUM_PE_VALID'): 
            numPeValid = int(line.split()[1])
        
        if any(line.split()[0] == module for module in compute_modules):
            compute_modules[line.split()[0]] = 1
            
        if any(line.split()[0] == key for key in indexes):
            indexes[line.split()[0]] = line.split()[1]
            
    return numPeValid, compute_modules, indexes
######################################################################################

######################################################################################
#FUNCTION TO CHANGE THE COMPUTE MODULES THAT NEED TO BE DEFINED
######################################################################################
def compute_module_instantiate(compute_modules, indexes):
    
    bashCommand = ""
    
    for key in compute_modules:
        if(compute_modules[key] == 1):
            bashCommand = bashCommand + "s,<" + str(key) + ">,,g; "
        else:
            bashCommand = bashCommand + "s,<" + str(key) + ">,//,g; "
    
    for key in indexes:
        bashCommand = bashCommand + "s,<" + str(key) + ">," + str(indexes[key]) + ",g; "
    
    #bashCommand = bashCommand + "' " + str(compute_file) + " > " + str(compute_file_write)
    
    print bashCommand
    return bashCommand
    #subprocess.check_output(['bash','-c', bashCommand])
######################################################################################

######################################################################################
#FUNCTION TO CHANGE THE NUMBER OF VALID PES IN THE ACCELERATOR
######################################################################################
def parameter_modification(numPeValid):
    
    bashCommand = "'s/<NUM_PE_VALID>/" + str(numPeValid) + "/g; "
    print bashCommand 
    return bashCommand
######################################################################################

######################################################################################
#RUN THE FUNCTIONS
######################################################################################
compute_modules = {}
indexes = {}

numPeValid, compute_modules, indexes = parse_config_file(config_file)

command_param = parameter_modification(numPeValid)

command_module = compute_module_instantiate(compute_modules, indexes)

complete_bashCommand = "sed " + str(command_param) + str(command_module) + "' " + str(file_read) + " > " + str(file_write)
print complete_bashCommand
subprocess.check_output(['bash','-c', complete_bashCommand])
######################################################################################

###################################END################################################