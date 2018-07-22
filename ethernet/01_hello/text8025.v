// Модуль видеоадаптера

module text8025(

    // 100 мегагерц
    input   wire        clk,

    // Выходные данные
    output  reg  [4:0]  red,    // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,  // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,   // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,     // Синхросигнал горизонтальной развертки
    output  wire        vs,     // Синхросигнал вертикальной развертки

    output  reg  [11:0] adapter_font,   // 2^12 = 4096 байт
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

// В этих регистрах мы будем хранить текущее положение луча на экране
reg [9:0] x = 1'b0; // 2^10 = 1024 точек возможно
reg [9:0] y = 1'b0;

// Положение X, когда начинается отрисовка видимой области, должно быть 0,
// без учета переднего порожека +8 смещение, т.к. такты слишком сильно рано 
// начинаются, и поэтому на начале необходимо ждать 8 тактов, чтобы символ появился

wire [9:0] x_real = x > 791 ? x - 792 : x + 8;

// Сместить на 40 символов, чтобы с 40-й строки начинался y_real=0
wire [9:0] y_real = x > 791 ? y + 1 : y;

// Объявим регистры со временными данными
reg [7:0] current_char;
reg [7:0] temp_current_attr;
reg [7:0] current_attr;
reg [7:0] current_data;
reg       flash;

// Извлекаем текущий бит (от 0 до 7) в зависимости от положения луча x
// Чтобы развернуть биты, надо сделать, чтобы они читались не от бита 0 к 7,
// а от 7 к 0, т.е. сделать им XOR 7
wire current_bit = current_data[ 3'h7 ^ x_real[2:0] ];

// Разбираем цветовую компоненту (нижние 4 бита отвечают за цвет символа)
wire [15:0] fr_color =

    // R(5 бит) G(6 бит) B(5 бит(
    current_attr[3:0] == 4'd0  ? { 5'h03, 6'h03, 5'h03 } : // 0 Черный (почти)
    current_attr[3:0] == 4'd1  ? { 5'h00, 6'h00, 5'h0F } : // 1 Синий (темный)
    current_attr[3:0] == 4'd2  ? { 5'h00, 6'h1F, 5'h00 } : // 2 Зеленый (темный)
    current_attr[3:0] == 4'd3  ? { 5'h00, 6'h1F, 5'h0F } : // 3 Бирюзовый (темный)
    current_attr[3:0] == 4'd4  ? { 5'h0F, 6'h00, 5'h00 } : // 4 Красный (темный)
    current_attr[3:0] == 4'd5  ? { 5'h0F, 6'h00, 5'h0F } : // 5 Фиолетовый (темный)
    current_attr[3:0] == 4'd6  ? { 5'h0F, 6'h1F, 5'h00 } : // 6 Коричневый
    current_attr[3:0] == 4'd7  ? { 5'h0F, 6'h1F, 5'h0F } : // 7 Серый -- тут что-то не то
    current_attr[3:0] == 4'd8  ? { 5'h07, 6'h0F, 5'h07 } : // 8 Темно-серый
    current_attr[3:0] == 4'd9  ? { 5'h00, 6'h00, 5'h1F } : // 9 Синий (темный)
    current_attr[3:0] == 4'd10 ? { 5'h00, 6'h3F, 5'h00 } : // 10 Зеленый
    current_attr[3:0] == 4'd11 ? { 5'h00, 6'h3F, 5'h1F } : // 11 Бирюзовый
    current_attr[3:0] == 4'd12 ? { 5'h1F, 6'h00, 5'h00 } : // 12 Красный
    current_attr[3:0] == 4'd13 ? { 5'h1F, 6'h00, 5'h1F } : // 13 Фиолетовый
    current_attr[3:0] == 4'd14 ? { 5'h1F, 6'h3F, 5'h00 } : // 14 Желтый
                                 { 5'h1F, 6'h3F, 5'h1F };  // 15 Белый

// Цветовая компонента фона (только 8 цветов)
wire [15:0] bg_color =

    // R(5 бит) G(6 бит) B(5 бит(
    current_attr[6:4] == 3'd0 ? { 5'h03, 6'h03, 5'h03 } : // 0 Черный (почти)
    current_attr[6:4] == 3'd1 ? { 5'h00, 6'h00, 5'h0F } : // 1 Синий (темный)
    current_attr[6:4] == 3'd2 ? { 5'h00, 6'h1F, 5'h00 } : // 2 Зеленый (темный)
    current_attr[6:4] == 3'd3 ? { 5'h00, 6'h1F, 5'h0F } : // 3 Бирюзовый (темный)
    current_attr[6:4] == 3'd4 ? { 5'h0F, 6'h00, 5'h00 } : // 4 Красный (темный)
    current_attr[6:4] == 3'd5 ? { 5'h0F, 6'h00, 5'h0F } : // 5 Фиолетовый (темный)
    current_attr[6:4] == 3'd6 ? { 5'h0F, 6'h1F, 5'h00 } : // 6 Коричневый
                                { 5'h0F, 6'h1F, 5'h0F };  // 7 Серый

// 2х битный счетчик
reg [23:0] clock_timer;

// Таймер, 0.5 с
always @(posedge clk) begin

    // 12,5 Мгц. Каждые 0,5 секунды перебрасывается регистр flash
    if (clock_timer == 12500000) begin
        clock_timer <= 1'b0;
        flash <= flash ^ 1'b1;
    end
    else
        clock_timer <= clock_timer + 1;

end

// Когда бит 1 переходит из состояния 0 в состояние 1, это значит, что
// будет осциллироваться на частоте 25 мгц (в 4 раза медленее, чем 100 мгц)
always @(posedge clk) begin

    // аналогично этой конструции на C
    // if (x == (horiz_whole - 1)) x = 0; else x += 1;
    x <= (x == horiz_whole - 1) ? 1'b0 : (x + 1'b1);

    // Когда достигаем конца горизонтальной линии, переходим к Y+1
    y <= (x == horiz_whole - 1) ? (y == vert_whole - 1 ? 1'b0 : (y + 1'b1) ) : y;

    // Генерация данных для последующего рисования
    case (x_real[2:0])

        // В x[9:3] хранится номер 0..79 (текущий символ)
        // В y[9:4] y=0..24 Адрес = (y*80 + x) * 2
        3'b000: font_char_addr <= 2*(x_real[9:3] + y_real[9:4] * 80);

        // Здесь мы будем принимать номер символа с "шины"
        3'b001: begin

            // На этом такте, отправляем новый адрес
            // он всегда будет +1 т.е. font_char_addr++
            current_char   <= font_char_data;
            font_char_addr <= {font_char_addr[11:1], 1'b1};

        end

        // Прием значения цвета на следующем такте
        3'b010: temp_current_attr <= font_char_data;

        // Делаем запрос на поиск части символа
        // {current_char, y[3:0]} = current_char * 16 + (y % 16)
        3'b110: adapter_font <= {current_char, y_real[3:0]};

        // Читаем ответ от знакогенератора (через 4 такта на скорости 100 мгц)
        // Или через 1 такт на скорости 25 Мгц, на которой мы сейчас и работаем
        3'b111: begin

            current_data <= adapter_data;
            current_attr <= temp_current_attr;

        end

    endcase

    // Мы находимся в видимой области рисования
    // Здесь не сразу выдаются данные, сначала они необходимым образом
    // загружаются в области заднего порожека, и потом уже мы можем показать

    if (x < horiz_visible && y < vert_visible) begin

        /* Ограничим на 25 символов по высоте (25 x 16 = 400) */
        /* Если бит 7 атрибута = 1, то при flash=1 показываем bg_color вместо fr_color */
        {red, green, blue} <= current_bit ? (current_attr[7] & flash ? bg_color : fr_color) : bg_color;

    end
    // В невидимой области мы ДОЛЖНЫ очищать в черный цвет
    // иначе видеоадаптер работать будет неправильно
    else begin {red, green, blue} <= 0; end

end

endmodule
