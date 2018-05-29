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
wire        reset = 1'b0;

// Внутрисхемная память
// ---------------------------------------------------------------------
reg [ 7:0] sram[65536]; 
reg [ 7:0] vram[2048]; /* Видеопамять */
reg [ 7:0] crom[8192]; /* CHR-ROM */

always @(posedge clk) begin

    /* SRAM */
    if (wreq)  sram[ ea ] <= dout;
    i_data  <= sram[ address ];
    
    /* VRAM */
    if (vwreq) vram[ waddr ] <= wdata;
    vin     <= vram[ waddr ];
    fin     <= crom[ waddr ];

end

// Роутинг памяти (из PPU к процессору). Важно указывать именно address
wire [7:0] din = (address[15:13] == 3'b001) ? ppu_dout : i_data;

initial begin $readmemh("init/ram.hex", sram, 16'h0000); end
initial begin $readmemh("init/rom.hex", sram, 16'h8000); end

// Центральный процессор
// ---------------------------------------------------------------------

cpu CPU( reset, cpuclk, 1'b1, address, din, dout, ea, wreq, rd); 

// Графический процессор
// ---------------------------------------------------------------------

wire [ 7:0] ppu_dout;
wire [10:0] vaddr; wire [7:0] vdata;
wire [12:0] faddr; wire [7:0] fdata;

reg  [ 7:0] vin;
reg  [ 7:0] fin;
wire [ 7:0] wdata;
wire [12:0] waddr;
wire        vwreq;

ppu PPU(

    /* 100 Mhz */
    clk,    
    reset,
    
    /* VGA */
    red, green, blue, hs, vs, 
    
    /* VRAM */
    vaddr, vdata,               /* Чтение видеоадаптером */
    vin, vwreq, waddr, wdata,   /* Чтение и запись */  
    
    /* CHR  */
    faddr, fdata, fin,          /* Чтение из CHR-ROM */
    
    ppuclk, /* 5 Mhz */
    cpuclk, /* 1.6 Mhz */
    
    /* Данные на запись/чтение */
    ea, dout, rd, wreq, ppu_dout
);

endmodule
