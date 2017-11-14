// Ядро AVR для эмуляции других процессоров

module core(

    input  wire        CLK_I,      // Сигнал синхронизации
    input  wire        RST_I,      // Синхронный сброс
    output wire [13:0] ROM_A,      // ROM 32k
    input  wire [15:0] ROM_I, 
    output reg  [21:0] ADR_O,      // RAM 8 Mb
    input  wire [15:0] DAT_I, 
    output wire [15:0] DAT_O, 
    output reg         WE_O    
);

// Состояния процессора
`define MAIN_LOOP   1'b0
`define STORE_LDREG 1'b1
`define INCR_INDEX  2'h2

// Перечисление команд
`define CMD_NONE    3'h0
`define INC_POST_X  3'h1
`define INC_POST_Y  3'h2
`define INC_POST_Z  3'h3
`define LD_X        3'h4
`define LD_Y        3'h5
`define LD_Z        3'h6

assign ROM_A = PC;
assign DAT_O = 1'b0;

wire [15:0] test_reg = {r[27], r[26], r[17], r[16]};

// Регистры
// ---------------------------------------------------------------------
reg [13:0] PC;
reg [13:0] SP;
reg  [8:0] R;       // Результат
reg  [7:0] F;       // Флаги результата

reg  [7:0] r[32];   // Все регистры, включая X,Y,Z
reg  [7:0] f;       // Реальные флаги

// I T H S | V N Z C
// 7 6 5 4 | 3 2 1 0

// Состояния
// ---------------------------------------------------------------------
reg [2:0]  cs;
reg [15:0] opcode;

reg        i_rjmp;     
reg [15:0] r_jmp;

reg       i_alu;        // Это АЛУ-операция
reg       i_save;       // Сохранить результат из АЛУ
reg [2:0] i_cmd;        // 1 = X+, 2 = Y+, 3 = Z+

