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

// 25 Mhz
always @(posedge bdiv[1]) begin

    if (x == 10'd800) begin
    
        x <= 1'b0;
        y <= (y == 10'd525) ? 1'b0 : (y + 1'b1); 
        
    end else x <= x + 1'b1;
    
    // Сигналы синхронизации
    hs <= (x >= 10'd656 && x <= 10'd751); // [ w=640 ] [front=16] [sync=96] [back=48]
    vs <= (y >= 10'd490 && y <= 10'd492); // [ h=480 ] [front=10] [sync=2]  [back=33]
    
    // Видеофрейм
    // ------------------------------------------------
    if (x < 10'd640 && y < 10'd480) begin
    
        if (x >= 64 && x < 576 && y >= 48 && y < 432) begin
        
            // Пока что серый цвет
            r <= bitset? 1'b0 : 5'h0F; 
            g <= bitset? 1'b0 : 6'h1F;
            b <= bitset? 1'b0 : 5'h0F;
        
        // Пока что серый цвет
        end else begin 
        
            r <= vga_border[0] ? 5'h0F : 1'b0; 
            g <= vga_border[1] ? 6'h1F : 1'b0;
            b <= vga_border[2] ? 5'h0F : 1'b0;
            
        end
    
    end else begin r <= 1'b0; g <= 1'b0; b <= 1'b0; end
    // ------------------------------------------------
    
    case (rx[3:0])
    
        // 10y yyyy | yyyx xxxx
        4'h0: begin addr <= {2'b10, ry[8:1], rx[8:4]}; end 
        
        // 101 10yy | yyyx xxxx
        4'h1: begin addr <= {5'b10110, ry[8:4], rx[8:4]}; bit8 <= d8_chr; end 
        
        // Битовая маска
        4'hF: begin attr <= d8_chr; mask <= bit8; end 

    endcase

end

endmodule
