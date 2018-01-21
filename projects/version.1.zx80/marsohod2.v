module marsohod2(

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

    // ----------------
    // Шилд расширения
    // ----------------

    // USB-A    2 pins
    inout   wire [1:0]  usb,

    // SOUND    2 channel
    output  wire        sound_left,
    output  wire        sound_right,

    // PS/2     keyb / mouse
    inout   wire [1:0]  ps2_keyb,
    inout   wire [1:0]  ps2_mouse   
);
// ---------------------------------------------------------------------

wire        locked;
wire        m_ready = 1'b1;
wire [15:0] o_addr;
wire [7:0]  o_data;
wire        o_wr;


// Îáúÿâëåíèå êîíñòàíò
// --------------------------------------------------------------------------------

wire [3:0]  cpu_led;
wire [15:0] address;     // Àäðåñóåìàÿ ÂÑß ïàìÿòü
wire        clock_25;    // Äåëåííàÿ íà 4 ñêîðîñòü ïðîöåññîðà (25 ìãö)
wire        clock_12;
wire        clock_6;
wire        clock_cpu = clock_25; // CPU clock    

// Çàïèñü äàííûõ â ïàìÿòè
reg  wren_100mhz = 1'b0;

// --------------------------------------------------------------------------------
// ÃÅÍÅÐÀÒÎÐ PLL. Ãåíåðèðóåò èìïóëüñû èç 100 ìãö â 25 ìãö (îñíîâíàÿ ÷àñòîòà).

pll PLL(
    .inclk0(clk), 
    .c0(clock_25), 
    .c1(clock_12), 
    .c2(clock_6), 
    .locked(locked)
);

// --------------------------------------------------------------------------------
// ÏÀÌßÒÜ ROM  (16 êèëîáàéò) $0000-$3FFF
// ÏÀÌßÒÜ RAM  (16 êèëîáàéò) $4000-$7FFF

// Óêàçàòåëü íà âèäåîïàìÿòü
wire [13:0] address_vm;

// Data Memory IO
wire [7:0] data8_rom;
wire [7:0] data8_ram;
wire [7:0] data8_vid;
wire [7:0] data8_w;
reg  [7:0] data8;

// Write Enabled
reg  wren_ram;
reg  wren_distr;
wire wren;

// Ïîðòû
wire        port_clock;
wire [15:0] port_addr;
wire [7:0]  port_data;
wire [7:0]  port_in;
wire [2:0]  vga_border;

// Çàïèñü â ïàìÿòü íà CLOCK = 0
always @(posedge clk) begin

    // Ïðè âûñîêîì ñèãíàëå CLK25 îñòàíàâëèâàòü çàïèñü 
    if (clock_cpu) begin    

        wren_100mhz <= 1'b0;
        wren_distr  <= 1'b0;
        
    end
    // Ïðè ïåðâîì íèçêîì ñèãíàëå çàïèñàòü òîëüêî 1 ðàç
    else if (!clock_cpu && !wren_100mhz) begin

        wren_100mhz <= 1'b1;
        wren_distr  <= wren;

    end

end

// $0000-$3FFF 16 êá ROM 
// ------------------------------------
rom  ROM(
    
    .clock   (clk),
    .addr_rd (address[13:0]),
    .q       (data8_rom)

);

// $4000-$7FFF 16 êá RAM  
// ------------------------------------
ram  RAM(

    .clock   (clk),

    // Read/Write
    .addr_rw (address[13:0]),
    .data    (data8_w),
    .wren    (wren_ram & wren_distr),
    .q_rw    (data8_ram),
    
    // Video Adapter
    .addr_rd (address_vm[13:0]),
    .q       (data8_vid)
);

// --------------------------------------------------------------------------------
// Ìàïïåð äàííûõ èç ðàçíûõ èñòî÷íèêîâ

// Ðàñïðåäåëåíèå, îòêóäà áðàòü äàííûå (ROM, RAM, SDRAM)
always @* begin

    // ROM 16K
    if (address < 16'h4000)       begin data8[7:0] = data8_rom[7:0]; wren_ram = 1'b0; end   
                   
    // RAM 16K
    else if (address < 16'h8000)  begin data8[7:0] = data8_ram[7:0]; wren_ram = 1'b1; end

end

// --------------------------------------------------------------------------------
// Öåíòðàëüíûé ïðîöåññîð. ßäðî âñåé ñèñòåìû.

processor CPU(

    .clock   (clock_cpu & locked),
    .i_data  (data8),        
    .o_data  (data8_w),
    .o_addr  (address),
    .o_wr    (wren),  
    
    // Ïîðòû, ñâÿçü ñ ìèðîì        
    .port_clock (port_clock), // Ñòðîá äëÿ çàïèñè â ïîðò
    .port_addr  (port_addr),
    .port_in    (port_in),    // PORT <-- CPU
    .port_data  (port_data),  // CPU  --> PORT
);

// --------------------------------------------------------------------------------
// Работа с портами ввода-вывода

port PORT(

    .clock      (port_clock),
    .addr       (port_addr),        
    .data_in    (port_data),
    .data_out   (port_in),
    .vga_border (vga_border),
);

// --------------------------------------------------------------------------------
// Видеоадаптер

video VID(

    .clock      (clock_25),

    // Данные для чтения
    .d8_chr     (data8_vid),
    .addr       (address_vm),
    .vga_border (vga_border),        

    // Видеовыходы
    .r(vga_red),
    .g(vga_green),
    .b(vga_blue),
    .hs(vga_hs),
    .vs(vga_vs)
);

endmodule
