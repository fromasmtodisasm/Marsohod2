/*
 * Демо-процессор на основе 6502, 8 бит
 */

wire [7:0]  i_data;
wire [15:0] o_addr;
wire [7:0]  o_data;
wire        o_wr;
 
demo_processor DPROC6502(

    // 25 Мгц опорная частота
	.clk_25     (locked & clock_25),    // PLL.locked & PLL.clock_25

	// Прямоугольный
	.i_data     (i_data),       // Входящие данные
	.o_addr     (o_addr),       // Текущий адрес
    .o_data     (o_data),       // Исходящие данные
    .o_wr       (o_wr),         // Уровень записи (0 - нет, 1 - записывается)

);
