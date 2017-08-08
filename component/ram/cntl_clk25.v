/*
 * ���������� ������ ������ � ������ �� CLK-25 CPU 
 * ������������ ��� demo_processor (25���)
 */

// BEGIN
reg [1:0] cntl_mw = 2'b00; // ������� ������������ ��������� ������ clk_25
assign    cntl_w  = cntl_mw == 2'b01 && o_wr; // ����������� ��������� ������ � ������ ������ [demo_processor.o_wr]
always @(posedge clk) cntl_mw <= {cntl_mw[0], clock_25}; // ������ ������� ��������� ������ [�� PLL.clock_25]
// END