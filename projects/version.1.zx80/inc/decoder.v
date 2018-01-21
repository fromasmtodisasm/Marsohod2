`ifndef __mod_decoder
`define __mod_decoder

// Опкод, независимый от t_state
wire [7:0] o = t_state ? opc : i_data;

// Декодирование инструкции

// grp-1
wire I_NOP          = o == 8'h00;
wire I_EX_AF        = o == 8'h08;
wire I_DJNZ         = o == 8'h10;
wire I_JR           = o == 8'h18;
// grp-2
wire I_RET          = o == 8'hC9;
wire I_EXX          = o == 8'hD9;
wire I_JPHL         = o == 8'hE9;
wire I_LDSPHL       = o == 8'hF9;
// grp-3
wire I_JP           = o == 8'hC3;
wire I_CALL         = o == 8'hCD;
wire I_DI           = o == 8'hF3;
wire I_EI           = o == 8'hFB;
wire I_EXDEHL       = o == 8'hEB;
wire I_EXSPHL       = o == 8'hE3;
wire I_BITS         = o == 8'hCB;
wire I_PREFIX_IX    = o == 8'hDD;
wire I_PREFIX_ED    = o == 8'hED;
wire I_PREFIX_IY    = o == 8'hFD;
wire I_OUT8A        = o == 8'hD3;
wire I_INA8         = o == 8'hDB;
// grp
wire I_JR_CC8       = {o[7:5], o[2:0]} == 6'b001000;    // 00 1xx 000   jr cc, *
wire I_LD_R16I      = {o[7:6], o[3:0]} == 6'b000001;    // 00 xx0 001   ld r16, **
wire I_ADD_HLR16    = {o[7:6], o[3:0]} == 6'b001001;    // 00 xx1 001   add r16, **
wire I_LDXXA        = {o[7:5], o[3:0]} == 7'b0000010;   // 00 0x0 010   ld (bc|de), a
wire I_LDAXX        = {o[7:5], o[3:0]} == 7'b0001010;   // 00 0x1 010   ld a, (bc|de)
wire I_nnnn_HLA     = {o[7:5], o[2:0]} == 6'b001010;    // 00 1xx 010   ld (**),a/hl | ld a/hl,(**)
wire I_INCR16       = {o[7:6], o[3:0]} == 6'b000011;    // 00 xx0 011   inc 16
wire I_DECR16       = {o[7:6], o[3:0]} == 6'b001011;    // 00 xx1 011   dec r16
wire I_INCR8        = {o[7:6], o[2:0]} == 5'b00100;     // 00 xxx 100   inc r8
wire I_DECR8        = {o[7:6], o[2:0]} == 5'b00101;     // 00 xxx 101   dec r8
wire I_LDR8I        = {o[7:6], o[2:0]} == 5'b00110;     // 00 xxx 110   ld  r8, *
wire I_SSDAA        = {o[7:6], o[2:0]} == 5'b00111;     // 00 xxx 111   rlca, rrca, rla, rra, daa, cpl, scf, ccf
wire I_LD           = {o[7:6]} == 2'b01;                // 01 aaa bbb   ld <a>, <b>
wire I_ALUR8        = {o[7:6]} == 2'b10;                // 10 aaa rrr   <alu> a, r8
wire I_POP16        = {o[7:6], o[3:0]} == 6'b110001;    // 11 xx0 001   pop r16
wire I_RET_CCC      = {o[7:6], o[2:0]} == 5'b11000;     // 11 ccc 000   ret <ccc>
wire I_JP_CCC       = {o[7:6], o[2:0]} == 5'b11010;     // 11 ccc 010   jp <ccc>, **
wire I_CALL_CCC     = {o[7:6], o[2:0]} == 5'b11100;     // 11 ccc 100   call <ccc>, **
wire I_PUSH16       = {o[7:6], o[3:0]} == 6'b110101;    // 11 xx0 101   push r16
wire I_ADDI8        = {o[7:6], o[2:0]} == 5'b11110;     // 11 aaa 110   <alu> a, *
wire I_RST          = {o[7:6], o[2:0]} == 5'b11111;     // 11 aaa 111   rst #
wire I_IRQ          = (irq != 1'b0);                    // Был вызван IRQ 

// Выбрать источник данных для битовых операции
// Если используется битовый префикс, опкод будет из DIN
wire [7:0] gc       = I_BITS ? (t_state == 1'b1 ? i_data : opc_cb) : o;

// 6-й регистр указывает на пам¤ть (hl)
wire O_HLMEM_53     = gc[5:3] == 3'h6;
wire O_HLMEM_20     = gc[2:0] == 3'h6;

// Источник данных из --rrr---
wire [7:0] r8_53    = gc[5:3] == 3'b000 ? B : 
                      gc[5:3] == 3'b001 ? C : 
                      gc[5:3] == 3'b010 ? D : 
                      gc[5:3] == 3'b011 ? E : 
                      gc[5:3] == 3'b100 ? H : 
                      gc[5:3] == 3'b101 ? L : A;

// Источник данных из -----rrr
wire [7:0] r8_20    = gc[2:0] == 3'b000 ? B : 
                      gc[2:0] == 3'b001 ? C : 
                      gc[2:0] == 3'b010 ? D : 
                      gc[2:0] == 3'b011 ? E : 
                      gc[2:0] == 3'b100 ? H : 
                      gc[2:0] == 3'b101 ? L : A;

// Определить условие для перехода дл¤ ret, call, jp

                     // Zero
wire K_JUMP_CCC    = o[5:3] == 3'b000 & !F[`ZF] | // NZ
                     o[5:3] == 3'b001 &  F[`ZF] | // Z
                     // Carry
                     o[5:3] == 3'b010 & !F[`CF] | // NC
                     o[5:3] == 3'b011 &  F[`CF] | // C
                     // Parity
                     o[5:3] == 3'b100 & !F[`PVF] | // PO, P=0 
                     o[5:3] == 3'b101 &  F[`PVF] | // PE, P=1                      
                     // Sign (Plus/Minus)
                     o[5:3] == 3'b110 & !F[`SF] |  // P
                     o[5:3] == 3'b111 &  F[`SF];   // M

`endif
