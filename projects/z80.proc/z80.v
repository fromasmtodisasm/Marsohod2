module z80(

    input   wire        reset,
    input   wire        clk,            // 100 Mhz
    input   wire        turbo,          // 1-турборежим
    input   wire [7:0]  i_data,
    output  reg  [7:0]  o_data,
    output  wire [15:0] o_addr,
    output  reg         o_wr,

    // Связь с внешним миром
    output  reg  [15:0] port,
    output  wire [7:0]  port_in,
    output  reg  [7:0]  port_out,
    output  reg         port_clk

);

// Указатель на шину адреса (pc / ab)
assign o_addr = abus ? ab : pc;

com_clock_divisor CCD(
    .clk        (clk),
    .clk_z80    (clk_z80),
    .param_div  (turbo ? 4'd1 : 4'd13)
);

// SZ-H-PNC ФЛаги
// 76543210

// Регистры общего назначения
reg [7:0] a; reg [7:0] f;
reg [7:0] b; reg [7:0] c;
reg [7:0] d; reg [7:0] e;
reg [7:0] h; reg [7:0] l;

// H/L зависит от префикса
wire [7:0] H =  prefix == 1 ? ix[15:8] :
                prefix == 2 ? iy[15:8] : h;
wire [7:0] L =  prefix == 1 ? ix[7:0] :
                prefix == 2 ? iy[7:0] : l;

// Дополнительные регистры
reg [7:0] a_prime; reg [7:0] f_prime;
reg [7:0] b_prime; reg [7:0] c_prime;
reg [7:0] d_prime; reg [7:0] e_prime;
reg [7:0] h_prime; reg [7:0] l_prime;

// Индексные регистры
reg [15:0]  ix;
reg [15:0]  iy;

// Управляющие регистры
reg [7:0]   i;
reg [7:0]   r;
reg [15:0]  sp;
reg [15:0]  pc;
reg [1:0]   imode;  // Режим прерывания
reg         iff1;   // Маскируемое прерывание #1
reg         iff2;   // Маскируемое прерывание #2
reg         is_halt = 0; // Остановлен?

// ---------------------------------------------------------------------
reg         abus     = 1'b0;        // address_bus: 0=pc, 1=ab
reg [15:0]  ab       = 1'b0;
reg [2:0]   rs       = 3'b000;      // текущий выбранный регистр (0-7)
reg         delay_di = 1'b0;        // предыдущая инструкция была DI
reg         delay_ei = 1'b0;        // предыдущая инструкция была EI
reg [3:0]   m_state  = 1'b0;        // машинное состояние исполнения кода
reg [3:0]   t_state  = 1'b0;        // инструкции для ожидания
reg [7:0]   opcode   = 1'b0;        // код операции
reg [1:0]   prefix   = 1'b0;        // 1-IX, 2-IY
reg [1:0]   lazy_prefix = 1'b0;     //
reg [15:0]  tmp      = 1'b0;        // временный регистр
reg         cb_prefix = 1'b0;       // =1 обработка CB-префиксированного опкода
reg         ed_prefix = 1'b0;       // =1 обработка ED-префиксированного опкода

// regsel указывает на определенный операнд из основного регистрового файла
wire [7:0]  operand =  rs == 3'b000 ? b :
                       rs == 3'b001 ? c :
                       rs == 3'b010 ? d :
                       rs == 3'b011 ? e :
                       rs == 3'b100 ? H :
                       rs == 3'b101 ? L :
                       // 6 = (hl), (ix+d), (iy+d)
                       rs == 3'b110 ? i_data : a;

reg [3:0]   alu_op = 4'h0;      // Операция АЛУ
reg [7:0]   alu_dest = 4'h0;    // Либо A, либо (HL)
reg [8:0]   alu_res;            // Результат - значение
reg [7:0]   alu_flag;           // Результат - флаги

