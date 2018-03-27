`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk = ~clk;

initial begin clk = 1; #4000 $finish; end
initial begin $dumpfile("nes.vcd"); $dumpvars(0, main); end

wire o_25_mhz;
wire o_ppu;

// ---------------------------------------------------------------------
clock CLOCK(clk, o_25_mhz, o_ppu);

endmodule
