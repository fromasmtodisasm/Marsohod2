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

assign vga_red = {5{pixel}};
assign vga_green = pixel ? {6{pixel}} : {5{vga_vi}}; 
assign vga_blue = {5{vga_vi}};

// 640x480 X: 688, 784; Y: 513, 515
// 800x600 X: 864, 984; Y: 623, 629

assign vga_hs = scanline_x > 10'd688 && scanline_x <= 10'd784; // area+back+sync[96]+front
assign vga_vs = scanline_y > 10'd513 && scanline_y <= 10'd515;  // area+back+sync[2]+front
wire   vga_vi = scanline_x < 10'd640 && scanline_y < 10'd480;

reg [1:0]  div25;
reg [10:0] scanline_x;
reg [9:0]  scanline_y;
reg        pixel;
reg [5:0]  timing;

// 100 -> 25, 50 Mhz
always @(posedge clk) begin
	div25 <= div25 + 1'b1;	
end

// Чисто вывод на экран 8x8 символа
wire [7:0] ch1 = scanline_y[2:0] == 3'b000 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b001 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b010 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b011 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b100 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b101 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b110 ? 8'b00000000 :  
                                             8'b00000000;

// Чисто проверка
wire [7:0] ch2 = scanline_y[2:0] == 3'b000 ? 8'b00000000 : 
                 scanline_y[2:0] == 3'b001 ? 8'b01000100 : 
                 scanline_y[2:0] == 3'b010 ? 8'b00111000 : 
                 scanline_y[2:0] == 3'b011 ? 8'b00101000 : 
                 scanline_y[2:0] == 3'b100 ? 8'b00111000 : 
                 scanline_y[2:0] == 3'b101 ? 8'b01000100 : 
                 scanline_y[2:0] == 3'b110 ? 8'b00000000 :  
                                             8'b00000000;

wire [7:0] ch = scanline_x[3] ^ scanline_y[3] ^ timing[5] ? ch1 : ch2;

// [1] 640x480 [800 x 525] 25 MHz
// [0] 800x600 [1040 x 666] 50 Mhz

always @(posedge div25[1]) begin	

    if (scanline_x == 11'd800) begin
        scanline_x <= 1'b0;
        if (scanline_y == 10'd525) begin
            scanline_y <= 1'b0;
            timing <= timing + 1'b1;
        end else begin
            scanline_y <= scanline_y + 1'b1;
        end
    end else begin
        scanline_x <= scanline_x + 1'b1;	
    end
    
    // Отрисовка видимой области (640x480, 800x600)
    pixel <= vga_vi ? ch[ scanline_x[2:0] ^ 3'b111 ] : 1'b0;

end

endmodule
