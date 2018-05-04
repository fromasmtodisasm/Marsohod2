module regfile(

    input  wire         clk,        // 100 Mhz
    input  wire [2:0]   Dr,         // Номер регистра Destination
    input  wire [2:0]   Sr,         // Номер регистра Source
    input  wire         b,          // Битность 0:8 бит, 1:16
    input  wire         W,          // Запись в регистр (W=1)
    input  wire [15:0]  d,          // Значение для записи (номер регистра: Dr)
    output reg  [15:0]  D,          // Значение регистра D
    output reg  [15:0]  S           // Значение регистра S

);

reg [15:0] ax = 16'h1254;
reg [15:0] cx = 16'h0440;
reg [15:0] dx = 16'h4010;
reg [15:0] bx = 16'h0201;
reg [15:0] sp = 16'h3024;
reg [15:0] bp = 16'h0342;
reg [15:0] si = 16'h0430;
reg [15:0] di = 16'h4003;

always @(posedge clk) begin

    if (W) begin

        case (Dr)

            3'b000: if (b) ax <= d; else ax[ 7:0] <= d[7:0];
            3'b001: if (b) cx <= d; else cx[ 7:0] <= d[7:0];
            3'b010: if (b) dx <= d; else dx[ 7:0] <= d[7:0];
            3'b011: if (b) bx <= d; else bx[ 7:0] <= d[7:0];
            3'b100: if (b) sp <= d; else ax[15:8] <= d[7:0];
            3'b101: if (b) bp <= d; else cx[15:8] <= d[7:0];
            3'b110: if (b) si <= d; else dx[15:8] <= d[7:0];
            3'b111: if (b) di <= d; else bx[15:8] <= d[7:0];

        endcase

    end

end

always @* begin

    // Первый регистр *назначение)
    case (Dr)
        3'b000: D = b ? ax : ax[7:0];
        3'b001: D = b ? cx : cx[7:0];
        3'b010: D = b ? dx : dx[7:0];
        3'b011: D = b ? bx : bx[7:0];
        3'b100: D = b ? sp : ax[15:8];
        3'b101: D = b ? bp : cx[15:8];
        3'b110: D = b ? si : dx[15:8];
        3'b111: D = b ? di : bx[15:8];
    endcase

    // Второй регистр (источник)
    case (Sr)
        3'b000: S = b ? ax : ax[ 7:0];
        3'b001: S = b ? cx : cx[ 7:0];
        3'b010: S = b ? dx : dx[ 7:0];
        3'b011: S = b ? bx : bx[ 7:0];
        3'b100: S = b ? sp : ax[15:8];
        3'b101: S = b ? bp : cx[15:8];
        3'b110: S = b ? si : dx[15:8];
        3'b111: S = b ? di : bx[15:8];
    endcase

end

endmodule
