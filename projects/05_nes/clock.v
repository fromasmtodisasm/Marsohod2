module clock(

    // Главные такты
    input   wire    i_100_mhz,

    // VGA
    output  wire    o_25_mhz,

    // NES PPU
    output  reg     o_ppu

);

initial o_ppu = 1'b0;

// Основная частота
reg     [1:0]   divisor     = 1'b0;
assign          o_25_mhz    = divisor[1];

// Вычисление необходимых таймингов
reg     [9:0]   XPos        = 1'b0;
reg             YOdd        = 1'b1;

// Делитель частоты
always @(posedge i_100_mhz) begin   
    divisor <= divisor + 1'b1;    
end

// Вычисление правильных таймингов (341 x 262)
always @(posedge o_25_mhz) begin
    
    XPos <= XPos == 10'd799 ? 1'b0 : XPos + 1'b1;
    YOdd <= YOdd == 10'd799 ? YOdd ^ 1'b1 : YOdd;
    
    // Передний фронт разрешать
    if (o_ppu == 1'b0) begin
        o_ppu <= YOdd & (XPos < 10'd682);
        
    // На обратном фронте разрешить только в необходимых пределах
    end else begin    
        o_ppu <= 1'b0;        
    end

end

endmodule
