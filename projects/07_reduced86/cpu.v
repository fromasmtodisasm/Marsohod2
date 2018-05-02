module cpu(

    /* Стандартные входы-выходы */
    input   wire        clk,        // 100 мегагерц
    input   wire [15:0] i,          // Data In (16 бит)
    output  reg  [15:0] o,          // Data Out,
    output  wire [31:0] a,          // Address 32 bit
    output  reg         w           // Write Enabled
);

// Реализация делителя частоты 1/4, т.е. выдача 25 Мгц
reg [1:0] d = 2'b00; always @(posedge clk) d <= d + 1;

endmodule
