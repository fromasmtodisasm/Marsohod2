`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk = ~clk;

initial begin clk = 1; #4000 $finish; end
initial begin $dumpfile("nes.vcd"); $dumpvars(0, main); end

wire        vga_clock;
wire        ppu_clock;
wire        cpu_clock;
wire [4:0]  red;
wire [5:0]  green;
wire [4:0]  blue;
wire        hs;
wire        vs;
wire [15:0] address;
wire [7:0]  i_data;
wire [7:0]  o_data;
wire        wreq;

// ---------------------------------------------------------------------

ppu PPU(

    clk,
    vga_clock,
    ppu_clock,
    cpu_clock,
    red, green, blue, hs, vs

);

cpu CPU(

    cpu_clock,
    address,
    i_data,
    o_data,
    wreq

);
    
endmodule
