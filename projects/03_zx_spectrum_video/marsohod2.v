module marsohod2(

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

wire [12:0] video_addr; // 2^13 = 8192
wire [ 7:0] video_data;

// Назначаем пины для модуля
// .green - внутренее название пина в самом модуле
// vga_green - внешнее (отсюда)

vga VGA_ADAPTER(

	.clk	(clk),	
	.red 	(vga_red),
	.green	(vga_green),
	.blue	(vga_blue),
	.hs		(vga_hs),
	.vs		(vga_vs),
    
    // Данные для вывода
    .video_addr (video_addr),
    .video_data (video_data)

);

// На самом деле, память используется неэкономно
// потому что 1 280 байт будет не занято (6912 из 8192)
videoram ZX_VIDEO_RAM(

    .clock      (clk),
    .addr_rd    (video_addr),       // Адресация 0..6191 байт
    .q          (video_data) 

);

endmodule
