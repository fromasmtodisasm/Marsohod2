module cpu(

    input   wire        clk,            // 100 Mhz
    input   wire        lock,           // Memory Locked?
    output  wire [19:0] o_addr,         // Адрес на чтение, 1 Мб
    input   wire [7:0]  i_data,         // Входящие данные
    output  reg  [7:0]  o_data,         // Исходящие данные
    output  reg         o_write         // Запрос на запись

);

// ---------------------------------------------------------------------
`define OPCODE_DECODER      3'h0
`define MODRM_DECODE        3'h1
`define OPCODE_EXEC         3'h2
// ---------------------------------------------------------------------
`define CARRY               0
`define PARITY              2
`define AUX                 4
`define ZERO                6
`define SIGN                7
`define TRAP                8
`define INTERRUPT           9
`define DIRECTION           10
`define OVERFLOW            11
// ---------------------------------------------------------------------

assign o_addr = memory? {ms, 4'b000} + ma : {cs, 4'b000} + ip;

// ---------------------------------------------------------------------
// Все регистры - сегментные, флаги, ip
reg [15:0] ax; reg [15:0] cx; reg [15:0] dx; reg [15:0] bx;
reg [15:0] sp; reg [15:0] bp; reg [15:0] si; reg [15:0] di;
reg [15:0] es; reg [15:0] cs; reg [15:0] ss; reg [15:0] ds;
reg [15:0] ip; reg [11:0] fl;

// Инициализируем
initial begin

    ax = 16'h1041; bx = 16'h0001; cx = 16'h0000; dx = 16'h0000;
    sp = 16'h0004; bp = 16'h5000; si = 16'h0010; di = 16'h0020;
    es = 16'h2377; cs = 16'hFC00; ss = 16'h0040; ds = 16'h0000;
    ip = 16'h0000;
    //       ODITSZ-A-P-C
    fl = 12'b000000000000;

    o_write = 1'b0;
    o_data  = 8'h00;

end
// ---------------------------------------------------------------------

// Машинное состояния. Это не микрокод.
reg [2:0]   m = 3'b0;
reg [2:0]   mcode = 1'b0;
reg [2:0]   modm_stage = 1'b0;
reg [7:0]   modrm = 8'h00;
reg [7:0]   opcode = 8'h00;

// wide =0 (byte), =1 (word)
reg         wide = 1'b0;

// =0 rm, reg
// =1 reg, rm
reg         direct = 1'b0;
reg [15:0]  op1 = 1'b0;
reg [15:0]  op2 = 1'b0;
reg [ 7:0]  hibyte = 1'b0;

// режим АЛУ
reg [2:0]   alu;
reg [16:0]  result;
reg [11:0]  rflags;

// Используется для указателя на память [mm_seg : mm_addr]
reg         memory = 1'b0;
reg [15:0]  ms = 1'b0;
reg [15:0]  ma = 1'b0;

// При сканировании опкода, если попался префикс, то он записывается сюда
reg [1:0]   prefix_id = 2'b00;

// Если равен 1, значит, инструкция имеет префикс
reg         prefix     = 1'b0;
reg         prefix_tmp = 1'b0;

