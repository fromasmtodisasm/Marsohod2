#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o main.qqq main.v z80.v
vvp main.qqq >> /dev/null

# gtkwave main.vcd

echo 'OK'
