// Набор инструкции Z80
module processor(

    input   wire            clock,      // 12,5 MHz
    output  wire    [15:0]  o_addr,     // Указатель на память
    input   wire    [7:0]   i_data,     // Данные из памяти
    output  reg     [7:0]   o_data,     // Данные за запись
    output  reg             o_wr,       // Строб записи в память

    // Порты
    output reg      [15:0]  port_addr,
    output reg      [7:0]   port_data,
    output wire     [7:0]   port_in,
    output reg              port_clock
);

assign o_addr = mem ? ap : pc;
assign led = A;

// Модули процессора
// -------------------------------------------------------------------
`include "inc/regs.v"               // Объявление регистров
`include "inc/initial.v"            // Инициализация
`include "inc/regs_write.v"         // Запись в регистр
`include "inc/alu.v"                // Арифметико-логическое устройство
`include "inc/decoder.v"            // Декодер инструкции
`include "inc/irq.v"                // IRQ

// Процессор работает на прямом фронте _/
// [!] Tip: w_reg = 0/1 на каждом t_state = 0
//          w_alu = 0/1 при АЛУ-инструкциях
// -------------------------------------------------------------------

always @(posedge clock) begin

    // Установка IRQ #38, после выполнения 32 первых тактов
    if (irq_38_timer == 16'd32 & ie) irq <= 3'h7;

    // Как можно проще сделать
    else case (t_state)

        /*
         * ДЕКОДЕР: TICK 1
         */

        4'h0: begin

            // Условия разрешения записи некоторых управляющих битов на
            // первом такте.

            // Запись в регистр AF из w_r16
            w_r16af <= 1'b0;

            // Запись в 8-битный регистр (номер w_num)
            w_reg   <= I_DJNZ |

                       // Кроме тех, что указывают на (hl)
                       ((I_INCR8 | I_DECR8) & !O_HLMEM_53) |

                       // Все инструкции, кроме scf / ccf
                       (I_SSDAA & (o[5:3] < 3'b110)) |

                       // Загружать в регистр только в том случае, если у операндов нет (hl)
                       (I_LD & !O_HLMEM_53 & !O_HLMEM_20) |

                       // В регистр писать на первом такте, если не (hl), и не CP
                       (I_ALUR8 & !O_HLMEM_20 & (o[5:3] != 3'b111));

            // Запись в регистр 16
            w_reg16 <= I_ADD_HLR16 | I_INCR16 | I_DECR16 | I_LDSPHL | I_EXDEHL;

            // Разрешение на запись флагов
            w_flag  <= I_ADD_HLR16 | I_SSDAA |

                       // Записать флаги, кроме (hl)
                       ((I_INCR8 | I_DECR8) & !O_HLMEM_53) |

                       // Аналогично
                       (I_ALUR8 & !O_HLMEM_20);

            // Установка указателя на память [ap]
            mem     <= I_LDXXA | I_LDAXX |

                       // При inc/dec, и операнд указывает на (hl)
                       (O_HLMEM_53 & (I_INCR8 | I_DECR8)) |

                       // При ld, один из операндов который указывает на (hl)
                       (I_LD & ( O_HLMEM_53 | O_HLMEM_20 )) |

                       // АЛУ-операци с памятью (hl)
                       (I_ALUR8 & O_HLMEM_20) |

                       // Указатель на память, есть переход ret/call/jp есть
                       ((I_RET_CCC) & K_JUMP_CCC) |

                       // Обязательные указатели в память
                       I_POP16 | I_RET | I_PUSH16 | I_RST | I_EXSPHL | I_IRQ;

            // Разрешение записи в память
            o_wr     <= I_LDXXA | (I_LD & O_HLMEM_53) | I_PUSH16 | I_RST | I_IRQ;

            // Нужно для того, чтобы знать, писать в ix/iy или нет
            postpref <= prefixed;

            // Флаг, который указывает, что перед инструкции был IX/IY-префикс (регистр prefix)
            // 1. Либо это IX/IY префикс
            // 2. Либо CBh - передать префикс далее
            prefixed <= (I_PREFIX_IX | I_PREFIX_IY) | (I_BITS & prefixed);

            // Сброс защелки порта
            port_clock <= 1'b0;

            // ------------------------------------------------------
            // Выполнение первого такта инструкции
            // ------------------------------------------------------

            // Вызов IRQ = rst # самый приоритетный
            // 11 aaa 111 rst #
            if (I_RST | I_IRQ) begin

                ap      <= sp - 2'h2;
                w_r     <= I_IRQ ? pc[15:8] : pcn[15:8];
                o_data  <= I_IRQ ? pc[7:0]  : pcn[7:0];
                t_state <= I_IRQ ? 4'h8 : 1'b1;

            end

            // 00 000 000 nop
            else if (I_NOP) pc <= pc + 1'b1;

            // DD IX префикс
            // FD IY префикс
            else if (I_PREFIX_IX | I_PREFIX_IY) begin

                pc     <= pc + 1'b1;
                prefix <= I_PREFIX_IY;

            end

            // 00 001 000 ex af, af`
            else if (I_EX_AF) begin

                bank_af <= !bank_af;
                pc      <= pc + 1'b1;

            end

            // 11 011 001 exx
            else if (I_EXX) begin

                bank_r  <= !bank_r;
                pc      <= pc + 1'b1;

            end

            // 11 101 001 jp (hl)
            else if (I_JPHL) begin

                pc      <= HL;
                t_state <= 1'b1;

            end

            // 11 111 001 ld sp, hl
            else if (I_LDSPHL) begin

                w_r16   <= HL;
                w_num16 <= 2'h3;
                pc      <= pc + 1'b1;

            end

            // 00 001 0000 djnz *
            else if (I_DJNZ) begin

                w_num <= `REG_B;
                w_r   <= B - 1'b1;

                // Условие выполнено, далее...
                if (B == 1'b1) begin

                    pc      <= pc + 2'h2;

                end else begin

                    pc      <= pc + 1'b1;
                    t_state <= 1'b1;

                end

            end

            // 00 001 1000 jr *
            else if (I_JR) begin

                t_state <= 1'b1;
                pc      <= pc + 1'b1;

            end

            // 00 1cc 000 jr cc, *
            else if (I_JR_CC8) begin

                // cc = nz, z, nc, c Условие было выполнено
                if (f[ o[4] ? `CF : `ZF] == o[3]) begin

                    t_state <= 1'b1;
                    pc      <= pc + 1'b1;

                // Условие не выполнено, пропуск rel8-байта
                end else pc <= pc + 2'h2;

            end

            // 00 xx0 001 ld r16, **
            else if (I_LD_R16I) begin

                w_num16 <= o[5:4];      // 0=BC, 1=DE, 2=HL, 3=SP
                pc      <= pc + 1'b1;
                t_state <= 1'b1;

            end

            // 00 xx1 001 ADD HL, <r16>
            else if (I_ADD_HLR16) begin

                w_r16   <= r_addhl_rr;  // Вычисление результата сложения
                flags   <= f_addhl_rr;
                w_num16 <= 2'b10;       // Результат записывается в HL
                pc      <= pc + 1'b1;

            end

            // 00 0x0 010 ld (bc, de), a
            // 00 0x1 010 ld a, (bc,de)
            else if (I_LDXXA | I_LDAXX) begin

                ap      <= o[4] ? DE : BC;
                o_data  <= A;
                pc      <= pc + 1'b1;
                t_state <= 1'b1;

            end

            // 00 1x0 010 ld (**), (hl,a)
            // 00 1x1 010 ld (a,hl), (**)
            else if (I_nnnn_HLA) begin

                pc      <= pc + 1'b1;
                t_state <= 1'b1;

            end

            // 00 xx0 011 inc r16
            // 00 xx1 011 dec r16
            else if (I_INCR16 | I_DECR16) begin

                // Прибавление или вычитание из 16-битного регистра. Флаги не меняются.
                w_r16   <= o[5:4] == 2'b00 ? (I_INCR16 ? BC + 1'b1 : BC - 1'b1) :
                           o[5:4] == 2'b01 ? (I_INCR16 ? DE + 1'b1 : DE - 1'b1) :
                           o[5:4] == 2'b10 ? (I_INCR16 ? HL + 1'b1 : HL - 1'b1) :
                                             (I_INCR16 ? sp + 1'b1 : sp - 1'b1);

                w_num16 <= o[5:4];
                pc      <= pc + 1'b1;

            end

            // 00 xxx 100 inc r8
            // 00 xxx 101 dec r8
            else if (I_INCR8 | I_DECR8) begin

                w_r     <= r_incdec_r8;
                w_num   <= {o[5:4], !o[3]};
                pc      <= pc + 1'b1;

                // Если происходит работа с (hl)
                if (O_HLMEM_53) begin t_state <= 1'b1; ap <= HL; end
                           else begin t_state <= 1'b0; flags <= f_incdec_r8; end

            end

            // 00 xxx 110 ld r8, *
            else if (I_LDR8I) begin

                pc      <= pc + 1'b1;
                t_state <= 1'b1;
                w_num   <= {o[5:4], !o[3]};

            end

            // 00 xxx 111 = {rlca, rrca, rla, rra, daa, cpl, scf, ccf}
            else if (I_SSDAA) begin

                w_num <= `REG_A;
                pc    <= pc + 1'b1;

                case (o[5:3])

                    // [DAA] Вообще не нужная функция. @todo сделать http://www.z80.info/z80syntx.htm#DAA
                    3'b100: begin w_r <= A; flags <= F[7:0]; end

                    // CPL
                    3'b101: begin

                        //         S Z     F5     H     F3     P/V   N     C
                        flags <= { F[7:6], !A[5], 1'b1, !A[3], F[2], 1'b1, F[0]};
                        w_r   <= A ^ 8'hFF;

                    end

                    3'b110: flags <= {F[7:5], 1'b0, F[3:2], 1'b0, 1'b1}; // scf
                    3'b111: flags <= {F[7:5], 1'b0, F[3:2], 1'b0, 1'b0}; // ccf

                    // rlca, rrca, rla, rra
                    // Выставление флагов согласовано, как в Z80
                    default: begin

                        w_r   <= r_gs;
                        flags <= f_gs_fin;

                    end

                endcase

            end

            // 01 aaa bbb ld <a>, <b>
            else if (I_LD) begin

                ap    <= HL;              // Чтение / Запись в память
                w_num <= {o[5:4], !o[3]}; // Для записи в регистр

                // HALT - остановить процессор
                if (o[5:0] == 6'b110110) begin

                    // .. и ничего не делать, так и будет тут стоять ..

                end
                // А. Запись в (hl) 2Т
                else if (o[5:3] == 3'b110) begin

                    o_data  <= r8_20;
                    pc      <= pc + 1'b1;
                    t_state <= 1'b1;

                end
                // B. Чтение из (hl) 2Т
                else if (o[2:0] == 3'b110) begin

                    pc      <= pc + 1'b1;
                    t_state <= 1'b1;

                end
                // C. Писать из регистра в регистр (1Т)
                else begin

                    w_r     <= r8_20;
                    pc      <= pc + 1'b1;

                end

            end

            // 10 aaa rrr <alu> a, r8
            else if (I_ALUR8) begin

                w_num   <= `REG_A;
                w_r     <= r_alur8[7:0];
                flags   <= f_alur8;
                ap      <= HL;
                pc      <= pc + 1'b1;

                // Читать из памяти (hl) операнд
                if (O_HLMEM_20) t_state <= 1'b1;

            end

            // 11 ccc 000 ret <ccc>
            // 11 xx0 001 pop r16
            // 11 001 001 ret
            else if (I_RET_CCC | I_POP16 | I_RET) begin

                ap      <= sp;
                pc      <= pc + 1'b1;
                t_state <= K_JUMP_CCC | I_POP16 | I_RET;

            end

            // 11 ccc 010 jp <ccc>
            // 11 000 011 jp **
            // 11 ccc 100 call <ccc>
            else if (I_JP_CCC | I_CALL_CCC | I_JP | I_CALL) begin

                // Если Condition не сработал, то пропуск PC + 3
                pc      <= K_JUMP_CCC | I_JP | I_CALL? pc + 1'b1 : pc + 2'h3;
                t_state <= K_JUMP_CCC | I_JP | I_CALL;

            end

            // 11 xx0 101 push r16
            else if (I_PUSH16) begin

                // Писать сначала Lo-байт
                o_data  <= o[5:4] == 2'b00 ? C : // BC
                           o[5:4] == 2'b01 ? E : // DE
                           o[5:4] == 2'b10 ? L : F; // HL, AF

                ap      <= sp - 2'h2;
                pc      <= pc + 1'b1;
                t_state <= 1'b1;

            end

            // 11 aaa 110 <alu> a, *
            else if (I_ADDI8) begin

                w_num   <= `REG_A;
                pc      <= pc + 1'b1;
                t_state <= 1'b1;

            end

            // DI / EI
            else if (I_DI | I_EI) begin

                pc <= pc + 1'b1;
                ie <= I_EI;

            end

            // EX DE, HL
            else if (I_EXDEHL) begin

                w_r16   <= HL;
                w_num16 <= 2'b01;   // Записать HL в DE
                ap      <= DE;
                pc      <= pc + 1'b1;
                t_state <= 1'b1;

            end

            // EX (SP), HL
            else if (I_EXSPHL) begin

                pc      <= pc + 1'b1;
                ap      <= sp;
                t_state <= 1'b1;

            end

            // CB <bit prefix>
            else if (I_BITS) begin

                t_state <= 1'b1;
                ap      <= HL;
                pc      <= pc + 1'b1;

            end

            // D3 out (*), a
            // DB in a, (*)
            else if (I_OUT8A | I_INA8) begin

                pc      <= pc + 1'b1;
                t_state <= 2'h1;

            end

            opc <= i_data;

        end

        /* *******************************************************************
         * TICK 2
         */

        4'h1: begin

            // JR, DJNZ, JR cc
            if (I_DJNZ || I_JR || I_JR_CC8) begin

                pc      <= pc + {{8{i_data[7]}}, i_data[7:0]} + 1'b1;
                t_state <= 1'b0;

            end

            // LD r16, i16 - lb
            else if (I_LD_R16I) begin

                w_r16[7:0] <= i_data;
                pc         <= pc + 1'b1;
                t_state    <= 2'h2;

            end

            // LD (bc, de), a
            else if (I_LDXXA) begin

                o_wr    <= 1'b0; // Отключить запись в память
                mem     <= 1'b0; // А также сделать чтение из [PC+1]
                t_state <= 1'b0;

            end

            // LD a, (bc, de)
            else if (I_LDAXX) begin

                w_reg   <= 1'b1;   // Запись i_data
                w_r     <= i_data; // i_data
                w_num   <= `REG_A; // в регистр A
                mem     <= 1'b0;
                t_state <= 1'b0;

            end

            // LD (***) <> [hl | a]
            else if (I_nnnn_HLA) begin

                ap[7:0] <= i_data;   // Считывание младшего байта смещения
                pc      <= pc + 1'b1;
                t_state <= 2'h2;

            end

            // INC/DEC (hl)
            else if (I_INCR8 | I_DECR8) begin

                o_data  <= r_incdec_r8;
                o_wr    <= 1'b1;
                t_state <= 2'h2;
                w_flag  <= 1'b1;
                flags   <= f_incdec_r8;

            end

            // LD r8, *
            else if (I_LDR8I) begin

                // Если данные загружаются в (hl)
                if (O_HLMEM_53) begin

                    ap      <= HL;
                    o_data  <= i_data;
                    mem     <= 1'b1;
                    o_wr    <= 1'b1;
                    t_state <= 2'h2;

                // Либо i8 пишется в регистр
                end else begin

                    w_r     <= i_data;
                    w_reg   <= 1'b1;
                    t_state <= 1'b0;

                end

                pc <= pc + 1'b1;

            end

            // LD (hl), r8 | r8, (HL)
            else if (I_LD) begin

                // Запись в регистр из памяти
                if ((o[2:0] == 3'b110)) begin w_r <= i_data; w_reg <= 1'b1; end

                // Выход
                o_wr    <= 1'b0;
                mem     <= 1'b0;
                t_state <= 1'b0;

            end

            // <ALU> a, (hl)
            // <ALU> a, *
            else if (I_ALUR8 | I_ADDI8) begin

                // CP не писать результат
                if (o[5:3] != 3'b111) w_reg <= 1'b1;

                w_r     <= r_alur8[7:0];
                mem     <= 1'b0;
                w_flag  <= 1'b1;
                flags   <= f_alur8;
                t_state <= 1'b0;

                if (I_ADDI8) pc <= pc + 1'b1;

            end

            // RET/RET <ccc>/POP 16
            else if (I_RET_CCC | I_POP16 | I_RET) begin

                w_r     <= i_data;    // Считывание младшего байта
                ap      <= ap + 1'b1; // К старшему байту
                t_state <= 2'h2;

                // sp <- sp + 2'h2
                w_r16    <= sp + 2'h2;
                w_reg16  <= 1'b1;
                w_num16  <= 2'h3;

            end

            // JP **
            else if (I_JP_CCC | I_CALL_CCC | I_JP | I_CALL) begin

                w_r     <= i_data;
                pc      <= pc + 1'b1;
                t_state <= 2'h2;

            end

            // JP (HL)
            else if (I_JPHL) begin

                w_r     <= i_data;
                pc      <= pc + 1'b1;
                t_state <= 2'h2;

            end

            // PUSH r16
            else if (I_PUSH16) begin

                // Писать Hi-байт
                o_data  <= o[5:4] == 2'b00 ? B : // BC
                           o[5:4] == 2'b01 ? D : // DE
                           o[5:4] == 2'b10 ? H : A; // HL, AF

                ap      <= ap + 1'b1;
                t_state <= 4'h4;

            end

            // EX DE, HL
            else if (I_EXDEHL) begin

                w_r16   <= ap;
                w_num16 <= 2'b10;   // Записать DE в HL
                t_state <= 1'b0;

            end

            // EX (SP), HL
            else if (I_EXSPHL) begin

                w_r16[7:0] <= i_data;
                ap         <= ap + 1'b1;
                t_state    <= 2'h2;

            end

            // BIT операции
            else if (I_BITS) begin

                pc        <= pc + 1'b1;
                opc_cb    <= i_data;
                prefixed  <= 1'b0;

                // Продолжить считывание из (hL)
                if (O_HLMEM_20) begin

                    mem     <= 1'b1;
                    t_state <= 2'h2;

                end

                // Либо сразу обработать регистр
                else begin

                    t_state <= 1'b0;
                    w_flag  <= gc[7:6] <  2'h2;   // Только для ShGrp / BIT
                    w_reg   <= gc[7:6] != 2'b01;  // Писать результат всем, кроме bit
                    w_num   <= {gc[2:1], !gc[0]}; // Куда писать
                    w_r     <= r_gs_fin;          // Что писать
                    flags   <= f_gs_fin;

                end

            end

            // OUT (*), A -- вывод данных в порт
            else if (I_OUT8A) begin

                pc         <= pc + 1'b1;
                port_addr  <= i_data;
                port_data  <= A;
                port_clock <= 1'b1;
                t_state    <= 1'b0;

            end

            // IN A, (*)
            else if (I_INA8) begin

                pc         <= pc + 1'b1;
                port_addr  <= i_data;
                t_state    <= 2'h2;

            end

            // RST #
            else if (I_RST) begin

                o_data  <= w_r;
                ap      <= ap + 1'b1;
                pc      <= {o[5:3], 3'b000};
                t_state <= 4'h4;

            end

        end

        /* *******************************************************************
         * TICK 3
         */

        4'h2: begin

            // LD r16, i16 - hb
            if (I_LD_R16I) begin

                w_r16[15:8] <= i_data;
                pc      <= pc + 1'b1;
                w_reg16 <= 1'b1;
                t_state <= 1'b0;

            end

            // LD (***) <> [hl | a]
            else if (I_nnnn_HLA) begin

                ap[15:8] <= i_data;
                pc       <= pc + 1'b1;
                mem      <= 1'b1;                   // Указатель на память (для чтения/записи)
                o_data   <= o[4] ? A : L;           // Пишем либо L, либо A
                t_state  <= 4'h3;

                // Начать писать в память в случае ld (**), [hl | a]
                if (o[3] == 1'b0) o_wr <= 1'b1;

            end

            // INC/DEC (hl), LD (HL), *
            else if (I_INCR8 | I_DECR8 | I_LDR8I) begin

                o_wr    <= 1'b0;
                mem     <= 1'b0;
                t_state <= 1'b0;

            end

            // RET/RET <ccc>
            else if (I_RET_CCC | I_RET) begin

                 // Переход на адрес, полученный из стека
                pc       <= {i_data[7:0], w_r[7:0]};
                mem      <= 1'b0;
                w_reg16  <= 1'b0;
                t_state  <= 1'b0;

            end

            // POP R16
            else if (I_POP16) begin

                 // Полученные из стека данные
                w_r16   <= {i_data[7:0], w_r[7:0]};
                w_r16af <= o[5:4] == 2'b11; // Писать в AF при POP AF
                w_num16 <= o[5:4]; // Куда писать результат
                mem     <= 1'b0;
                t_state <= 1'b0;

            end

            // JP (HL), JP, CALL
            else if (I_JPHL | I_JP_CCC| I_CALL_CCC | I_JP | I_CALL) begin

                w_r     <= pcn[15:8]; // hi-байт
                o_data  <= pcn[7:0];  // lo-байт
                ap      <= sp - 2'h2;
                pc      <= {i_data[7:0], w_r[7:0]};

                // Сохранение в стек
                if (I_CALL_CCC | I_CALL) begin

                    o_wr    <= 1'b1;
                    mem     <= 1'b1;
                    t_state <= 4'h3;

                end else t_state <= 1'b0;


            end

            // EX (SP), HL
            else if (I_EXSPHL) begin

                w_r16[15:8] <= i_data;
                w_reg16     <= 1'b1;        // Писать в HL значение из памяти
                w_num16     <= 2'h2;        // в 2=HL
                ap          <= ap - 1'b1;   // Теперь писать в память что было в HL
                o_data      <= L;           // Писать младший байт в память
                w_r         <= H;           // Сохранить прежнее значение HL
                o_wr        <= 1'b1;
                t_state     <= 2'h3;

            end

            // Битовые операции над HL
            else if (I_BITS) begin

                t_state <= 3'h4;
                w_flag  <= gc[7:6] <  2'h2;   // Только для ShGrp / BIT
                o_wr    <= 1'b1;
                w_num   <= {gc[2:1], !gc[0]}; // Куда писать
                o_data  <= r_gs_fin;          // Что писать
                flags   <= f_gs_fin;

            end

            // IN A, (*)
            else if (I_INA8) begin

                w_reg   <= 1'b1;
                w_num   <= `REG_A;
                w_r     <= port_in; // Записать из порта значение
                t_state <= 1'b0;

            end

        end

        /* *******************************************************************
         * TICK 4
         */

        4'h3: begin

            // LD (***) <> [hl | a]
            if (I_nnnn_HLA) begin

                // Запись из памяти в регистр: o[4] = (L, A)
                if (o[3]) begin

                    w_r    <= i_data;
                    w_num  <= o[4] ? `REG_A : `REG_L; // Читаем также (зависит от o[3])
                    w_reg  <= 1'b1;

                    // Если записываем в A, то выход из процедуры
                    if (o[4]) begin

                        mem     <= 1'b0;
                        t_state <= 1'b0;

                    // Иначе будем писать H на следующем этапе
                    end else begin

                        t_state <= 4'h4;
                        ap      <= ap + 1'b1;

                    end

                // Запись в память из A, H
                end else begin

                    // Если была запись регистра A, отключение записи в память, переход к 0-му состоянию
                    if (o[4]) begin

                        mem     <= 1'b0;
                        o_wr    <= 1'b0;
                        t_state <= 1'b0;

                    // Иначе пишем H
                    end else begin

                        o_data  <= H;
                        ap      <= ap + 1'b1;
                        t_state <= 4'h4;

                    end

                end

            end

            // CALL
            else if (I_CALL_CCC | I_CALL) begin

                o_data  <= w_r;
                ap      <= ap + 1'b1;
                t_state <= 4'h4;

            end

            // EX (SP), HL
            else if (I_EXSPHL) begin

                o_data  <= w_r;
                ap      <= ap + 1'b1;
                t_state <= 4'h4;
                w_reg16 <= 1'b0;

            end

        end

        /* *******************************************************************
         * TICK 5
         */

        4'h4: begin

            // LD (***) <> [hl | a]
            if (I_nnnn_HLA) begin

                // Запись в H, и выход
                if (o[3]) begin w_num <= `REG_H; w_r <= i_data; end

                // Выход и закрытие сохранении в память
                mem     <= 1'b0;
                o_wr    <= 1'b0;
                t_state <= 1'b0;

            end

            // EX (SP), HL Просто завершить запись
            else if (I_EXSPHL | I_BITS) begin

                o_wr    <= 1'b0;
                mem     <= 1'b0;
                t_state <= 1'b0;


            end

            // CALL
            else if (I_CALL_CCC | I_CALL | I_PUSH16 | I_RST) begin

                o_wr    <= 1'b0;
                mem     <= 1'b0;
                t_state <= 1'b0;

                // sp = sp - 2
                w_reg16 <= 1'b1;
                w_r16   <= sp - 2'h2;
                w_num16 <= 3'h3;

            end

        end

        /*
         * IRQ handler
         */
        4'h8: begin

            o_data  <= w_r;
            ap      <= ap + 1'b1;
            pc      <= {irq, 3'b000};
            irq     <= 1'b0;
            t_state <= 4'h9;

        end

        4'h9: begin

            o_wr    <= 1'b0; mem   <= 1'b0;      t_state <= 1'b0; // Переход на 0-й такт
            w_reg16 <= 1'b1; w_r16 <= sp - 2'h2; w_num16 <= 3'h3; // Запись SP = SP - 2

        end

    endcase

end

endmodule
