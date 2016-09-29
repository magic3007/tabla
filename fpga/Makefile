TOP_MODULE ?= zynq_loopback_wrapper

HW_SRC_DIR := hw-imp
HW_FILELIST := $(HW_SRC_DIR)/file.list
HW_SRC_FILES := $(shell cat $(HW_FILELIST) | egrep -v '\#' | grep -v "include")
HW_SRC := $(HW_SRC_FILES:%=$(HW_SRC_DIR)/%)

SIM_COMPILER := iverilog
SIM_INCLUDE_DIR := $(HW_SRC_DIR)/include
SIM_COMPILER_FLAGS := -I $(SIM_INCLUDE_DIR)
SIM_BINDIR = $(HW_SRC_DIR)/bin
SIM_WAVEFORM_DIR := $(SIM_BINDIR)/waveform

SIM_TBLIST := tb.list
SIM_TESTS := $(shell cat $(HW_SRC_DIR)/$(SIM_TBLIST) | egrep -v '\#')

OUTPUT_FOLDER := $(realpath synthesis-output)
LOGFILE := vivado.log
BITFILE := $(OUTPUT_FOLDER)/$(TOP_MODULE).bit 
HDF_FILE := $(OUTPUT_FOLDER)/$(TOP_MODULE).hdf 
BITFILE_GOLDEN := $(OUTPUT_FOLDER)/zynq_wrapper_golden.bit

SYNTHESIS_OUTPUT := $(BITFILE) $(HDF_FILE)

SW_DIR := ./arm_software
CFLAGS := -O3 -I $(SW_DIR)/lib -c -static
SW_SRCDIR := $(SW_DIR)/src
SW_LIBDIR := $(SW_DIR)/lib
SW_BINDIR := $(OUTPUT_FOLDER)

STANDALONE_LDFLAGS := -Wl,-T -Wl,$(SW_DIR)/lib/lscript.ld -L $(SW_DIR)/lib
STANDALONE_LIBS := -Wl,--start-group,-lxil,-lgcc,-lc,-lm,--end-group
STANDALONE_CC := /opt/Xilinx/SDK/2016.2/gnu/arm/lin/bin/arm-xilinx-eabi-gcc
SW_STANDALONE_OBJDIR := $(SW_DIR)/obj/standalone
SW_STANDALONE_SRCFILES := $(SW_SRCDIR)/standalone.c $(SW_SRCDIR)/platform.c
SW_STANDALONE_OBJS := $(SW_STANDALONE_SRCFILES:$(SW_SRCDIR)/%.c=$(SW_STANDALONE_OBJDIR)/%.o)
STANDALONE := $(SW_BINDIR)/standalone.elf

LINUX_LDFLAGS := 
LINUX_CC :=/opt/Xilinx/SDK/2016.2/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-gcc
SW_LINUX_OBJDIR := $(SW_DIR)/obj/linux
SW_LINUX_SRCFILES := $(SW_SRCDIR)/linux.c
SW_LINUX_SRC_OBJS := $(SW_LINUX_SRCFILES:$(SW_SRCDIR)/%.c=$(SW_LINUX_OBJDIR)/%.o)
LINUX := $(SW_BINDIR)/linux.elf

PETALINUX_PROJECT := ./tablaOS
PETALINUX_DIR := /opt/Xilinx/petalinux-v2016.2-final/tools/common/petalinux/bin
PETALINUX_CONFIG := $(PETALINUX_DIR)/petalinux-config
PETALINUX_BUILD := $(PETALINUX_DIR)/petalinux-build
PETALINUX_CREATE := $(PETALINUX_DIR)/petalinux-create
PETALINUX_PACKAGE := $(PETALINUX_DIR)/petalinux-package

VIVADO_VERSION := 2016.2
VIVADO_PATH := /opt/Xilinx/Vivado
VIVADO_BIN :=$(VIVADO_PATH)/$(VIVADO_VERSION)/bin/vivado
VIVADO_FLAGS := -notrace
VIVADO_TCL:=tcl/vivado_2016_2.tcl

XMD:=/opt/Xilinx/SDK/2015.2/bin/xmd
XMD_TCL:=tcl/run_benchmark.tcl
RESET_ZYNQ_TCL:=tcl/reset_zynq.tcl
PS7_TCL:=tcl/ps7_init.tcl
###############################################################################
all: $(SYNTHESIS_OUTPUT) ELF
	@#bash -i -c ~/.bashrc 
	@#$(BITFILE) ELF

###############################################################################
############ SIMULATION ############
compile:
	@echo "Compiling all sources"
	$(SIM_COMPILER) $(SIM_COMPILER_FLAGS) -o compile.out -s $(TOP_MODULE) $(HW_SRC)
	@echo 'Done !'
	@echo

test: $(SIM_TESTS)

$(SIM_TESTS:%=$(SIM_BINDIR)/%.out): $(HW_FILELIST) $(HW_SRC)
	@echo "Compiling Testbench - $@"
	@mkdir -p $(SIM_BINDIR)
	@$(SIM_COMPILER) $(SIM_COMPILER_FLAGS) -o $@ -s $(@:$(SIM_BINDIR)/%.out=%)_tb $(HW_SRC)
	@echo 'Done !'
	@echo

