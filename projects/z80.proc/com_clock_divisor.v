
/*
 * Делитель частоты. Процессор работает на частоте 3.5 МГц. Делить
 * частоту будем как 100 Mhz / 3,5 Mhz ~ 28 тактов на 100 Мгц = 1 такту
 * на 3.5. Но на самом деле, используем 14 тактов на CLK=1, и 14 тактов
 * на CLK=0.
 */

module com_clock_divisor(

    input  wire clk,
    output reg  clk_z80,
            
    // Параметр делителя частоты
    // 100 / 3.5 / 2 = 14 - 1 = 13
    // 100 / 25 / 2  = 2 - 1  = 1

    input  wire [3:0] param_div
);

reg [3:0] div     = 1'b0;
reg [1:0] delay   = 3'h2;
initial   clk_z80 = 1'b0;

always @(posedge clk) begin

    // Небольшая задержка, чтобы синхронизовать такты
    if (delay) begin
    
        delay <= delay - 1;
            
    end
    
    // Делитель частоты
    else if (div == param_div) begin

        div     <= 1'b0;
        clk_z80 <= clk_z80 + 1'b1;

    end else begin

        div <= div + 1'b1;

    end

end

endmodule
