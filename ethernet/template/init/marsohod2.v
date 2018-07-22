module marsohod2(

    /* ----------------
     * Archectural Marsohod2
     * ---------------- */

    // COMMON
    input   wire        CLK100MHZ,
    output  wire [3:0]  LED,
    input   wire [1:0]  KEY,
    output  wire        ADC_CLK,
    input   wire [7:0]  ADC,

    // SDRAM
    output  wire        SDRAM_CLK,
    output  wire [11:0] SDRAM_A,
    output  wire [1:0]  SDRAM_BANK,
    inout   wire [15:0] SDRAM_DQ,
    output  wire        SDRAM_LDQM,
    output  wire        SDRAM_UDQM,
    output  wire        SDRAM_RAS,
    output  wire        SDRAM_CAS,
    output  wire        SDRAM_WE,

    // VGA
    output  wire [4:0]  VGA_RED,
    output  wire [5:0]  VGA_GREEN,
    output  wire [4:0]  VGA_BLUE,
    output  wire        VGA_HS,
    output  wire        VGA_VS,

    // FTDI (PORT-B)
    input   wire        FTDI_RX,
    output  wire        FTDI_TX,
    input   wire        FTDI_BD0,
    output  wire        FTDI_BD1,

    /* ----------------
     * Ethernet Shield
     * ---------------- */

    output  wire        RTL_XI,      // Crystal Input 25 Mhz
     
    input   wire        RTL_RXCLK,   // Receive Clock
    input   wire        RTL_RXDV,    // Received Data Valid
    input   wire [3:0]  RTL_RXD,     // RX Data

    output  wire [3:0]  RTL_TXD,     // TX Data
    input   wire        RTL_TXEN,    // Presence of a valid nibble data on TX
    output  wire        RTL_TXCLK,   // Clock for TX
    output  wire        RTL_MDC,     // Management Data Clock
    inout   wire        RTL_MDIO,    // Management Data Input/Output
    output  wire        RTL_RESETB   // Reset

);
// --------------------------------------------------------------------------
assign RTL_RESETB = 1;
assign RTL_MDC    = 0;
assign RTL_XI     = CLOCK25MHZ & LOCKED;
wire   LOCKED;
wire   CLOCK25MHZ;

pll u0(
    .clk    (CLK100MHZ),
    .clk25  (CLOCK25MHZ),
    .locked (LOCKED)
);
// --------------------------------------------------------------------------



endmodule
