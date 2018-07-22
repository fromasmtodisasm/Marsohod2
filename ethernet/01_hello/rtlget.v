/* Прием сигналов от Realtek Ethernet */
module rtlget(

    input wire          rtl_clk,   /* 25Mhz */
	input wire [3:0]    rtl_rxd,   /* Полученный ниббл */
	input wire          rtl_rxdv   /* Получены валидные данные */
    
);

reg [7:0] RByte = 8'h00;  /* Следующий принятый байт */
reg       RLatch = 1'b0;  /* Указатель ниббла */
//reg       Prdx   = 1'b0;  /* Предыдущее состояние rtl_rxdv, чтобы определять конец последотательности */

/* Прием пакета в правильном порядке */
always @(posedge rtl_clk) begin

    if (rtl_rxdv) begin
    
        /* Поскольку байты в Ethernet BIG Endian, то биты записываются в обратном порядке 0123, а не 3:0 */
        /* И первый ниббл сначала записывается в младшую часть, потом переходя в старшую, тем самым биты идут как 0->7 */
        RByte  <= {RByte[3:0], rtl_rxdv[0], rtl_rxdv[1], rtl_rxdv[2], rtl_rxdv[3]};
        
        /* Когда RLatch = 0, считается, что байт принят успешно */
        RLatch <= ~RLatch;
                
    end else /* Сброс */ RLatch <= 1'b0;

end

endmodule
