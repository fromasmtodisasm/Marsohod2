module vga(

    // 100 мегагерц
    input   wire        clk,

    // Выходные данные
    output  reg  [4:0]  red,        // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,      // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,       // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,         // синхросигнал горизонтальной развертки
    output  wire        vs,          // синхросигнал вертикальной развертки

    // Данные для вывода
    output  reg  [12:0] video_addr,
    input   wire [ 7:0] video_data
    
);

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
reg [9:0] x = 1'b0; // 2^10 = 1024 точек возможно
reg [9:0] y = 1'b0;

reg [7:0] current_char;
reg [7:0] current_attr;

// 2х битный счетчик
reg [1:0] clock_divider;

// Делитель частоты. На входе частота - 100 мгц, а на выходе будет 25 Мгц
always @(posedge clk) clock_divider <= clock_divider + 1'b1;

// Чтобы правильно начинались данные, нужно их выровнять
wire [7:0] X = x[9:1] - 32;
wire [7:0] Y = y[9:1] - 24;

// Получаем текущий бит
wire current_bit = current_char[ 7 ^ X[2:0] ];

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
    
        // Видеоадрес в ZX Spectrum непросто вычислить
        //         FEDC BA98 7654 3210    
        // Адрес =    Y Yzzz yyyx xxxx
                
                               // БанкY  СмещениеY ПолубанкY СмещениеX
        4'b0000: video_addr <= { Y[7:6], Y[2:0],   Y[5:3],   X[7:3] };
        
        // Подготовка к выводу символа
        4'b1111: current_char <= video_data;

    endcase
    
    // Мы находимся в видимой области рисования
    if (x < horiz_visible && y < vert_visible) begin
    
        if (x >= 64 && x < (64 + 512) && y >= 48 && y < (48 + 384)) begin
        
            {red, green, blue} <= current_bit ? {5'h1F, 6'h3F, 5'h1F} : {5'h03, 6'h03, 5'h03};
        
        end else begin
        
            // Тут будет бордюр
            {red, green, blue} <= {5'h03, 6'h03, 5'h03}; 
        
        end
    
    // В невидимой области мы ДОЛЖНЫ очищать в черный цвет
    // иначе видеоадаптер работать будет неправильно
    end else {red, green, blue} <= 16'h0000;
    
end

endmodule
