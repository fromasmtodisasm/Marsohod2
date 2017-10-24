#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o icarus_qqq icarus.v icarus_memory.v processor.v 
vvp icarus_qqq >> /dev/null

# gtkwave icarus_result.vcd
echo "OK"
