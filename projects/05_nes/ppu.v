// Модуль видеоадаптера

module ppu(

    // 100 мегагерц
    input   wire        CLK25,
    input   wire        RESET,

    // Выходные данные
    output  reg  [4:0]  red,        // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,      // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,       // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,         // синхросигнал горизонтальной развертки
    output  wire        vs,         // синхросигнал вертикальной развертки

    /* Видеопамять (2Кб) */
    output  reg  [10:0] vaddr,
    input   wire [ 7:0] vdata,

    /* Интерфейс для чтения и записи в видеопамять */
    input   wire [7:0]  VIN,
    output  reg         WVREQ,
    output  reg  [12:0] WADDR,
    output  reg  [7:0]  WDATA,

    // --- чтение и запись из памяти (2-х портовая)

    /* Знакогенератор */
    output  reg  [12:0] faddr,
    input   wire [ 7:0] fdata,
    input   wire [ 7:0] FIN,

    /* Исходящий PPU/CPU */
    output  wire        CLKPPU,
    output  reg         CLKCPU,

    /* Обмен данными с процессором */
    input   wire [15:0] ea,         /* Запрошенный эффективный адрес */
    input   wire [ 7:0] din,        /* Данные из процессора */
    input   wire        RD,         /* Действие чтения из памяти */
    input   wire        WREQ,       /* Запрос на запись в PPU */
    output  reg  [ 7:0] DOUT,       /* Выход данных из PPU */

    /* NMI сигнал */
    output  reg         NMI,         /* Выход NMI */
    output  wire [ 7:0] DEBUG

);

/* Валидный тайминг PPU (~5 Мгц) */
assign CLKPPU = !DE2Y & DE2X;

// ===========
assign DEBUG = ADDR[7:0];

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

// 640 (видимая область) + 48 (задний порожек) + 96 (синхронизация) + 16 (передний порожек)
// 640 + 48 = [688, 688 + 96 = 784]

assign hs = x >= (horiz_visible + horiz_front) && x < (horiz_visible + horiz_front + horiz_sync);
assign vs = y >= (vert_visible  + vert_front)  && y < (vert_visible  + vert_front  + vert_sync);

// В этих регистрах мы будем хранить текущее положение луча на экране
reg [9:0]   x = 1'b0; // 2^10 = 1024 точек возможно
reg [9:0]   y = 1'b0;

/* Формирователи частоты */
reg       DE2X      = 1'b0;     /* Половинная частота (12.5 Мгц) */
reg       DE2Y      = 1'b0;     /* Деление сканлайна на 2 */
reg [8:0] PPUX      = 1'b0;     /* Положение X в сканлайне [0..340]=341T */
reg [8:0] PPUY      = 1'b0;     /* Положение Y в сканлайне [0..261]=262T */

/* Параметры видеоадаптера */
reg  [ 5:0] PALBG[16];          /* Палитра фона в регистрах PPU */
reg  [ 5:0] PALSP[16];          /* Палитра спрайтов в регистрах PPU */
reg  [15:0] ADDR    = 16'h2055; /* Адрес внутри PPU */
reg  [ 1:0] div     = 2'b00;    /* Формирование PPU/CPU clock */
reg  [15:0] rgb;                /* Данные из стандартной палитры PPL */

/* Данные для рендеринга */
// ---------------------------------------------------------------------
reg  [7:0]  chrl;
reg  [7:0]  chrh;
reg  [7:0]  hiclr;      /* 3=[7:6] 2=[5:4] 1=[3:2] 0=[1:0] */
reg  [1:0]  colorpad;   /* Атрибуты */
reg  [15:0] colormap;   /* Цвета битов */