$(SIM_TESTS): %:$(SIM_BINDIR)/%.out
	@echo "Simulating Testbench $<"
	@mkdir -p $(SIM_WAVEFORM_DIR)
	@$(SIMULATOR) $(SIMULATOR_FLAGS) $<
	@echo 'Done !'
	@echo

###############################################################################
############ SYNTHESIS ############

$(BITFILE): $(HW_SRC) $(HW_FILELIST) $(VIVADO_TCL)
	@echo "Synthesizing Tabla"
	@\rm -rf $(OUTPUT_FOLDER)
	@mkdir -p $(OUTPUT_FOLDER)
	@$(VIVADO_BIN) -mode batch $(VIVADO_FLAGS) -source $(VIVADO_TCL) -tclargs $(TOP_MODULE) 2>&1 | tee $(OUTPUT_FOLDER)/$(LOGFILE) | grep "Tabla"
	@\rm vivado*.*

vivado_gui: 
	$(VIVADO_BIN) &
###############################################################################

###############################################################################
############ SOFTWARE ############

ELF: $(STANDALONE) $(LINUX)


$(STANDALONE): $(SW_STANDALONE_OBJS)
	@mkdir -p $(SW_BINDIR)
	@echo -n 'Linking ...'
	@$(STANDALONE_CC) $(STANDALONE_LDFLAGS) $(SW_STANDALONE_OBJS) -o $@ $(STANDALONE_LIBS)
	@echo ' Done !'
	@echo 'Executable generated : ' $@
	@echo ' '

$(SW_STANDALONE_OBJS):$(SW_STANDALONE_OBJDIR)/%.o:$(SW_SRCDIR)/%.c
	@mkdir -p $(SW_STANDALONE_OBJDIR)
	@echo -n Compiling $< ...
	@$(STANDALONE_CC) $(CFLAGS) $< -o $@
	@echo ' Done !'

$(LINUX): $(SW_LINUX_SRC_OBJS)
	@mkdir -p $(SW_BINDIR)
	@echo -n 'Linking ...'
	@$(LINUX_CC) $(LINUX_LDFLAGS) $(SW_LINUX_SRC_OBJS) -o $@ $(LINUX_LIBS)
	@echo ' Done !'
	@echo 'Executable generated : ' $@
	@echo ' '

$(SW_LINUX_SRC_OBJS):$(SW_LINUX_OBJDIR)/%.o:$(SW_SRCDIR)/%.c
	@mkdir -p $(SW_LINUX_OBJDIR)
	@echo -n Compiling $< ...
	@$(LINUX_CC) $(CFLAGS) $< -o $@
	@echo ' Done !'

###############################################################################
############ LAUNCH ############
launch: $(STANDALONE) $(LINUX)
	@echo "Launching Tabla"
	@$(XMD) -tcl $(XMD_TCL) $(BITFILE) $(PS7_TCL) $(STANDALONE) 2>&1 | tee $(OUTPUT_FOLDER)/launch.log | grep -i "error" || true
	@echo "Done"

launch_golden: 
	$(XMD) -tcl $(XMD_TCL) $(BITFILE_GOLDEN) $(PS7_TCL) $(STANDALONE)

reset_zynq:
	$(XMD) -tcl $(RESET_ZYNQ_TCL) $(PS7_TCL)
###############################################################################

###############################################################################
############ BUILD LINUX ############
BUILD_LINUX: $(PETALINUX_PROJECT)
	@echo "Build Linux Tabla"
	@$(PETALINUX_CONFIG) -p $(PETALINUX_PROJECT) --get-hw-description $(OUTPUT_FOLDER)
	@$(PETALINUX_CONFIG) -p $(PETALINUX_PROJECT) -c rootfs
	@$(PETALINUX_BUILD) -p $(PETALINUX_PROJECT)

GENERATE_BOOT_BIN:
	$(PETALINUX_PACKAGE) -p $(PETALINUX_PROJECT) --boot --fsbl $(PETALINUX_PROJECT)/images/linux/zynq_fsbl.elf --fpga $(BITFILE) --uboot --force -o $(PETALINUX_PROJECT)/images/linux/BOOT.BIN
	@echo "Done"

$(PETALINUX_PROJECT):
	@echo "Creating Petalinux project for Tabla"
	@$(PETALINUX_CREATE) --type project --template zynq --name $@
###############################################################################

###############################################################################
############ Cleanup ############
clean:
	@echo Cleaning up...
	@rm -rf $(SW_STANDALONE_OBJDIR)/*.o
	@rm -rf $(SW_LINUX_OBJDIR)/*.o
	@rm -f $(STANDALONE)
	@rm -rf vivado.* vivado_*.*
	@rm -rf *.jou *.log *.str
	@rm -f $(SIM_TESTS:%=$(SIM_BINDIR)/%.out)
	@echo 'Done !'
	@echo

superclean: clean
	@rm -rf vivado
	@rm -rf $(OUTPUT_FOLDER)
