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

/* Реальные значения X,Y, начинаются с (0, 0) */
wire [9:0]  X = x - 64 + 16;
wire [9:0]  Y = y;

/* Параметры видеоадаптера */
reg         bankbg = 1'b1;      /* Выбранный банк для отрисовки фона */


//reg  [5:0]  color;      /* Запрос цвета из палитры */
reg  [15:0] rgb;        /* Данные из стандартной палитры PPL */

/* Данные для рендеринга */
reg  [7:0]  chrl;
reg  [7:0]  chrh;
reg  [7:0]  hiclr;      /* 3=[7:6] 2=[5:4] 1=[3:2] 0=[1:0] */
reg  [1:0]  colorpad;   /* Атрибуты */
reg  [15:0] colormap;   /* Цвета битов */

/* Текущий рисуемый цвет фона */
wire [3:0]  current_color = {colorpad, colormap[ {X[3:1], 1'b1} ], colormap[ {X[3:1], 1'b0} ]};

/* Два дополнительных бита из ATTR секции VRAM */
wire [1:0]  cpad = {hiclr[ {Y[5], X[5], 1'b1} ],  /* 7531 */
                    hiclr[ {Y[5], X[5], 1'b0} ]}; /* 6420 */
                
// !! Temporary !!                
wire [5:0] color = current_color;
                
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
    
        case (x[3:0])
        
            /* Прочитаем из памяти символ 8x8 */
            4'h0: begin vaddr <= { Y[8:4], X[8:4] }; /* 32x30 */ end
            
            /* Начнем чтение CHR (BA=0, CHR=00000000, B=0, Y=000} */
            4'h1: begin faddr <= {bankbg, vdata[7:0], 1'b0, Y[3:1]}; end
            
            /* Чтение верхней палитры знакогенератора */
            4'h2: begin faddr <= {bankbg, vdata[7:0], 1'b1, Y[3:1]}; chrl <= fdata; end
                        
            /* Палитра прочитана, читаем дополнительную палитру */
            4'h3: begin vaddr <= { 4'b1111, Y[8:6], X[8:6] }; chrh <= fdata; end            
            
            /* Читать данные, завершены */
            4'h4: begin hiclr <= vdata; end
            
            /* Итоговый результат */
            4'hF: begin
                
                /* Старшие цвета пикселей */
                colorpad <= cpad;
                
                /* Нижние цвета пикселей */
                colormap <= {/* BIT 7 */ chrh[0], chrl[0], /* BIT 6 */ chrh[1], chrl[1], 
                             /* BIT 5 */ chrh[2], chrl[2], /* BIT 4 */ chrh[3], chrl[3],
                             /* BIT 3 */ chrh[4], chrl[4], /* BIT 2 */ chrh[5], chrl[5], 
                             /* BIT 1 */ chrh[6], chrl[6], /* BIT 0 */ chrh[7], chrl[7]};

            end

        endcase

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

always @* case (color)

    6'd0: rgb = 16'h73ae;
	6'd1: rgb = 16'h88c4;
	6'd2: rgb = 16'ha800;
	6'd3: rgb = 16'h9808;
	6'd4: rgb = 16'h7011;
	6'd5: rgb = 16'h1015;
	6'd6: rgb = 16'h14;
	6'd7: rgb = 16'h4f;
	6'd8: rgb = 16'h168;
	6'd9: rgb = 16'h220;
	6'd10: rgb = 16'h280;
	6'd11: rgb = 16'h11e0;
	6'd12: rgb = 16'h59e3;
	6'd16: rgb = 16'hbdf7;
	6'd17: rgb = 16'heb80;
	6'd18: rgb = 16'he9c4;
	6'd19: rgb = 16'hf010;
	6'd20: rgb = 16'hb817;
	6'd21: rgb = 16'h581c;
	6'd22: rgb = 16'h15b;
	6'd23: rgb = 16'ha79;
	6'd24: rgb = 16'h391;
	6'd25: rgb = 16'h4a0;
	6'd26: rgb = 16'h540;
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
