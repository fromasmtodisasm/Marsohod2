/*
 * Программируемый микрокалькулятор
 */
 
// --------------------------------------------------------------------------
module marsohod2(

    /* ----------------
    * Архитектурно в Марсоходе-2
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
    * Шилд расширения
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

/*
 * Генератор частот, по умолчанию 1/4, 3/25, 1/16 к входящей частоте
 */

wire locked;
wire clock_25;  // 25.00
wire clock_12;  // 12.00
wire clock_6;   //  6.00
 
pll PLL(

    .clk        (clk),          // Входящие 100 Мгц
    .locked     (locked),       // 0 - устройство генератора ещё не сконфигурировано, 1 - готово и стабильно
    .c0         (clock_25),     // 25,0 Mhz
    .c1         (clock_12),     // 12,5 Mhz
    .c2         (clock_6)       // 6,25 Mhz

);

/*
 * Внутрисхемная память в ПЛИС [16384 байта] / ROM
 */

wire cntl_w; // --> использовать кастомный контроллер
 
rom PRGROM(

    .clock   (clk),
    .addr_rd (o_addr[13:0]),
    .q       (i_data),
    // -- tmp 
    .addr_wr (o_addr[13:0]),
    .data_wr (o_data),
    .wren    (cntl_w),
    //.qw      (i_data)

);

// --- Контроллер строба записи в память из CLK-25 CPU ---
// BEGIN
reg [2:0] cntl_mw = 3'b000;
assign    cntl_w  = cntl_mw == 3'b011 && o_wr;
always @(posedge clk) cntl_mw <= {cntl_mw[1:0], clock_25}; 
// END

/*
 * Демо-процессор на основе 6502, 8 бит
 */

wire [7:0]  i_data;
wire [15:0] o_addr;
wire [7:0]  o_data;
wire        o_wr;

demo_processor DPROC6502(

	.clock_25   (locked & clock_25),
	.i_data     (i_data),
	.o_addr     (o_addr),
    .o_data     (o_data),
    .o_wr       (o_wr),

);

endmodule