// RET/CALL/JP <ccc>
wire        cond_success =  (opcode[5:4] == 3'b00 & f[6] == opcode[3]) || // NZ(0),Z(1)
                            (opcode[5:4] == 3'b01 & f[0] == opcode[3]) || // NC(0),C(1)
                            (opcode[5:4] == 3'b10 & f[2] == opcode[3]) || // PO(0),PE(1)
                            (opcode[5:4] == 3'b11 & f[7] == opcode[3]);   // P(0),M(1)

// Тип операции АЛУ
wire        r_is_sub    = (alu_op == 4'h2) | (alu_op == 4'h3) | (alu_op == 4'h7);
wire        r_is_logic  = (alu_op == 4'h4) | (alu_op == 4'h5) | (alu_op == 4'h6);

// Half Carry ADD / SUB
wire        r_half_add   = alu_dest[3:0] + operand[3:0] > 4'hF;
wire        r_half_sub   = alu_dest[3:0] < operand[3:0];

// Overflow
wire        r_overflow_add = (alu_dest[7] &  operand[7] & !alu_res[7]) | (!alu_dest[7] & !operand[7] & alu_res[7]);
wire        r_overflow_sub = (alu_dest[7] & !operand[7] & !alu_res[7]) | (!alu_dest[7] &  operand[7] & alu_res[7]);

// Флаг четности @todo для логических операции
wire        r_parity8 = alu_res[7] ^ alu_res[6] ^ alu_res[5] ^ alu_res[4] ^
                        alu_res[3] ^ alu_res[2] ^ alu_res[1] ^ alu_res[0] ^ 1'b1;

// Битовые инструкции (RES / SET)
wire [7:0]  bits    = opcode[5:3] == 3'b000 ? {operand[7:1], opcode[6]} :
                      opcode[5:3] == 3'b001 ? {operand[7:2], opcode[6], operand[0]} :
                      opcode[5:3] == 3'b010 ? {operand[7:3], opcode[6], operand[1:0]} :
                      opcode[5:3] == 3'b011 ? {operand[7:4], opcode[6], operand[2:0]} :
                      opcode[5:3] == 3'b100 ? {operand[7:5], opcode[6], operand[3:0]} :
                      opcode[5:3] == 3'b101 ? {operand[7:6], opcode[6], operand[4:0]} :
                      opcode[5:3] == 3'b110 ? {operand[7],   opcode[6], operand[5:0]} :
                                              {              opcode[6], operand[6:0]};

wire [7:0]  bit_res = opcode[7] ? bits[7:0] : alu_res[7:0];

// Инструкция DAA
wire [7:0]  DAA = a   + ((f[4] | (a[3:0] > 8'h09)) ? 8'h06 : 8'h00);
wire [7:0]  DAS = a   - ((f[4] | (a[3:0] > 8'h09)) ? 8'h06 : 8'h00);
wire [7:0]  daa = DAA + ((f[0] | (a[7:0] > 8'h99)) ? 8'h60 : 8'h00);
wire [7:0]  das = DAS - ((f[0] | (a[7:0] > 8'h99)) ? 8'h60 : 8'h00);

// Результат и флаги DAA
wire [7:0]  daa_res = f[1] ? das[7] : daa[7];
wire [7:0]  daa_flag = {

    /* S */ daa_res[7],
    /* Z */ daa_res[7:0] == 1'b0,
    /* - */ daa_res[5],
    /* H */ daa_res[4] ^ a[4],
    /* - */ daa_res[3],
    /* P */ daa_res[0] ^ daa_res[1] ^ daa_res[2] ^ daa_res[3] ^ daa_res[4] ^ daa_res[5] ^ daa_res[6] ^ daa_res[7] ^ 1'b1,
    /* N */ f[1],
    /* C */ f[0] | (a > 8'h99)

};

// Арифметико-логическое устройство
always @* begin

    case (alu_op)

        /* ADD */ 4'h0: alu_res = alu_dest + operand;
        /* ADC */ 4'h1: alu_res = alu_dest + operand + f[0];
        /* SUB */ 4'h2: alu_res = alu_dest - operand;
        /* SBC */ 4'h3: alu_res = alu_dest - operand - f[0];
        /* AND */ 4'h4: alu_res = alu_dest & operand;
        /* XOR */ 4'h5: alu_res = alu_dest ^ operand;
        /* OR  */ 4'h6: alu_res = alu_dest | operand;
        /* CP  */ 4'h7: alu_res = alu_dest - operand;

        /* БИТОВЫЕ СДВИГИ */
        /* RLC */ 4'h8: alu_res = {operand[6:0],   operand[7]};
        /* RRC */ 4'h9: alu_res = {operand[0],     operand[7:1]};
        /* RL  */ 4'hA: alu_res = {operand[6:0],   f[0]};
        /* RR  */ 4'hB: alu_res = {f[0],           operand[7:1]};
        /* SLA */ 4'hC: alu_res = {operand[6:0],   1'b0};
        /* SRA */ 4'hD: alu_res = {operand[7],     operand[7:1]};
        /* SLL */ 4'hE: alu_res = {operand[6:0],   1'b0};
        /* SRL */ 4'hF: alu_res = {1'b0,           operand[7:1]};

    endcase

    // Арифметические операции
    if (alu_op < 8) begin

        alu_flag = {

            /* S */ alu_res[7],
            /* Z */ alu_res[7:0] == 1'b0,
            /* - */ alu_res[5],
            /* H */ r_is_sub ? r_half_sub : r_half_add,
            /* - */ alu_res[3],
            /* P */ r_is_logic ? r_parity8 : (r_is_sub ? r_overflow_sub : r_overflow_add),
            /* N */ r_is_sub,
            /* C */ alu_res[8]
        };

    end

    // Сдвиговые
    else begin

        alu_flag = {

            /* S */ f[7],
            /* Z */ f[6],
            /* - */ alu_res[5],
            /* H */ 1'b0,
            /* - */ alu_res[3],
            /* P */ f[2],
            /* N */ 1'b0,
            /* C */ alu_op[0] ? alu_res[0] : alu_res[7]

        };

    end

end

initial begin

          a = 1;          b = 3;          c = 3;          d = 1;
          e = 0;          h = 0;          l = 8;          f = 0;
    a_prime = 2;    b_prime = 0;    c_prime = 0;    d_prime = 0;
    e_prime = 0;    h_prime = 0;    l_prime = 0;    f_prime = 4;

    ix      = 0; iy     = 0;
    i       = 0; r      = 0;
    pc      = 0; sp     = 16'h8000; // 16'hDFF0
    imode   = 0; iff1   = 0;
                 iff2   = 0;

    o_wr     = 0;
    port     = 0;
    port_out = 0;
    port_clk = 0;

end

// Работа с 16-битными операндами
wire [16:0] addhl_r16       = {H, L} + tmp[15:0];
wire [12:0] addhl_r16_hf    = {H, L} + tmp[11:0];
wire [15:0] inc_r16         = tmp + 1;
wire [15:0] dec_r16         = tmp - 1;

wire [6:0]  r_inc           = r[6:0] + 1'b1;
wire [15:0] pc_inc          = pc + 1'b1;
wire [15:0] relative8       = {{8{i_data[7]}}, i_data[7:0]};

// Декодер инструкции
always @(posedge clk_z80) begin

    // Нажата кнопка сброса
    if (reset) begin
    
        pc <= 0;
    
    end

    // "Пустые инструкции", чтобы подогнать кол-во тактов на инструкцию
    else if (t_state && !turbo) begin t_state <= t_state - 1; end

    // Текущая исполнимая инструкция
    else if (m_state == 0) begin

        pc       <= pc + 1;
        r        <= {r[7], r_inc[6:0]};
        port_clk <= 0;

        // ПРЕФИКС CB: Bit
        if (i_data == 8'hCB) begin

            cb_prefix   <= 1;
            m_state     <= 1;
            t_state     <= 3;

        end

        // ПРЕФИКС ED: Extended
        else if (i_data == 8'hED) begin

            ed_prefix   <= 1;
            m_state     <= 1;
            t_state     <= 3;

        end

        // ПРЕФИКС IX:
        else if (i_data == 8'hDD) begin

            lazy_prefix <= 2'b01;
            t_state     <= 3;

        end

        // ПРЕФИКС IY:
        else if (i_data == 8'hFD) begin

            lazy_prefix <= 2'b10;
            t_state     <= 3;

        end

        // ОПЕРАЦИЯ
        else begin

            // if (iff1.. & interrupt) begin end

            // "Отложенный" DI/EI. Они срабатывают через 1 инструкцию!
            if (delay_di) begin iff1 <= 0; iff2 <= 0; end
            else
            if (delay_ei) begin iff1 <= 1; iff2 <= 1; end

            prefix      <= lazy_prefix;
            lazy_prefix <= 1'b0;
            opcode      <= i_data;  // Записать опкод с шины данных
            m_state     <= 1;       // К декодеру инструкции (2-й такт)
            delay_di    <= 0;
            delay_ei    <= 0;
            is_halt     <= 0;

        end

    end

    // Префикс CB:
    else if (cb_prefix) begin

        case (m_state)

           // Декодирование опкода CBh
           1: begin

                if (lazy_prefix) begin

                    case (lazy_prefix)

                        1: ab <= ix + relative8;
                        2: ab <= iy + relative8;

                    endcase

                    lazy_prefix <= 0;
                    prefix      <= 1;
                    pc          <= pc + 1;

                end else begin

                    opcode      <= i_data;
                    alu_op      <= {1'b1, i_data[5:3]};
                    rs          <= i_data[2:0];
                    pc          <= pc + 1;
                    m_state     <= 2;

                    if (prefix == 0) ab <= {h, l};

                end

            end

            // Расчет
            2: begin

                if (prefix) begin

                    rs      <= 3'b110;
                    abus    <= 1;

                end
                else begin

                    abus    <= (opcode[2:0] == 3'b110);

                end

                m_state <= 3;

            end

            //  Запись результата в регистр
            3: begin

                // BIT n, r8
                if (opcode[7:6] == 2'b01) begin

                    /* N */ f[1]    <= 1'b0;
                    /* Z */ f[6]    <= !operand[ opcode[5:3] ];
                    /* H */ f[4]    <= 1'b1;
                    /* P */ f[2]    <= f[6];
                    /* S */ f[7]    <= (opcode[5:3] == 3'b111) & !f[6];

                    m_state     <= 0;
                    cb_prefix   <= 0;
                    abus        <= 0;

                end

                // Запись результата (shift, res, set)
                else begin

                    case (opcode[2:0])

                        0: b <= bit_res[7:0];
                        1: c <= bit_res[7:0];
                        2: d <= bit_res[7:0];
                        3: e <= bit_res[7:0];
                        4: h <= bit_res[7:0];
                        5: l <= bit_res[7:0];
                        6: o_data <= bit_res[7:0];
                        7: a <= bit_res[7:0];

                    endcase

                    // Сохранить флаги только на операциях сдвига
                    if (opcode[7:6] == 2'b00) f <= alu_flag;

                    // Выбор, как завершить инструкцию
                    m_state     <= (opcode[2:0] == 3'b110) ? 4 : 0;
                    cb_prefix   <= (opcode[2:0] == 3'b110) ? 1 : 0;
                    abus        <= (opcode[2:0] == 3'b110) ? 1 : 0;

                end

            end

            // Сохранение результата в памяти
            4: begin o_wr <= 1; m_state <= 5; end
            5: begin o_wr <= 0; abus <= 0; m_state <= 0; cb_prefix <= 0; t_state <= 11 - 6; end

        endcase

    end

    // Префикс ED:
    else if (ed_prefix) begin

        if (m_state == 1) begin

            opcode  <= i_data;
            pc      <= pc + 1;
            m_state <= 2;

        end else casex (opcode)

            // 12T IN r8, (c)
            8'b01_xxx_000: begin



            end

            // 12T OUT (c), r8
            8'b01_xxx_001: begin



            end

            // 15T SUB HL, r16
            8'b01_xx0_010: begin



            end

            // 15T ADC HL, r16
            8'b01_xx1_010: begin



            end

            // 20T LD (**), r16
            8'b01_xx0_011: begin



            end

            // 20T LD r16, (**)
            8'b01_xx1_011: begin



            end

            // 14T RETN
            8'b01_xxx_101: begin



            end

            // 8T IM *
            8'b01_xxx_110: begin



            end

            // LD I, A
            // LD R, A
            // LD A, I
            // LD A, R
            // RRD
            // RLD

            // Не работающий опкод (NOP)
            default: begin m_state <= 0; t_state <= 4 - 2; end

        endcase


    end

    // Декодирование и исполнение инструкции
    else casex (opcode)

        // 4T NOP
        8'b00_000_000: begin

            t_state <= 4-2;
            m_state <= 0;

        end

        // 4T EX AF, AF'
        8'b00_001_000: begin

            t_state <= 4-2;
            a       <= a_prime;
            f       <= f_prime;
            a_prime <= a;
            f_prime <= f;
            m_state <= 0;

        end

        // 8T/13T DJNZ *
        8'b00_010_000: begin

            // На следующем такте B=0, значит, 8Т и к следующему опкоду
            if (b == 1) begin

                t_state <= 8-2;
                pc      <= pc + 1;

            end else begin

                t_state <= 13-2;
                pc      <= pc + 1 + relative8;

            end

            m_state <= 0;
            b <= b - 1'b1;

        end

        // 12T JR *
        8'b00_011_000: begin

            t_state <= 12-2;
            m_state <= 0;
            pc      <= pc + 1 + relative8;

        end

        // 12/7T JR (NZ,Z,NC,C), *
        8'b00_1xx_000: begin

            // 00 NZ  10 NC
            // 01 Z   11 C

            // CF: если выбран NC (opcode[3] = 0), то срабатывает при f[0] = 0
            // ZF: если выбран NZ (opcode[3] = 0), то срабатывает при f[6] = 0
            if (opcode[3] == f[ opcode[4] ? 0 : 6 ]) begin

                t_state <= 12 - 2;
                pc      <= pc + 1 + relative8;

            end else begin

                t_state <= 7 - 2;
                pc      <= pc + 1;

            end

            m_state <= 0;

        end

        // 10T LD r16, **
        8'b00_xx0_001: begin

            case (m_state)

                1: begin tmp[7:0] <= i_data; m_state <= 2; pc <= pc + 1; end
                2: begin

                    case (opcode[5:4])

                        2'b00: begin b <= i_data; c <= tmp[7:0]; end
                        2'b01: begin d <= i_data; e <= tmp[7:0]; end
                        2'b10: begin

                            case (prefix)

                                0: begin h <= i_data; l <= tmp[7:0]; end
                                1: ix <= {i_data, tmp[7:0]};
                                2: iy <= {i_data, tmp[7:0]};

                            endcase

                        end
                        2'b11: begin sp <= {i_data, tmp[7:0]}; end

                    endcase

                    pc <= pc + 1;
                    m_state <= 0;
                    t_state <= 10-3;

                end

            endcase

        end

        // 11T ADD HL, r16
        8'b00_xx1_001: begin

            case (m_state)

                // (1) Вычисление
                1: begin

                    tmp <= opcode[5:4] == 2'b00 ? {b, c} :
                           opcode[5:4] == 2'b01 ? {d, e} :
                           opcode[5:4] == 2'b10 ? {H, L} : sp;

                    m_state <= 2;

                end

                // (2) Запись результата
                2: begin

                    case (prefix)

                        0: begin h <= addhl_r16[15:8]; l <= addhl_r16[7:0]; end
                        1: ix <= addhl_r16[15:0];
                        2: iy <= addhl_r16[15:0];

                    endcase

                    f[0] <= addhl_r16[16];
                    f[1] <= 1'b0;
                    f[3] <= addhl_r16[11];
                    f[4] <= addhl_r16_hf[12];
                    f[5] <= addhl_r16[13];

                    m_state <= 0;
                    t_state <= 11-3;

                end


            endcase

        end

        // 7T LD (BC|DE), A
        8'b00_0x0_010: begin

            case (m_state)

                // Выставить данные на шину данных, и установить шину адреса
                1: begin o_data <= a; abus <= 1; ab <= opcode[4] ? {d,e} : {b,c}; m_state <= 2; end
                // Запись
                2: begin o_wr <= 1; m_state <= 3; end
                // Завершение
                3: begin o_wr <= 0; abus <= 0; m_state <= 0; t_state <= 7-4; end

            endcase

        end

        // 7T LD A, (BC|DE)
        8'b00_0x1_010: begin

            case (m_state)

                // Выставить данные на шину данных, и установить шину адреса
                1: begin abus <= 1; ab <= opcode[4] ? {d,e} : {b,c}; m_state <= 2; end
                // Чтение
                2: begin abus <= 0; a <= i_data; m_state <= 0; t_state <= 7-3; end

            endcase

        end

        // 16T LD (**), (HL|IX|IY)
        8'b00_100_010: begin

            case (m_state)

                1: begin ab[7:0] <= i_data; pc <= pc + 1; m_state <= 2;  end
                2: begin

                    ab[15:8]    <= i_data;
                    pc          <= pc + 1;
                    abus        <= 1;
                    m_state     <= 3;

                    case (prefix)

                        0: o_data <= l;
                        1: o_data <= ix[7:0];
                        2: o_data <= iy[7:0];

                    endcase

                end

                3: begin o_wr <= 1; m_state <= 4; end
                4: begin o_wr <= 0; ab <= ab + 1; m_state <= 5; end
                5: begin

                    m_state <= 6;
                    case (prefix)

                        0: o_data <= h;
                        1: o_data <= ix[15:8];
                        2: o_data <= iy[15:8];

                    endcase

                end

                6: begin o_wr <= 1; m_state <= 7; end
                7: begin o_wr <= 0; abus <= 0; m_state <= 0; t_state <= 16 - 8; end

            endcase

        end

        // 16T LD (HL|IX|IY), (**)
        8'b00_101_010: begin

            case (m_state)

                1: begin ab[ 7:0] <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin ab[15:8] <= i_data; pc <= pc + 1; m_state <= 3; abus <= 1; end
                3: begin tmp[7:0] <= i_data; ab <= ab + 1; m_state <= 4; end
                4: begin

                    case (prefix)

                        0: begin h <= i_data; l <= tmp[7:0]; end
                        1: ix <= {i_data, tmp[7:0]};
                        2: iy <= {i_data, tmp[7:0]};

                    endcase

                    m_state <= 0;
                    t_state <= 16 - 5;
                    abus    <= 0;

                end

            endcase

        end

        // 13T LD (**), A
        8'b00_110_010: begin

            case (m_state)

                1: begin ab[ 7:0] <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin ab[15:8] <= i_data; pc <= pc + 1; m_state <= 3; o_data <= a; abus <= 1; end
                3: begin m_state <= 4; o_wr <= 1; end
                4: begin m_state <= 0; o_wr <= 0; abus <= 0; t_state <= 13 - 5; end

            endcase

        end

        // 13T LD A, (**)
        8'b00_111_010: begin

            case (m_state)

                1: begin ab[ 7:0] <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin ab[15:8] <= i_data; pc <= pc + 1; m_state <= 3; abus <= 1; end
                3: begin a <= i_data; m_state <= 0; o_wr <= 0; abus <= 0; t_state <= 13 - 4; end

            endcase

        end

        // 6T INC/DEC r16
        8'b00_xxx_011: begin

            case (m_state)

                // Чтение
                1: begin

                    case (opcode[5:4])

                        0: tmp <= {b, c};
                        1: tmp <= {d, e};
                        2: tmp <= {H, L};
                        3: tmp <= sp;

                    endcase

                    m_state <= 2;

                end

                // Вычисление
                2: begin tmp <= opcode[3] ? dec_r16 : inc_r16; m_state <= 3; end

                // Запись результата
                3: begin

                    case (opcode[5:4])

                        0: begin b <= tmp[15:8]; c <= tmp[7:0]; end
                        1: begin d <= tmp[15:8]; e <= tmp[7:0]; end
                        2: begin

                            case (prefix)

                                0: begin h <= tmp[15:8]; l <= tmp[7:0]; end
                                1: ix <= tmp;
                                2: iy <= tmp;

                            endcase

                        end


                        3: begin sp <= tmp; end

                    endcase

                    m_state <= 0;
                    t_state <= 6 - 4;

                end

            endcase

        end

        // 4T/11T INC/DEC r8
        8'b00_xxx_10x: begin

            case (m_state)

                // если (HL/IX+d/IY+d), то включение режима address bus
                1: begin

                    rs      <= opcode[5:3];
                    abus    <= (opcode[5:3] == 3'd6) && (!prefix);
                    ab      <= {H, L};
                    m_state <= 2;

                end

                // Вычисление / Переход
                2: begin

                    f[1] <= opcode[0];

                    // Используется обращение к (HL), IX+d, IY+d
                    if (opcode[5:3] == 3'd6) begin

                        // IX: IY: Использ
                        if (prefix) begin

                            abus    <= 1;
                            ab      <= ab + relative8;
                            pc      <= pc + 1;
                            t_state <= 8;
                            prefix  <= 0;

                        // Вычисление и подготовка к записи в память
                        end else begin

                            tmp[8:0]    <= opcode[0] ? i_data - 1 : i_data + 1;
                            o_data[7:0] <= opcode[0] ? i_data - 1 : i_data + 1;
                            m_state     <= 4;

                        end

                    end

                    // INC/DEC r
                    else begin

                        tmp[8:0]    <= opcode[0] ? operand - 1 : operand + 1;
                        m_state     <= 3;

                    end

                end

                // Сохранение
                3: begin

                    case (rs)

                        0: b <= tmp[7:0];
                        1: c <= tmp[7:0];
                        2: d <= tmp[7:0];
                        3: e <= tmp[7:0];
                        4: case (prefix)

                            0: h        <= tmp[7:0];
                            1: ix[15:8] <= tmp[7:0];
                            2: iy[15:8] <= tmp[7:0];

                        endcase
                        5: case (prefix)

                            0: l        <= tmp[7:0];
                            1: ix[7:0]  <= tmp[7:0];
                            2: iy[7:0]  <= tmp[7:0];

                        endcase
                        7: a <= tmp[7:0];

                    endcase

                    /* C */ f[0] <= tmp[8];
                    /* P */ f[2] <= 0; // !! tmp[7] ^ tmp[6] ^ tmp[5] ^ tmp[4] ^ tmp[3] ^ tmp[2] ^ tmp[1] ^ tmp[0] ^ 1'b1;
                    /* Y */ f[3] <= tmp[3];
                    /* H */ f[4] <= tmp[3:0] == (f[1] ? 4'b1111 : 4'b0000);
                    /* X */ f[5] <= tmp[5];
                    /* Z */ f[6] <= tmp[7:0] == 0;
                    /* S */ f[7] <= tmp[7];

                    m_state <= 0;

                end

                // Запись в память
                4: begin o_wr <= 1; m_state <= 5; end

                // Выход к сохранению флагов
                5: begin o_wr <= 0; abus <= 0; m_state <= 3; t_state <= 11 - 6; end

            endcase

        end

        // 7/10T LD r8, *
        8'b00_xxx_110: begin

            case (m_state)

                // Загрузка Immediate
                1: begin

                    tmp[7:0] <= i_data;
                    pc      <= pc + 1;
                    m_state <= 2;
                    ab      <= {H, L};

                end

                // Запись в регистр
                2: begin

                    case (opcode[5:3])

                        0: b <= tmp[7:0];
                        1: c <= tmp[7:0];
                        2: d <= tmp[7:0];
                        3: e <= tmp[7:0];
                        4: case (prefix)

                            0: h         <= tmp[7:0];
                            1: ix[15:8]  <= tmp[7:0];
                            2: iy[15:8]  <= tmp[7:0];

                        endcase
                        5: case (prefix)

                            0: l        <= tmp[7:0];
                            1: ix[7:0]  <= tmp[7:0];
                            2: iy[7:0]  <= tmp[7:0];

                        endcase
                        6: begin

                            abus <= 1;

                            if (prefix) begin

                                o_data  <= i_data;
                                ab      <= ab + {{8{tmp[7]}}, tmp[7:0]};
                                pc      <= pc + 1;

                            end else begin
                                o_data  <= tmp[7:0];
                            end

                        end
                        7: a <= tmp[7:0];

                    endcase

                    t_state <= 7 - 3;
                    m_state <= opcode[5:3] == 6 ? 3 : 0;

                end

                // Запись в память
                3: if (prefix) begin

                    prefix  <= 0;
                    t_state <= 9;

                end else begin

                    o_wr    <= 1;
                    m_state <= 4;

                end

                // Завершить запись
                4: begin o_wr <= 0; m_state <= 0; abus <= 0; t_state <= 1; end

            endcase

        end

        // 4T RLCA, RRCA, RLA, RRA
        8'b00_0xx_111: begin

            case (m_state)

                1: begin alu_dest <= a; alu_op <= {1'b1, opcode[5:3]}; m_state <= 2; end
                2: begin a <= alu_res[7:0]; f <= alu_flag; m_state <= 0; t_state <= 4 - 3; end

            endcase

        end

        // 4T DAA
        8'b00_100_111: begin

            a <= daa_res;
            f <= daa_flag;
            m_state <= 0;
            t_state <= 4 - 2;

        end

        // 4T CPL
        8'b00_101_111: begin

            a <= a ^ 8'hFF;
            f[1] <= 1'b1;
            f[4] <= 1'b1;
            f[5] <= a[5];
            f[3] <= a[3];
            m_state <= 0;
            t_state <= 4 - 2;

        end

        // 4T CCF
        8'b00_110_111: begin

            f <= {f[7:6], a[5], 1'b0, a[3], f[2], 1'b1, f[0]};
            m_state <= 0;
            t_state <= 4 - 2;

        end

        // 4T CPL
        8'b00_111_111: begin

            f <= {f[7:6], a[5], f[0], a[3], f[2], 1'b0, f[0] ^ 1'b1};
            m_state <= 0;
            t_state <= 4 - 2;

        end

        // 76h HALT
        8'b01_110_110: begin

            pc      <= pc - 1'b1;
            is_halt <= 1;
            m_state <= 0;

        end

        // 4/7T LD r8, r8
        8'b01_xxx_xxx: begin

            case (m_state)

                // Декодинг
                1: begin

                    rs      <= opcode[2:0];
                    ab      <= {H, L};
                    m_state <= 2;

                end

                // Разбор
                2: begin

                    // Либо А, либо B - (HL)
                    if ((opcode[2:0] == 3'b110) || (opcode[5:3] == 3'b110)) begin

                        if (prefix) begin

                            ab      <= ab + relative8;
                            pc      <= pc + 1;
                            t_state <= 8;
                            prefix  <= 0;

                        end else begin

                            abus    <= 1;
                            m_state <= 3;
                            t_state <= 7 - 6;

                        end

                    end

                    else m_state  <= 3;

                end

                // Сохранение в указанный регистр
                3: begin

                    case (opcode[5:3])

                        0: b <= operand;
                        1: c <= operand;
                        2: d <= operand;
                        3: e <= operand;
                        4: case (prefix)

                            0: h <= operand;
                            1: ix[15:8] <= operand;
                            2: iy[15:8] <= operand;

                        endcase
                        5: case (prefix)

                            0: l <= operand;
                            1: ix[7:0] <= operand;
                            2: iy[7:0] <= operand;

                        endcase
                        6: o_data <= operand;
                        7: a <= operand;

                    endcase

                    abus    <= (opcode[5:3] == 3'b110) ? 1 : 0;
                    m_state <= (opcode[5:3] == 3'b110) ? 4 : 0;

                end

                // Запись данных
                4: begin o_wr <= 1; m_state <= 5; end
                5: begin o_wr <= 0; m_state <= 0; abus <= 0; end

            endcase

        end

        // ALU инструкции
        8'b10_xxx_xxx: begin

            case (m_state)

                // Подготовка
                1: begin

                    ab       <= {H, L};
                    alu_dest <= a;              // A
                    rs       <= opcode[2:0];    // r8
                    alu_op   <= opcode[5:3];
                    m_state  <= 2;

                end

                // Разбор
                2: begin

                    if (opcode[2:0] == 3'b110) begin

                        if (prefix) begin

                            ab      <= ab + relative8;
                            pc      <= pc + 1;
                            t_state <= 8;
                            prefix  <= 0;

                        end else begin

                            m_state <= 3;
                            t_state <= 7 - 4; // +3 такта

                        end

                        abus <= 1;

                    // 4T операция
                    end else m_state <= 3;

                end

                // Запись результата
                3: begin

                    if (opcode[5:3] !== 3'b111)
                        a <= alu_res[7:0];

                    f       <= alu_flag;
                    abus    <= 0;
                    m_state <= 0;

                end

            endcase

        end

        // 5/11T RET ccc
        // 10T   RET
        8'b11_xxx_000,
        8'b11_001_001: begin

            case (m_state)

                // Проверка условия
                1: if (cond_success || opcode[0]) begin

                    m_state <= 2;
                    abus    <= 1;
                    ab      <= sp;
                    sp      <= sp + 2;
                    t_state <= opcode[0] ? (10 - 4) : (11 - 4);

                end else begin

                    m_state <= 0;
                    t_state <= 5 - 2;

                end

                // Загрузка из стека
                2: begin pc[7:0]  <= i_data; ab <= ab + 1; m_state <= 3; end
                3: begin pc[15:8] <= i_data; ab <= ab + 1; m_state <= 0; abus <= 0; end

            endcase

        end

        // POP r16
        8'b11_xx0_001: begin

            case (m_state)

                // Подготовка
                1: begin ab <= sp; sp <= sp + 2; abus <= 1; m_state <= 2; t_state <= 10 - 4; end

                // Младший байт
                2: begin

                    case (opcode[5:4])

                        0: c <= i_data;
                        1: e <= i_data;
                        2: case (prefix)

                            0: l <= i_data;
                            1: ix[7:0] <= i_data;
                            2: iy[7:0] <= i_data;

                        endcase
                        3: f <= i_data;

                    endcase

                    ab <= ab + 1;
                    m_state <= 3;

                end

                // Старший байт
                3: begin

                    case (opcode[5:4])

                        0: b <= i_data;
                        1: d <= i_data;
                        2: case (prefix)

                            0: h <= i_data;
                            1: ix[15:8] <= i_data;
                            2: iy[15:8] <= i_data;

                        endcase
                        3: a <= i_data;

                    endcase

                    abus <= 0;
                    m_state <= 0;

                end

            endcase

        end

        // 4T EXX
        8'b11_011_001: begin

            t_state <= 4 - 2;
            m_state <= 0;

            b <= b_prime; b_prime <= b;
            c <= c_prime; c_prime <= c;
            d <= d_prime; d_prime <= d;
            e <= e_prime; e_prime <= e;
            h <= h_prime; h_prime <= h;
            l <= l_prime; l_prime <= l;

        end

        // 4T JP (HL)
        8'b11_101_001: begin

            m_state <= 0;
            t_state <= 4 - 2;
            pc <= {H, L};

        end

        // 6T LD SP,O HL
        8'b11_111_001: begin

            m_state <= 0;
            t_state <= 6 - 2;
            sp <= {H, L};

        end

        // 10T JP ccc, **
        // 10T JP **
        8'b11_xxx_010,
        8'b11_000_011: begin

            case (m_state)

                // Загрузка младшего байта
                1: begin

                    tmp[7:0] <= i_data;
                    pc       <= pc + 1;
                    m_state  <= 2;

                end

                // Старшего + переход (либо нет)
                2: begin

                    if (cond_success || opcode[0])
                        pc <= {i_data, tmp[7:0]};
                    else
                        pc <= pc + 1;

                    m_state <= 0;
                    t_state <= 10 - 3;

                end

            endcase

        end

        // 11T OUT (*), A
        8'b11_010_011: begin

            case (m_state)

                1: begin port <= i_data; port_out <= a; pc <= pc + 1; m_state <= 2; end
                2: begin port_clk <= 1; m_state <= 0; t_state <= 11 - 3; end

            endcase

        end

        // 11T IN A, (*)
        8'b11_011_011: begin

            case (m_state)

                1: begin port <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin a <= port_in; m_state <= 0; t_state <= 11 - 3; end

            endcase

        end

        // 19T EX (SP), hl
        8'b11_100_011: begin

            case (m_state)

                // Подготовка шины
                1: begin ab <= sp; abus <= 1; m_state <= 2; end

                // Прочитать данные, записать L, ix[7:0], iy[7:0] в память
                2: begin tmp[7:0] <= i_data; o_data <= L; o_wr <= 1; m_state <= 3; end

                // Прекратить запись, перейти к следующему байту
                3: begin o_wr <= 0; ab <= ab + 1; m_state <= 4; end

                // Начать запись старшего байта
                4: begin tmp[15:8] <= i_data; o_data <= H; o_wr <= 1; m_state <= 5; end

                // Прекратить запись, записать результат
                5: begin

                    o_wr <= 0;

                    case (prefix)

                        0: begin {h, l} <= tmp; end
                        1: begin ix <= tmp; end
                        2: begin iy <= tmp; end

                    endcase

                    t_state <= 19 - 6;
                    m_state <= 0;
                    abus    <= 0;

                end


            endcase

        end

        // 4T EX DE, HL
        8'b11_101_011: begin

            case (prefix)

                0: {h, l} <= {d, e};
                1: ix <= {d, e};
                2: iy <= {d, e};

            endcase

            {d, e} <= {H, L};

            m_state <= 0;
            t_state <= 4 - 2;

        end

        // 4T DI/EI
        8'b11_11x_011: begin

            m_state     <= 0;
            delay_ei    <=  opcode[3];
            delay_di    <= !opcode[3];
            t_state     <= 4 - 2;

        end

        // 17/10T CALL (nz,z,nc,c,po,pe,p,m), **
        // 10T    CALL **
        8'b11_xxx_100,
        8'b11_001_101: begin

            case (m_state)

                1: begin tmp[7:0] <= i_data; pc <= pc_inc; m_state <= 2; end
                2: begin

                    pc <= pc_inc;

                    if (cond_success || opcode[0]) begin

                        abus        <= 1;
                        ab          <= sp - 1;
                        sp          <= sp - 2;
                        o_data      <= pc_inc[15:8];
                        tmp[15:8]   <= i_data;
                        m_state     <= 3;

                    end else begin

                        m_state     <= 0;
                        t_state     <= 10 - 3;

                    end

                end

                // Запись старшего байта
                3: begin o_wr <= 1; m_state <= 4; end
                4: begin o_wr <= 0; m_state <= 5; ab <= ab - 1; o_data <= pc[7:0]; end

                // Запись младшего байта
                5: begin o_wr <= 1; m_state <= 6; end
                6: begin o_wr <= 0; abus <= 0; m_state <= 0; t_state <= 17 - 7; pc <= tmp; end

            endcase

        end

        // 11T PUSH r16
        8'b11_xx0_101: begin

            case (m_state)

                1: begin

                    abus    <= 1;
                    ab      <= sp - 1;
                    sp      <= sp - 2;
                    m_state <= 2;

                    case (opcode[5:4])

                        0: begin o_data <= b; tmp[7:0] <= c; end
                        1: begin o_data <= d; tmp[7:0] <= e; end
                        2: begin o_data <= H; tmp[7:0] <= L; end
                        3: begin o_data <= a; tmp[7:0] <= f; end

                    endcase
                end

                // Запись WORD
                2: begin o_wr <= 1; m_state <= 3; end
                3: begin o_wr <= 0; m_state <= 4; o_data <= tmp[7:0]; ab <= ab - 1; end
                4: begin o_wr <= 1; m_state <= 5; end
                5: begin o_wr <= 0; m_state <= 0; abus <= 0; t_state <= 11 - 6; end

            endcase

        end

        // 7T <ALU> *
        8'b11_xxx_110: begin

            case (m_state)

                // Подготовка
                1: begin

                    alu_dest <= a;
                    rs       <= 3'b110; // i_data
                    alu_op   <= opcode[5:3];
                    m_state  <= 2;

                end

                // Исполнение
                2: begin

                    if (alu_op !== 3'b111)
                        a <= alu_res[7:0];

                    f       <= alu_flag;
                    pc      <= pc + 1;
                    t_state <= 7 - 3;
                    m_state <= 0;

                end

            endcase

        end

        // 11T RST #n
        8'b11_xxx_111: begin

            case (m_state)

                1: begin m_state <= 2; abus <= 1; ab <= sp - 1; sp <= sp - 2; o_data <= pc[15:8];  end
                2: begin m_state <= 3; o_wr <= 1; end
                3: begin m_state <= 4; o_wr <= 0; ab <= ab - 1; o_data <= pc[7:0]; end
                4: begin m_state <= 5; o_wr <= 1; end
                5: begin m_state <= 0; o_wr <= 0; abus <= 0; t_state <= 11 - 6; pc <= {opcode[5:3], 3'b000}; end

            endcase

        end

    endcase
end


endmodule
