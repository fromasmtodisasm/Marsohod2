#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o icarus.qqq ic.v
vvp icarus.qqq >> /dev/null

# gtkwave result.vcd

echo 'OK'
