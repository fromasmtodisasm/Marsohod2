/*
 * Монохромный модуль видеоадаптера на 80x50 (8x8)
 */

module text8050(

    // 100 мегагерц
    input   wire        clk,

    // Выходные данные
    output  reg  [4:0]  red,    // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,  // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,   // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,     // Синхросигнал горизонтальной развертки
    output  wire        vs,     // Синхросигнал вертикальной развертки

    output  reg  [10:0] adapter_font,   // 2^11 = 2048 байт
    input   wire [ 7:0] adapter_data,   // Полученные данные от знакогенератора
    output  reg  [11:0] font_char_addr, // Указатель в видеопамять
    input   wire [ 7:0] font_char_data  // Значение из видеопамяти

);

// Тайминги для горизонтальной развертки (640)
parameter horiz_visible = 640;
parameter horiz_back    = 48;
parameter horiz_sync    = 96;
parameter horiz_front   = 16;
parameter horiz_whole   = 800;

// Тайминги для вертикальной развертки (400)
//                              // 400  480
parameter vert_visible = 400;   // 400  480
parameter vert_back    = 35;    // 35   33
parameter vert_sync    = 2;     // 2    2
parameter vert_front   = 12;    // 12   10
parameter vert_whole   = 449;   // 449  525

// 640 + 48 = [688, 688 + 96 = 784]
assign hs = x >= (horiz_visible + horiz_front) && x < (horiz_visible + horiz_front + horiz_sync);
assign vs = y >= (vert_visible  + vert_front)  && y < (vert_visible  + vert_front  + vert_sync);

// Текущее положение луча на экране
reg [9:0] x = 1'b0;
reg [9:0] y = 1'b0;

// Для того, чтобы корректировать предварительную выборку
wire [9:0] x_real = x > 791 ? x - 792 : x + 8;
wire [9:0] y_real = x > 791 ? y + 0   : y - 1;

// Объявим регистры со временными данными
reg [7:0] current_char;
reg [7:0] current_data;
reg       attr;

// Извлекаем текущий бит (от 0 до 7) в зависимости от положения луча x
wire current_bit = current_data[ x_real[2:0] ];

// 25 Мгц
always @(posedge clk) begin

    // Формирование кадра
    x <= (x == horiz_whole - 1) ? 1'b0 : (x + 1'b1);
    y <= (x == horiz_whole - 1) ? (y == vert_whole - 1 ? 1'b0 : (y + 1'b1) ) : y;

    // Получение данных из знакогенератора
    case (x_real[2:0])

        3'b000: begin font_char_addr <= (x_real[9:3] + y_real[9:3] * 80); end /* Поиск символа */
        3'b001: begin current_char   <=  font_char_data; end 
        3'b110: begin adapter_font   <= {current_char[6:0], y_real[2:0]}; end /* Поиск знакогенератора */
        3'b111: begin current_data   <=  adapter_data; attr <= current_char[7]; end

    endcase

    // Видимая область рисования
    if (x < horiz_visible && y < vert_visible) 
        {red, green, blue} <= current_bit ^ attr ? {5'h0F, 6'h1F, 5'h0F} : 0;   
    else 
        {red, green, blue} <= 0;

end

endmodule
