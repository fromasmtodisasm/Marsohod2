/*
 * Отладочный модуль icarus verilog для памяти
 */
 
`define BITS_ADDR 16
`define BITS_DATA 8
`define ADDR_SIZE 65536
`define MEM_BINFILE "icarus_rom.hex"

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

    $readmemh(`MEM_BINFILE, memory) ;
    
    q_0  = 1'b0;              q  = 1'b0;
    qw_0 = 1'b0; qw_1 = 1'b0; qw = 1'b0;
    
end

reg  [(`BITS_DATA - 1):0]  q_0;
reg  [(`BITS_DATA - 1):0] qw_0; 
reg  [(`BITS_DATA - 1):0] qw_1;

always @(posedge clk) begin

    // Задержка в 2 такта на чтение из памяти
    q_0  <= memory[ addr_rd ];  
    q    <= q_0;                
    
    // Задержка в 4 такта после записи
    // 4Т вместо 2Т сделано намеренно из-за реальных сильных задержек в реальных ПЛИС
    qw_1 <= memory[ addr_wr ];
    qw_0 <= qw_1;              // Задержка на -3
    qw   <= qw_0;              // Задержка на -2
    
    // Сначала запись, потом будет чтение на следующем такте
    if (wren) memory[ addr_wr ] <= data_wr;

end

endmodule
