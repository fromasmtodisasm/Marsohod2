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

reg [1:0]  div25;
reg [10:0] x;
reg [9:0]  y;
reg [15:0] color;

wire [4:0] r = color[15:11];
wire [5:0] g = color[10:5];
wire [4:0] b = color[4:0];

assign vga_red   = display ? r : 1'b0;
assign vga_green = display ? g : 1'b0;
assign vga_blue  = display ? b : 1'b0;

// 640x480 X: 688, 784; Y: 513, 515
assign vga_hs  = x > 10'd688 && x <= 10'd784;
assign vga_vs  = y > 10'd513 && y <= 10'd515;
wire   display = x < 10'd640 && y < 10'd480;

// 100 -> 25, 50 Mhz
always @(posedge clk) div25 <= div25 + 1'b1;

reg [16:0] addr;
wire [3:0] q;

img IMGROM(

    .clock   (clk),
    .addr_rd (addr),
    .q       (q),
);

                                 
// [1] 640x480 [800 x 525] 25 MHz
always @(posedge div25[1]) begin	

    x <= x == 11'd799 ? 1'b0 : x + 1;
    y <= x == 11'd799 ? (y == 10'd524 ? 1'b0 : y + 1) : y;
    
    addr <= (x[10:1] + y[9:1]*320);
    case (q)
    
        4'h0: color <= 16'b00000_000000_00000;
        4'h1: color <= 16'b00000_000000_00111;
        4'h2: color <= 16'b00000_001111_00000;
        4'h3: color <= 16'b00000_001111_00111;
        4'h4: color <= 16'b00111_000000_00000;
        4'h5: color <= 16'b00111_000000_00111;
        4'h6: color <= 16'b00111_001111_00000;
        4'h7: color <= 16'b01111_011111_01111;
        4'h8: color <= 16'b00111_001111_00111;
        4'h9: color <= 16'b00000_000000_11111;
        4'hA: color <= 16'b00000_111111_00000;
        4'hB: color <= 16'b00000_111111_11111;
        4'hC: color <= 16'b11111_000000_00000;
        4'hD: color <= 16'b11111_000000_11111;
        4'hE: color <= 16'b11111_111111_00000;
        4'hF: color <= 16'b11111_111111_11111;

    endcase
        
end

endmodule
