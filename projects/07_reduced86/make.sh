#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o main.qqq main.v cpu.v
vvp main.qqq >> /dev/null
rm main.qqq

# gtkwave main.vcd

echo 'OK'
