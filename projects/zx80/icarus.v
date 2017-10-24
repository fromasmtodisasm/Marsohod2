module main;

reg clk;
reg cpu;

wire [3:0]  led;
reg  [7:0]  data8_in;
wire [7:0]  data8_out;
wire [15:0] address;
wire        wren;

// Порты
wire [15:0] port_addr;
wire [7:0]  port_data;  // Данные в порт
wire [7:0]  port_out;   // Данные из порта
wire        port_clock;

// VGA-бордюр
wire [2:0]  vga_border;

//устанавливаем экземпляр тестируемого модуля
processor CPU(cpu, address, data8_in, data8_out, wren, port_addr, port_data, port_out, port_clock);
port PORT(port_clock, port_addr, port_data, port_out, vga_border);

//моделируем сигнал тактовой частоты
always #1 clk = ~clk;
always #4 cpu = ~cpu;

//от начала времени...
initial begin
  clk = 0;
  cpu = 0;
  #2000 $finish; // заканчиваем симуляцию
end 

// создаем файл VCD для последующего анализа сигналов
initial
begin
  $dumpfile("output.vcd");
  $dumpvars(0, CPU);
  $dumpvars(0, PORT);
end

// Вся память
reg [7:0]  sdram[1048576];
reg [8:0]  b8;
reg        wren_already; // Уже записывали?

// Симуляция записи в память
always @(posedge clk) begin
   
    // Лаг - 1Т, для тестрования достаточно
    data8_in <= sdram[ address ];
    
    if (wren) begin
    
        // Строб записи - запись идет на CLOCK=0
        if (!cpu && !wren_already) begin
        
            sdram[ address ] <= data8_out[7:0];   
            wren_already     <= 1'b1;
            
        end
        // Сброс => 0, если такт CPU = 1
        else if (cpu) begin
        
            wren_already <= 1'b0;
    
        end

    end

end

initial begin

    b8       = 1'b0;
    data8_in = 1'b0;

    // Подключить файл с инициализацией памяти
    `include "icarus_memory.v"    

end

endmodule
