module vga(

    // 100 мегагерц
    input   wire        clk,

    // Выходные данные
    output  reg  [4:0]  red,        // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,      // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,       // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,         // синхросигнал горизонтальной развертки
    output  wire        vs,         // синхросигнал вертикальной развертки

    // Данные для вывода
    output  reg  [ 9:0] video_addr, // 768 + 256 = 1024 (1 страница)
    input   wire [ 7:0] video_data,
    output  reg  [10:0] char_addr, // 2048
    input   wire [ 7:0] char_data
    
);

// ---------------------------------------------------------------------

// Тайминги для горизонтальной развертки (640)
parameter horiz_visible = 640;
parameter horiz_back    = 48;
parameter horiz_sync    = 96;
parameter horiz_front   = 16;
parameter horiz_whole   = 800;

// Тайминги для вертикальной развертки (400)
//                              // 400  480
parameter vert_visible = 480;   // 400  480
parameter vert_back    = 33;    // 35   33
parameter vert_sync    = 2;     // 2    2
parameter vert_front   = 10;    // 12   10
parameter vert_whole   = 525;   // 449  525

// 640 (видимая область) + 16 (передний порожек) + 96 (синхронизация) + 48 (задний порожек)
assign hs = x >= (horiz_visible + horiz_front) && x < (horiz_visible + horiz_front + horiz_sync);
assign vs = y >= (vert_visible  + vert_front)  && y < (vert_visible  + vert_front  + vert_sync);

// В этих регистрах мы будем хранить текущее положение луча на экране
reg [9:0] x = 1'b0;         // 2^10 = 1024 точек возможно
reg [9:0] y = 1'b0;
reg [1:0] clock_divider;    // 2х битный счетчик

// Делитель частоты. На входе частота - 100 мгц, а на выходе будет 25 Мгц
always @(posedge clk) clock_divider <= clock_divider + 1'b1;
// ---------------------------------------------------------------------

reg [7:0] current_char;
reg [7:0] current_attr;
reg [7:0] current_char_temp;

// Чтобы правильно начинались данные, нужно их выровнять
wire [7:0] X = x[9:1] - 24;
wire [7:0] Y = y[9:1] - 24;

// Получаем текущий бит
wire current_bit = current_char[ 7 ^ X[2:0] ];

// Текущий цвет точки
// Если сейчас рисуется бит - то нарисовать цвет из атрибута (FrColor), иначе - BgColor
wire [3:0] cur_color = (current_bit ? current_attr[3:0] : current_attr[7:4]);

// Вычисляем цвет. Если бит 3=1, то цвет яркий, иначе обычного оттенка (половинной яркости)
wire [15:0] color = 

    cur_color == 4'd0 ?  { 5'h03, 6'h03, 5'h03 } :
    cur_color == 4'd1 ?  { 5'h00, 6'h00, 5'h0F } :
    cur_color == 4'd2 ?  { 5'h00, 6'h1F, 5'h00 } :
    cur_color == 4'd3 ?  { 5'h00, 6'h1F, 5'h0F } :
    cur_color == 4'd4 ?  { 5'h0F, 6'h00, 5'h00 } :
    cur_color == 4'd5 ?  { 5'h0F, 6'h00, 5'h0F } :
    cur_color == 4'd6 ?  { 5'h0F, 6'h1F, 5'h00 } :
    cur_color == 4'd7 ?  { 5'h0F, 6'h1F, 5'h0F } :
    cur_color == 4'd8 ?  { 5'h07, 6'h0F, 5'h07 } :
    cur_color == 4'd9 ?  { 5'h00, 6'h00, 5'h1F } :
    cur_color == 4'd10 ? { 5'h00, 6'h3F, 5'h00 } :
    cur_color == 4'd11 ? { 5'h00, 6'h3F, 5'h1F } :
    cur_color == 4'd12 ? { 5'h1F, 6'h00, 5'h00 } :
    cur_color == 4'd13 ? { 5'h1F, 6'h00, 5'h1F } :
    cur_color == 4'd14 ? { 5'h1F, 6'h3F, 5'h00 } :
                         { 5'h1F, 6'h3F, 5'h1F };

// Шрифты отсюда
// https://github.com/dhepper/font8x8

// Когда бит 1 переходит из состояния 0 в состояние 1, это значит, что
// будет осциллироваться на частоте 25 мгц (в 4 раза медленее, чем 100 мгц)
always @(posedge clock_divider[1]) begin

    // аналогично этой конструции на C
    // if (x == 799) x = 0; else x += 1;
    x <= x == (horiz_whole - 1) ? 1'b0 : (x + 1'b1);
    
    // Когда достигаем конца горизонтальной линии, переходим к Y+1
    if (x == (horiz_whole - 1)) begin
    
        // if (x == 524) y = 0; else y += 1;
        y <= y == (vert_whole - 1) ? 1'b0 : (y + 1'b1);

    end
    
    // Обязательно надо тут использовать попиксельный выход, а то пиксели
    // наполовину съезжают
    
    case (x[3:0])

        // Видеоадрес для извлечения нужного charmap
        4'b0000: video_addr <= { Y[7:3], X[7:3] };
        
        // Выбираем текущее положение знакоместа
        4'b0001: char_addr <= {video_data, Y[2:0]};
        
        // Запись временного значения
        4'b0010: current_char_temp <= char_data;
        
        // Запрос атрибута по x=0..15, y=0..15 с 768-го адреса
        //   [yyyyy] [xxxxx]
        //  110000    0000 
        4'b0011: video_addr <= { 2'b11, Y[7:4], X[7:4] };

        // Записать маску битов и атрибуты
        4'b1111: begin

            current_char <= current_char_temp;            
            current_attr <= video_data;

        end

    endcase
    
    // Мы находимся в видимой области рисования
    if (x < horiz_visible && y < vert_visible) begin
    
        if (x >= 64 && x < (64 + 512) && y >= 48 && y < (48 + 384)) begin
        
            // Цвет вычисляется выше и зависит от
            // 1. Атрибута 
            // 2. Это пиксель или нет
            {red, green, blue} <= color;
        
        // Бордюр
        end else begin

            {red, green, blue} <= {5'h03, 6'h03, 5'h03}; 
        
        end
    
    // В невидимой области мы ДОЛЖНЫ очищать в черный цвет
    // иначе видеоадаптер работать будет неправильно
    end else {red, green, blue} <= 16'h0000;
    
end

endmodule
