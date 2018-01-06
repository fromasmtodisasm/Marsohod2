#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o icarus.qqq icarus.v z80.v com_clock_divisor.v
vvp icarus.qqq >> /dev/null

# gtkwave result.vcd
echo 'OK'
