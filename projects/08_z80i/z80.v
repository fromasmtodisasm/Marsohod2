/* 
 * Не находится в ведении копирайтов. Сделан, как кофе с утра.
 * Реклама: я кот, хозяин спит, лей вискаса, а то разодру обои.
 */
 
module z80(

    // О`клок
    input wire          clk,

    // Кот    #1 Порт
    output reg [15:0]   Ca,
    input wire [7:0]    Ci,
    
    // Данные #2 Порт
    output reg [15:0]   Da,
    input wire [7:0]    Di,
    output reg [7:0]    Do,
    output reg          Dw

);

endmodule
