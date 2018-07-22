
// Объявляем нужные провода
wire [11:0] adapter_font;
wire [ 7:0] adapter_data;
wire [11:0] font_char_addr;
wire [ 7:0] font_char_data;

text8025 u0vga(

	.clk	(CLOCK25MHZ),	
	.red 	(VGA_RED),
	.green	(VGA_GREEN),
	.blue	(VGA_BLUE),
	.hs		(VGA_HS),
	.vs		(VGA_VS),
    
    // Источник знакогенератора
    .adapter_font (adapter_font),
    .adapter_data (adapter_data),
    
    // Сканирование символов
    .font_char_addr (font_char_addr),
    .font_char_data (font_char_data)

);

// Здесь хранятся шрифты (знакогенератор)
textfont u1vga(

    .clock      (CLK100MHZ),    // Тактовая частота - 100 Мгц для памяти
    .addr_rd    (adapter_font), // Адрес, чтобы узнать значение следующих 8 бит для шрифта
    .q          (adapter_data)  // Здесь будет это значение через 2 такта на скорости 100 Мгц
);


// Информация о символах и атрибутах
textram u2vga(

    .clock      (CLK100MHZ),      // Тактовая частота - 100 Мгц для памяти
    .addr_rd    (font_char_addr), // В памяти сначала хранится символ, потом его цвет
    .q          (font_char_data)  // Тут будет результат 
);
