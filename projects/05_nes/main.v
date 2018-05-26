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
wire [15:0] ea;
reg  [7:0]  i_data;
wire [7:0]  o_data;
wire        wreq;

// Внутрисхемная память
// ---------------------------------------------------------------------
reg [ 7:0] memory[65536]; // 64 общая память
reg [ 7:0] video[65536];  // видеопамять
reg [ 7:0] i_latency = 1'b0;

always @(posedge clk) begin

    if (wreq) memory[ ea ] <= o_data;
    
    i_latency <= memory[ address ];
    i_data    <= i_latency;

end

initial begin $readmemh("init/ram.hex", memory, 16'h0000); end
initial begin $readmemh("init/rom.hex", memory, 16'h8000); end 

// Центральный процессор
// ---------------------------------------------------------------------

// Формирование особой частоты для тестов
reg cpuclock = 1'b0; 
reg [2:0] div = 2'b00; 
always @(posedge clk) if (div == 2'b10) 
    begin div <= 1'b0; cpuclock <= ~cpuclock; end 
    else  div <= div + 1'b1;

cpu CPU( cpuclock, 1'b1, address, i_data, o_data, ea, wreq);

// Графический процессор
// ---------------------------------------------------------------------

ppu PPU(

    clk,
    vga_clock,
    ppu_clock,
    cpu_clock,
    red, 
    green, 
    blue, 
    hs, 
    vs

);

    
endmodule
