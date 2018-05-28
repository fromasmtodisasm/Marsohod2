// Модуль видеоадаптера

module ppu(

    // 100 мегагерц
    input   wire        CLK25,

    // Выходные данные
    output  reg  [4:0]  red,        // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,      // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,       // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,         // синхросигнал горизонтальной развертки
    output  wire        vs,         // синхросигнал вертикальной развертки

    /* Видеопамять (2Кб) */
    output  reg  [10:0] vaddr,
    input   wire [ 7:0] vdata,

    /* Знакогенератор */
    output  reg  [12:0] faddr,
    input   wire [ 7:0] fdata

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

// 640 (видимая область) + 48 (задний порожек) + 96 (синхронизация) + 16 (передний порожек)
// 640 + 48 = [688, 688 + 96 = 784]
assign hs = x >= (horiz_visible + horiz_front) && x < (horiz_visible + horiz_front + horiz_sync);
assign vs = y >= (vert_visible  + vert_front)  && y < (vert_visible  + vert_front  + vert_sync);

// В этих регистрах мы будем хранить текущее положение луча на экране
reg [9:0]   x = 1'b0; // 2^10 = 1024 точек возможно
reg [9:0]   y = 1'b0;

/* Параметры видеоадаптера */
reg         bankbg = 1'b1;      /* Выбранный банк для отрисовки фона */
reg  [5:0]  PALBG[16];          /* Палитра в регистрах PPU */
reg  [15:0] rgb;                /* Данные из стандартной палитры PPL */

/* Данные для рендеринга */
reg  [7:0]  chrl;
reg  [7:0]  chrh;
reg  [7:0]  hiclr;      /* 3=[7:6] 2=[5:4] 1=[3:2] 0=[1:0] */
reg  [1:0]  colorpad;   /* Атрибуты */
reg  [15:0] colormap;   /* Цвета битов */

/* Два дополнительных бита из ATTR секции VRAM */
wire [1:0]  cpad = {hiclr[ {PPUY[4], PPUX[4], 1'b1} ],  /* 7531 */
                    hiclr[ {PPUY[4], PPUX[4], 1'b0} ]}; /* 6420 */

/* Текущий рисуемый цвет фона */
wire [3:0]  curclr = {colorpad, colormap[ {PPUX[2:0], 1'b1} ], colormap[ {PPUX[2:0], 1'b0} ]};

// Транслируем в конечный цвет
wire [5:0]  color = PALBG[ (curclr[1:0] == 2'b00) ? 4'h0 : curclr[3:0] ];

initial begin

    /* 0 */  PALBG[0]  = 5'h12;
    /* 1 */  PALBG[1]  = 5'h16;
    /* 2 */  PALBG[2]  = 5'h30;
    /* 3 */  PALBG[3]  = 5'h38;
    /* 4 */
    /* 5 */  PALBG[5]  = 5'h17;
    /* 6 */  PALBG[6]  = 5'h26;
    /* 7 */  PALBG[7]  = 5'h07;
    /* 8 */
    /* 9 */  PALBG[9]  = 5'h16;
    /* 10 */ PALBG[10] = 5'h00;
    /* 11 */ PALBG[11] = 5'h30;
    /* 12 */
    /* 13 */ PALBG[13] = 5'h38;
    /* 14 */ PALBG[14] = 5'h28;
    /* 15 */ PALBG[15] = 5'h10;

end

reg       DE2P = 1'b0; /* Уменьшители частоты */
reg       DE2Y = 1'b0; /* Деление сканлайна на 2 */
reg [8:0] PPUX = 1'b0; /* Положение X в сканлайне [0..340]=341T */
reg [8:0] PPUY = 1'b0; /* Положение Y в сканлайне [0..261]=262T */

// Тайминги PPU 341 x 262 линии
// https://wiki.nesdev.com/w/index.php/Clock_rate (NTSC)

always @(posedge CLK25) begin

    /* Сброс регистров таймингов PPU */
    if (x == 0 && y == 0) DE2P <= 1'b0;

    /* Пропуск 64 тактов (25 Mhz), потом 341T по 2T на частоте 25 Мгц */
    /* -16 для того, чтобы PPU успел подготовить данные. 525-я линия Y не используется */
    else if (x > (64 - 16) && x <= (746 - 16)) DE2P <= ~DE2P;

end

/* ~ 5,3675 Mhz: PPUX=[0..340], PPUY=[0..261] */
always @(posedge DE2P) begin

    // PPUX, PPUY могут быть замещены

    case (PPUX[2:0])

        /* Прочитаем из памяти символ 8x8 */
        3'h0: begin vaddr <= {PPUY[7:3], PPUX[7:3]}; /* 32x30 */ end

        /* Начнем чтение CHR (BA=0, CHR=00000000, B=0, Y=000} */
        3'h1: begin faddr <= {bankbg, vdata[7:0], 1'b0, PPUY[2:0]}; end

        /* Чтение верхней палитры знакогенератора */
        3'h2: begin faddr <= {bankbg, vdata[7:0], 1'b1, PPUY[2:0]}; chrl <= fdata; end

        /* Палитра прочитана, читаем дополнительную палитру */
        3'h3: begin vaddr <= { 4'b1111, PPUY[7:5], PPUX[7:5] }; chrh <= fdata; end

        /* Читать данные, завершены */
        3'h4: begin hiclr <= vdata; end

        /* Итоговый результат */
        3'h7: begin

            /* Старшие цвета пикселей */
            colorpad <= cpad;

            /* Нижние цвета пикселей */
            colormap <= {/* BIT 7 */ chrh[0], chrl[0], /* BIT 6 */ chrh[1], chrl[1],
                         /* BIT 5 */ chrh[2], chrl[2], /* BIT 4 */ chrh[3], chrl[3],
                         /* BIT 3 */ chrh[4], chrl[4], /* BIT 2 */ chrh[5], chrl[5],
                         /* BIT 1 */ chrh[6], chrl[6], /* BIT 0 */ chrh[7], chrl[7]};

        end

    endcase

    // 525-й такт, не используемый в NES
    if (y == vert_whole - 1) PPUY <= 1'b0;

    // Конец сканлайна (341 пиксель)
    else if (PPUX == 9'd340) begin

        PPUX <= 1'b0;
        DE2Y <= ~DE2Y;

        /* Второй сканлайн НЕ учитывается. При достижении 261-го, сбросить до 0 */
        if (DE2Y) PPUY <= PPUY + 1'b1; // (PPUY == 9'd261 ? 1'b0 : PPUY + 1'b1;

    end else begin

        PPUX <= PPUX + 1'b1;

    end

end

// Частота видеоадаптера VGA 25 Mhz
always @(posedge CLK25) begin

    // аналогично этой конструции на C
    // if (x == (horiz_whole - 1)) x = 0; else x += 1;
    x <= x == (horiz_whole - 1) ? 1'b0 : (x + 1'b1);

    // Когда достигаем конца горизонтальной линии, переходим к Y+1
    if (x == (horiz_whole - 1)) begin

        // if (x == (vert_whole - 1)) y = 0; else y += 1;
        y <= y == (vert_whole - 1) ? 1'b0 : (y + 1'b1);

    end

    // Мы находимся в видимой области рисования
    // Здесь не сразу выдаются данные, сначала они необходимым образом
    // загружаются в области заднего порожека, и потом уже мы можем показать

    if (x < horiz_visible && y < vert_visible) begin

        // Экран Денди находится посередине
        if (x >= 64 && x < 576)

            {red, green, blue} <= {rgb[4:0], rgb[10:5], rgb[15:11]};

        else
            /* Сверху и снизу подсвечивается легким синим */
            {red, green, blue} <= {5'h03, 6'h03, 5'h03};

    end

    // В невидимой области мы ДОЛЖНЫ очищать в черный цвет
    // иначе видеоадаптер работать будет неправильно
    else begin

        red   <= 1'b0;
        green <= 1'b0;
        blue  <= 1'b0;

    end

end

/* Преобразования номера цвета палитры в реальный */
always @* case (color)

    6'd0:  rgb = 16'h73ae;
	6'd1:  rgb = 16'h88c4;
	6'd2:  rgb = 16'ha800;
	6'd3:  rgb = 16'h9808;
	6'd4:  rgb = 16'h7011;
	6'd5:  rgb = 16'h1015;
	6'd6:  rgb = 16'h0014;
	6'd7:  rgb = 16'h004f;
	6'd8:  rgb = 16'h0168;
	6'd9:  rgb = 16'h0220;
	6'd10: rgb = 16'h0280;
	6'd11: rgb = 16'h11e0;
	6'd12: rgb = 16'h59e3;
	6'd16: rgb = 16'hbdf7;
	6'd17: rgb = 16'heb80;
	6'd18: rgb = 16'he9c4;
	6'd19: rgb = 16'hf010;
	6'd20: rgb = 16'hb817;
	6'd21: rgb = 16'h581c;
	6'd22: rgb = 16'h015b;
	6'd23: rgb = 16'h0a79;
	6'd24: rgb = 16'h0391;
	6'd25: rgb = 16'h04a0;
	6'd26: rgb = 16'h0540;
	6'd27: rgb = 16'h3c80;
	6'd28: rgb = 16'h8c00;
	6'd32: rgb = 16'hffff;
	6'd33: rgb = 16'hfde7;
	6'd34: rgb = 16'hfcab;
	6'd35: rgb = 16'hfc54;
	6'd36: rgb = 16'hfbde;
	6'd37: rgb = 16'hb3bf;
	6'd38: rgb = 16'h63bf;
	6'd39: rgb = 16'h3cdf;
	6'd40: rgb = 16'h3dfe;
	6'd41: rgb = 16'h1690;
	6'd42: rgb = 16'h4ee9;
	6'd43: rgb = 16'h9fcb;
	6'd44: rgb = 16'hdf40;
	6'd48: rgb = 16'hffff;
	6'd49: rgb = 16'hff35;
	6'd50: rgb = 16'hfeb8;
	6'd51: rgb = 16'hfe5a;
	6'd52: rgb = 16'hfe3f;
	6'd53: rgb = 16'hde3f;
	6'd54: rgb = 16'hb5ff;
	6'd55: rgb = 16'haedf;
	6'd56: rgb = 16'ha73f;
	6'd57: rgb = 16'ha7fc;
	6'd58: rgb = 16'hbf95;
	6'd59: rgb = 16'hcff6;
	6'd60: rgb = 16'hf7f3;
	default: rgb = 1'b0;

endcase

endmodule
