module clock(

    // Кварцевый осциллятор 100 Mhz
    input   wire    osc_clock,

    // VGA 25,2 Мгц
    output  wire    vga_clock,

    // PPU 5.1 Мгц
    output  reg     ppu_clock,

    // CPU 1.71 Мгц
    output  reg     cpu_clock

);

initial ppu_clock = 1'b0;
initial cpu_clock = 1'b0;

// Основная частота
assign          vga_clock   = div[1];
reg     [1:0]   div         = 1'b0;

// Вычисление необходимых таймингов
reg     [9:0]   XPos        = 1'b0; // 0..799
reg             YOdd        = 1'b1; // 1..0
reg     [1:0]   COdd        = 1'b0; // 0,1,2

// Делитель частоты
always @(posedge osc_clock) div <= div + 1'b1;

// Такторая частота PPU ниже в примерно ~2 x 2,3 раза, чем VGA
// Вычисление правильных таймингов (341 x 262)
always @(posedge vga_clock) begin
    
    XPos <= XPos == 10'd799 ? 1'b0 : XPos + 1'b1;
    YOdd <= XPos == 10'd799 ? YOdd ^ 1'b1 : YOdd;
    
    // В строку из 800Т должно помещаться только 341 PPU
    ppu_clock <= ppu_clock ? 1'b0 : (YOdd && (XPos < 10'd682));

end

// Тактовая частота процессора в 3 раза ниже, чем PPU
always @(posedge ppu_clock) begin

    if (YOdd)
    
        case (COdd)
        
            2'b00: begin COdd <= 2'b01; cpu_clock <= 1'b1; end
            2'b01: begin COdd <= 2'b10; cpu_clock <= 1'b0; end
            2'b10: begin COdd <= 2'b00; end
        
        endcase

end

endmodule
