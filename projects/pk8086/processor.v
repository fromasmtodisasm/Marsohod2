// Набор инструкции x8086
module processor(

    input   wire            clock,      // 10 mhz
    input   wire            locked,     // Если =0, PLL не сконфигурирован
    input   wire            m_ready,    // Готовность данных из памяти (=1 данные готовы)
    output  wire    [19:0]  o_addr,     // Указатель на память
    input   wire    [15:0]  i_data,     // Данные из памяти
    output  wire    [15:0]  o_data,     // Данные за запись
    output  wire            o_wr        // Строб записи в память

);

// Текущий указатель на память
assign o_addr = xa ? {XS, 4'h0} + EA : {CS, 4'h0} + IP;

// Т.к. данные 16-битные, то записывается то, что находится либо в старшем, либо в младшем байте
assign o_data = o_addr[0] ? {o8_data, i_data[7:0]} : {i_data[15:8], o8_data};

// 1 Загрузка операции в память 6 байт (3 такта)
// 2 Декодирование
// 3 Исполнение
// 4 Запись результатов

// ОПИСАНИЯ РЕГИСТРОВ
// ---------------------------------------------------------------------

    // Сегментные регистры
    reg [15:0] CS; reg [15:0] IP;
    reg [15:0] DS; reg [15:0] ES;
    reg [15:0] SS;
    
    // Рабочий (эффективный) адрес
    reg [15:0] XS; reg [15:0] EA;

    // Регистры общего назначения
    reg [15:0] AX; reg [15:0] BP;
    reg [15:0] CX; reg [15:0] SP; 
    reg [15:0] DX; reg [15:0] SI;
    reg [15:0] BX; reg [15:0] DI;

// ---------------------------------------------------------------------

// Текущий байт для его обработки
reg  [7:0]  o8_data;
wire [7:0]  i8_data = o_addr[0] ? i_data[15:8] : i_data[7:0];

// Управляющие регистры
// ---------------------------------------------------------------------

reg         xa;                         // Указатель на XS:EA
reg [3:0]   m;
reg [7:0]   opc;

// Префиксы
reg RepNZ;      reg t_RepNZ;            // Префикс RepNZ
reg RepZ;       reg t_RepZ;             // Префикс RepZ
reg Override;   reg t_Override;         // Сегментный префикс есть

// ---------------------------------------------------------------------
initial begin

    m  = 1'b0;
    xa = 1'b0;
    o8_data = 8'h00;

    // Стартовый адрес всегда тут :FFFF0
    CS = 16'h0000; // @TODO ---- 16'hFFFF;
    IP = 16'h0000;
    
    opc = 1'b0;
    
    t_RepNZ = 1'b0; 
    t_RepZ  = 1'b0;
    t_Override = 1'b0;

end

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ОСНОВНОЙ ПРОЦЕССОРНЫЙ ТАКТ
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

always @(posedge clock) if (locked) begin

    case (m)
    
        // Разбор инструкции или их выполнение в тот же момент
        4'h0: begin 
        
            IP <= IP + 1'b1;

            // Префиксы
            if      (i8_data == 8'h26) begin t_Override <= 1'b1; XS <= ES; end
            else if (i8_data == 8'h2E) begin t_Override <= 1'b1; XS <= CS; end
            else if (i8_data == 8'h36) begin t_Override <= 1'b1; XS <= SS; end
            else if (i8_data == 8'h3E) begin t_Override <= 1'b1; XS <= DS; end  
            else if (i8_data == 8'hF2) begin t_RepNZ <= 1'b1; end
            else if (i8_data == 8'hF3) begin t_RepZ  <= 1'b1; end
            // Исполнение опкода
            else begin

                // Выбор сегмента с учетом Override
                XS <= t_Override ? XS : DS;

                // Перенос "теневых" к исполняемым
                Override <= t_Override;
                RepNZ <= t_RepNZ;
                RepZ <= t_RepZ;

                // Сброс на следующий раз
                t_Override <= 1'b0;
                t_RepNZ <= 1'b0;
                t_RepZ <= 1'b0;
                
                // Для последующего использования                
                opc <= i8_data;            
            
            end
        
        end

    endcase    
end

endmodule

