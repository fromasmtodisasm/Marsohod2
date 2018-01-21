`ifndef __mod_irq
`define __mod_irq

reg [2:0]  irq;
reg [18:0] irq_38_timer;


// 25 mhz
always @(posedge clock) begin

    if (irq_38_timer == 19'd500000) begin
        irq_38_timer <= 1'b0;
    end else begin
        irq_38_timer <= irq_38_timer + 1'b1;
    end

end

`endif