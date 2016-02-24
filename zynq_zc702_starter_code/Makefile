HW_FILELIST := file.list
HW_SRC := $(shell cat $(HW_FILELIST) | egrep -v '\#')

OUTPUT_FOLDER := zynq_output
LOGFILE := vivado.log
BITFILE := $(OUTPUT_FOLDER)/zynq_wrapper.bit

CFLAGS := -O3 -Wall -I./arm_software/lib -c
SW_DIR := arm_software
SW_SRCDIR := $(SW_DIR)/src
SW_LIBDIR := $(SW_DIR)/lib
SW_BINDIR := $(OUTPUT_FOLDER)

STANDALONE_LDFLAGS := -Wl,-T -Wl,./arm_software/lib/lscript.ld -L ./arm_software/lib
STANDALONE_LIBS := -Wl,--start-group,-lxil,-lgcc,-lc,-lm,--end-group
STANDALONE_CC := /opt/Xilinx/SDK/2015.2/gnu/arm/lin/bin/arm-xilinx-eabi-gcc
SW_STANDALONE_OBJDIR := $(SW_DIR)/obj/standalone
SW_STANDALONE_SRCFILES := $(SW_SRCDIR)/standalone.c $(SW_SRCDIR)/platform.c 
SW_STANDALONE_OBJS := $(SW_STANDALONE_SRCFILES:$(SW_SRCDIR)/%.c=$(SW_STANDALONE_OBJDIR)/%.o)
STANDALONE := $(SW_BINDIR)/standalone.elf

LINUX_LDFLAGS := 
LINUX_CC := /opt/Xilinx/SDK/2015.2/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi-gcc
SW_LINUX_OBJDIR := $(SW_DIR)/obj/linux
SW_LINUX_SRCFILES := $(SW_SRCDIR)/linux.c
SW_LINUX_SRC_OBJS := $(SW_LINUX_SRCFILES:$(SW_SRCDIR)/%.c=$(SW_LINUX_OBJDIR)/%.o)
LINUX := $(SW_BINDIR)/linux.elf

VIVADO :=/opt/Xilinx/Vivado/2015.2/bin/vivado
VIVADO_TCL:=tcl/zynq_generate_bitfile.tcl

XMD:=/opt/Xilinx/SDK/2015.2/bin/xmd
XMD_TCL:=tcl/run_benchmark.tcl
PS7_TCL:=tcl/ps7_init.tcl
###############################################################################
all: $(BITFILE) ELF

###############################################################################
############ HARDWARE ############

$(BITFILE): $(HW_SRC) $(HW_FILELIST) $(VIVADO_TCL)
	@echo "Generating bitfile"
	@$(VIVADO) -mode batch -source $(VIVADO_TCL)
	@echo "Done!"

vivado_gui: 
	$(VIVADO) &
###############################################################################

###############################################################################
############ SOFTWARE ############

ELF: $(STANDALONE) $(LINUX)

$(STANDALONE): $(SW_STANDALONE_OBJS)
	@echo -n 'Linking ...'
	@$(STANDALONE_CC) $(STANDALONE_LDFLAGS) $(SW_STANDALONE_OBJS) -o $@ $(STANDALONE_LIBS)
	@echo ' Done !'
	@echo 'Executable generated : ' $@
	@echo ' '

$(SW_STANDALONE_OBJS):$(SW_STANDALONE_OBJDIR)/%.o:$(SW_SRCDIR)/%.c
	@echo -n Compiling $< ...
	@$(STANDALONE_CC) $(CFLAGS) $< -o $@
	@echo ' Done !'

$(LINUX): $(SW_LINUX_SRC_OBJS)
	@echo -n 'Linking ...'
	@$(LINUX_CC) $(LINUX_LDFLAGS) $(SW_LINUX_SRC_OBJS) -o $@ $(LINUX_LIBS)
	@echo ' Done !'
	@echo 'Executable generated : ' $@
	@echo ' '

$(SW_LINUX_SRC_OBJS):$(SW_LINUX_OBJDIR)/%.o:$(SW_SRCDIR)/%.c
	@echo -n Compiling $< ...
	@$(LINUX_CC) $(CFLAGS) $< -o $@
	@echo ' Done !'

clean:
	@echo Cleaning up...
	@rm -rf $(SW_STANDALONE_OBJDIR)/*.o
	@rm -rf $(SW_LINUX_OBJDIR)/*.o
	@rm -f $(STANDALONE)
	@rm -rf vivado.* vivado_*.*
	@echo 'Done !'
###############################################################################
############ LAUNCH ############
launch: $(LINUX) $(STANDALONE)
	@$(XMD) -tcl $(XMD_TCL) $(BITFILE) $(PS7_TCL) $(STANDALONE)
