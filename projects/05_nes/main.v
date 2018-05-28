`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk = ~clk;

initial begin clk = 1; #4000 $finish; end
initial begin $dumpfile("nes.vcd"); $dumpvars(0, main); end

wire [4:0]  red;
wire [5:0]  green;
wire [4:0]  blue;
wire        hs;
wire        vs;
wire        rd;
wire [15:0] address;
wire [15:0] ea;
wire [7:0]  dout;
reg  [7:0]  i_data;
wire        wreq;
wire        ppuclk;
wire        cpuclk;

// Внутрисхемная память
// ---------------------------------------------------------------------
reg [ 7:0] memory[65536]; // 64 общая память
reg [ 7:0] video[65536];  // видеопамять

always @(posedge clk) begin

    if (wreq) memory[ ea ] <= dout;

    i_data <= memory[ address ];

end

// Роутинг памяти (из PPU к процессору). Важно указывать именно address
wire [7:0] din = (address[15:13] == 3'b001) ? ppu_dout : i_data;

initial begin $readmemh("init/ram.hex", memory, 16'h0000); end
initial begin $readmemh("init/rom.hex", memory, 16'h8000); end

// Центральный процессор
// ---------------------------------------------------------------------

cpu CPU( cpuclk, 1'b1, address, din, dout, ea, wreq, rd);

// Графический процессор
// ---------------------------------------------------------------------

wire [ 7:0] ppu_dout;
wire [10:0] vaddr; wire [7:0] vdata;
wire [12:0] faddr; wire [7:0] fdata;

ppu PPU(

    /* 100 Mhz */
    clk,
    
    /* VGA */
    red, green, blue, hs, vs, 
    
    /* VRAM */
    vaddr, vdata, 
    
    /* CHR  */
    faddr, fdata, 
    
    ppuclk, /* 5 Mhz */
    cpuclk, /* 1.6 Mhz */
    
    /* Данные на запись/чтение */
    ea, dout, rd, wreq, ppu_dout
);

endmodule
