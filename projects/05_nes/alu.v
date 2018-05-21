
module alu(

    input  wire [7:0] A,        /* < Значение A */
    input  wire [7:0] B,        /* < Значение B */
    input  wire [3:0] alu,      /* < Режим АЛУ */
    input  wire [7:0] P,        /* < Флаги на вход */
    output wire [7:0] alu_res,  /* > Результат */
    output wire [7:0] alu_flag  /* > Флаги */    
        
);

assign alu_res  = alu_rs[7:0];
assign alu_flag = alu_fn;

// АЛУ
// ---------------------------------------------------------------------

reg [3:0] alu_mode = 1'b0;   // Режим АЛУ
reg [8:0] alu_rs;           // Результат АЛУ
reg [7:0] alu_fn;           // Новые флаги

always @* begin

    case (alu)

        4'b0000: /* ORA */ begin

            alu_rs = A | B;
            alu_fn = {alu_rs[7], P[6:2], ~|alu_rs, P[0]};

        end

        4'b0001: /* AND */ begin

            alu_rs = A & B;
            alu_fn = {alu_rs[7], P[6:2], ~|alu_rs, P[0]};

        end

        4'b0010: /* EOR */ begin

            alu_rs = A ^ B;
            alu_fn = {alu_rs[7], P[6:2], ~|alu_rs, P[0]};

        end

        4'b0011: /* ADC */ begin

            alu_rs = A + B + P[0];
            alu_fn = {
                /* S */ alu_rs[7],
                /* V */ (A[7] ^ B[7] ^ 1'b1) & (A[7] ^ alu_rs[7]),
                /* - */ P[5:2],
                /* Z */ ~|alu_rs,
                /* C */ alu_rs[8]
            };

        end

        4'b0100: /* STA, STX, STY */ begin

            alu_rs = A;
            alu_fn = P;

        end

        4'b0101: /* LDA, LDX, LDY */ begin

            alu_rs = B;
            alu_fn = {B[7], P[6:2], ~|B, P[0]};

        end

        4'b0110: /* CMP, CPX, CPY */ begin

            alu_rs = A - B;
            alu_fn = {
                /* S */ alu_rs[7],
                /* - */ P[6:2],
                /* Z */ ~&alu_rs,
                /* C */ ~alu_rs[8]
            };

        end

        4'b0111: /* SBC */ begin

            alu_rs = A - B - (!P[0]);
            alu_fn = {
                /* S */ alu_rs[7],
                /* V */ (A[7] ^ B[7]) & (A[7] ^ alu_rs[7]),
                /* - */ P[5:2],
                /* Z */ ~|alu_rs,
                /* C */ ~alu_rs[8]
            };

        end
        
        /* ADD: Для вычислений эффективного адреса */
        4'b1000: begin
        
            alu_rs = A + B;
            alu_fn = {P[7:1], alu_rs[8]};
        
        end        

    endcase

end

endmodule
