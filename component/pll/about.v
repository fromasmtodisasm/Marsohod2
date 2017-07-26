/*
 * Генератор частот, по умолчанию 1/4, 1/8, 1/16 к входящей частоте
 */
 
wire locked;
wire clock_6;
wire clock_12;
wire clock_25;
 
pll PLL(

    .clk        (clk),          // Входящие 100 Мгц
    .locked     (locked),       // 0 - устройство генератора ещё не сконфигурировано, 1 - готово и стабильно
    .c0         (clock_25),     // 25,0 Mhz
    .c1         (clock_12),     // 12,5 Mhz
    .c2         (clock_6)       // 6,25 Mhz

);