always @(posedge clk) begin

    // Декодирование опкода либо полное/частичное исполнение
    if (m == `OPCODE_DECODER) begin

        // Стадия декодера ModRM
        modm_stage  <= 1'b0;
        opcode      <= i_data;
        mcode       <= 1'b0;

        // Декодирование префиксов    
        casex (i_data)

            // 26, 2e, 36, 3e (es: cs: ss: ds:)
            8'b001x_x110: begin

                prefix_tmp <= 1'b1;
                prefix_id  <= i_data[4:3];

            end

            // Это реальный опкод, удаляем временные префиксы, перенося
            // данные о наличии префикса далее, в саму инструкцию

            default: begin

                prefix     <= prefix_tmp;
                prefix_tmp <= 1'b0;

            end

        endcase

        // Декодер реальных опкодов
        casex (i_data)

            // <ALU> ModRM
            8'b00xx_x0xx: begin

                m       <= `MODRM_DECODE;
                wide    <= i_data[0];
                direct  <= i_data[1];
                alu     <= opcode[5:3];

            end

            // <ALU> al/ax, i8/16
            8'b00xx_x10x: begin

                m       <= `OPCODE_EXEC;
                alu     <= opcode[5:3];
                op1     <= i_data[0] ? ax : ax[7:0];

            end

            // PUSH seg | r16
            8'b000x_x110,
            8'b0101_0xxx: begin

                m       <= `OPCODE_EXEC;
                ms      <= ss;
                ma      <= sp - 2'h2;
                sp      <= sp - 2'h2;
                memory  <= 1'b1;
                o_write <= 1'b1;
                
                if (i_data[6])
                
                    case (i_data[2:0])
                    
                        3'b000: begin o_data <= ax[7:0]; hibyte <= ax[15:8]; end
                        3'b001: begin o_data <= cx[7:0]; hibyte <= cx[15:8]; end
                        3'b010: begin o_data <= dx[7:0]; hibyte <= dx[15:8]; end
                        3'b011: begin o_data <= bx[7:0]; hibyte <= bx[15:8]; end
                        3'b100: begin o_data <= sp[7:0]; hibyte <= sp[15:8]; end
                        3'b101: begin o_data <= bp[7:0]; hibyte <= bp[15:8]; end
                        3'b110: begin o_data <= si[7:0]; hibyte <= si[15:8]; end
                        3'b111: begin o_data <= di[7:0]; hibyte <= di[15:8]; end
                    
                    endcase
                    
                else

                    case (i_data[4:3])

                        2'b00: begin o_data <= es[7:0]; hibyte <= es[15:8]; end
                        2'b01: begin o_data <= cs[7:0]; hibyte <= cs[15:8]; end
                        2'b10: begin o_data <= ss[7:0]; hibyte <= ss[15:8]; end
                        2'b11: begin o_data <= ds[7:0]; hibyte <= ds[15:8]; end

                    endcase

            end

            // POP seg | r16
            8'b000x_x111,
            8'b0101_1xxx: begin

                m       <= `OPCODE_EXEC;
                ms      <= ss;
                ma      <= sp;
                sp      <= sp + 2'h2;
                memory  <= 1'b1;

            end

            // INC/DEC r16
            8'b0100_xxxx: begin
            
                case (i_data[2:0])
                
                    3'b000: op1 <= i_data[3] ? ax - 1'b1 : ax + 1'b1;
                    3'b001: op1 <= i_data[3] ? cx - 1'b1 : cx + 1'b1;
                    3'b010: op1 <= i_data[3] ? dx - 1'b1 : dx + 1'b1;
                    3'b011: op1 <= i_data[3] ? bx - 1'b1 : bp + 1'b1;
                    3'b100: op1 <= i_data[3] ? sp - 1'b1 : sp + 1'b1;
                    3'b101: op1 <= i_data[3] ? bp - 1'b1 : bp + 1'b1;
                    3'b110: op1 <= i_data[3] ? si - 1'b1 : si + 1'b1;
                    3'b111: op1 <= i_data[3] ? di - 1'b1 : di + 1'b1;

                endcase

                m <= `OPCODE_EXEC;
            
            end            

        endcase

        ip <= ip + 1'b1;

    end

    // Декодирование байта ModRM
    else if (m == `MODRM_DECODE) begin

        case (modm_stage)

            2'h0: begin

                modrm   <= i_data;
                ip      <= ip + 1'b1;

                // Операнд 1
                case (direct ? i_data[5:3] : i_data[2:0])

                    3'b000: op1 <= wide ? ax : ax[ 7:0];
                    3'b001: op1 <= wide ? cx : cx[ 7:0];
                    3'b010: op1 <= wide ? dx : dx[ 7:0];
                    3'b011: op1 <= wide ? bx : bx[ 7:0];
                    3'b100: op1 <= wide ? sp : ax[15:8];
                    3'b101: op1 <= wide ? bp : cx[15:8];
                    3'b110: op1 <= wide ? si : dx[15:8];
                    3'b111: op1 <= wide ? di : bx[15:8];

                endcase

                // Операнд 2
                case (direct ? i_data[2:0] : i_data[5:3])

                    3'b000: op2 <= wide ? ax : ax[ 7:0];
                    3'b001: op2 <= wide ? cx : cx[ 7:0];
                    3'b010: op2 <= wide ? dx : dx[ 7:0];
                    3'b011: op2 <= wide ? bx : bx[ 7:0];
                    3'b100: op2 <= wide ? sp : ax[15:8];
                    3'b101: op2 <= wide ? bp : cx[15:8];
                    3'b110: op2 <= wide ? si : dx[15:8];
                    3'b111: op2 <= wide ? di : bx[15:8];

                endcase

                // ----------
                // Определение, какой сегмент будет загружен
                // ----------

                // сегмент перегружен префиксом
                if (prefix) case (prefix_id)
                    2'b00: ms <= es;
                    2'b01: ms <= cs;
                    2'b10: ms <= ss;
                    2'b11: ms <= ds;
                endcase
                // если выбран b010 [bp+si] или b011 [bp+di]
                else if (i_data[2:1] == 2'b01) ms <= ss;
                // если выбран b110, то ss: применяется только к mod <> 2'b00
                else if (i_data[2:0] == 3'b110) ms <= (i_data[7:6] == 2'b00 ? ds : ss);
                // все остальные по умолчанию ds:
                else ms <= ds;

                // ----------
                // Выборка смещения
                // ----------

                case (i_data[2:0])

                    3'b000: ma <= bx + si;
                    3'b001: ma <= bx + di;
                    3'b010: ma <= bp + si;
                    3'b011: ma <= bp + di;
                    3'b100: ma <= si;
                    3'b101: ma <= di;
                    // тут +disp16
                    3'b110: ma <= i_data[7:6] == 2'b00 ? 1'b0 : bp;
                    3'b111: ma <= bx;

                endcase

                // Выбран регистр -> фаза выполнения опкода
                if (i_data[7:6] == 2'b11) begin

                    m <= `OPCODE_EXEC;

                // Указатель на память
                end else begin

                    modm_stage <= 2'h1;

                    // чтение из памяти на след. такте возможно (mod=00 и r/m != b110)
                    if (i_data[7:6] == 2'b00 && i_data[2:0] !== 3'b110)
                        memory <= 1'b1;

                end

            end

            2'h1: begin

                modm_stage <= 2'h2;

                case (modrm[7:6])

                    2'b00: begin

                        // Это чистый disp16
                        if (modrm[2:0] == 3'b110) begin

                            ip <= ip + 1'b1;
                            ma[7:0] <= i_data;

                        // чтение данных из памяти
                        end else begin

                            if (direct) op2 <= i_data; else op1 <= i_data;
                            if (wide == 1'b0) m <= `OPCODE_EXEC; else ma <= ma + 1'b1;

                        end

                    end

                    // +disp8
                    2'b01: begin

                        ip <= ip + 1'b1;
                        ma <= ma + {{8{i_data[7]}}, i_data[7:0]};
                        memory <= 1'b1;

                    end

                    // +disp16
                    2'b10: begin

                        ip <= ip + 1'b1;
                        ma <= ma + {8'h00, i_data[7:0]};

                    end

                endcase

            end

            2'h2: begin

                modm_stage <= 2'h3;

                case (modrm[7:6])

                    2'b00: begin

                        // к чтению из памяти (1 или 2 байта)
                        if (modrm[2:0] == 3'b110) begin

                            ip <= ip + 1'b1;
                            ma[15:8] <= i_data;
                            memory <= 1'b1;

                        // старший байт читается из памяти и переход к исполнению
                        end else begin

                            m <= `OPCODE_EXEC;
                            if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;
                            ma <= ma - 1'b1;

                        end

                    end

                    // чтение младшего байта (и переход к исполнению)
                    2'b01: begin

                        if (direct) op2 <= i_data; else op1 <= i_data;
                        if (wide == 1'b0) m <= `OPCODE_EXEC; else ma <= ma + 1'b1;

                    end

                    // +disp16
                    2'b10: begin

                        ip <= ip + 1'b1;
                        ma[15:8] <= ma[15:8] + i_data;
                        memory <= 1'b1;

                    end

                endcase

            end

            2'h3: begin

                modm_stage <= 3'h4;

                case (modrm[7:6])

                    // чтение lo-байта
                    2'b00, 2'b10: begin

                        if (direct) op2 <= i_data; else op1 <= i_data;
                        if (wide == 1'b0) m <= `OPCODE_EXEC; else ma <= ma + 1'b1;

                    end

                    // завершение чтения hi-байта
                    2'b01: begin

                        m <= `OPCODE_EXEC;
                        ma <= ma - 1'b1;
                        if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;

                    end

                endcase

            end

            3'h4: begin

                if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;
                ma <= ma - 1'b1;
                m <= `OPCODE_EXEC;

            end

        endcase

    end

    // Исполнение инструкции
    else if (m == `OPCODE_EXEC) begin

        casex (opcode)

            // <ALU> ModRM
            8'b00xx_x0xx: begin

                case (mcode)

                3'h0: begin

                    fl <= rflags;

                    /* CMP не сохраняется */
                    if (alu != 3'b111) begin

                        // reg, r/m; r/m = reg --> сохранить в регистр
                        if (direct | (!direct & modrm[7:6] == 2'b11)) begin

                            case (direct ? modrm[5:3] : modrm[2:0])

                                3'b000: if (wide) ax <= result[15:0]; else ax[ 7:0] <= result[7:0];
                                3'b001: if (wide) cx <= result[15:0]; else cx[ 7:0] <= result[7:0];
                                3'b010: if (wide) dx <= result[15:0]; else dx[ 7:0] <= result[7:0];
                                3'b011: if (wide) bx <= result[15:0]; else bx[ 7:0] <= result[7:0];
                                3'b100: if (wide) sp <= result[15:0]; else ax[15:8] <= result[7:0];
                                3'b101: if (wide) bp <= result[15:0]; else cx[15:8] <= result[7:0];
                                3'b110: if (wide) si <= result[15:0]; else dx[15:8] <= result[7:0];
                                3'b111: if (wide) di <= result[15:0]; else bx[15:8] <= result[7:0];

                            endcase

                            memory <= 1'b0;
                            m <= `OPCODE_DECODER;

                        end

                        // Сохранить в память
                        else begin

                            o_data  <= result[ 7:0];
                            hibyte  <= result[15:8];
                            mcode   <= wide ? 3'h1 : 3'h2;
                            o_write <= 1'b1;

                        end

                    // Переход к получению следующего опкода
                    end else begin

                        memory <= 1'b0;
                        m <= `OPCODE_DECODER;

                    end
                end

                // Запись результатов
                3'h1: begin mcode <= 3'h2; o_data <= hibyte; ma <= ma + 1'b1; end
                3'h2: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

                endcase

            end

            // <ALU> al/ax, i8/16
            8'b00xx_x10x: begin

                case (mcode)

                // imm8
                3'h0: begin

                    ip      <= ip + 1'b1;
                    op2     <= i_data;
                    mcode   <= opcode[0] ? 3'h1 : 3'h2;

                end

                // imm16
                3'h1: begin

                    ip        <= ip + 1'b1;
                    op2[15:8] <= i_data;
                    mcode     <= 3'h2;

                end

                // Запись результата
                3'h2: begin

                    m <= `OPCODE_DECODER;

                    // CMP не писать в регистр
                    if (alu != 3'b111) begin
                        if (opcode[0])
                            ax[15:0] <= result;
                        else
                            ax[7:0] <= result[7:0];
                    end

                    fl <= rflags;

                end

                endcase

            end

            // PUSH seg | r16
            8'b000x_x110,
            8'b0101_0xxx: case (mcode)

                4'h0: begin ma <= ma + 1'b1; o_data <= hibyte; mcode <= 4'h1; end
                4'h1: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

            endcase

            // POP seg
            8'b000x_x111,
            8'b0101_1xxx: case (mcode)

                /* LO */ 4'h0: begin
                
                    if (opcode[6])
                        case (opcode[2:0])
                            3'b000: ax[7:0] <= i_data;
                            3'b001: cx[7:0] <= i_data;
                            3'b010: dx[7:0] <= i_data;
                            3'b011: bx[7:0] <= i_data;
                            3'b100: sp[7:0] <= i_data;
                            3'b101: bp[7:0] <= i_data;
                            3'b110: si[7:0] <= i_data;
                            3'b111: di[7:0] <= i_data;
                        endcase
                    else
                        case (opcode[4:3])
                            2'b00: es[7:0] <= i_data;
                            2'b10: ss[7:0] <= i_data;
                            2'b11: ds[7:0] <= i_data;
                        endcase

                    ma    <= ma + 1'b1;
                    mcode <= 1'b1;

                end

                /* HI */ 4'h1: begin

                    if (opcode[6])
                        case (opcode[2:0])
                            3'b000: ax[15:8] <= i_data;
                            3'b001: cx[15:8] <= i_data;
                            3'b010: dx[15:8] <= i_data;
                            3'b011: bx[15:8] <= i_data;
                            3'b100: sp[15:8] <= i_data;
                            3'b101: bp[15:8] <= i_data;
                            3'b110: si[15:8] <= i_data;
                            3'b111: di[15:8] <= i_data;
                        endcase
                    else
                    case (opcode[4:3])
                        2'b00: es[15:8] <= i_data;
                        2'b10: ss[15:8] <= i_data;
                        2'b11: ds[15:8] <= i_data;
                    endcase

                    memory <= 1'b1;
                    m <= `OPCODE_DECODER;

                end

            endcase

            // INC/DEC r16
            8'b0100_xxxx: begin
            
                fl <= {
                    /* OF */ opcode[3] ? op1 == 8'h7f : op1 == 8'h80,
                    /* DF */ fl[10],
                    /* IF */ fl[9],
                    /* TF */ fl[8],
                    /* SF */ op1[15],
                    /* ZF */ op1 == 1'b0,
                    /*    */ 1'b0,
                    /* AF */ opcode[3] ? op1[3:0] == 4'hF : op1[3:0] == 4'h0,
                    /*    */ 1'b0,
                    /* PF */ op1[0] ^ op1[1] ^ op1[2] ^ op1[3] ^ op1[4] ^ op1[5] ^ op1[6] ^ op1[7] ^ 1'b1,
                    /*    */ 1'b1,
                    /* CF */ opcode[3] ? op1 == 16'hffff : op1 == 16'h0000
                };
                
                case (opcode[2:0])
                
                    3'b000: ax <= op1;
                    3'b001: cx <= op1;
                    3'b010: dx <= op1;
                    3'b011: bx <= op1;
                    3'b100: sp <= op1;
                    3'b101: bp <= op1;
                    3'b110: si <= op1;
                    3'b111: di <= op1;

                endcase


                m <= `OPCODE_DECODER;
            
            end
    
        endcase

    end

end

// ---------------------------------------------------------------------
// Арифметическо-логическое устройство
// ---------------------------------------------------------------------

wire parity = result[0]  ^ result[1]  ^ result[2]  ^ result[3] ^
              result[4]  ^ result[5]  ^ result[6]  ^ result[7] ^ 1'b1;

wire zero_8  = result[7:0]  == 8'h00;
wire zero_16 = result[15:0] == 16'h0000;

wire [3:0] bsw = wide ? 15 : 7;

always @* begin

    case (alu)

        /* ADD */ 3'b000: result = op1 + op2;
        /* OR  */ 3'b001: result = op1 | op2;
        /* ADC */ 3'b010: result = op1 + op2 + fl[ `CARRY ];
        /* SBB */ 3'b011: result = op1 - op2 - fl[ `CARRY ];
        /* AND */ 3'b100: result = op1 & op2;
        /* SUB */ 3'b101: result = op1 - op2;
        /* XOR */ 3'b110: result = op1 ^ op2;
        /* CMP */ 3'b110: result = op1 - op2;

    endcase

    case (alu)

        /* ADD */
        /* ADC */
        3'b000,
        3'b010: rflags = {
            /* OF */ (op1[ bsw ] ^ op2[ bsw ] ^ 1'b1) & (op1[ bsw ] ^ result[ bsw ]),
            /* DF */ fl[10],
            /* IF */ fl[9],
            /* TF */ fl[8],
            /* SF */ result[ bsw ],
            /* ZF */ wide ? zero_16 : zero_8,
            /*    */ 1'b0,
            /* AF */ op1[3:0] + op2[3:0] + (alu[1] & fl[ `CARRY ]) >= 5'h10, // ADC = +Carry
            /*    */ 1'b0,
            /* PF */ parity,
            /*    */ 1'b1,
            /* CF */ result[ bsw + 1 ]
        };

        /* OR  */
        /* AND */
        /* XOR */
        3'b001,
        3'b100,
        3'b110: rflags = {
            /* OF */ 1'b0,
            /* DF */ fl[10],
            /* IF */ fl[9],
            /* TF */ fl[8],
            /* SF */ result[ bsw ],
            /* ZF */ wide ? zero_16 : zero_8,
            /*    */ 1'b0,
            /* AF */ i_data[4], // Undefined
            /*    */ 1'b0,
            /* PF */ parity,
            /*    */ 1'b1,
            /* CF */ 1'b0
        };

        /* SUB */
        /* CMP */
        /* SBB */
        3'b101,
        3'b110,
        3'b011: rflags = {
            /* OF */ (op1[ bsw ] ^ op2[ bsw ]) & (op1[ bsw ] ^ result[ bsw ]),
            /* DF */ fl[10],
            /* IF */ fl[9],
            /* TF */ fl[8],
            /* SF */ result[ bsw ],
            /* ZF */ wide ? zero_16 : zero_8,
            /*    */ 1'b0,
            /* AF */ op1[3:0] < op2[3:0] + (!alu[2] & fl[ `CARRY ]), // SBB = -Carry
            /*    */ 1'b0,
            /* PF */ parity,
            /*    */ 1'b1,
            /* CF */ result[ bsw + 1 ]
        };

    endcase

end

endmodule
