`timescale 10ns / 1ns

module main;

// --------------------------------------------------------------------------
// ИНИЦИАЛИЗАЦИЯ ВВОДА-ВЫВОДА
// --------------------------------------------------------------------------

reg clk;
reg clock_25;
reg clock_12;
reg clock_6;

// Базовые
reg [3:0]   led;  // Out
reg [1:0]   keys; // In

// ADC
reg         adc_clock_20mhz;
reg [7:0]   adc_input;

// SDRAM
reg        sdram_clock;
reg [11:0] sdram_addr;
reg [1:0]  sdram_bank;
reg [15:0] sdram_dq;        // InOut
reg        sdram_ldqm;
reg        sdram_udqm;
reg        sdram_ras;
reg        sdram_cas;
reg        sdram_we;
    
// VGA
reg [4:0]  vga_red;
reg [5:0]  vga_green;
reg [4:0]  vga_blue;
reg        vga_hs;
reg        vga_vs;

// FTDI (PORT-B)
reg        ftdi_rx;
reg        ftdi_tx;

/* ----------------
* Шилд расширения
* ---------------- */

// USB-A    2 pins
reg [1:0]  usb;

// SOUND    2 channel
reg        sound_left;
reg        sound_right;

// PS/2     keyb / mouse
reg [1:0]  ps2_keyb;
reg [1:0]  ps2_mouse;

// Моделируем сигнал тактовой частоты
always #0.5 clk         = ~clk;      // 100.00
always #2   clock_25    = ~clock_25; //  25.00
always #4   clock_12    = ~clock_12; //  12.50
always #8   clock_6     = ~clock_6;  //   6.25

// От начала времени...
initial begin

  clk      = 1;
  clock_25 = 0;
  clock_12 = 0;
  clock_6  = 0;
  #2000 $finish;

end 
// --------------------------------------------------------------------------

// создаем файл VCD для последующего анализа сигналов
initial
begin

    $dumpfile("icarus_result.vcd");
    $dumpvars(0, main);

end

wire CLK_I = clock_25;
wire RST_I = 1'b0;

// 16 bit x 16384 = 32k
wire [13:0] ROM_A;

// 16 bit x 4 Mb = 8 Mb
wire [21:0] ADR_O;

// Данные
reg  [15:0] ROM_I;
reg  [15:0] DAT_I;
wire [15:0] DAT_O;

// ПРОЦЕССОР
// --------------------------------------------------------------------------

// Wishbone
core ACORE(

    CLK_I, // Сигнал синхронизации
    RST_I, // Синхронный сброс
    ROM_A, // ROM 32k
    ROM_I, 
    ADR_O, // RAM 8M
    DAT_I, 
    DAT_O, 
    WE_O
    
);

// Эмулятор памяти SDRAM
// ---------------------------------------------------------------------

reg [15:0] ram_8m [65535 : 0];
reg [15:0] rom_32k [32767 : 0];
reg [15:0] t_DAT_I;

integer j;
initial begin

    $readmemh("core.hex", rom_32k);
    
    ram_8m[ 16'h00 ] = 16'h1234;
    ram_8m[ 16'h01 ] = 16'h2345;
    ram_8m[ 16'h80 ] = 16'hAFBF;
    ram_8m[ 16'h81 ] = 16'h2345;

end

always @(posedge clk) begin

      ROM_I <= rom_32k[ ROM_A ];         
    t_DAT_I <= ram_8m[ ADR_O[21:1] ];
      DAT_I <= t_DAT_I;

end

endmodule
