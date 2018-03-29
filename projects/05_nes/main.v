`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk = ~clk;

initial begin clk = 1; #4000 $finish; end
initial begin $dumpfile("nes.vcd"); $dumpvars(0, main); end

wire vga_clock;
wire ppu_clock;
wire cpu_clock;

// ---------------------------------------------------------------------
clock CLOCK(clk, vga_clock, ppu_clock, cpu_clock);

endmodule
