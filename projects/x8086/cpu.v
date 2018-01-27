module cpu(

    input   wire        clk,            // 100 Mhz
    input   wire        lock,           // Memory Locked?
    output  wire [19:0] o_addr,         // Адрес на чтение, 1 Мб
    input   wire [7:0]  i_data,         // Входящие данные
    output  wire [7:0]  o_data,         // Исходящие данные
    output  wire        o_write         // Запрос на запись

);

// ---------------------------------------------------------------------
`define OPCODE_DECODER      3'h0
`define MODRM_DECODE        3'h1
`define OPCODE_EXEC         3'h2
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

    ax = 16'h0000; bx = 16'h0001; cx = 16'h0000; dx = 16'h0000;
    sp = 16'h0000; bp = 16'h5000; si = 16'h0010; di = 16'h0020;
    es = 16'h0000; cs = 16'hFC00; ss = 16'h0040; ds = 16'h0000;
    ip = 16'h0000;
    //       ODITSZ-A-P-C
    fl = 12'b000000000000;

end
// ---------------------------------------------------------------------

// Машинное состояния. Это не микрокод.
reg [2:0]   m = 3'b0;
reg [2:0]   modm_stage = 1'b0;
reg [7:0]   modrm = 8'h00;
reg [7:0]   opcode = 8'h00;

// wide =0 (byte), =1 (word)
reg         wide = 1'b0;

// =0 rm, reg
// =1 reg, rm
reg         direct = 1'b0;
reg [15:0]  op1;
reg [15:0]  op2;

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

        // Декодирование префиксов
        // Если используется префикс, то он запоминается.
        // В любом другом случае, т.е. при декодировании НЕ префикса,
        // временные "защелки" сбрасываются, чтобы не переместить
        // информацию о наличии префикса на следующую инструкцию

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

            // Классический блок арифметико-логического устройства
            8'b00xx_x0xx: begin

                m       <= `MODRM_DECODE;
                wide    <= i_data[0];
                direct  <= i_data[1];
                // выбор режима АЛУ

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

                // Фаза выполнения опкода
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
                            if (wide == 1'b0) m <= `OPCODE_EXEC;

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
                        if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;

                    end

                endcase

            end

            3'h4: begin

                if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;
                m <= `OPCODE_EXEC;

            end

        endcase

    end

end


endmodule
