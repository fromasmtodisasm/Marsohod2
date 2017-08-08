/*
 * 8-битный процессор
 * 
 * - на основе инструкции 6502
 * - на скорости 25 мгц
 */
 
module demo_processor(
   
    // Тактирование процессора на стандартной частоте 25 Мгц
    input   wire        clock_25,
    
    // 8-битная шина данных
    input   wire [7:0]  i_data,         // Входящие данные
    output  wire [15:0] o_addr,         // 16-битный адрес (64 кб адресное пространство)
    output  wire [7:0]  o_data,         // Данные для записи
    output  wire        o_wr            // Запись в память

);

assign o_wr = 1'b0;
assign o_addr = 1'b0;

endmodule
