`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

wire [15:0] Ca;  reg  [ 7:0] Ci; /* Кот */
wire [15:0] Da;  reg  [ 7:0] Di; wire [ 7:0] Do; wire Dw; /* Дата */
reg  [7:0]  Ci_; reg  [ 7:0] Di_;

reg [7:0] CIRAM[65536]; /* Сделаем тут доступной всю память */

always @(posedge clk) begin

    // На реальной ПЛИС тут будет задержка
    Ci_ <= CIRAM[ Ca ]; Ci <= Ci_;
    Di_ <= CIRAM[ Da ]; Di <= Di_;
    
    // Писать в память на 2-м такте после CPU.
    if (Dw && Dv == 2'b00) CIRAM[ Da ] <= Do;

end

/* Загрузить тестбенчовые данные в память */
initial begin $readmemh("rom/rom.hex", CIRAM, 16'h0000); end

// ---------------------------------------------------------------------

reg         CPUClk = 1'b0;
reg  [ 1:0] Dv = 2'b00; 

always @(posedge clk) case (Dv)

    2'b00: {Dv, CPUClk} <= {2'b01, 1'b0};
    2'b01: {Dv, CPUClk} <= {2'b10, 1'b0};
    2'b10: {Dv, CPUClk} <= {2'b00, 1'b1};
    
endcase 

z80 Z80(
     CPUClk,         /* 16 Mhz */
     Ca, Ci,         /* Ка-Ки */
     Da, Di, Do, Dw  /* Дадидодв */
);

endmodule
