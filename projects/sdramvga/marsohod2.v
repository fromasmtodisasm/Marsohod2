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

sdramvga640 SDRAM_VGA640x480(
	
	// 100 Mhz
	.clock      (clk),

    // Hardware SDRAM interface
    .clksdram   (sdram_clock),
    .addr       (sdram_addr),
    .bank       (sdram_bank),
    .dq         (sdram_dq),
    .ldqm       (sdram_ldqm),
    .udqm       (sdram_udqm),
    .ras        (sdram_ras),
    .cas        (sdram_cas),
    .we         (sdram_we),
    
    // VGA 640x480
    .vga_red    (vga_red),
    .vga_green  (vga_green),
    .vga_blue   (vga_blue),
    .vga_hs     (vga_hs),
    .vga_vs     (vga_vs),

    // Read/Write 
    .address    (address),        // Адрес, по словам
    .i_data     (i_data),         // Входящие данные
    .o_data     (o_data),         // Исходящие данные
    .rdwr       (rdwr),           // =0 (Чтение), =1 (Запись)
    .clk        (io_clk),            // Такт на чтение, запись
    .lock       (lock)            // =1 память недоступна на чтение/запись
);

reg  [21:0] address = 22'h0;
wire [15:0] i_data  = 16'hEFA6;
wire [15:0] o_data;
wire [15:0] rdwr = 1'b1;
wire [15:0] io_clk = 1'b1;

reg [15:0] divt;
always @(posedge clock) begin
    divt <= divt + 1'b1;
end
always @(posedge divt[15]) begin
    address <= address + 1'b1;
    i_data <= i_data + 1'b1;
end

endmodule
