/*
 * ���������� ������ ������ � ������ �� CLK-25 CPU 
 * ������������ ��� demo_processor (25���)
 */

// BEGIN
reg [2:0] cntl_mw = 3'b000; // ������� ������������ ��������� ������ clk_25
assign    cntl_w  = cntl_mw == 3'b011 && o_wr; // ����������� ��������� ������ � ������ ������ [demo_processor.o_wr]
always @(posedge clk) cntl_mw <= {cntl_mw[1:0], clock_25}; // ������ ������� ��������� ������ [�� PLL.clock_25]
// END