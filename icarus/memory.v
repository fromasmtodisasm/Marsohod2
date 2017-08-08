/*
 * Отладочный модуль icarus verilog для памяти
 */
 
`define BITS_ADDR 14
`define BITS_DATA 8
`define ADDR_SIZE 16384
`define MEM_BINFILE "initial.bin"

/*
 * ИНТЕГРАЦИЯ В КОД ICARUS VERILOG [icarus.v]
 
 wire [?:0] addr_rd;
 wire [?:0] q;
 wire [?:0] addr_wr;
 wire [?:0] data_wr;
 wire       wren;
 wire [?:0] qw;
 
 memory MEMORY(clk, addr_rd, q, addr_wr, data_wr, wren, qw);
 
 */ 


// Интерфейс
module memory(

    input  wire                      clk,
    input  wire [(`BITS_ADDR - 1):0] addr_rd,
    output reg  [(`BITS_DATA - 1):0] q,
    input  wire [(`BITS_ADDR - 1):0] addr_wr,
    input  wire [(`BITS_DATA - 1):0] data_wr,
    input  wire                      wren,
    output reg  [(`BITS_DATA - 1):0] qw

);

//  --------------------------------------------------
reg [`BITS_ADDR - 1 : 0] memory [`ADDR_SIZE - 1: 0];

// Инициализация памяти
//  --------------------------------------------------

initial begin

    $readmemb(`MEM_BINFILE, memory) ;

end

reg  [(`BITS_DATA - 1):0] q_0;  reg  [(`BITS_DATA - 1):0] q_1;
reg  [(`BITS_DATA - 1):0] qw_0; reg  [(`BITS_DATA - 1):0] qw_1;

always @(posedge clk) begin

    // Задержка в 4 такта после записи
    // 4Т вместо 2Т сделано намеренно из-за реальных сильных задержек в реальных ПЛИС

    q_0  <= memory[ addr_rd ];  qw_0 <= memory[ addr_rd ]; // Задержка на -4
    q_1  <= q_0;                qw_1 <= qw_0;              // Задержка на -3
    q    <= q_1;                qw   <= qw_1;              // Задержка на -2
    
    // Сначала запись, потом будет чтение на следующем такте
    if (wren) memory[ addr_wr ] <= data_wr;

end

endmodule
