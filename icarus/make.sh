#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o qqq icarus.v memory.v
vvp qqq >> /dev/null

# gtkwave result.vcd
