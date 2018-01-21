`ifndef __mod_alu
`define __mod_alu

/*
 * На вход
 */
 
// Следующий PC
wire [15:0] pcn = pc + 1'b1;

// Инструкция INC/DEC r8
// --------------------------------------------------------------------------------
wire [7:0] r_incdec_r8 = t_state != 0 ? (I_INCR8 ? i_data + 1'b1 : i_data - 1'b1) : // Инкремент в памяти (hl)
                                        (I_INCR8 ? r8_53  + 1'b1 : r8_53  - 1'b1);  // Для инкремента регистров

// Подсчет четности результата                                        
wire       r_incdec_pb = r_incdec_r8[7] ^ r_incdec_r8[6] ^ r_incdec_r8[5] ^ r_incdec_r8[4] ^ 
                         r_incdec_r8[3] ^ r_incdec_r8[2] ^ r_incdec_r8[1] ^ r_incdec_r8[0] ^ 1'b1;

wire [7:0] f_incdec_r8 = {r_incdec_r8[7],      // Знак
                          r_incdec_r8 == 1'b0, // Результат - ноль?
                          r_incdec_r8[5],      // F5 -> копируется
                          r_incdec_r8[3:0] == (I_INCR8 ? 4'h0 : 4'hf), // Полуперенос?
                          r_incdec_r8[3],      // F3 -> копируется
                          r_incdec_pb,         // Четность результата      
                          1'b0, 
                          F[0]};

// ADD HL, <rr>
// --------------------------------------------------------------------------------  
wire [16:0] r_addhl_op = o[5:4] == 2'b00 ? BC :
                         o[5:4] == 2'b01 ? DE :
                         o[5:4] == 2'b10 ? HL : sp;

// Выполнение сложения числа
wire [16:0] r_addhl_rr = HL + r_addhl_op; 
wire        r_addhl_hc = ((HL[3] | r_addhl_op[3]) & r_addhl_rr[3]) | (HL[3] & r_addhl_op[3] & r_addhl_rr[3]);

// Определение флагов
wire [7:0]  f_addhl_rr = {F[7:6],          // S,Z не меняются
                          r_addhl_rr[13],  // F5 Копируется из бита 5 старшего байта результата                           
                          r_addhl_hc,      // Полуперенос 
                          r_addhl_rr[11],  // F3 Аналогично F5
                          F[2],            // P/V не затрагивается
                          1'b0,            // N=0, операция ADD
                          r_addhl_rr[16]}; // Перенос (carry)

// <ALU> a, OP
// --------------------------------------------------------------------------------
// 0=add 1=adc 2=sub 3=sbc 4=and 5=xor 6=or 7=cp
wire [7:0]  r_aluop = t_state ? i_data : r8_20;
wire [8:0]  r_alur8 = o[5:3] == 3'b000 ? A + r_aluop : 
                      o[5:3] == 3'b001 ? A + r_aluop + F[0] : 
                      o[5:3] == 3'b011 ? A - r_aluop - F[0] : 
                      o[5:3] == 3'b100 ? A & r_aluop : 
                      o[5:3] == 3'b101 ? A ^ r_aluop : 
                      o[5:3] == 3'b110 ? A | r_aluop : (A - r_aluop); // 010 SUB = 111 CP

