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

assign sdram_addr = o_addr[11:0]; // отладка

wire [15:0] o_addr;
wire [ 7:0] o_data;

// Роутер - откуда брать данные?
wire [ 7:0] i_data = o_addr[15:14] == 2'b00 ? i_data_0 :
                     o_addr[15:14] == 2'b01 ? i_data_1 : 8'hFF;

wire [ 7:0] i_data_0;
wire [ 7:0] i_data_1;
wire        o_wr;
reg         programm  = 1'b0;

z80 Z80(

    .reset  (programm | !keys[0]),
    .clk    (clk),
    .turbo  (1'b0),
    .i_data (i_data),
    .o_data (o_data),
    .o_addr (o_addr),
    .o_wr   (o_wr),

);

// ---------------------------------------------------------------------
// ZX ROM 16K

reg  [15:0] rom_i_addr = 1'b0;
reg  [7:0]  prg_i_data = 1'b0;

rom ROM16K(

    .clock   (clk),
    .addr_rd (o_addr[13:0]),
    .q       (i_data_0),

    // Программатор
    .wren    (rom_bank_wr & (rom_i_addr[15:14] == 2'b00)),
    .addr_wr (rom_i_addr[13:0]),
    .data_wr (prg_i_data)

);

// ---------------------------------------------------------------------
// Выбор источника записи и чтения

wire wr_idata = programm ? (rom_bank_wr & (rom_i_addr[15:14] == 2'b01)) : (o_wr & (o_addr[15:14] == 2'b01));
wire wr_oaddr = programm ? rom_i_addr[13:0] : o_addr[13:0];
wire wr_odata = programm ? prg_i_data[7:0]  : o_data[7:0];

// ZX RAM 16K ($4000-$7FFF), видеопамять ($4000-$5AFF)
// Запись возможна только при o_addr - [$4000, $7FFF]

ram RAM16K(

    .clock   (clk),
    .wren    (wr_idata),
    .addr_wr (wr_oaddr),
    .data_wr (wr_odata),
    .qw      (i_data_1),

    // Видеопамять
    .addr_rd (rd_addr),
    .q       (d8_chr)

);

// Видеоадаптер
// ---------------------------------------------------------------------

wire [7:0]  d8_chr;
wire [13:0] rd_addr;

vadapter VGA(

    .clock      (clk),          // 100 Mhz -> 25 Mhz
    .addr       (rd_addr),
    .d8_chr     (d8_chr),
    .vga_border (0),
    .r          (vga_red),
    .g          (vga_green),
    .b          (vga_blue),
    .hs         (vga_hs),
    .vs         (vga_vs)
);

// ---------------------------------------------------------------------

/*
 * Адаптер частот PLL
 */

wire locked;
wire clock_25;  // 25.00
wire clock_12;  // 12.00
wire clock_6;   //  6.00

pll PLL(

    .clk        (clk),          // Входящие 100 Мгц
    .locked     (locked),       // 0 - устройство генератора ещё не сконфигурировано, 1 - готово и стабильно
    .c0         (clock_25),     // 25,0 Mhz
    .c1         (clock_12),     // 12,0 Mhz
    .c2         (clock_6)       //  6,0 Mhz

);

/*
 * Последовательный порт
 * Скорость 230400 бод или 25600 байт в секунду (25 кбайт/с)
 */

wire [7:0]  rx_byte;
wire        rx_ready;
wire        clk12;

serial SERIAL(

	.clk12    (locked & clock_12),  // Частота 12.0 Mhz
	.rx       (ftdi_rx),            // Входящие данные
	.rx_byte  (rx_byte),            // Исходящий байт (8 bit)
	.rx_ready (rx_ready)            // Строб готовности

);

// Включение программатора 32 КБ ROM памяти
always @(posedge rx_ready) begin

    prg_i_data <= rx_byte;

    if (programm == 1'b0) begin

        programm    <= 1'b1;
        rom_bank_wr <= 1'b1;
        rom_i_addr  <= 1'b0;

    end
    else begin

        if (rom_i_addr == 16'h8000) begin
            programm    <= 1'b0;
            rom_bank_wr <= 1'b0;
        end

        rom_i_addr <= rom_i_addr + 1'b1;

    end

end

// 32KB памяти будут отрабатываться через SDRAM
// 28T будет тратиться на чтение, запись, refresh блоков

// Активная нагрузка (13) + Пассивная (13)
// ACTIVATE (3) CAS (1) READ/WRITE (3) PRECHARGE (2)

endmodule
