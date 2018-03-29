module ppu(

    // Кварцевый осциллятор 100 Mhz
    input   wire        osc_clock,

    // VGA 25,2 Мгц
    output  wire        vga_clock,

    // PPU 5.1 Мгц
    output  reg         ppu_clock,

    // CPU 1.71 Мгц
    output  reg         cpu_clock,

    // Выходные данные
    output  reg  [4:0]  red,        // 5 бит на красный (4,3,2,1,0)
    output  reg  [5:0]  green,      // 6 бит на зеленый (5,4,3,2,1,0)
    output  reg  [4:0]  blue,       // 5 бит на синий (4,3,2,1,0)
    output  wire        hs,         // синхросигнал горизонтальной развертки
    output  wire        vs          // синхросигнал вертикальной развертки

);

// ---------------------------------------------------------------------

initial begin cpu_clock = 1'b0; ppu_clock = 1'b0; end

// Тайминги для горизонтальной развертки (640)
parameter horiz_visible = 640;
parameter horiz_back    = 48;
parameter horiz_sync    = 96;
parameter horiz_front   = 16;
parameter horiz_whole   = 800;

// Тайминги для вертикальной развертки (400)
//                              // 400  480
parameter vert_visible = 480;   // 400  480
parameter vert_back    = 33;    // 35   33
parameter vert_sync    = 2;     // 2    2
parameter vert_front   = 10;    // 12   10
parameter vert_whole   = 525;   // 449  525

// 640 (видимая область) + 16 (передний порожек) + 96 (синхронизация) + 48 (задний порожек)
assign hs = x >= (horiz_visible + horiz_front) && x < (horiz_visible + horiz_front + horiz_sync);
assign vs = y >= (vert_visible  + vert_front)  && y < (vert_visible  + vert_front  + vert_sync);

// Частота 25 Мгц
assign vga_clock = clock_divider[1];

// В этих регистрах мы будем хранить текущее положение луча на экране
reg [9:0] x = 1'b0;                 // 2^10 = 1024 точек возможно
reg [9:0] y = 1'b0;
reg [1:0] clock_divider = 1'b0;     // 2х битный счетчик
reg [1:0] cpu_div       = 1'b0;

// Делитель частоты. На входе частота - 100 мгц, а на выходе будет 25 Мгц
always @(posedge osc_clock) clock_divider <= clock_divider + 1'b1;
// ---------------------------------------------------------------------

// Когда бит 1 переходит из состояния 0 в состояние 1, это значит, что
// будет осциллироваться на частоте 25 мгц (в 4 раза медленее, чем 100 мгц)
always @(posedge vga_clock) begin

    x <= x == 799 ?             1'b0 : (x + 1'b1);
    y <= x == 799 ? (y == 524 ? 1'b0 : (y + 1'b1)) : y;
    
    // В строку (800 тактов) помещается только 341 тактов PPU
    ppu_clock <= (x >= 64 && x < (64 + 341*2)) ? (ppu_clock ? 1'b0 : ~y[0]) : 1'b0;
    
    // Мы находимся в видимой области рисования
    if (x < 640 && y < 480) begin
    
		// Экран 512x480 находится по центру
        if (x >= 64 && x < 576 && y < 480) begin
        
            {red, green, blue} <= {5'h0F, 6'h1F, 5'h0F};
            
        // Бордюр
        end else begin

            {red, green, blue} <= {5'h03, 6'h03, 5'h03}; 
        
        end
    
    // В невидимой области мы ДОЛЖНЫ очищать в черный цвет
    // иначе видеоадаптер работать будет неправильно
    end else {red, green, blue} <= 16'h0000;
    
end

// Тактовая частота процессора в 3 раза ниже, чем PPU
always @(posedge ppu_clock) begin

    if (~y[0])
    
        case (cpu_div)
        
            2'b00: begin cpu_div <= 2'b01; cpu_clock <= 1'b1; end
            2'b01: begin cpu_div <= 2'b10; cpu_clock <= 1'b0; end
            2'b10: begin cpu_div <= 2'b00; end
        
        endcase
    
    else cpu_clock <= 1'b0;

end

endmodule
