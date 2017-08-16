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
    output  reg  [7:0]  o_data,         // ������ ��� ������
    output  reg         o_wr            // ������ � ������

);

/*
 * �������
 */

assign o_addr = alt ? addr : pc;

/*
 * ��������
 */
 
reg [7:0]  a; // �����������
reg [7:0]  x; // ��������� �������
reg [7:0]  y; // ��������� �������
reg [7:0]  p; // �����
reg [7:0]  s; // ���� $100-$1FF
reg [15:0] pc; // ������� ������

/*
 * ���������
 */

reg [3:0]  t;        // ������� ��������� ����������
reg [7:0]  op_cache; // ���������� ��������� ������
reg        alt;      // ���� =1, �� ������� � ������ [addr], ����� �� [pc]
reg [15:0] addr;     // ��������� �� ������� ������� ������

/*
 * ������������� ��������� ��������
 */

initial begin

    a = 8'h00;
    x = 8'h00; y = 8'h00;
    p = 8'h00; s = 8'h00;
    
    t = 4'h0;
    alt = 1'b0;
    
    // ������ ��������� �������
    pc     = 16'h0000;
    addr   = 16'h0000;
    
    op_cache = 8'h00;
    o_data = 8'h00;
    o_wr = 1'b0;

end

/*
 * ���������� ���� ��������
 */

// ���������� ����� �� �����
wire [7:0] opcode = t ? op_cache : i_data;
 
// ����������-���������� �������� [aaaxxx01]
wire c_alu = opcode[1:0] == 2'b01;

/* -------------------------------------------------------------------------
 * ���������� ���� ��������
 *
 * (I,X)    - ������ (I+X) & 255, ���������� 16 ������� ����� (wrapping) 
 * (I),Y    - ������� 16 ������ ����� (I), ����� + Y
 * IMM      - ��������� ���� �������� ���������������� ���������
 * ZP       - ���������� ����� �� ZeroPage
 * IND      - ���������� 16 ��� �� (ABS) ������
 */
 
// (I,X) xxx00001
wire t_ndx = c_alu & (opcode[4:0] == 5'b00001);

// (I),Y xxx10001 | 10111110
wire t_ndy = c_alu & (opcode[4:0] == 5'b10001);

// IMM xxx01001 | 1xx00001 | 10100010
wire t_imm = (c_alu & (opcode[4:0] == 5'b01001)) | ({opcode[7], opcode[4:0]} == 6'b100001) | (opcode == 8'hA2);

// #ZP xxx001xx
wire t_zp = (opcode[4:2] == 3'b001);

// IND 01101100
wire t_ind = (opcode == 8'h6C);

// #ABS xxx001xx (����� JMP IND)
// #ABS 00100000
wire t_abs = ((opcode[4:2] == 3'b001) && ~t_ind) || (opcode == 8'h20);

// ZPY 10x10110
wire t_zpy = (opcode == 8'hB6 || opcode == 8'h96);

// ZPX xxx101xx
wire t_zpx = (opcode[4:2] == 3'b101) && ~t_zpy;

// ABY xxx11010 (���)
// ABY 10x11110 (��������� ����������)
wire t_aby = (c_alu & (opcode[4:0] == 5'b11001)) || (opcode == 8'hBE) || (opcode == 8'h9E);

// ABX xxx111xx
wire t_abx = (opcode[4:2] == 3'b111) && ~t_aby;

// REL xxx10000
wire t_rel = (opcode[4:0] == 5'b10000);

// Implied ������� ��� ����������
// xxx 010 00
// xxx 110 00
// xxx 010 10
// 1xx 110 10
// 01x 000 00 RTI / RTS
// 000 000 00 BRK

// ����� ���������� ��� ���������� Implied
wire t_imp = ~(t_ndx | t_ndy | t_imm | t_zp | t_ind | t_abs | t_abx | t_aby | t_zpx | t_zpy | t_rel);

// -------------------------------------------------------------------------

/*
 * ������� ������������ ������
 */

always @(posedge clock_25) begin

    case (t)
    
        /*
         * ���������� ������ ���������� ����� ����������
         */
    
        4'h0: begin
        
            op_cache <= i_data;            
            pc <= pc + 1'b1;
        
        end

    endcase

end

endmodule
