/*
 * 8-битный процессор
 * 
 * - на основе инструкции 6502
 * - на скорости 25 мгц
 */
 
module demo_processor(
   
    // Тактирование процессора на стандартной частоте 25 Мгц
    input   wire        clock_25,
    
    // 8-битная шина данных
    input   wire [7:0]  i_data,         // Входящие данные
    output  wire [15:0] o_addr,         // 16-битный адрес (64 кб адресное пространство)
    output  reg  [7:0]  o_data,         // Данные для записи
    output  reg         o_wr            // Запись в память

);

/*
 * Роутинг
 */

assign o_addr = alt ? addr : pc;

/*
 * Регистры
 */
 
reg [7:0]  a; // Аккумулятор
reg [7:0]  x; // Индексный регистр
reg [7:0]  y; // Индексный регистр
reg [7:0]  p; // Флаги
reg [7:0]  s; // Стек $100-$1FF
reg [15:0] pc; // Регистр адреса

/*
 * Состояния
 */

reg [3:0]  t;        // Текущее состояние процессора
reg [7:0]  op_cache; // Предущущее состояние опкода
reg        alt;      // Если =1, то смотрит в память [addr], иначе на [pc]
reg [15:0] addr;     // Указатель на рабочую область памяти

/*
 * Инициализация первичных значений
 */

initial begin

    a = 8'h00;
    x = 8'h00; y = 8'h00;
    p = 8'h00; s = 8'h00;
    
    t = 4'h0;
    alt = 1'b0;
    
    // Должны совпадать вначале
    pc     = 16'h0000;
    addr   = 16'h0000;
    
    op_cache = 8'h00;
    o_data = 8'h00;
    o_wr = 1'b0;

end

/*
 * Дешифратор кода операции
 */

// Актуальный опкод всё время
wire [7:0] opcode = t ? op_cache : i_data;
 
// Арифметико-логические операции [aaaxxx01]
wire c_alu = opcode[1:0] == 2'b01;

/* -------------------------------------------------------------------------
 * Дешифрация типа операнда
 *
 * (I,X)    - Расчет (I+X) & 255, извлечение 16 битного числа (wrapping) 
 * (I),Y    - Сначала 16 битный адрес (I), потом + Y
 * IMM      - Следующий байт является непосредственным значением
 * ZP       - Извлечение байта из ZeroPage
 * IND      - Извлечение 16 бит из (ABS) адреса
 */
 
// (I,X) xxx00001
wire t_ndx = c_alu & (opcode[4:0] == 5'b00001);

// (I),Y xxx10001 | 10111110
wire t_ndy = c_alu & (opcode[4:0] == 5'b10001);

// IMM xxx01001 | 1xx00001 | 10100010
wire t_imm = (c_alu & (opcode[4:0] == 5'b01001)) | ({opcode[7], opcode[4:0]} == 6'b100001) | (opcode == 8'hA2);

// #ZP xxx001xx
wire t_zp = (opcode[4:2] == 3'b001);

// IND 01101100
wire t_ind = (opcode == 8'h6C);

// #ABS xxx001xx (кроме JMP IND)
// #ABS 00100000
wire t_abs = ((opcode[4:2] == 3'b001) && ~t_ind) || (opcode == 8'h20);

// ZPY 10x10110
wire t_zpy = (opcode == 8'hB6 || opcode == 8'h96);

// ZPX xxx101xx
wire t_zpx = (opcode[4:2] == 3'b101) && ~t_zpy;

// ABY xxx11010 (АЛУ)
// ABY 10x11110 (Отдельная инструкция)
wire t_aby = (c_alu & (opcode[4:0] == 5'b11001)) || (opcode == 8'hBE) || (opcode == 8'h9E);

// ABX xxx111xx
wire t_abx = (opcode[4:2] == 3'b111) && ~t_aby;

// REL xxx10000
wire t_rel = (opcode[4:0] == 5'b10000);

// Implied считать все оставшиеся
// xxx 010 00
// xxx 110 00
// xxx 010 10
// 1xx 110 10
// 01x 000 00 RTI / RTS
// 000 000 00 BRK

// Метод исключения для нахождения Implied
wire t_imp = ~(t_ndx | t_ndy | t_imm | t_zp | t_ind | t_abs | t_abx | t_aby | t_zpx | t_zpy | t_rel);

// -------------------------------------------------------------------------

/*
 * Главная процессорная логика
 */

always @(posedge clock_25) begin

    case (t)
    
        /*
         * Выполнение первой инструкции после дешифрации
         */
    
        4'h0: begin
        
            op_cache <= i_data;            
            pc <= pc + 1'b1;
        
        end

    endcase

end

endmodule
