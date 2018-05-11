module cpu(

    /* Стандартные входы-выходы */
    input   wire        clk,        // 100 мегагерц
    output  wire        clk25,      // 25 мегагерц
    input   wire [7:0]  i,          // Data In (16 бит)
    output  reg  [7:0]  o,          // Data Out,
    output  wire [19:0] a,          // Address 32 bit
    output  reg         w           // Запись [o] на HIGH уровне wm

);

initial begin

    o  = 8'h00;
    w  = 1'b0;

end

// Главные такты
always @(posedge clk25) begin

    // Декодирование опкода и префикса
    // Декодирование modrm если он есть
    // Исполнение операции через микрокод
    // Запись результатов

end

endmodule
