module cpu(

    /* Стандартные входы-выходы */
    input   wire        clk,        // 100 мегагерц
    input   wire        clk25,      // 25 мегагерц
    input   wire [7:0]  i,          // Data In (16 бит)
    output  reg  [7:0]  o,          // Data Out,
    output  wire [15:0] a,          // Address 32 bit
    output  reg         w           // Запись [o] на HIGH уровне wm

);

`define SM_INITIAL      0       // Исходное положение
`define SM_MODRM        1       // Фаза декодирования ModRM байта
`define SM_EXEC         2       // Исполнение инструкции
`define SM_EXEC_2       3

/* Описатели процедур */
`define SUB_NORMAL      0       // Нормальное исполнение кода
`define SUB_WRITE_MEM   1       // Процедура записи WReg/CBit в [ea]
`define SUB_WRITE_MEM2  2

// Указатель на код или данные
assign a = sw ? ea : ip;

initial begin o = 8'h00; w = 1'b0; end

// Состояние процессора
// ---------------------------------------------------------------------
reg [3:0]  m  = 1'b0;           /* Текущее машинное состояние */
reg        sw = 1'b0;           /* Переключение на альтернативный адрес */
reg [15:0] ea = 16'h0000;       /* Альтернативный/эффективный адрес */
reg [ 7:0] opcode = 8'h00;      /* Принятый опкод */
reg [ 7:0] modrm  = 8'h00;      /* Принятый байт ModRM */
reg [ 2:0] modrm_stage = 1'b0;  /* Стадия разбора ModRM */
reg [ 4:0] routine = 1'b0;      /* Микроисполнение процедур */
reg [ 2:0] micro = 1'b0;        /* Микрокод */

// Набор регистров
// ---------------------------------------------------------------------
reg [2:0]  CReg = 3'b000;   /* Выбор регистра */
reg [2:0]  CAlu = 3'b000;   /* Номер режима АЛУ */
reg        CBit = 1'b0;     /* Выбор битности */
reg [15:0] DReg;            /* Результат выборки */
reg [15:0] WReg = 1'b0;     /* Для записи в регистр */
reg        WR   = 1'b0;     /* Разрешение записи в регистр */

reg [15:0] op1 = 1'b0;      /* Операнд 1: Destination */
reg [15:0] op2 = 1'b0;      /* Операнд 2: Source */

/* Регистры процессора */
reg [15:0] ax    = 16'h0605;
reg [15:0] cx    = 16'h1245;
reg [15:0] dx    = 16'h64EA;
reg [15:0] bx    = 16'hE004;
reg [15:0] sp    = 16'h0000;
reg [15:0] bp    = 16'h0000;
reg [15:0] si    = 16'h1234;
reg [15:0] di    = 16'h0000;
reg [11:0] flags = 12'b0000_0000_0000;
reg [15:0] ip    = 16'hFFF0;

/* Текущий регистр: DReg = GetValue(CReg, CBit) */
always @* begin
    case (CReg)
        3'h0: DReg = CBit ? ax : {8'h00, ax[7:0]};
        3'h1: DReg = CBit ? cx : {8'h00, cx[7:0]};
        3'h2: DReg = CBit ? dx : {8'h00, dx[7:0]};
        3'h3: DReg = CBit ? bx : {8'h00, bx[7:0]};
        3'h4: DReg = CBit ? sp : {8'h00, ax[15:8]};
        3'h5: DReg = CBit ? bp : {8'h00, cx[15:8]};
        3'h6: DReg = CBit ? si : {8'h00, dx[15:8]};
        3'h7: DReg = CBit ? di : {8'h00, bx[15:8]};
    endcase
end

/* Запись результа на обратном фронте в регистр */
always @(negedge clk25) if (WR)
case (CReg)
    3'h0: if (CBit) ax <= WReg; else ax[7:0] <= WReg[7:0];
    3'h1: if (CBit) cx <= WReg; else cx[7:0] <= WReg[7:0];
    3'h2: if (CBit) dx <= WReg; else dx[7:0] <= WReg[7:0];
    3'h3: if (CBit) bx <= WReg; else bx[7:0] <= WReg[7:0];
    3'h4: if (CBit) sp <= WReg; else ax[15:8] <= WReg[7:0];
    3'h5: if (CBit) bp <= WReg; else cx[15:8] <= WReg[7:0];
    3'h6: if (CBit) si <= WReg; else dx[15:8] <= WReg[7:0];
    3'h7: if (CBit) di <= WReg; else bx[15:8] <= WReg[7:0];
endcase

// ---------------------------------------------------------------------
// Арифметико-логическое устройство (стандартное)
// ---------------------------------------------------------------------

reg [16:0] Ar;   /* Результат исполнения АЛУ */
reg [11:0] Af;   /* Флаги */

// Некоторые флаги АЛУ
wire Zero8  = Ar[7:0] == 8'h00;
wire Zero16 = Ar[15:8] == 8'h00 && Zero8;
wire Sign8  = Ar[7];
wire Sign16 = Ar[15];
wire Parity = Ar[0]^Ar[1]^Ar[2]^Ar[3]^Ar[4]^Ar[5]^Ar[6]^Ar[7]^1'b1;

/* Специальный случай: переполнение ADD/SUB */
wire ADD_Overflow8  = (op1[7]  ^ op2[7]  ^ 1'b1) & (op2[7]  ^ Ar[7]);
wire ADD_Overflow16 = (op1[15] ^ op2[15] ^ 1'b1) & (op2[15] ^ Ar[15]);
wire SUB_Overflow8  = (op1[7]  ^ op2[7]        ) & (op2[7]  ^ Ar[7]);
wire SUB_Overflow16 = (op1[15] ^ op2[15]       ) & (op2[15] ^ Ar[15]);

always @* begin

    case (CAlu)
    
        /* ADD */  3'h0: Ar = op1 + op2;
        /* OR  */  3'h1: Ar = op1 | op2;
        /* ADC */  3'h2: Ar = op1 + op2 + flags[0];
        /* SBB */  3'h3: Ar = op1 - op2 - flags[0];
        /* AND */  3'h4: Ar = op1 & op2;
        /* SUB */  3'h5: Ar = op1 - op2;
        /* XOR */  3'h6: Ar = op1 ^ op2;
        /* CMP */  3'h7: Ar = op1 - op2;
        
    endcase
    
    case (CAlu)
    
        /* ADD, ADC */
        3'h0, 3'h2: 
            Af = {
                /* 11 OF */ CBit ? ADD_Overflow16 : ADD_Overflow8,
                /* 10 DF */ flags[10],
                /*  9 IF */ flags[9], 
                /*  8 TF */ flags[8],
                /*  7 SF */ CBit ? Sign16 : Sign8,
                /*  6 ZF */ CBit ? Zero16 : Zero8,
                /*  5  - */ 1'b0,
                /*  4 AF */ op1[3:0] + op2[3:0] + (CAlu == 3'h2 /* ADC */ ? flags[0] : 1'b0) > 4'hF,
                /*  3  - */ 1'b0,
                /*  2 PF */ Parity,
                /*  1  - */ 1'b1,
                /*  0 CF */ CBit ? Ar[16] : Ar[8]
            };
            
        /* SBB, SUB, CMP */
        3'h3, 3'h5, 3'h7:
            Af = {
                /* 11 OF */ CBit ? SUB_Overflow16 : SUB_Overflow8,
                /* 10 DF */ flags[10],
                /*  9 IF */ flags[9], 
                /*  8 TF */ flags[8],
                /*  7 SF */ CBit ? Sign16 : Sign8,
                /*  6 ZF */ CBit ? Zero16 : Zero8,
                /*  5  - */ 1'b0,
                /*  4 AF */ op1[3:0] < op2[3:0] + (CAlu == 3'h3 /* SBB */ ? flags[0] : 1'b0),
                /*  3  - */ 1'b0,
                /*  2 PF */ Parity,
                /*  1  - */ 1'b1,
                /*  0 CF */ CBit ? Ar[16] : Ar[8]
            };
        
        /* OR, XOR, AND */
        default: 
            Af = {
                /* 11 OF */ 1'b0,
                /* 10 DF */ flags[10],
                /*  9 IF */ flags[9], 
                /*  8 TF */ flags[8],
                /*  7 SF */ CBit ? Sign16 : Sign8,
                /*  6 ZF */ CBit ? Zero16 : Zero8,
                /*  5  - */ 1'b0,
                /*  4 AF */ Ar[4], /* Undefined */
                /*  3  - */ 1'b0,
                /*  2 PF */ Parity,
                /*  1  - */ 1'b1,
                /*  0 CF */ 1'b0
            };
    
    endcase

end

// ---------------------------------------------------------------------
// Главные такты
// ---------------------------------------------------------------------

always @(posedge clk25) begin

    /* Микропроцедуры */
    case (routine)

        /* Запись WReg (битность CBit) в память [ea]. После записи CBit=0 */
        `SUB_WRITE_MEM:  begin o <= WReg[7:0]; w <= 1'b1; routine <= `SUB_WRITE_MEM2; end
        `SUB_WRITE_MEM2: begin 
        
            routine <= CBit? `SUB_WRITE_MEM2 : `SUB_NORMAL; 
            o    <= WReg[15:8]; 
            ea   <= ea + 1'b1;
            w    <= CBit; /* Включить запись, если 16 бит, либо выключить */
            sw   <= CBit; /* Отключить указатель на EA если достигли 8 бит записи */
            CBit <= 1'b0;

        end
    
        /* Нормальное исполнение кода */
        default: begin

            case (m)

                /* Декодер, распределение */
                `SM_INITIAL: begin

                    opcode      <= i;
                    micro       <= 1'b0;
                    modrm_stage <= 1'b0;
                    WR          <= 1'b0; /* Сброс записи в регистр на обратном фронте */

                    casex (i)

                        /* Выбор режима АЛУ и сканирование байта ModRM */
                        8'b00_xxx_0xx: begin

                            CAlu <= i[5:3];
                            m    <= `SM_MODRM;

                        end
                        
                        /* АЛУ AL/AX + Immediate */
                        8'b00_xxx_10x: begin
                        
                            CReg <= 3'h0;   /* AL или AX */
                            CAlu <= i[5:3]; /* Режим АЛУ */
                            CBit <= i[0];
                            m    <= `SM_EXEC;
                        
                        end

                        /* Групповые АЛУ инструкции (и другие) */
                        8'b10_00x_xxx,
                        
                        /* Сдвиговые инструкции */
                        8'b11_010_0xx,
                        
                        /* LES, MOV */
                        8'b11_001_1xx: m <= `SM_MODRM;

                        /* Все другие опкоды - на исполнение */
                        default: m <= `SM_EXEC;

                    endcase

                    /* К следующей инструкции */
                    ip <= ip + 1'b1;

                end

                /* Разбор байта ModRM */
                `SM_MODRM: case (modrm_stage)

                    /* Стадия 1: Считывание байта */
                    3'h0: begin

                        /* Пишем на будущее */
                        modrm <= i;

                        /* Разбор указателя на память (16 бит) */
                        case (i[2:0])
                            3'h0: ea <= bx + si;
                            3'h1: ea <= bx + di;
                            3'h2: ea <= bp + si;
                            3'h3: ea <= bp + di;
                            3'h4: ea <= si;
                            3'h5: ea <= di;
                            3'h6: ea <= (i[7:6] == 2'b00) ? 16'h0000 : bp;
                            3'h7: ea <= bx;
                        endcase

                        /* (@todo) Здесь должен быть сегмент, но его нет пока */

                        /* Начинаем считывать регистр */
                        CBit <= opcode[0];
                        CReg <= i[5:3];

                        /* Переключимся сразу на память, если mod = 00 и rm != 6 */
                        sw <= (i[7:6] == 2'b00) && (i[2:0] != 3'h6);

                        /* Перейти к следующему байту */
                        ip <= ip + 1'b1;

                        /* К следующему шагу */
                        modrm_stage <= 3'h1;

                    end

                    /* Считывание регистра, либо, возможно, данных из памяти */
                    3'h1: begin

                        /* В зависимости от выбранного D (направления), пишется операнд из регистра (8/16 bit) */
                        op1 <= opcode[1] ? DReg : i;
                        op2 <= opcode[1] ? i : DReg;

                        /* В случае, если регистр выбран как операнд, а не память */
                        CReg <= modrm[2:0];

                        /* Решение, что делать дальше */
                        case (modrm[7:6])

                            /* Либо завершить чтение из памяти, либо переход к disp16 */
                            2'b00: begin

                                /* Либо прочитать 16-битный disp16 */
                                if (modrm[2:0] == 3'h6) begin ip <= ip + 1'b1; ea[7:0] <= i; modrm_stage <= 3'h3; end

                                /* 16-битный операнд: читать старшие 8 бит */
                                else if (opcode[0]) begin ea <= ea + 1'b1; modrm_stage <= 3'h5; end

                                /* Либо перейти к исполнению */
                                else begin m <= `SM_EXEC; end

                            end

                            /* Disp8: Знаковое расширение 8 до 16 бит. Переход к считыванию данных в операнд */
                            2'b01: begin modrm_stage <= 3'h4; ip <= ip + 1'b1; ea <= ea + {{8{i[7]}}, i[7:0]}; sw <= 1'b1; end

                            /* Disp16: Прибавить нижние 8 бит, и переход к чтению 16 битной части */
                            2'b10: begin modrm_stage <= 3'h3; ip <= ip + 1'b1; ea <= ea + {8'h00, i[7:0]}; end

                            /* Прочитать регистр вместо памяти, и выйти к исполнению */
                            2'b11: begin modrm_stage <= 3'h2; end

                        endcase

                    end

                    /* Считывание второго регистра из modrm и переход к исполнению */
                    3'h2: begin

                        op1 <= opcode[1] ? op1 : DReg;
                        op2 <= opcode[1] ? DReg : op2;
                        m <= `SM_EXEC;

                    end

                    /* Прочитать +disp16 */
                    3'h3: begin

                       ea[15:8] <= ea[15:8] + i;
                       ip <= ip + 1'b1;
                       sw <= 1'b1;
                       modrm_stage <= 3'h4;

                    end

                    /* Считывание 8 или 16 бит из [ea] */
                    3'h4: begin

                        /* Нижние 8 бит читать всегда */
                        op1 <= opcode[1] ? op1 : i;
                        op2 <= opcode[1] ? i : op2;

                        /* Есть 16 бит? Прочесть их */
                        if (opcode[0]) begin modrm_stage <= 3'h5; ea <= ea + 1'b1; end

                        /* Либо перейти к исполнению */
                        else m <= `SM_EXEC;

                    end

                    /* Читать старшие 8 бит */
                    3'h5: begin

                        op1[15:8] <= opcode[1] ? op1[15:8] : i;
                        op2[15:8] <= opcode[1] ? i : op2[15:8];

                        /* Вернуть ea, чтобы знать, куда их писать обратно */
                        ea <= ea - 1'b1;
                        m <= `SM_EXEC;

                    end

                endcase

                /* Исполнение инструкции */
                `SM_EXEC: casex (opcode)

                    /* Инструкции АЛУ ModRM */
                    8'b00_xxx_0xx: begin

                        /* Не должно быть CMP */
                        if (CAlu < 3'h7) begin

                            CBit <= opcode[0];  /* Битность */
                            WReg <= Ar;         /* Данные для записи */
                        
                            /* (1) Пишем в регистр, 
                               (2) Уже был выбран регистр */

                            if (modrm[7:6] == 2'b11 || opcode[1]) begin

                                WR   <= 1'b1;
                                CReg <= opcode[1] ? modrm[5:3] : modrm[2:0];

                            end

                            /* Иначе запись в память [ea] */
                            else routine <= `SUB_WRITE_MEM;                        
                            
                        end
                        
                        flags <= Af;
                        m <= `SM_INITIAL; /* Возврат обратно */
                    
                    end

                    /* <ALU> al/ax, i8/i16 */
                    8'b00_xxx_10x: begin
                    
                        case (micro)
                        
                            /* Загрузка операнда в АЛУ */
                            3'h0: begin 
                            
                                micro <= 3'h1; 
                                op1   <= DReg;      /* Загрузить AL/AX */
                                op2   <= i;         /* Загрузить нижние 8 бит */
                                ip    <= ip + 1'b1; 
                                
                            end
                            
                            /* Расчет 8 бит */
                            3'h1: begin 
                            
                                micro <= 3'h2;                                
                                WR    <= 1'b1;              /* Запись в регистр результата */
                                WReg  <= Ar;                /* На запись 8/16 бит */
                                ip    <= ip + opcode[0];    /* IP+0, если записывали БАЙТ */                                
                                flags <= Af;                                
                                                                
                                if (~CBit) m <= `SM_INITIAL; /* Если 8 бит, перейти к сканированию снова */                                
                                op2[15:8] <= i;              /* Подготовка 16-битного операнда */
                                
                            end
                            
                            /* Расчет 16 бит */
                            3'h2: begin
                            
                                WReg  <= Ar;
                                flags <= Af;   
                                m     <= `SM_INITIAL;

                            end
                            
                        endcase

                    end

                endcase

            endcase
            
        end
    
    endcase

end

endmodule
