module videoadapter(

    input   wire            clock,          // 100 Mhz
    output  wire            hs,
    output  wire            vs,
    output  wire    [4:0]   r,
    output  wire    [5:0]   g,
    output  wire    [4:0]   b

);

assign r = {5{1'b0}};
assign g = {5{pixel}};
assign b = {5{1'b0}};

reg     [1:0]   div25;
reg     [10:0]  x;
reg     [9:0]   y;

assign  hs = x > 10'd688 && x <= 10'd784; 
assign  vs = y > 10'd513 && y <= 10'd515; 
wire    display = x < 10'd640 && y < 10'd480;

reg             pixel;
reg     [5:0]   timing;

// 100 -> 25, 50 Mhz
always @(posedge clock) div25 <= div25 + 1'b1;

// Чисто вывод на экран 8x8 символа
wire [7:0] ch1 = y[2:0] == 3'b000 ? 8'b00000000 : 
                 y[2:0] == 3'b001 ? 8'b00000000 : 
                 y[2:0] == 3'b010 ? 8'b00000000 : 
                 y[2:0] == 3'b011 ? 8'b00000000 : 
                 y[2:0] == 3'b100 ? 8'b00000000 : 
                 y[2:0] == 3'b101 ? 8'b00000000 : 
                 y[2:0] == 3'b110 ? 8'b01010100 :  
                                    8'b00000000;

// Чисто проверка
wire [7:0] ch2 = y[2:0] == 3'b000 ? 8'b01111100 : 
                 y[2:0] == 3'b001 ? 8'b11000110 : 
                 y[2:0] == 3'b010 ? 8'b11000110 : 
                 y[2:0] == 3'b011 ? 8'b11000110 : 
                 y[2:0] == 3'b100 ? 8'b11111110 : 
                 y[2:0] == 3'b101 ? 8'b11000110 : 
                 y[2:0] == 3'b110 ? 8'b11000110 :  
                                    8'b00000000;

wire [7:0] ch = x[3] ^ y[3] ^ timing[5] ? ch1 : ch2;

// [1] 640x480 [800 x 525] 25 MHz
// [0] 800x600 [1040 x 666] 50 Mhz

always @(posedge div25[1]) begin	

    if (x == 11'd800) begin
        x <= 1'b0;
        if (y == 10'd525) begin
            y <= 1'b0;
            timing <= timing + 1'b1;
        end else begin
            y <= y + 1'b1;
        end
    end else begin
        x <= x + 1'b1;	
    end
    
    // Отрисовка видимой области (640x480, 800x600)
    pixel <= display ? ch[ x[2:0] ^ 3'b111 ] : 1'b0;

end

endmodule