`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

reg [7:0]   i; wire [7:0] o; wire [19:0] a;
wire        w; wire       W;  
reg  [1:0]  flw = 2'b00; 

// ------------------------------------- Регистровый файл --------------

// Список регистров
reg [ 7:0] memory[1048575];

initial begin $readmemh("init/bios.hex", memory, 20'hFE000); end
initial begin $readmemh("init/ram.hex", memory, 20'h00000); end

always @(posedge clk) begin

    // Чтение данных из памяти
    i <= memory[ a ];
    
    // Запись данных в память
    if (w) memory[ a ] <= o;
    
    // Для записи - задержка данных может быть
    flw <= {flw[0], clk25};

end

// ------------------------------------- Центральный процессор ---------
cpu CPU(/* Главное */   clk, clk25, i, o, a, w);
    
endmodule
