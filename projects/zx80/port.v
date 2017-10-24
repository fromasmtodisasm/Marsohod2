module port(

    input  wire        clock,
    input  wire [15:0] addr,
    input  wire [7:0]  data_in,
    output wire [7:0]  data_out,
    
    output reg [2:0]   vga_border
    
);

initial begin

    vga_border = 3'b111; // По умолчанию это белый цвет бордюда

end

// ----------------------------------------------------
assign data_out = 

    // Цвет бордера из регистра VGA
    (addr == 16'h00FE) ? vga_border : 1'b0;

// Запись в порт только на обратном фронте
// ----------------------------------------------------
always @(negedge clock) begin

    case (addr)

        // ... чтение из клавиатуры (последняя клавиша) --> 16'h00FF
        16'h00FE: vga_border[2:0] <= data_in[2:0];

    endcase

end

endmodule 
