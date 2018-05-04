module cpu(

    /* Стандартные входы-выходы */
    input   wire        clk,        // 100 мегагерц
    output  wire        clk25,      // 25 мегагерц
    input   wire [7:0]  i,          // Data In (16 бит)
    output  reg  [7:0]  o,          // Data Out,
    output  wire [19:0] a,          // Address 32 bit
    output  reg         w           // Запись [o] на HIGH уровне wm

);

// Адрес, куда смотрит сейчас код или данные
assign a = {cs, 4'h0} + ip;

// Реализация делителя частоты 1/4, т.е. выдача 25 Мгц
reg [1:0] Dx = 2'b00; assign clk25 = Dx[1]; always @(posedge clk) Dx <= Dx + 1;

reg [2:0]  Dr = 3'h0;
reg [2:0]  Sr = 3'h0;
reg [15:0] D;
reg [15:0] S;
reg        b;
reg        W;
reg [15:0] d = 16'h0000;

// Указатель инструкции
reg [15:0] cs = 16'hF000; reg [15:0] ip = 16'hE000;

// Указатель временных данных
reg [15:0] se = 16'h0000; reg [15:0] ea = 16'h0000;

// Регистровый файл
regfile RegFile(clk, Dr, Sr, b, W, d, D, S);

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
