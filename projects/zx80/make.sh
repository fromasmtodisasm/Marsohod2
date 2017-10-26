#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o icarus_qqq icarus.v processor.v port.v
vvp icarus_qqq >> /dev/null

# gtkwave result.vcd
