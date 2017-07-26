module rand32(

    input  wire        clock,
    output reg  [31:0] rnd

);

initial rnd = 32'h00000001;

// Следующий бит случайности
wire next_bit = rnd[31] ^ rnd[30] ^ rnd[29] ^ rnd[27] ^ rnd[25] ^ rnd[0];

// Генератор
always @(posedge clock) begin rnd <= { next_bit, rnd[31:1] }; end

endmodule