// Определить, что это SUB/SBC/CP операции
wire        r_is_sub   = (o[5:3] == 3'b011) | (o[5:3] == 3'b111) | (o[5:3] == 3'b010); // Это вычитание
wire        r_is_logic = (o[5:3] == 3'b100) | (o[5:3] == 3'b101) | (o[5:3] == 3'b110); // Это логические

// Выставить соответственно, carry флаг
wire        r_carry8 = r_alur8[8];

// Halfcarry Add Table
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Предположим, что a = A, b = r_aluop, c = r_alur8
// Таблица
// c b a | half_carry
// 0 0 0 | 0
// 0 0 1 | 1
// 0 1 0 | 1
// 0 1 1 | 1
// 1 0 0 | 0
// 1 0 1 | 0
// 1 1 0 | 0
// 1 1 1 | 1
// тогда half_carry = (a + b) & !c + a*b*c

wire        r_half_add_1 = ((A[3] | r_aluop[3]) & r_alur8[3]) | (A[3] & r_aluop[3] & r_alur8[3]);
wire        r_half_add_2 = ((A[7] | r_aluop[7]) & r_alur8[7]) | (A[7] & r_aluop[7] & r_alur8[7]);
wire        r_half_add   = r_half_add_1 | r_half_add_2;

// Halfcarry Sub Table
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Предположим, что a = A, b = r_aluop, c = r_alur8
// Таблица:
// c b a | half_carry
// 0 0 0 | 0
// 0 0 1 | 0
// 0 1 0 | 1
// 0 1 1 | 0
// 1 0 0 | 1
// 1 0 1 | 0
// 1 1 0 | 1
// 1 1 1 | 1
// тогда half_carry = !a * (b xor c) + b*c

// 7-й и 3-й биты SUB:
wire        r_half_sub_1 = (!A[3] & (r_aluop[3] ^ r_alur8[3])) | (r_aluop[3] & r_alur8[3]);
wire        r_half_sub_2 = (!A[7] & (r_aluop[7] ^ r_alur8[7])) | (r_aluop[7] & r_alur8[7]);
wire        r_half_sub   = r_half_sub_1 | r_half_sub_2;

// Флаг четности @todo для логических операции
wire        r_parity8 = r_alur8[7] ^ r_alur8[6] ^ r_alur8[5] ^ r_alur8[4] ^ 
                        r_alur8[3] ^ r_alur8[2] ^ r_alur8[1] ^ r_alur8[0] ^ 1'b1;
                        
// Таблица overflow для add / sub
// c b a | add sub
// 0 0 0 | 0   0
// 0 0 1 | 0   1
// 0 1 0 | 0   0
// 0 1 1 | 1   0
// 1 0 0 | 1   0
// 1 0 1 | 0   0
// 1 1 0 | 0   1
// 0 1 1 | 0   0
// add = a *  b * !c | !a * !b * c
// sub = a * !b * !c | !a *  b * c 

wire        r_overflow_add = (A[7] &  r_aluop[7] & !r_alur8[7]) | (!A[7] & !r_aluop[7] & r_alur8[7]);
wire        r_overflow_sub = (A[7] & !r_aluop[7] & !r_alur8[7]) | (!A[7] &  r_aluop[7] & r_alur8[7]);

// Результирующие флаги от 8-битной АЛУ-операции
wire [7:0]  f_alur8 = {r_alur8[7],           // S=знак
                       r_alur8[7:0] == 1'b0, // Z=нуль
                       r_alur8[5],           // F5 копируется
                       r_is_sub ? r_half_sub : r_half_add, // HalfCarry = ADD/SUB
                       r_alur8[3],           // F3 копируется
                       // Parity / oVerflow
                       r_is_logic ? r_parity8 :(r_is_sub ? r_overflow_sub : r_overflow_add),
                       r_is_sub,             // N - Sub, Sbc или Cp 
                       r_carry8              // Carry
                      };

// <SHIFT> <operand>
// --------------------------------------------------------------------------------
wire [7:0]  gs      = t_state == 2'h1 ? r8_20 : // <grp> reg8
                      t_state == 2'h2 ? i_data :   // <grp> (hl)
                                        A;      // rlca, rrca, rla, rra

// Вычисление смещения
wire [7:0]  r_gs    =   gc[5:3] == 3'b000 ? {gs[6:0],gs[7]} : // rlc
                        gc[5:3] == 3'b001 ? {gs[0],gs[7:1]} : // rrc
                        gc[5:3] == 3'b010 ? {gs[6:0],F[0]}  : // rl
                        gc[5:3] == 3'b011 ? {F[0],gs[7:1]}  : // rr
                        gc[5:3] == 3'b100 ? {gs[6:0],1'b0}  : // sla
                        gc[5:3] == 3'b101 ? {gs[7],gs[7:1]} : // sra
                        gc[5:3] == 3'b110 ? {gs[6:0],1'b0}  : // sll
                                            {1'b0,gs[7:1]};   // srl

// RES b,r
wire [7:0]  r_gs_res =  gc[5:3] == 3'b000 ? {gs[7:1],1'b0} :
                        gc[5:3] == 3'b001 ? {gs[7:2],1'b0,gs[0]} :
                        gc[5:3] == 3'b010 ? {gs[7:3],1'b0,gs[1:0]} :
                        gc[5:3] == 3'b011 ? {gs[7:4],1'b0,gs[2:0]} :
                        gc[5:3] == 3'b100 ? {gs[7:5],1'b0,gs[3:0]} :
                        gc[5:3] == 3'b101 ? {gs[7:6],1'b0,gs[4:0]} :
                        gc[5:3] == 3'b110 ? {gs[7:7],1'b0,gs[5:0]} :
                                                    {1'b0,gs[6:0]};

// SET b,r
wire [7:0]  r_gs_set =  gc[5:3] == 3'b000 ? {gs[7:1],1'b1} :
                        gc[5:3] == 3'b001 ? {gs[7:2],1'b1,gs[0]} :
                        gc[5:3] == 3'b010 ? {gs[7:3],1'b1,gs[1:0]} :
                        gc[5:3] == 3'b011 ? {gs[7:4],1'b1,gs[2:0]} :
                        gc[5:3] == 3'b100 ? {gs[7:5],1'b1,gs[3:0]} :
                        gc[5:3] == 3'b101 ? {gs[7:6],1'b1,gs[4:0]} :
                        gc[5:3] == 3'b110 ? {gs[7:7],1'b1,gs[5:0]} :
                                                    {1'b1,gs[6:0]};

// Финальный результат
wire [7:0]  r_gs_fin =  gc[7:6] == 2'b00 ? r_gs :     // shift
                        gc[7:6] == 2'b01 ? r_gs :     // bit
                        gc[7:6] == 2'b10 ? r_gs_res : // rest
                                          r_gs_set;
                                           
// Финальные флаги
// Одинаковые, но для 0,2,4,6 - из бита 7, а 1,3,5,7 - из 0-го
wire [7:0]  f_gs_fin =  gc[7:6] == 2'b00 ? 
                        {F[7:5], 1'b0, F[3:2], 1'b0, gc[3] ? gs[0] : gs[7]} :    // ShGRP
                        
                        // S   Z               F5     H     -  -    0     -
                        {F[7], !gs[ gc[5:3] ], F[5], 1'b0, F[3:2], 1'b0, F[0]};  // BIT
                                           

`endif
