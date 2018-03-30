module cpu(

    input  wire        cpu_clock,       // 1.71 МГц
    output wire [15:0] address,         // Указатель адреса
    input  wire [7:0]  i_data,          // Входящие данные
    output wire [7:0]  o_data,          // Исходящие данные
    output reg         wreq             // Строб записи в память

);

// Методы адресации
parameter FET = 4'h0;       // Сканирование опкода
parameter NDX = 4'h1;
parameter NDY = 4'h2;
parameter IMM = 4'h3;
parameter ABS = 4'h4;
parameter ABX = 4'h5;
parameter ABY = 4'h6;
parameter ZP  = 4'h7;
parameter ZPX = 4'h8;
parameter ZPY = 4'h9;
parameter REL = 4'hA;
parameter ACC = 4'hB;
parameter IMP = 4'hC;

// Регистры
// ---------------------------------------------------------------------
reg [7:0]   A  = 8'h0;
reg [7:0]   X  = 8'h0;
reg [7:0]   Y  = 8'h0;
reg [7:0]   P  = 8'h0;
reg [7:0]   S  = 8'h0;
reg [15:0]  PC = 16'h0;

// Состояние процессора
// ---------------------------------------------------------------------
reg [3:0]   cpu_state = 1'b0;

// Обычно вторым операндом является i_data
wire [7:0] src = i_data;
wire [7:0] alt = A;

// ---------------------------------------------------------------------
always @(posedge cpu_clock) begin


    case (cpu_state)

        // Сканирование опкода
        FET: begin

            casex (i_data)

                // Indirect, X
                8'bxxx_000_x1: begin cpu_state <= NDX; end

                // Immediate
                8'bxxx_010_x1,
                8'b1xx_000_x1: begin cpu_state <= IMM; end

                // Indirect, Y
                8'bxxx_100_x1: begin cpu_state <= NDY; end

                // Absolute, Y
                8'bxxx_110_x1: begin cpu_state <= ABY; end

                // ZeroPage
                8'bxxx_001_xx: begin cpu_state <= ZP; end

                // Absolute
                8'bxxx_011_xx,
                8'b001_000_00: begin cpu_state <= ABS; end

                // ZeroPage, Y
                8'b10x_101_1x: begin cpu_state <= ZPY; end

                // ZeroPage, X
                8'bxxx_101_xx: begin cpu_state <= ZPX; end

                // Absolute, Y
                8'b10x_111_1x: begin cpu_state <= ABY; end

                // Absolute, X
                8'bxxx_111_xx: begin cpu_state <= ABX; end

                // Relative
                8'bxxx_100_00: begin cpu_state <= REL; end

                // Accumulator
                8'b0xx_010_10: begin cpu_state <= ACC; end

                // Implied
                default: begin cpu_state <= IMP; end

            endcase

        end

    endcase

end

// АЛУ
// ---------------------------------------------------------------------

reg [3:0]   alu = 1'b0;
reg [8:0] alu_rs;       // Результат АЛУ
reg [7:0] alu_fn;       // Новые флаги

always @* begin

    case (alu)

        3'b000: /* ORA */ begin

            alu_rs = A | src;
            alu_fn = {alu_rs[7], P[6:2], alu_rs == 1'b0, P[0]};

        end

        3'b001: /* AND */ begin

            alu_rs = A & src;
            alu_fn = {alu_rs[7], P[6:2], alu_rs == 1'b0, P[0]};

        end

        3'b010: /* EOR */ begin

            alu_rs = A ^ src;
            alu_fn = {alu_rs[7], P[6:2], alu_rs == 1'b0, P[0]};

        end

        3'b011: /* ADC */ begin

            alu_rs = A + src + P[0];
            alu_fn = {
                /* S */ alu_rs[7],
                /* V */ (A[7] ^ src[7] ^ 1'b1) & (A[7] ^ alu_rs[7]),
                /* - */ P[5:2],
                /* Z */ alu_rs == 1'b0,
                /* C */ alu_rs[8]
            };

        end

        4'b100: /* STA, STX, STY */ begin

            alu_rs = alt;
            alu_fn = P;

        end

        4'b101: /* LDA, LDX, LDY */ begin

            alu_rs = src;
            alu_fn = {src[7], P[6:2], src == 1'b0, P[0]};

        end

        4'b110: /* CMP, CPX, CPY */ begin

            alu_rs = alt - src;
            alu_fn = {
                /* S */ alu_rs[7],
                /* - */ P[6:2],
                /* Z */ alu_rs == 1'b0,
                /* C */ ~alu_rs[8]
            };

        end

        4'b111: /* SBC */ begin

            alu_rs = A - src - (!P[0]);
            alu_fn = {
                /* S */ alu_rs[7],
                /* V */ (A[7] ^ src[7]) & (A[7] ^ alu_rs[7]),
                /* - */ P[5:2],
                /* Z */ alu_rs == 1'b0,
                /* C */ ~alu_rs[8]
            };

        end

    endcase

end

endmodule
