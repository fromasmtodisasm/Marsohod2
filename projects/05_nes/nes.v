module nes(

    /* ----------------
     * Archectural Marsohod2
     * ---------------- */

    // CLOCK    100 Mhz
    input   wire        clk,

    // LED      4
    output  reg [3:0]   led,

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

wire [15:0] address;        /* Чтение */    
wire [15:0] eawr;           /* Запись в память (EA) */
wire [ 7:0] dout;           /* Выход данных из процессора */
wire        mreq;           /* Запрос на запись из процессора */
wire        NMI;

/* Роутинг записи памяти */
wire [7:0]  Dram;
wire [7:0]  Drom;
wire [7:0]  Dppu;
reg  [1:0]  dlVRAM = 2'b00;     /* Отложенная запись в VRAM */
reg  [1:0]  dlSRAM = 2'b00;     /* ... в SRAM */

wire        sram_write = eawr     < 16'h0800;
wire        sram_route = address  < 16'h0800;
wire        srom_route = address >= 16'h8000;
wire        ppu_route  = address >= 16'h2000 && address < 16'h3FFF;

wire [7:0]  din = sram_route ? Dram :               /* 0000-07FF SRAM */
                  ppu_route  ? Dppu :               /* 2000-3FFF PPU */
                  srom_route ? Drom : 8'h00;        /* 8000-FFFF ROM */

always @(posedge clk) dlSRAM <= {dlSRAM[0], CLKCPU};
always @(posedge clk) dlVRAM <= {dlVRAM[0], WVREQ};
                  
// --------------------------------------------------------------------------

cpu C6502(
    
    .RESET  ( prg_enable ),     // Сброс процессора
    .CLK    ( CLKCPU ),         // 1.71 МГц
    .CE     ( 1'b1 ),           // Временное блокирование исполнения (DMA Request)
    .ADDR   ( address ),        // Адрес программы или данных
    .DIN    ( din ),            // Входящие данные
    .DOUT   ( dout ),           // Исходящие данные
    .EAWR   ( eawr ),           // Эффективный адрес
    .WREQ   ( wreq ),           // =1 Запись в память по адресу EA
    .RD     ( RD ),             // =1 Чтение из PPU
    .NMI    (NMI),
);

// --------------------------------------------------------------------------

reg [1:0] div = 2'b00; always @(posedge clk) div <= div + 1'b1;

wire [10:0] addr_vrd; // 2048
wire [12:0] addr_frd; // 8192
wire [ 7:0] data_vrd;
wire [ 7:0] data_frd;
wire [ 7:0] FIN;
wire [ 7:0] VIN;
wire [ 7:0] WDATA;
wire [12:0] WADDR;
wire        WVREQ;
wire        RD;

ppu PPU(
    
    .CLK25  (div[1]),
    .RESET  (prg_enable),
    .red    (vga_red),
    .green  (vga_green),
    .blue   (vga_blue),
    .hs     (vga_hs),
    .vs     (vga_vs),
    
    /* Тактовые частоты */
    .CLKPPU (CLKPPU),
    .CLKCPU (CLKCPU),
    
    /* Видеопамять (2Кб) */
    .vaddr  (addr_vrd), /* Чтение из памяти VRAM */
    .vdata  (data_vrd), /* Данные из VRAM */
    
    /* Обмен данными с видеопамятью */
    .ea     (eawr),     /* Адрес EA */
    .din    (dout),     /* Вход из процессора */
    .RD     (RD),       /* Запрос на чтение */
    .WREQ   (wreq),     /* Запрос на запись */
    .DOUT   (Dppu),     /* Выход из PPU */
    .VIN    (VIN),      /* Вход из VRAM */
    .WVREQ  (WVREQ),    /* Запрос на запись в VRAM */
    .WADDR  (WADDR),    /* Адрес к VRAM */
    .WDATA  (WDATA),    /* Данные для записи в VRAM */
    .NMI    (NMI),
    
    /* Знакогенератор */
    .faddr  (addr_frd), /* Адрес CHR-ROM */
    .fdata  (data_frd), /* Данные CHR-ROM */
    .FIN    (FIN),      /* Данные из знакогенератора на чтение */    
    
    
);

// Программирование ROM 
// --------------------------------------------------------------------------

wire [7:0]  rx_byte;
wire        locked;
wire        clock_25;  // 25.00
wire        clock_12;  // 12.00
wire        clock_6;   //  6.00
wire        rx_ready;

pll PLL(

    .clk        (clk),          // Входящие 100 Мгц
    .locked     (locked),       // 0 - устройство генератора ещё не сконфигурировано, 1 - готово и стабильно
    .c0         (clock_25),     // 25,0 Mhz
    .c1         (clock_12),     // 12,0 Mhz
    .c2         (clock_6)       //  6,0 Mhz

);

uart UART(
    .clk12      (clock_12),
    .rx         (ftdi_rx),
    .rx_byte    (rx_byte),
    .rx_ready   (rx_ready),
);

parameter  prg_len = 16384;

reg [7:0]  prg_idata   = 1'b0; /* Данные для записи */
reg [13:0] prg_addr    = 1'b0; /* Адрес (16Kb) */
reg        prg_wren    = 1'b0; /* Производится запись в память */
reg        prg_enable  = 1'b0; /* Программирование включено */
reg [1:0]  prg_negedge = 2'b00;

/* Регистрация negedge rx_ready */
always @(posedge clk) prg_negedge <= {prg_negedge[0], rx_ready};

// Включение программатора 32 КБ ROM памяти
always @(posedge rx_ready) begin

    prg_idata <= rx_byte;

    if (prg_enable == 1'b0) begin

        prg_enable <= 1'b1;
        prg_wren   <= 1'b1;
        prg_addr   <= 16'h0000;
        led[0]     <= 1'b1;

    end
    else begin

        if (prg_addr == (prg_len - 2)) begin
            prg_enable <= 1'b0;
            prg_wren   <= 1'b0;
            led[0]     <= 1'b0;
        end

        prg_addr <= prg_addr + 1'b1;

    end

end

// --------------------------------------------------------------------------

/* Видеопамять 2Кб */
vram VRAM(

    /* Для чтения из PPU */
    .clock   (clk),
    .addr_rd (addr_vrd),
    .q       (data_vrd),
    
    /* Для записи из PPU */
    .addr_wr (WADDR[10:0]),
    .data_wr (WDATA),
    .wren    (dlVRAM == 2'b01),
    .qw      (VIN),

);

/* Знакогенератор 8Кб */
romchr CHRROM(

    /* Для чтения из PPU */
    .clock   (clk),
    .addr_rd (addr_frd),
    .q       (data_frd),
    
    /* Для записи из программатора */
    .addr_wr (WADDR),
    .qw      (FIN)

);

/* Память программ 16 Кб (Базовыая) */
rom ROM(

    .clock    (clk),
    .addr_rd  (address[13:0]), // 16K
    .q        (Drom),
        
    /* Для записи из PPU */
    .addr_wr (prg_addr),
    .data_wr (prg_idata),
    .wren    (prg_wren && prg_negedge == 2'b10),

);

/* Оперативная память 2 Кб */
sram SRAM(

    /* Чтение */
    .clock    (clk),
    .addr_rd  (address[10:0]), // 2K
    .q        (Dram),
    
    /* Запись на обратном фронте CPU в память */
    .addr_wr  (address[10:0]),
    .data_wr  (dout),
    .wren     (dlSRAM == 2'b10 && wreq && sram_write),

);


endmodule
