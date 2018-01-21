`ifndef __mod_regs
`define __mod_regs

// Объявление имен флагов
`define SF  7
`define ZF  6
`define HF  4
`define PVF 2
`define NF  1
`define CF  0

// Bit  | 7 6 5  4 3  2   1 0
// Flag | S Z F5 H F3 P/V N C
// S-Sign, Z-Zero, H-Half, P/V-Parity/Overflow, N-Substract (если было вычитание), C-Carry

// Первый / второй набор регистров
reg [7:0] a;   reg [7:0] a_;
reg [7:0] f;   reg [7:0] f_;
reg [7:0] b;   reg [7:0] b_;
reg [7:0] c;   reg [7:0] c_;
reg [7:0] d;   reg [7:0] d_;
reg [7:0] e;   reg [7:0] e_;
reg [7:0] h;   reg [7:0] h_;
reg [7:0] l;   reg [7:0] l_;

// Индексные
reg [7:0] xh;  reg [7:0] xl;
reg [7:0] yh;  reg [7:0] yl;

// i[15:8], r[7:0] специальные регистры
reg [15:0] ir;

reg [15:0]  ap;     // address pointer (указатель на сканируемую область в памяти)
reg [15:0]  pc;     // program counter
reg [15:0]  sp;     // stack pointer
reg         ie;     // Interrupt Enabled = 0/1

// ------------------------------------------------------------------------

// Алиасы 8-битных регистров. Зависит от текущего банка с регистрами
wire [7:0] A = bank_af ? a_ : a;
wire [7:0] F = bank_af ? f_ : f;
wire [7:0] B = bank_r  ? b_ : b;
wire [7:0] C = bank_r  ? c_ : c;
wire [7:0] D = bank_r  ? d_ : d;
wire [7:0] E = bank_r  ? e_ : e;
wire [7:0] H = is_prefix ? (prefix ? yh : xh) : (bank_r  ? h_ : h);
wire [7:0] L = is_prefix ? (prefix ? yl : xl) : (bank_r  ? l_ : l);

// Алиасы для 16-битных регистров
wire [15:0] BC = {B, C};
wire [15:0] DE = {D, E};
wire [15:0] HL = {H, L};

// На t_state = 0 значимым является prefix для считывания, на t_state - postpref
wire        is_prefix = (prefixed & (t_state == 1'b0)) | ((t_state != 1'b0) & postpref);

// Управляющие регистры 
// ------------------------------------------------------------------------
reg         mem;                    // =0 (указатель на PC), =1 (AP)
reg         w_reg;                  // Если =1, то на обратном фронте будет записан регистр
reg         w_reg16;                // =1 писать в bc, de, hl, sp 
reg         w_r16af;                // =1 писать в af
reg [7:0]   w_r;                    // Источник записи для w_mode = 0
reg [15:0]  w_r16;                  // Для w_reg16 = 1
reg [2:0]   w_num;                  // Номер регистра на запись
reg [1:0]   w_num16;                // (bc,de,hl,sp)
reg         bank_r;                 // =0 (основной набор регистров) =1 (дополнительный)
reg         bank_af;                // =0 (основной af), =1 (доп)
reg         w_flag;                 // =1 разрешить запись в flags
reg [7:0]   flags;                  // Подготовленные флаги для записи в f, f`

// Префиксы
reg         prefixed;               // Для t_state = 0
reg         postpref;               // Для t_state > 0
reg         prefix;                 // 0=ix, 1=iy
reg [7:0]   opc_pf;                 // Полученный код из префиксного IX/IY

// Текущий опкод
reg [7:0]   opc;
reg [7:0]   opc_cb;                 // Сохраненное для CB-префикса
reg [3:0]   t_state;                // Машинное состояние t=0..n

`endif