// Результат = 0 ==> ZF=1
wire a_zero = (R[7:0] == 8'h00);
wire a_neg  =  R[7];

// Извлечь текущий код операции
wire [15:0] o = cs > 0 ? opcode : ROM_I;

// Это Immediate?
wire i_imm = (o[15:12] == 4'b0011 | // CPI
              o[15:12] == 4'b0100 | // SBCI
              o[15:12] == 4'b0101 | // SUBI
              o[15:12] == 4'b0110 | // ORI
              o[15:12] == 4'b1110 | // LDI
              o[15:12] == 4'b0111   // ANDI
             );

// Номера регистров
wire [4:0] Rn = { i_imm | o[9], o[3:0]};
wire [4:0] Dn = { i_imm | o[8], o[7:4]} ;

// Значение регистров
wire [7:0] Rr = r[ Rn ];
wire [7:0] Rd = r[ Dn ];

// Вычисления
// ---------------------------------------------------------------------

// Immediate 8-bit
wire [7:0] K = {o[11:8], o[3:0]};

wire [8:0] c_add  = Rd + Rr;
wire [8:0] c_sub  = Rd - Rr;
wire [8:0] c_sbc  = c_sub - f[0];
wire [8:0] c_adc  = c_add + f[0];
wire [8:0] c_subi = Rd - K;
wire [8:0] c_sbci = Rd - K - f[0];

wire [7:0] c_and  = Rd & Rr;
wire [7:0] c_or   = Rd | Rr;
wire [7:0] c_eor  = Rd ^ Rr;
wire [7:0] c_andi = Rd & K;
wire [7:0] c_ori  = Rd | K;

// Индексные регистры
wire [15:0] Xr = {r[27], r[26]};
wire [15:0] Xr_inc = Xr + 1'b1;

wire [15:0] Yr = {r[29], r[28]};
wire [15:0] Yr_inc = Yr + 1'b1;

wire [15:0] Zr = {r[31], r[30]};
wire [15:0] Zr_inc = Zr + 1'b1;

// Overflow для SUBI/SBCI и др.
wire H_subi = (!Rd[3] & K[3]) | (K[3] & R[3]) | (R[3] & !Rd[3]); // Half Carry
wire V_subi = (Rd[7] & !K[7] & !R[7]) | (!Rd[7] & K[7] & R[7]);  // Overflow

// Инициализация
// ---------------------------------------------------------------------
initial begin

    PC     = 14'h0000;
    ADR_O  = 14'h0000;
    WE_O   = 1'b0;
    f      = 8'h00;
    F      = 8'h00;
    cs     = 1'b0;
        
    // Общие регистры
    r[0]  = 8'h00; r[1]  = 8'h00; r[2]  = 8'h00;  r[3]  = 8'h00;
    r[4]  = 8'h00; r[5]  = 8'h00; r[6]  = 8'h00;  r[7]  = 8'h00;
    r[8]  = 8'h00; r[9]  = 8'h00; r[10] = 8'h00;  r[11] = 8'h00;
    r[12] = 8'h00; r[13] = 8'h00; r[14] = 8'h00;  r[15] = 8'h00;

    r[16] = 8'h00; r[17] = 8'h00; r[18] = 8'h00;  r[19] = 8'h00;
    r[20] = 8'h00; r[21] = 8'h00; r[22] = 8'h00;  r[23] = 8'h00;
    r[24] = 8'h00; r[25] = 8'h00; 
    
    // Специальные регистры
    r[26] = 8'h00; r[27] = 8'h00; // X
    r[28] = 8'h00; r[29] = 8'h00; // Y
    r[30] = 8'h00; r[31] = 8'h00; // Z

end

// Декодер инструкции, вычисление АЛУ-результата на 1-м такте
// ---------------------------------------------------------------------
always @* begin

    casex (o)

        // CPC    Rd, Rr
        // ---------------------------
        16'b000001_xx_xxxx_xxxx: begin
        
            R = c_sbc;
            F = f;
            
            i_cmd  = 1'b0;
            i_alu  = 1'b1;
            i_save = 1'b0;

        end

        // SBC    Rd, Rr
        // ---------------------------
        16'b000010_xx_xxxx_xxxx: begin
        
            R = c_sbc;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end

        // ADD    Rd, Rr
        // ---------------------------
        16'b000011_xx_xxxx_xxxx: begin
        
            R = c_add;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end

        // CPSE   Rd, Rr
        // ---------------------------
        16'b000100_xx_xxxx_xxxx: begin
        
            R = c_sub;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b0;
            i_save = 1'b0;
        
        end
    
        // CP     Rd, Rr
        // ---------------------------
        16'b000101_xx_xxxx_xxxx: begin
        
            R = c_sub;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // SUB    Rd, Rr
        // ---------------------------
        16'b000110_xx_xxxx_xxxx: begin
        
            R = c_sub;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // ADC    Rd, Rr
        // ---------------------------
        16'b000111_xx_xxxx_xxxx: begin
        
            R = c_adc;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end                       
        
        // AND    Rd, Rr
        // ---------------------------
        16'b001000_xx_xxxx_xxxx: begin
        
            R = c_and;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // EOR    Rd, Rr
        // ---------------------------
        16'b001001_xx_xxxx_xxxx: begin
        
            R = c_eor;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // OR     Rd, Rr
        // ---------------------------
        16'b001010_xx_xxxx_xxxx: begin
        
            R = c_or;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // MOV    Rd, Rr
        // ---------------------------
        16'b001011_xx_xxxx_xxxx: begin
        
            R = Rr;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // CPI    Rd, K
        // ---------------------------
        16'b0011_xxxx_xxxx_xxxx: begin
        
            R = c_subi;
            F = {f[7:6], H_subi, H_subi ^ V_subi, V_subi, a_neg, a_zero, R[8]};
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b0;
        
        end
        
        // SBCI   Rd, K
        // ---------------------------
        16'b0100_xxxx_xxxx_xxxx: begin
        
            R = c_sbci;
            F = {f[7:6], H_subi, H_subi ^ V_subi, V_subi, a_neg, a_zero, R[8]};
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // SUBI   Rd, K
        // ---------------------------
        16'b0101_xxxx_xxxx_xxxx: begin
        
            R = c_subi;
            F = {f[7:6], H_subi, H_subi ^ V_subi, V_subi, a_neg, a_zero, R[8]};
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // ORI    Rd, K
        // ---------------------------
        16'b0110_xxxx_xxxx_xxxx: begin
        
            R = c_ori;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;

        end
        
        // ANDI   Rd, K
        // ---------------------------
        16'b0111_xxxx_xxxx_xxxx: begin
        
            R = c_andi;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // LDI   Rd, K
        // ---------------------------
        16'b1110_xxxx_xxxx_xxxx: begin
        
            R = K;
            F = f;
            
            i_cmd = 1'b0;
            i_alu = 1'b1;
            i_save = 1'b1;
        
        end
        
        // LD   Rd, X+/Y+/Z+
        // ---------------------------
        16'b1001_000x_xxxx_1101: begin i_cmd = `INC_POST_X; i_alu = 1'b0; ADR_O = Xr; end
        16'b1001_000x_xxxx_1001: begin i_cmd = `INC_POST_Y; i_alu = 1'b0; ADR_O = Yr; end
        16'b1001_000x_xxxx_0001: begin i_cmd = `INC_POST_Z; i_alu = 1'b0; ADR_O = Zr; end
        16'b1001_000x_xxxx_1100: begin i_cmd = `LD_X;       i_alu = 1'b0; ADR_O = Xr; end
        16'b10x0_xx0x_xxxx_1xxx: begin i_cmd = `LD_Y;       i_alu = 1'b0; ADR_O = Yr + {o[13],o[11:10],o[2:0]}; end
        16'b10x0_xx0x_xxxx_0xxx: begin i_cmd = `LD_Z;       i_alu = 1'b0; ADR_O = Zr + {o[13],o[11:10],o[2:0]}; end

        // В любых других случаях ошибочный опкод
        // ---------------------------
        default: begin
        
            F = f; 
            i_cmd = 1'b0;
            i_alu = 1'b0;
            i_save = 1'b0;
            
        end

    endcase

end

// ---------------------------------------------------------------------

// Главный исполняемый цикл процессора
always @(posedge CLK_I) begin

    case (cs)
    
        `MAIN_LOOP: begin     
        
            opcode <= ROM_I;
            
            // Относительный переход RJMP
            // ~~~~~~~~~~~~~~~
            if (o[15:12] == 4'b1100) 
            begin PC <= PC + 1'b1 + {{4{o[11]}}, o[11:0]}; end
            
            // Это однотактовая операция АЛУ :: Сохранить только если это разрешено   
            // ~~~~~~~~~~~~~~~
            else if (i_alu) 
            begin PC <= PC + 1'b1; f <= F; if (i_save) r[ Dn ] <= R[7:0]; end

            // LD Rd, X/Y/Z+
            // ~~~~~~~~~~~~~~~
            else if (i_cmd == `INC_POST_X || i_cmd == `INC_POST_Y || i_cmd == `INC_POST_Z || 
                     i_cmd == `LD_X       || i_cmd == `LD_Y       || i_cmd == `LD_Z) 
            begin PC <= PC + 1'b1; cs <= `STORE_LDREG; end

        end
        
        // LD reg, X/Y/Z[+]
        // Запись в регистр значения из памяти
        // --------------------------------------------------------------
        `STORE_LDREG: begin

            r[ Dn ] <= ADR_O[0] ? DAT_I[15:8] : DAT_I[7:0];
            
            // Случай с LD Rd, X/Y+q/Z+q
            if (i_cmd == `LD_X || i_cmd == `LD_Y || i_cmd == `LD_Z)
                cs <= `MAIN_LOOP;
            else 
                cs <= `INCR_INDEX;
        
        end
        
        // INC X,Y,Z
        `INCR_INDEX: begin
        
                 // X++
                 if (i_cmd == `INC_POST_X) begin r[26] <= Xr_inc[7:0]; r[27] <= Xr_inc[15:8]; end
                 // Y++
            else if (i_cmd == `INC_POST_Y) begin r[28] <= Yr_inc[7:0]; r[29] <= Yr_inc[15:8]; end
                 // Z++
            else if (i_cmd == `INC_POST_Z) begin r[30] <= Zr_inc[7:0]; r[31] <= Zr_inc[15:8]; end

            cs <= `MAIN_LOOP;  

        end
    
    endcase

end

endmodule
