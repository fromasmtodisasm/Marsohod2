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

assign sdram_addr = a[11:0];

/* Делитель частоты до 25 Мгц */
reg [1:0] div; always @(posedge clk) div <= div + 1'b1; wire clk25 = div[1];

wire [15:0] a;
reg  [7:0]  i;
wire [7:0]  o;
wire w;

wire [7:0] q_rom;

biosrom BIOSROM(
    
    .clock   (clk),
    .addr_rd (a[12:0]),
    .q       (q_rom)
);

/* Маппинг памяти */
always @* begin

    casex (a)
    
        // Область BIOS памяти (E000-FFFF) 8Kb
        16'b111x_xxxx_xxxx_xxxx: i = q_rom;
        
        // Любая другая область
        default: i = 8'h00;        
    
    endcase

end

/* Процессор */
cpu CPU(

    clk,    // 100 мегагерц
    clk25,  // 25 мегагерц
    i,      // Data In
    o,      // Data Out
    a,      // Aдрес
    w       // Запись [o] на HIGH уровне

);
endmodule
