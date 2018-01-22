module cpu(

    input   wire        clk,            // 100 Mhz
    input   wire        i_ready,        // Если 0, то данные не готовы
    output  wire [19:0] o_addr,         // Адрес на чтение, 1 Мб
    input   wire [15:0] i_data,         // Входящие данные
    output  wire [15:0] o_data,         // Исходящие данные
    output  wire        o_write,        // Запрос на запись
    output  wire [19:0] o_ip,           // Instruction Pointer
    input   wire [47:0] i_instr_cache

);

reg [15:0] ip = 16'h0000;
reg [15:0] cs = 16'hFC00;

assign o_addr = 16'h2;
assign o_ip = {cs, 4'h0} + ip;
assign o_data = 16'hACDE;
assign o_write = 1'b0;

always @(posedge clk) if (i_ready) ip <= ip + 1;

endmodule
