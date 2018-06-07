module marsohod2(

    /* ----------------
     * Archectural Marsohod2
     * ---------------- */

    // CLOCK    100 Mhz
    input   wire        clk,

    // LED      4
    output  reg  [3:0]  led,

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

reg  kbd_reset = 1'b0;
reg  div; always @(posedge clk) div <= !div;
wire ps2_command_was_sent;
wire ps2_error_communication_timed_out;
wire [7:0] ps2_data;
wire       ps2_data_clk;

PS2_Controller Keyboard(

	/* Вход */
    .CLOCK_50       (div),
	.reset          (1'b0),
	.the_command    (1'b0),
	.send_command   (1'b0),

	/* Ввод-вывод */
	.PS2_CLK(ps2_keyb[1]),
 	.PS2_DAT(ps2_keyb[0]),

	/* Статус команды */
	.command_was_sent  (ps2_command_was_sent),
	.error_communication_timed_out (ps2_error_communication_timed_out),

    /* Выход полученных */
	.received_data      (ps2_data),
	.received_data_en   (ps2_data_clk)

);

always @(posedge div) begin

    if (ps2_data_clk) begin
    
        case (ps2_data)
        
            8'h01: led[0] <= 1'b1;
            8'h02: led[0] <= 1'b0;
            
        endcase
    
    end

end
    
endmodule
