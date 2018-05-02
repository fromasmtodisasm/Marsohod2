`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("result.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

wire [7:0]  i; wire [7:0] o; wire [19:0] a;
wire        w;
wire [7:0]  d; 

// ------------------------------------- Регистровый файл --------------

wire [2:0]  Dr;  wire [2:0] Sr; wire [1:0]  b;
reg  [15:0] ia; reg  [15:0] ib;
wire        wr; wire [15:0] dw;

// Список регистров
reg [31:0] registers[8];

initial begin

    registers[0] = 16'h0000; // AX
    registers[1] = 16'h0000; // CX
    registers[2] = 16'h0000; // DX
    registers[3] = 16'h0000; // BX
    registers[4] = 16'h0000; // SP
    registers[5] = 16'h0000; // BP
    registers[6] = 16'h0000; // SI 
    registers[7] = 16'h0000; // DI
    
    ia = 16'h0000;
    ib = 16'h0000;
    
end

always @(posedge clk) begin

    ia <= registers[ Dr ];
    ib <= registers[ Sr ];
    
    if (wr) registers[ Dr ] <= dw;

end

// ------------------------------------- Центральный процессор ---------
cpu CPU(/* Главное */   clk, i, o, a, w, d, 
        /* Регистры */  Dr, Sr, b, ia, ib, wr, dw);
    
endmodule
