/*
 * Контроллер строба записи в память из CLK-25 CPU 
 * Используется для demo_processor (25Мгц)
 */

// BEGIN
reg [2:0] cntl_mw = 3'b000; // Зашёлка отслеживания переднего фронта clk_25
assign    cntl_w  = cntl_mw == 3'b011 && o_wr; // Обнаружение переднего фронта и уровня записи [demo_processor.o_wr]
always @(posedge clk) cntl_mw <= {cntl_mw[1:0], clock_25}; // Запись защёлки переднего фронта [из PLL.clock_25]
// END