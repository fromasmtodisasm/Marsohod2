`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("result.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

// Для 32-х тиков требуется инициализация - бит должен попасть в сдвиг

// Входящие
reg     [31:0] operand_A        = 32'h0080BABA;
reg     [31:0] operand_B        = 32'h00000002;

// Исходящие
reg     [31:0] remainder        = 32'h00000000;
reg     [31:0] result           = 32'h00000000;
wire    [32:0] subtract         = remainder - operand_B;
wire    [30:0] remainder_next   = subtract[32] ? remainder[30:0] : subtract[30:0];
reg     [5:0]  ticker           = 1'b0;

always @(posedge clk) begin

    // 33 такта
    if (ticker != 6'd33) begin     

        // Если remainder < B, оставить remainder, либо вычесть
        remainder <= {remainder_next, operand_A[31]};
        result    <= {result[30:0], subtract[32] ^ 1'b1};
        operand_A <= {operand_A[30:0], 1'b0};
        
        // 33 тика
        ticker    <= ticker + 1'b1;
    
    end

end

endmodule
