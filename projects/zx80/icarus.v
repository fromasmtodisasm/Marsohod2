module main;

reg clk;
reg cpu;

wire [3:0]  led;
reg  [7:0]  data8_in;
wire [7:0]  data8_out;
wire [15:0] address;
wire        wren;

// �����
wire [15:0] port_addr;
wire [7:0]  port_data;  // ������ � ����
wire [7:0]  port_out;   // ������ �� �����
wire        port_clock;

// VGA-������
wire [2:0]  vga_border;

//������������� ��������� ������������ ������
processor CPU(cpu, address, data8_in, data8_out, wren, port_addr, port_data, port_out, port_clock);
port PORT(port_clock, port_addr, port_data, port_out, vga_border);

//���������� ������ �������� �������
always #1 clk = ~clk;
always #4 cpu = ~cpu;

//�� ������ �������...
initial begin
  clk = 0;
  cpu = 0;
  #2000 $finish; // ����������� ���������
end 

// ������� ���� VCD ��� ������������ ������� ��������
initial
begin
  $dumpfile("output.vcd");
  $dumpvars(0, CPU);
  $dumpvars(0, PORT);
end

// ��� ������
reg [7:0]  sdram[1048576];
reg [8:0]  b8;
reg        wren_already; // ��� ����������?

// ��������� ������ � ������
always @(posedge clk) begin
   
    // ��� - 1�, ��� ����������� ����������
    data8_in <= sdram[ address ];
    
    if (wren) begin
    
        // ����� ������ - ������ ���� �� CLOCK=0
        if (!cpu && !wren_already) begin
        
            sdram[ address ] <= data8_out[7:0];   
            wren_already     <= 1'b1;
            
        end
        // ����� => 0, ���� ���� CPU = 1
        else if (cpu) begin
        
            wren_already <= 1'b0;
    
        end

    end

end

initial begin

    b8       = 1'b0;
    data8_in = 1'b0;

    // ���������� ���� � �������������� ������
    `include "icarus_memory.v"    

end

endmodule