/* Текущий рисуемый цвет фона */
wire [3:0]  curclr = {colorpad[ 1 ],
                      colorpad[ 0 ],
                      colormap[ {X[2:0], 1'b1} ],
                      colormap[ {X[2:0], 1'b0} ]};

// Транслируем в конечный цвет
wire [3:0]  colmp = (curclr[1:0] == 2'b00) || /* Прозрачный */
                    (PPUX[7:3] == 0 && CTRL1[1] == 1'b0) /* Скрытие левого столбца */ ? 4'h0 : curclr[3:0];
                    
wire [5:0]  color = PALBG[ (x < 64 || x > 575) ? 4'h0 : colmp ];
// ---------------------------------------------------------------------

/* Флаг VBlank */
wire VBlank     = VBlankPPU ^ VBlankCPU;
reg  VBlankPPU  = 1'b0;
reg  VBlankCPU  = 1'b0;

/* Инициализация */
initial begin

    CLKCPU = 1'b0;
    DOUT   = 8'h00;
    WVREQ  = 1'b0;
    NMI    = 1'b0;
    WADDR  = 16'h0000;

    /* 0 */  PALBG[0]  = 6'h12; // 12
    /* 1 */  PALBG[1]  = 6'h16; // 16
    /* 2 */  PALBG[2]  = 6'h30; // 30
    /* 3 */  PALBG[3]  = 6'h38; // 38
    /* 4 */
    /* 5 */  PALBG[5]  = 6'h17;
    /* 6 */  PALBG[6]  = 6'h26;
    /* 7 */  PALBG[7]  = 6'h07;
    /* 8 */
    /* 9 */  PALBG[9]  = 6'h16;
    /* 10 */ PALBG[10] = 6'h00;
    /* 11 */ PALBG[11] = 6'h30;
    /* 12 */
    /* 13 */ PALBG[13] = 6'h38;
    /* 14 */ PALBG[14] = 6'h28;
    /* 15 */ PALBG[15] = 6'h10;

end

/*  Регистры контроля
// ---------------------
7   Формирование запроса прерывания NMI при кадровом синхроимпульсе
    (0 - запрещено; 1 - разрешено)

6   (Не используется, должен быть 0)
5   Размер спрайтов (0 - 8x8; 1 - 8x16)
4   Выбор знакогенератора фона (0/1)
3   Выбор знакогенератора спрайтов (0/1)
2   Выбор режима инкремента адреса при обращении к видеопамяти
    (0 – увеличение на единицу «горизонтальная запись»;
     1 - увеличение на 32 «вертикальная запись»)

1,0 Адрес активной экранной страницы
    (00 – $2000; 01 – $2400; 10 – $2800; 11 - $2C00)
*/

reg [7:0]  CTRL0  = 8'b0_00_00_0_00;

/* 7-5     Яркость экрана/интенсивность цвета в RGB (в Денди не используется)
    4      0 – Спрайты не отображаются; 1 – Спрайты отображаются
    3      0 – Фон не отображается; 1 – Фон отображается
    2      0 – Спрайты невидны в крайнем левом столбце; 1- Все спрайты видны
    1      0 – Рисунок фона невиден в крайнем левом столбце; 1 - Весь фон виден
    0      Тип дисплея: Color/Monochrome (в Денди не используется) */

reg [7:0]  CTRL1  = 8'b000_11_00_0;

/* Адрес спрайта */
reg [7:0]  SPRADR = 8'h0;

/* Буфер VRAM */
reg  [7:0] BUFF = 8'hFF;

/* Nametable по умолчанию */
reg  [1:0] NTA;

/* Текущий Nametable (0/1) */
wire       NTBank = NTA[0] ^ NTA[0] ^ X[8] ^ Y[8] ^ RegH ^ RegV; // HMirror=0 у большинства

reg        RegH = 1'b0;
reg        RegV = 1'b0;
reg  [4:0] RegHT; // Грубый X скроллинг
reg  [4:0] RegVT; // Грубый Y скроллинг
reg  [3:0] RegFH; // Точный скроллинг по X
reg  [3:0] RegFV; // Точный скроллинг по Y

wire [8:0] Xs = PPUX[7:0] + {RegHT[4:0], RegFH[2:0]};
wire [8:0] X  = PPUX >= (341 - 8) ? {RegHT[4:0], 3'b000} : Xs;
wire [8:0] Y  = PPUY[7:0] + {RegVT[4:0], RegFV[2:0]};

/* Четная/Нечетная запись в регистры */
reg        FIRSTW = 1; 

// -----------------------------------------------------------------------------

// Тайминги PPU 341 x 262 линии
// https://wiki.nesdev.com/w/index.php/Clock_rate (NTSC)

always @(posedge CLK25) begin

    /* Сброс регистров таймингов PPU */
    if (x == 0 && y == 0) DE2X <= 1'b0;

    /* Пропуск 64 тактов (25 Mhz), потом 341T по 2T на частоте 25 Мгц */
    /* -16 для того, чтобы PPU успел подготовить данные. 525-я линия Y не используется */
    else if (x > (64 - 16) && x <= (746 - 16)) DE2X <= ~DE2X;

end

/* Тайминг процессора (который в 3 раза медленнее PPU) */
always @(posedge CLKPPU) begin

    case (div)

        2'b00: begin div <= 2'b01; CLKCPU <= 1'b1; end
        2'b01: begin div <= 2'b10; CLKCPU <= 1'b0; end
        2'b10: begin div <= 2'b00; end

    endcase

end

/* Операции с памятью и регистрами (CPU <-> PPU) */
always @(posedge CLKPPU) begin

    // ----------------------
    // Установка NMI, VBlank
    // ----------------------

    /* Установка VBlank=1, NMI=0/1 */
    if (div == 2'b01) begin // PPUX == 1 && 
    
        if (PPUY == 241) begin 

            NMI       <= CTRL0[7];
            VBlankPPU <= VBlankPPU ^ VBlank ^ 1'b1;

        end

        /* Установка VBlank=0, NMI=0 */
        else if (PPUY == 260) begin

            NMI       <= 1'b0;
            VBlankPPU <= VBlankPPU ^ VBlank ^ 1'b0;

        end

    end
        
    // ----------------------
    // Джойстики
    // ----------------------
             
    /*  */
    //16'h4016: if (RD) DOUT <= 8'h00;
    //16'h4017: if (RD) DOUT <= 8'h00;


    // ----------------------
    // Операции с памятью PPU
    // 2000h - 3FFFh
    // ----------------------
    
    if (ea[15:13] == 3'b001) begin

        /* Запись в память только на разрешенных адресах */
        WVREQ   <= (ea[2:0] == 3'h7) && (div == 2'b01) && WREQ && (ADDR >= 16'h2000 && ADDR < 16'h3F00);
       
        case (div)

            /* Запись или чтение */
            2'b01: begin
            
                case (ea[2:0])

                    /* w/o Регистр управления 0 */
                    3'h0: if (WREQ) CTRL0 <= din;

                    /* w/o Регистр управления 1 */
                    3'h1: if (WREQ) CTRL1 <= din;

                    /* r/o Чтение статуса */
                    3'h2: if (RD) begin

                        DOUT <= {
                            VBlank,         /* Генерация синхроимпульса */
                            1'b0,           /* Вывод спрайта ID=0 */
                            1'b0,           /* =1 На линии более 8 спрайтов */
                            (PPUY > 241),   /* Разрешение записи в видеопамять */
                            4'b0000         /* Не используется */
                        };

                        /* Если был 1, перевести в 0, иначе оставить как 0 */
                        VBlankCPU <= VBlankCPU ^ VBlank ^ 1'b0;
                        
                        /* Сбросить Odd/Even */
                        FIRSTW <= 1;

                    end

                    /* w/o Адрес спрайта */
                    3'h3: if (WREQ) SPRADR <= din;

                    /* r/w Операция записи в память спрайтов */
                    // 3'h4

                    /* w/o(2) Установка данных о скроллинге */
                    3'h5: if (WREQ) begin
                    
                        if (FIRSTW) begin                    
                            RegHT <= din[7:3];
                            RegFH <= din[2:0];                    
                        end 
                        else begin                    
                            RegVT <= din[7:3];
                            RegFV <= din[2:0];
                        end

                        FIRSTW <= ~FIRSTW;                    
                    end

                    /* w/o(2) Запись адреса */
                    3'h6: if (WREQ) begin
                                    
                        if (FIRSTW) /* Первый */ begin                    
                            
                            ADDR[15:8] <= din;
                            
                            RegVT <= {din[1:0], RegVT[2:0]};    // = (RegVT & 7) | ((din & 3) << 3);
                            RegH  <= din[2];                    // = (din >> 2) & 1;
                            RegV  <= din[3];                    // = (din >> 3) & 1;
                            RegFV <= din[5:4];                  // = (din >> 4) & 3;
                        
                        end 
                        else /* Второй */ begin
                        
                            RegVT <= {RegVT[4:3], din[7:5]};    // = (regVT & 24) | ((din >> 5) & 7);                        
                            RegHT <=  din[4:0];                 // =  din & 31;
                        
                            ADDR[7:0]  <= din;      
                                          
                        end
                    
                        FIRSTW <= ~FIRSTW;                
                    end

                    /* r/w Запись/чтение данных */
                    3'h7: begin
                        
                        /* Записать данные в память */
                        if (WREQ) begin

                            WADDR <= ADDR;

                            /* Писать можно только в VRAM (исключая палитру) */
                            if (ADDR < 16'h3F00) begin WDATA <= din; end

                            /* Палитра фона */
                            else if (ADDR < 16'h3F10) begin PALBG[ ADDR[3:0] ] <= din[5:0]; end

                            /* Палитра спрайтов */
                            else if (ADDR < 16'h3F20) begin PALSP[ ADDR[3:0] ] <= din[5:0]; end

                        end 
                        /* Прочитать из памяти */
                        else if (RD) begin

                            // Чтение данных
                            if (ADDR < 16'h3F00) begin                            
                                WADDR <= ADDR;
                                DOUT  <= BUFF;
                            end
                            // Читать палитру
                            else if (ADDR < 16'h3F10) begin
                                DOUT <= PALBG[ ADDR[3:0] ];
                            end
                            else if (ADDR < 16'h3F20) begin
                                DOUT <= PALSP[ ADDR[3:0] ];
                            end
                            
                        end

                    end
                   
                endcase

            end

            /* Снять запись в память на этом такте */
            2'b10: begin

                case (ea[2:0])

                    // Инкремент ADDR +1/+32 при чтении или записи
                    3'h7: if (WREQ | RD) begin

                        /* Читать в буфер */
                        if (RD && ADDR < 16'h3F00) begin
                            BUFF <= (ADDR < 16'h2000 ? FIN : VIN);
                        end
                        
                        ADDR <= ADDR + (CTRL0[2] ? 6'h20 : 1'b1);

                    end

                endcase

            end
            
        endcase
        
    end

    else begin
    
        {WVREQ} <= 1'b0;        
    end
end

/* ~ 5,3675 Mhz: PPUX=[0..340], PPUY=[0..261] */
// -----------------------------------------------------------------

always @(posedge DE2X) begin    

    /* Выключен рендеринг */
    /* Либо спрайты, либо фон не отображаются - тогда выключить рендеринг */
    if (CTRL1[4:3] == 2'b00 && 0) begin /* Пока всегда отображать */

        colorpad <= 2'b00;
        colormap <= 16'h0000;

    end

    /* При рендеринге, vaddr / faddr заняты */
    else begin

        /* Прорисовка фона */
        case (X[2:0])

            /* Прочитаем из памяти символ 8x8 */
            3'h0: begin vaddr <= {NTBank, Y[7:3], X[7:3]}; /* 32x30 */ end

            /* Начнем чтение CHR (BA=0, CHR=00000000, B=0, Y=000} */
            3'h1: begin faddr <= {CTRL0[4], vdata[7:0], 1'b0, Y[2:0]}; end

            /* Чтение верхней палитры знакогенератора, а также дополнительной ATTR */
            3'h2: begin faddr <= {CTRL0[4], vdata[7:0], 1'b1, Y[2:0]}; 
                        vaddr <= {NTBank, 4'b1111, Y[7:5], X[7:5] }; 
                        chrl  <= fdata; end

            /* Палитра прочитана */
            3'h3: begin hiclr <= vdata; chrh <= fdata; end

            // 4,5,6 -- поиск спрайтов на будущий сканлайн

            /* Результат */
            3'h7: begin
            
                /* Старшие цвета пикселей */
                colorpad <= {hiclr[ {Y[4], X[4], 1'b1} ],  /* 7|5|3|1 */
                             hiclr[ {Y[4], X[4], 1'b0} ]}; /* 6|4|2|0 */

                /* Нижние цвета пикселей */
                colormap <= {/* BIT 7 */ chrh[0], chrl[0], /* BIT 6 */ chrh[1], chrl[1],
                             /* BIT 5 */ chrh[2], chrl[2], /* BIT 4 */ chrh[3], chrl[3],
                             /* BIT 3 */ chrh[4], chrl[4], /* BIT 2 */ chrh[5], chrl[5],
                             /* BIT 1 */ chrh[6], chrl[6], /* BIT 0 */ chrh[7], chrl[7]};
            end

        endcase

    end

    // -----------------------------------------------------------------

    // 525-й такт, не используемый в NES
    if (y == vert_whole - 1) begin
    
        NTA  <= 2'b00; /* Сброс NameTable по умолчанию */
        PPUY <= 1'b0;
        
    end

    // Конец сканлайна (341 пиксель)
    else if (PPUX == 9'd340) begin

        PPUX <= 1'b0;
        DE2Y <= ~DE2Y;
        
        /* @todo Переписать счетчики, адреса страниц, скроллинг в новые регистры */
        
        // Установить новый NameTable по умолчанию для следующей линии
        NTA  <= {1'b0, CTRL0[0]};

        /* Второй сканлайн НЕ учитывается. При достижении 261-го, сбросить до 0 */
        if (DE2Y) PPUY <= PPUY + 1'b1;

    end else begin

        PPUX <= PPUX + 1'b1;

    end

end

// Частота видеоадаптера VGA 25 Mhz
always @(posedge CLK25) begin

    // аналогично этой конструции на C
    x <= x == (horiz_whole - 1) ? 1'b0 : (x + 1'b1);

    // Когда достигаем конца горизонтальной линии, переходим к Y+1
    if (x == (horiz_whole - 1)) begin
        y <= y == (vert_whole - 1) ? 1'b0 : (y + 1'b1);
    end

    if (x < horiz_visible && y < vert_visible)
         {red, green, blue} <= {rgb[4:0], rgb[10:5], rgb[15:11]};
    else {red, green, blue} <= 16'h0000;

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
