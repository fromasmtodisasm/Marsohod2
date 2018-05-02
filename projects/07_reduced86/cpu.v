module cpu(

    /* Стандартные входы-выходы */
    input   wire        clk,        // 100 мегагерц
    input   wire [7:0]  i,          // Data In (16 бит)
    output  reg  [7:0]  o,          // Data Out,
    output  wire [19:0] a,          // Address 32 bit
    output  reg         wm,         // Запись [d] на переднем фронте
    output  reg  [7:0]  d,          // То, что записываем в память
    
    /* Регистровый файл */
    output  reg  [2:0]  Dr,         // Номера регистров A, B
    output  reg  [2:0]  Sr,
    output  wire [1:0]  b,          // Битность 0 - 8 bit, 1-16, 2-32, 3-?
    input   wire [15:0] ia,         // Значение регистра A
    input   wire [15:0] ib,         // Значение регистра B
    output  reg         wr,         // Запись в регистр
    output  reg  [15:0] dw          // Значение для записи (номер регистра: A)
);

// Реализация делителя частоты 1/4, т.е. выдача 25 Мгц
reg [1:0] D = 2'b00; assign clk25 = D[1]; always @(posedge clk) D <= D + 1;

initial begin

    dw = 16'h0000;
    d  = 16'h0000;
    o  = 8'h00;
    wr = 1'b0;
    wm = 1'b0;
    Dr = 3'h0;
    Sr = 3'h0;

end

// Главные такты
always @(posedge clk25) begin


end

endmodule
