module marsohod2(

    /* ----------------
     * Archectural Marsohod2
     * ---------------- */

    // COMMON
    input   wire        CLK100MHZ,
    output  reg  [3:0]  LED,
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

/*
wire [7:0] eth_data;
wire       eth_ready;
wire       eth_term;

rtlget eth(

    .rtl_clk  (RTL_RXCLK),
	.rtl_rxd  (RTL_RXD),
	.rtl_rxdv (RTL_RXDV),
    .data     (eth_data),
    .ready    (eth_ready),
    .term     (eth_term)

);
*/

// Регистрация нового байта
reg [7:0]  _dataw;
reg [11:0] _addrw;
reg [11:0] _addr;

reg  [1:0] _par = 1'b0;
reg        _w1;
reg        _w2;
wire       _w = (_w1 ^ _w2);
reg         wr = 1'b0;

wire [3:0] _rxd = {RTL_RXD[0], RTL_RXD[1], RTL_RXD[2], RTL_RXD[3]};

reg        clr = 1'b0;
reg        freeze  = 1'b0; // Заморозка приема
reg        freezed = 1'b0; // Заморозка приема
reg [3:0]  rnibble;

always @(posedge RTL_RXCLK) begin

    if (!freezed) begin
    // ------------
    if (RTL_RXDV) begin
    
        LED     <= _rxd;
        rnibble <= _rxd;
       
        if  (_rxd < 10)
             _dataw <= {1'b0, 3'h3, _rxd}; // 0-9
        else _dataw <= {1'b0, 3'h4, _rxd - 4'h9}; // A-F

        _addr  <= (clr ? 1'b0 : _addrw);
        _addrw <= (clr ? 1'b0 : _addrw) + 1'b1 + (_par[0] ? 2 : 0);
        _par   <= _par + 1'b1;
        clr    <= 1'b0;
        
        if (_addrw == 81 && {rnibble, _rxd} == 8'h08) // 08
        //if (_addrw == 85 && {rnibble, _rxd} == 8'h64) // 08
            freeze <= 1'b1;

        _w1 <= _w ^ _w1  ^ 1'b1;
    
    
    end
    else begin 
    
        _par    <= 0; 
        clr     <= 1'b1; 
        freezed <= freeze;
        
        // Дорисовка
        if (_addrw < 4000) begin
        
            _dataw <= {8'h01};
            _w1    <= _w ^ _w1  ^ 1'b1;
            _addr  <= _addrw;
            _addrw <= _addrw + 1'b1;
        
        end
        
    end
    // ------------
    end else LED <= 4'b1111;
    

end

// Сброс записи
reg lat;
always @(posedge CLK100MHZ) begin
        
    if ({lat, _w} == 2'b11) begin
    
        wr  <= 1'b1;
        //_w2 <= _w ? _w2 ^ 1'b1 : _w2;
        _w2 <= _w2 ^ _w;
        
    end else 
        wr  <= 1'b0;
    
    lat <= _w;
       
end

// --------------------------------------------------------------------------

// Объявляем нужные провода
wire [10:0] adapter_font;
wire [ 7:0] adapter_data;
wire [11:0] font_char_addr;
wire [ 7:0] font_char_data;

text8050 u0vga(

	.clk	(CLOCK25MHZ),	
	.red 	(VGA_RED),
	.green	(VGA_GREEN),
	.blue	(VGA_BLUE),
	.hs		(VGA_HS),
	.vs		(VGA_VS),
    
    // Источник знакогенератора
    .adapter_font (adapter_font),
    .adapter_data (adapter_data),
    
    // Сканирование символов
    .font_char_addr (font_char_addr),
    .font_char_data (font_char_data)

);

// Здесь хранятся шрифты (знакогенератор)
textfont u1vga(

    .clock      (CLK100MHZ),    // Тактовая частота - 100 Мгц для памяти
    .addr_rd    (adapter_font), // Адрес, чтобы узнать значение следующих 8 бит для шрифта
    .q          (adapter_data)  // Здесь будет это значение через 2 такта на скорости 100 Мгц
);

// Информация о символах и атрибутах
textram u2vga(

    .clock      (CLK100MHZ),      // Тактовая частота - 100 Мгц для памяти
    .addr_rd    (font_char_addr), // В памяти сначала хранится символ, потом его цвет
    .q          (font_char_data),  // Тут будет результат 

    .wren       (wr),
    .addr_wr    (_addr),
    .data_wr    (_dataw),
);

endmodule
