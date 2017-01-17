#!/bin/bash

mkdir binary/
mkdir binary/mem-inst/

mv meminst.json meminst.txt weightInst.txt binary/mem-inst/
mv bin/ binary/bin-inst/
mv inst/ binary/json-inst/
mv hex/ binary/hex-inst/
mv artifacts/ binary/
mv config.list binary/
mv inst_info.txt binary/

mkdir ../fpga/hw-imp/include/linear-3/
mkdir ../fpga/hw-imp/include/linear-3/mem-inst
mkdir ../fpga/hw-imp/include/linear-3/compute-inst

cp binary/mem-inst/{meminst.txt,weightInst.txt} ../fpga/hw-imp/include/linear-3/mem-inst/
cp binary/bin-inst/* ../fpga/hw-imp/include/linear-3/compute-inst/
