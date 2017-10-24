// Набор инструкции x8086
module processor(

    input   wire            clock,      // 12,5 MHz
    input   wire            locked,     // Если =0, PLL не сконфигурирован
    input   wire            m_ready,    // Готовность данных из памяти (=1 данные готовы)
    output  wire    [15:0]  o_addr,     // Указатель на память
    input   wire    [7:0]   i_data,     // Данные из памяти
    output  reg     [7:0]   o_data,     // Данные за запись
    output  reg             o_wr        // Строб записи в память

);

endmodule

