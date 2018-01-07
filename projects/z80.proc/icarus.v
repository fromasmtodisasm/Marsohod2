`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------
reg         i_clk;
reg         o_clk;
always #0.5 i_clk         = ~i_clk;
always #0.5 o_clk         = ~o_clk;

initial begin
    i_clk = 1; 
    o_clk = 0; 
    #2000 $finish; 
end

initial begin $dumpfile("result.vcd"); $dumpvars(0, main); end
// ---------------------------------------------------------------------

reg  [7:0]  i_data;
wire [7:0]  o_data;
wire [15:0] o_addr;
wire        o_wr;

z80 IZ80(
    i_clk,
    1'b1,
    i_data,
    o_data,
    o_addr,
    o_wr
);

// ---------------------------------------------------------------------
reg [7:0] memory[65535:0];

initial begin
    $readmemh("rom.hex", memory);
end


always @(posedge o_clk) begin

    i_data <= memory[ o_addr ];    
    if (o_wr) memory[ o_addr ] <= o_data;

end

endmodule
