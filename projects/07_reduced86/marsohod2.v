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
wire w; reg  wm;

wire [7:0]  q_rom;
wire [7:0]  q_ram;
wire [7:0]  q_vid;
reg         wren_vram;
reg         wren_cram;

biosrom BIOSROM( /* 8Kb */

    .clock   (clk),
    .addr_rd (a[12:0]),
    .q       (q_rom)
);

comram COMMONRAM( /* 16Kb */

    .clock   (clk),
    .addr_wr (a[13:0]),
    .data_wr (o),
    .wren    (wren_cram),
    .q       (q_ram)
);

// ---------------------------------------------------------------------
// Объявляем нужные провода
wire [11:0] adapter_font;
wire [ 7:0] adapter_data;
wire [11:0] font_char_addr;
wire [ 7:0] font_char_data;

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

    // Источник знакогенератора
    .adapter_font (adapter_font),
    .adapter_data (adapter_data),

    // Сканирование символов
    .font_char_addr (font_char_addr),
    .font_char_data (font_char_data)

);

// Здесь хранятся шрифты (знакогенератор)
fontrom VGA_FONT_ROM(

    .clock      (clk),          // Тактовая частота - 100 Мгц для памяти
    .addr_rd    (adapter_font), // Адаптер будет указывать адрес, который ему интересен,
                                // чтобы узнать значение следующих 8 бит для шрифта
    .q          (adapter_data)  // Здесь будет это значение через 2 такта на скорости 100 Мгц
);

// Информация о символах и атрибутах
fontram VGA_VIDEORAM(

    .clock      (clk),            // Тактовая частота - 100 Мгц для памяти
    .addr_rd    (font_char_addr), // В памяти сначала хранится символ, потом его цвет
    .q          (font_char_data), // Тут будет результат

    /* Взаимодействие с процессором */
    .addr_wr    (a[11:0]),
    .data_wr    (o),
    .wren       (1'b0 & wren_vram), /* --- временно отключено --- */
    .qw         (q_vid),
);
// ---------------------------------------------------------------------

/* Отложенная на 1 такт запись в память */
always @(posedge clk) wm <= w;

/* Маппинг памяти */
always @* begin

    casex (a)

        // Область BIOS памяти (E000-FFFF) 8Kb
        16'b111x_xxxx_xxxx_xxxx: begin i = q_rom; {wren_vram, wren_cram} = 2'b00; end

        // Общая быстрая память (0000-3FFF) 16 Kb
        16'b00xx_xxxx_xxxx_xxxx: begin i = q_ram; {wren_vram, wren_cram} = {1'b0, wm}; end

        // Видеопамять текстовая (B000-BFFF) 2 Kb
        16'b1011_xxxx_xxxx_xxxx: begin i = q_vid; {wren_vram, wren_cram} = {wm, 1'b0}; end
 
        // Любая другая область
        default: begin i = 8'h00; {wren_vram, wren_cram} = 2'b00; end

    endcase

end

// https://wiki.osdev.org/VGA_Fonts -- Vga I/O

cpu CPU( /* Процессор */

    clk,    // 100 мегагерц
    clk25,  // 25 мегагерц
    i,      // Data In
    o,      // Data Out
    a,      // Aдрес
    w       // Запись [o] на HIGH уровне

);
endmodule
