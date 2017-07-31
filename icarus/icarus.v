`timescale 10ns / 1ns

module main;

reg clk;
reg pll_0;
reg pll_1;
reg pll_2;

// Моделируем сигнал тактовой частоты
always #0.5 clk   = ~clk;
always #4   pll_0 = ~pll_0;
always #8   pll_1 = ~pll_1;
always #16  pll_2 = ~pll_2;

// От начала времени...
initial begin
  clk = 1;
  pll_0 = 0;
  pll_1 = 0;
  pll_2 = 0;
  #2000 $finish;
end 

// создаем файл VCD для последующего анализа сигналов
initial
begin

    $dumpfile("result.vcd");
    $dumpvars(0, main);
    
end

// -----------------------------------

// ПРИМЕР
// cpu CPU(clk, i_data, o_data, o_addr);



endmodule
