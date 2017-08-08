/*
 * 8-������ ���������
 * 
 * - �� ������ ���������� 6502
 * - �� �������� 25 ���
 */
 
module demo_processor(
   
    // ������������ ���������� �� ����������� ������� 25 ���
    input   wire        clock_25,
    
    // 8-������ ���� ������
    input   wire [7:0]  i_data,         // �������� ������
    output  wire [15:0] o_addr,         // 16-������ ����� (64 �� �������� ������������)
    output  wire [7:0]  o_data,         // ������ ��� ������
    output  wire        o_wr            // ������ � ������

);

assign o_wr = 1'b0;
assign o_addr = 1'b0;

endmodule
