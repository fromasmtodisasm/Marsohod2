module cpu(

    input  wire        cpu_clock,       // 1.71 МГц
    output wire [15:0] address,         // Указатель адреса
    input  wire [7:0]  i_data,          // Входящие данные
    output wire [7:0]  o_data,          // Исходящие данные
    output reg         wreq             // Строб записи в память

);

reg [3:0]   cpu_state = 1'b0;

always @(posedge cpu_clock) begin

    
    case (cpu_state)
    
        // Сканирование опкода
        4'h0: begin

            casex (i_data)
            
                // Indirect, X
                8'bxxx_000_x1: begin cpu_state <= 4'h0; end
                
                // Immediate
                8'bxxx_010_x1,
                8'b1xx_000_x1: begin cpu_state <= 4'h0; end

                // Indirect, Y
                8'bxxx_100_x1: begin cpu_state <= 4'h0; end

                // Absolute, Y
                8'bxxx_110_x1: begin cpu_state <= 4'h0; end

                // ZeroPage
                8'bxxx_001_xx: begin cpu_state <= 4'h0; end
                
                // Absolute
                8'bxxx_011_xx,
                8'b001_000_00: begin cpu_state <= 4'h0; end

                // ZeroPage, Y
                8'b10x_101_1x: begin cpu_state <= 4'h0; end
                
                // ZeroPage, X
                8'bxxx_101_xx: begin cpu_state <= 4'h0; end
                
                // Absolute, Y
                8'b10x_111_1x: begin cpu_state <= 4'h0; end
                
                // Absolute, X
                8'bxxx_111_xx: begin cpu_state <= 4'h0; end
                
                // Relative
                8'bxxx_100_00: begin cpu_state <= 4'h0; end
                                
                // Accumulator
                8'b0xx_010_10: begin cpu_state <= 4'h0; end
                
                // Implied
                default: begin cpu_state <= 4'h0; end
            
            endcase

        end
            
    endcase

end

endmodule
