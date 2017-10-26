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

assign ROM_A = PC;

// Регистры
// ---------------------------------------------------------------------
reg [13:0] PC;
reg [13:0] SP;
reg [7:0]  f;     // Флаги
reg [7:0]  r[32]; // Все регистры, включая X,Y,Z

wire [4:0] Rn = { i_immediate | o[9], o[3:0]};
wire [4:0] Dn = { i_immediate | o[8], o[7:4]} ;

// Исходные регистры R,D
wire [7:0] R  = r[ Rn ];
wire [7:0] D  = r[ Dn ];

// Вычисления
// ---------------------------------------------------------------------
reg  [8:0] Rr;      // Результат
reg  [7:0] Rf;      // Флаги

wire [7:0] K = {o[11:8], o[3:0]};

wire [8:0] c_add = D + R;
wire [8:0] c_sub = D - R;
wire [8:0] c_sbc = c_sub - f[0];
wire [8:0] c_adc = c_add + f[0];
wire [7:0] c_and = D & R;
wire [7:0] c_or  = D | R;
wire [7:0] c_eor = D ^ R;

wire [7:0] c_andi = D & K;
wire [7:0] c_ori  = D | K;
wire [7:0] c_subi = D - K;
wire [7:0] c_sbci = D - K - f[0];

// Состояния
// ---------------------------------------------------------------------
reg [2:0]  cs;       // Состояние процессора
reg [15:0] opcode;
reg        i_alu;

// Текущий опкод
wire [15:0] o = cs ? opcode : DAT_I;

// Это Immediate?
wire       i_immediate = (o[15:12] == 4'b0011 | 
                          o[15:12] == 4'b0100 |
                          o[15:12] == 4'b0101 |
                          o[15:12] == 4'b0110 |
                          o[15:12] == 4'b0111);

// Инициализация
// ---------------------------------------------------------------------
initial begin

    PC     = 14'h0000;
    ADR_O  = 14'h0000;
    WE_O   = 1'b0;
    f      = 8'h00;
    cs     = 1'b0;

end

// Декодер инструкции, вычисление АЛУ-результата на 1-м такте
// ---------------------------------------------------------------------
always @* begin

    casex (o)

        // CPC    Rd, Rr
        16'b000001_xx_xxxx_xxxx: begin
        
            Rr = c_sbc;
            i_alu = 1'b1;

        end

        // SBC    Rd, Rr
        16'b000010_xx_xxxx_xxxx: begin
        
            Rr = c_sbc;
            i_alu = 1'b1;
        
        end

        // ADD    Rd, Rr
        16'b000011_xx_xxxx_xxxx: begin
        
            Rr = c_add;
            i_alu = 1'b1;
        
        end

        // CPSE   Rd, Rr
        16'b000100_xx_xxxx_xxxx: begin
        
            Rr = c_sub;
        
        end
    
        // CP     Rd, Rr
        16'b000101_xx_xxxx_xxxx: begin
        
            Rr = c_sub;
            i_alu = 1'b1;
        
        end
        
        // SUB    Rd, Rr
        16'b000110_xx_xxxx_xxxx: begin
        
            Rr = c_sub;
            i_alu = 1'b1;
        
        end
        
        // ADC    Rd, Rr
        16'b000111_xx_xxxx_xxxx: begin
        
            Rr = c_adc;
            i_alu = 1'b1;
        
        end                       
        
        // AND    Rd, Rr
        16'b001000_xx_xxxx_xxxx: begin
        
            Rr = c_and;
            i_alu = 1'b1;
        
        end
        
        // EOR    Rd, Rr
        16'b001001_xx_xxxx_xxxx: begin
        
            Rr = c_eor;
            i_alu = 1'b1;
        
        end
        
        // OR     Rd, Rr
        16'b001010_xx_xxxx_xxxx: begin
        
            Rr = c_or;
            i_alu = 1'b1;
        
        end
        
        // MOV    Rd, Rr
        16'b001011_xx_xxxx_xxxx: begin
        
            Rr = R;
            i_alu = 1'b1;
        
        end
        
        // CPI    Rd, K
        16'b0011_xxxx_xxxx_xxxx: begin
        
            Rr = c_subi;
            i_alu = 1'b1;
        
        end
        
        // SBCI   Rd, K
        16'b0100_xxxx_xxxx_xxxx: begin
        
            Rr = c_sbci;
            i_alu = 1'b1;
        
        end
        
        // SUBI   Rd, K
        16'b0101_xxxx_xxxx_xxxx: begin
        
            Rr = c_subi;
            i_alu = 1'b1;
        
        end
        
        // ORI    Rd, K
        16'b0110_xxxx_xxxx_xxxx: begin
        
            Rr = c_ori;
            i_alu = 1'b1;

        end
        
        // ANDI   Rd, K
        16'b0111_xxxx_xxxx_xxxx: begin
        
            Rr = c_andi;
            i_alu = 1'b1;
        
        end
        
        // В любых других случаях ошибочный опкод
        default: begin
        
            i_alu = 1'b0;
            
            
        end

    endcase

end

// ---------------------------------------------------------------------

// Главный исполняемый цикл процессора
always @(posedge CLK_I) begin

    case (cs)

        // =========== ТАКТ 1 ==============
        
        3'h0: begin
        
            // Сохранить на будущее
            opcode <= DAT_I;

            // Это однотактовая операция АЛУ
            if (i_alu) begin
            
                PC <= PC + 1'b1;
                r[ Dn ] <= Rr[7:0]; // при условии сохранения
            
            end
            
        end
    
    endcase

end

endmodule
