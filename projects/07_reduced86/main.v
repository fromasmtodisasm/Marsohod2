`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg clk = 1'b0;
reg clk25 = 1'b0;

always #0.5 clk         = ~clk;
always #2 clk25       = ~clk25;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

reg  [7:0]  i; /* Вход CPU */
wire [7:0]  o; /* Выход из CPU */
wire [15:0] a;
wire        w; 
reg  [1:0]  flw = 2'b00; 

// ------------------------------------- Регистровый файл --------------
reg [ 7:0] memory[65536];

/*
    0000-7FFF  Общая память (32кб)
    B800-BFFF  Видеопамять текстовая (2k)
    C000-FFFF  BIOS (8кб)
*/

// Ревизия 1
initial begin $readmemh("init/ram.hex",  memory, 16'h0000); end
initial begin $readmemh("init/bios.hex", memory, 16'hE000); end 

always @(posedge clk) begin

    // Чтение данных из памяти
    i <= memory[ a ];
    
    // Запись данных в память
    if (w) memory[ a ] <= o;
    
end

// ------------------------------------- Центральный процессор ---------
cpu CPU(clk, clk25, i, o, a, w);
    
endmodule
