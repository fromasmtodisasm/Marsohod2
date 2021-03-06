/*
 * Видеоадаптер
 */
 
module vadapter(

    input wire        clock,        
    input wire [7:0]  d8_chr,
    input wire [2:0]  vga_border,
    output reg [13:0] addr,
    output reg [4:0]  r,
    output reg [5:0]  g,
    output reg [4:0]  b,
    output reg        hs,
    output reg        vs
);

// ---------------------------------------------------------------------------
// http://tinyvga.com/vga-timing/640x480@60Hz
// ---------------------------------------------------------------------------

reg  [9:0] x;
reg  [9:0] y;
reg  [7:0] attr;
reg  [7:0] bit8;
reg  [7:0] mask;

wire [9:0] rx = x - 8'd48;
wire [9:0] ry = y - 8'd48;
wire       bitset = mask[ 3'h7 ^ rx[3:1] ];

reg [1:0] bdiv = 2'b00;
always @(posedge clock) bdiv <= bdiv + 1'b1;

reg [15:0] color_fr;
reg [15:0] color_bg;
reg [15:0] border;

reg [6:0] frame = 1'b0; // 0..49
reg [9:0] n = 1'b0; // счетчик
reg       blink;

// Цвета
always @* begin

    case ({attr[6],attr[2:0]})
    
        4'b0000: color_fr = 16'b00000_000000_00000;
        4'b0001: color_fr = 16'b00000_000000_11000;
        4'b0010: color_fr = 16'b11000_000000_00000;
        4'b0011: color_fr = 16'b11000_000000_11000;
        4'b0100: color_fr = 16'b00000_110000_00000;
        4'b0101: color_fr = 16'b00000_110000_11000;
        4'b0110: color_fr = 16'b11000_110000_00000;
        4'b0111: color_fr = 16'b11000_110000_11000;
        4'b1000: color_fr = 16'b00000_000000_00000;
        4'b1001: color_fr = 16'b00000_000000_11111;
        4'b1010: color_fr = 16'b11111_000000_00000;
        4'b1011: color_fr = 16'b11111_000000_11111;
        4'b1100: color_fr = 16'b00000_111111_00000;
        4'b1101: color_fr = 16'b00000_111111_11111;
        4'b1110: color_fr = 16'b11111_111111_00000;
        4'b1111: color_fr = 16'b11111_111111_11111;
    
    endcase
    
    case (attr[5:3]) 
    
        3'b000: color_bg = 16'b00000_000000_00000;
        3'b001: color_bg = 16'b00000_000000_11000;
        3'b010: color_bg = 16'b11000_000000_00000;
        3'b011: color_bg = 16'b11000_000000_11000;
        3'b100: color_bg = 16'b00000_110000_00000;
        3'b101: color_bg = 16'b00000_110000_11000;
        3'b110: color_bg = 16'b11000_110000_00000;
        3'b111: color_bg = 16'b11000_110000_11000;

    endcase
    
    case (vga_border[2:0]) 
    
        3'b000: border = 16'b00010_000011_00011; // Хак, чтобы монитор не "ехал"
        3'b001: border = 16'b00000_000000_11000;
        3'b010: border = 16'b11000_000000_00000;
        3'b011: border = 16'b11000_000000_11000;
        3'b100: border = 16'b00000_110000_00000;
        3'b101: border = 16'b00000_110000_11000;
        3'b110: border = 16'b11000_110000_00000;
        3'b111: border = 16'b11000_110000_11000;

    endcase

end

// 25 Mhz
always @(posedge bdiv[1]) begin

    if (x == 10'd799) begin
    
        x <= 1'b0;
        y <= (y == 10'd524) ? 1'b0 : (y + 1'b1);
        
        // 50 Гц симуляция фрейма
        if (n == 10'd624) begin 
        
            n <= 1'b0; 
            
            // Каждые 1/2 секунд - blink
            if (frame == 6'd24) begin
                
                frame <= 1'b0;
                blink <= !blink;
                
            end else begin            
                frame <= frame + 1'b1; 
            end
            
            // @todo do call interrupt 
            
        end else n <= n + 1'b1;
        
    end else x <= x + 1'b1;
    
    // Сигналы синхронизации
    hs <= (x >= 10'd656 && x <= 10'd751); // [ w=640 ] [front=16] [sync=96] [back=48]
    vs <= (y >= 10'd490 && y <= 10'd492); // [ h=480 ] [front=10] [sync=2]  [back=33]
    
    // Видеофрейм
    // ------------------------------------------------
    if (x < 10'd640 && y < 10'd480) begin
    
        if (x >= 64 && x < 576 && y >= 48 && y < 432) begin
        
            // Если есть атрибут "мерцание", использовать blink
            {r, g, b} <= (attr[7] ? (bitset ^ blink) : bitset) ? color_fr : color_bg;
            
        // Пока что серый цвет
        end else begin 
        
            {r, g, b} <= border;
            
        end
    
    end else begin r <= 1'b0; g <= 1'b0; b <= 1'b0; end
    // ------------------------------------------------
    
    case (rx[3:0])
    
        // 10Y Yyyy | YYYx xxxx
        4'h0: begin addr <= {2'b10, ry[8:7], ry[3:1], ry[6:4], rx[8:4]}; end 
        
        // 101 10yy | yyyx xxxx
        4'h1: begin addr <= {5'b10110, ry[8:4], rx[8:4]}; bit8 <= d8_chr; end 
        
        // Битовая маска
        4'hF: begin attr <= d8_chr; mask <= bit8; end 

    endcase

end

endmodule
