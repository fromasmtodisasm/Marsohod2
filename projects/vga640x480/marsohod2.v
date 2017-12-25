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

wire [ 1:0] cmd;
wire [15:0] dr;
wire [15:0] dw;
wire        wren;
wire [21:0] addr;

sdram SDRAM(

    // Hardware Interface
    .clock  (clk),
    .sdclk  (sdram_clock),
    .addr   (sdram_addr),
    .bank   (sdram_bank),
    .dq     (sdram_dq),
    .ldqm   (sdram_ldqm),
    .udqm   (sdram_udqm),
    .ras    (sdram_ras),
    .cas    (sdram_cas),
    .we     (sdram_we),
    
    // Extension
    .rden    (rden),
    .wren    (wren),
    .address (addr),
    .data_wr (dw),      // Data for Write
    .data_rd (dr),      // Data for Read
    .busy    (busy)
);

videoadapter VIDEOUT(

    .clock  (clk),
    .hs     (vga_hs),
    .vs     (vga_vs),
    .r      (vga_red),
    .g      (vga_green),
    .b      (vga_blue),
    
    // Control
    .busy   (busy),
    .rden   (rden),
    .addr   (addr),
    .dr     (dr),
    
    .wren     (wren),
    .dw       (dw)
);


endmodule
