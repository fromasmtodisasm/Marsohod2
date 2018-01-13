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
wire [15:0] port;
wire [7:0]  port_in; 
wire [7:0]  port_out;
wire        port_clk;

z80 IZ80(
    1'b0,
    i_clk,
    1'b0, // 1'b1 -- turbo
    i_data,
    o_data,
    o_addr,
    o_wr,    
    port,
    port_in,
    port_out,
    port_clk
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
