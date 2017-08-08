/*
 * ����-��������� �� ������ 6502, 8 ���
 */

wire [7:0]  i_data;
wire [15:0] o_addr;
wire [7:0]  o_data;
wire        o_wr;
 
demo_processor DPROC6502(

    // 25 ��� ������� �������
	.clk_25     (locked & clock_25),    // PLL.locked & PLL.clock_25

	// �������������
	.i_data     (i_data),       // �������� ������
	.o_addr     (o_addr),       // ������� �����
    .o_data     (o_data),       // ��������� ������
    .o_wr       (o_wr),         // ������� ������ (0 - ���, 1 - ������������)

);
