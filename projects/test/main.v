`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------
reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 1; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end
// ---------------------------------------------------------------------

reg [2:0] a = 1'b0;
wire      b = &a;      /* Логическое сложение всех единиц */
wire      c = ~^a;     /* Расчет четности */
wire      d = a[1] && ~&a;

/* Групповая сборка битов: &a, ^a, |a -- рассчитывается к группе */

always @(posedge clk) a <= a + 1'b1;

endmodule
