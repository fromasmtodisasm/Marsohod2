/*
videoadapter VGADISP(
    .clock  (clk),
    .hs     (vga_hs),
    .vs     (vga_vs),
    .r      (vga_red),
    .g      (vga_green),
    .b      (vga_blue)
);
*/

module videoadapter(

    input   wire            clock,  // 100 Mhz
    output  wire            hs,
    output  wire            vs,
    output  wire    [4:0]   r,
    output  wire    [5:0]   g,
    output  wire    [4:0]   b,
    
    output  reg             rden,
    output  reg     [21:0]  addr,
    input   wire    [15:0]  dr,
    
    output  reg     [15:0]  dw,
    output  reg             wren
);

assign r = dp[15:11];
assign g = dp[10:5];
assign b = dp[4:0];

reg     [15:0]  dp;
reg     [2:0]   div25;
reg     [10:0]  x;
reg     [9:0]   y;

assign  hs = x > 10'd688 && x <= 10'd784; 
assign  vs = y > 10'd513 && y <= 10'd515; 
wire    display = x < 10'd640 && y < 10'd480;
wire    xend = x == 11'd800;
wire    yend = y == 10'd525;

// -----------------------------------
// [1] 640x480 [800 x 525] 25 MHz
// [0] 800x600 [1040 x 666] 50 Mhz
// -----------------------------------

always @(posedge clock) div25 <= div25 + 1'b1;
always @(posedge div25[1]) begin    

    // Позиция "курсора" в текущем фрейме
    x <= xend ?         1'b0 : x + 1'b1;
    y <= xend ? (yend ? 1'b0 : y + 1'b1) : y;

    
    if (display) begin

        addr <= {y[8:0], x[7:0]}; 
        rden <= 1'b1;  
        dp   <= dr; 
        wren <= 1'b0;
    
    // Out of Screen: operate others
    end else begin 
    
        dp <= 1'b0; 
        rden <= 1'b0; 
        
        addr <= {y[8:0], x[9:0] - 640}; 
        
        if (y < 32) begin dw <= {y[7:0],x[7:0]}; wren <= 1'b1; end
        
    end

end

endmodule