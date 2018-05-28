module nes(

    /* ----------------
     * Archectural Marsohod2
     * ---------------- */

    // CLOCK    100 Mhz
    input   wire        clk,

    // LED      4
    output  wire [3:0]  led,

    // KEYS     2
    input   wire [1:0]  keys,

    // ADC      8 bit
    output  wire        adc_clock_20mhz,
    input   wire [7:0]  adc_input,

    // SDRAM
    output  wire        sdram_clock,
    output  wire [11:0] sdram_addr,
    output  wire [1:0]  sdram_bank,
    inout   wire [15:0] sdram_dq,
    output  wire        sdram_ldqm,
    output  wire        sdram_udqm,
    output  wire        sdram_ras,
    output  wire        sdram_cas,
    output  wire        sdram_we,

    // VGA
    output  wire [4:0]  vga_red,
    output  wire [5:0]  vga_green,
    output  wire [4:0]  vga_blue,
    output  wire        vga_hs,
    output  wire        vga_vs,

    // FTDI (PORT-B)
    input   wire        ftdi_rx,
    output  wire        ftdi_tx,

    /* ----------------
     * Extension Shield
     * ---------------- */

    // USB-A    2 pins
    inout   wire [1:0]  usb,

    // SOUND    2 channel
    output  wire        sound_left,
    output  wire        sound_right,

    // PS/2     keyb / mouse
    inout   wire [1:0]  ps2_keyb,
    inout   wire [1:0]  ps2_mouse
);
// --------------------------------------------------------------------------

reg  [1:0]  div;
wire        clk25 = div[1];

wire [15:0] address;        /* Чтение */    
wire [15:0] waddr;          /* Запись в память */
reg  [ 7:0] din;
wire [ 7:0] dout;
wire        mreq;

// --------------------------------------------------------------------------
always @(posedge clk) div <= div + 1'b1;

// --------------------------------------------------------------------------

/*
cpu C6502(
    
    .CLK    ( clk17 ),          // 1.71 МГц
    .CE     ( 1'b1 ),           // Готовность памяти
    .ADDR   ( address ),        // Адрес программы или данных
    .DIN    ( din ),            // Входящие данные
    .DOUT   ( dout ),           // Исходящие данные
    .EAWR   ( waddr ),          // Эффективный адрес
    .WREQ   ( wreq ),           // =1 Запись в память по адресу EA
);
*/

// --------------------------------------------------------------------------

wire [10:0] addr_vrd; // 2048
wire [12:0] addr_frd; // 8192
wire [ 7:0] data_vrd;
wire [ 7:0] data_frd;

vram VRAM(

    /* Для чтения из PPU */
    .clock   (clk),
    .addr_rd (addr_vrd),
    .q       (data_vrd),
    
    /* Для записи из PPU */

);

romchr CHRROM(

    /* Для чтения из PPU */
    .clock   (clk),
    .addr_rd (addr_frd),
    .q       (data_frd),
    
    /* Для записи из программатора */

);

ppu PPU(
    
    .CLK25  (clk25),
    .red    (vga_red),
    .green  (vga_green),
    .blue   (vga_blue),
    .hs     (vga_hs),
    .vs     (vga_vs),
    
    /* Видеопамять (2Кб) */
    .vaddr  (addr_vrd),
    .vdata  (data_vrd),
    
    /* Знакогенератор */
    .faddr  (addr_frd),
    .fdata  (data_frd),   
    
);

endmodule
