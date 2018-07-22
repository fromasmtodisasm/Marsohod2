/* Прием сигналов от Realtek Ethernet */
module rtlget(

    input  wire         rtl_clk,   /* 25Mhz */
	input  wire [3:0]   rtl_rxd,   /* Полученный ниббл */
	input  wire         rtl_rxdv,  /* Получены валидные данные */
    output reg [7:0]    data,      /* Байт */
    output wire         ready,     /* Байт готов */
    output wire         term       /* Признак конца потока */
);

reg latch = 1'b0;  /* Указатель ниббла */
reg rxdv  = 1'b0;  /* Предыдущее состояние rtl_rxdv, чтобы определять конец последотательности */

/* Если =0 и предыдущее состояние =1, то байт готов */
assign ready = (~latch) & rxdv;
assign term = rxdv & (~rtl_rxdv);

/* Предыдущее состояние */
always @(posedge rtl_clk) begin

    rxdv <= rtl_rxdv; 
    
end

/* Прием пакета в правильном порядке */
always @(posedge rtl_clk) begin

    if (rtl_rxdv) begin
    
        /* Поскольку байты в Ethernet BIG Endian, то биты записываются в обратном порядке 0123, а не 3:0 */
        /* И первый ниббл сначала записывается в младшую часть, потом переходя в старшую, тем самым биты идут как 0->7 */
        data   <= {data[3:0], rtl_rxd[0], rtl_rxd[1], rtl_rxd[2], rtl_rxd[3]};
        
        /* Когда RLatch = 0, считается, что байт принят успешно */
        latch <= ~latch;
                
    end 
    else /* Сброс */ latch <= 1'b0;

end

endmodule
