/*
 * Генератор 32-х битных случайных чисел
 * https://marsohod.org/projects/proekty-dlya-platy-marsokhod3/325-random-gen
 */

wire [31:0] rnd;
 
rand32 RAND32(

    .clock (clk), // 100 Mhz 
    .rnd   (rnd)  // 32 bit

);