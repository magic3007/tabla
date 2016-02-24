# Read arguments
if {$argc != 3 && $argc != 4} {
    puts "The script requires three arguments."
    puts "\tUsage: xmd -tcl tcl/run_benchmark.tcl [bitfile] [ps7init] [elffile]"
    exit 1
} else {
    set bitfile [lindex $argv 0]
    set ps7init [lindex $argv 1]
    set elffile [lindex $argv 2]
}

source $ps7init
connect arm hw
rst -system
fpga -f $bitfile
ps7_init
ps7_post_config
dow $elffile
con
