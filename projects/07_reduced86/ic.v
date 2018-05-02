`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("result.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

wire [15:0] i;
wire [15:0] o;
wire [31:0] a;
wire        w;
    
cpu CPU(clk, i, o, a, w);
    
endmodule
