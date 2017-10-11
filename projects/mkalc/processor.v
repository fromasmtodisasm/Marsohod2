/*
 * Простой 8-битный процессор
 * 
 * - на основе инструкции 6502
 * - на скорости 25 мгц
 */
 
module processor(

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
 7 6 5 4 3 2 1 0
 N V 1 B D I Z C (Флаги)


 N - Negative (отрицательное число)
 V - Overflow (переполнение)
 B - Breakpoint
 D - Decimal (двоично-десятичный режим)
 I - Interrupt (прерывание)
 Z - Zero (результат равен 0)
 C - Carry (перенос)
 
 */

/*
 * Состояния
 */

reg [3:0]  t;        // Текущее состояние процессора
reg [2:0]  am;       // Address Mode = 0..7, декодирование
reg [7:0]  op_cache; // Предущущее состояние опкода
reg        alt;      // Если =1, то смотрит в память [addr], иначе на [pc]
reg [15:0] addr;     // Указатель на рабочую область памяти
reg [7:0]  tmp8;     // Временный 8-bit регистр


/*
 * Инициализация первичных значений
 */

initial begin

    a = 8'h17;
    x = 8'h00; 
    y = 8'h00;
    p = 8'h00; 
    s = 8'h00;
    
    t   = 4'h0;
    am  = 3'h0;
    alt = 1'b0;
    
    // Должны совпадать вначале
    pc     = 16'h0000;
    addr   = 16'h0000;
    
    op_cache = 8'h00;
    o_data  = 8'h00;
    o_wr    = 1'b0;

end

/*
 * Вычисления АЛУ
 */
 
wire [7:0] r_ora = a | i_data;
wire [7:0] r_and = a & i_data;
wire [7:0] r_eor = a ^ i_data;
wire [8:0] r_adc = a + i_data + p[0];
wire [8:0] r_sbc = a - i_data - p[0] ^ 1'b1;
wire       r_adc_v = (a[7] ^ i_data[7] ^ 1'b1) & (a[7] ^ r_adc[7]);
wire       r_sbc_v = (a[7] ^ i_data[7]       ) & (a[7] ^ r_adc[7]);

wire [15:0] pc_rel = pc + {{8{i_data[7]}}, i_data[6:0]} + 1'b1;

/*
 * Дешифратор кода операции
 */

// Актуальный опкод всё время
wire [7:0] opcode = t ? op_cache : i_data;

// Вычисление ZP адресации на основе различных типов адресации (2,6,7)
wire [7:0] zpx = i_data + (t == 4'h6 ? y : (t == 4'h7 ? x : 1'b0));

/*
 * Главная процессорная логика
 */

always @(posedge clock_25) begin

    case (t)
    
        // Дешифратор режима адресации
        4'h0: begin

            op_cache <= i_data;
            pc <= pc + 1'b1;
            am <= 1'b0;
        
            // Дешифрация
            casex (opcode)
            
                // Непрямой,X            ($FF,X)
                8'bxxx_000_x1: t <= 4'h1;                
                
                // ZP,Y                  $FF,Y
                8'b10x_101_1x: t <= 4'h6;

                // ZP,X                  $FF,X
                8'bxxx_101_xx: t <= 4'h7;
                
                // ZP                    $FF
                8'bxxx_001_xx, 
                8'b1xx_00x_00: t <= 4'h2;

                // Абсолютный            $FFFF
                8'b001_000_00,
                8'bxxx_011_xx: t <= 4'h3;
                
                // (Непрямой),Y          ($FF),Y
                8'bxxx_100_x1: t <= 4'h8;

                // Абсолютный,Y          $FFFF,Y
                8'bxxx_110_x1, 
                8'b10x_111_1x: t <= 4'h4;

                // Абсолютный,X          $FFFF,X
                8'bxxx_111_xx: t <= 4'h5;
                
                // Условные переходы     Метка (-128..127)
                8'bxxx_100_00: t <= 4'h9; 
                
                // #Непосредственный     #$FF
                8'bxxx_010_x1: t <= 4'hC;
                
                // Инструкции пересылки
                8'b00x_110_00: p[0] <= opcode[5]; // CLC, SEC
                8'b01x_110_00: p[2] <= opcode[5]; // CLI, SEI
                8'b100_110_00: begin a <= y; p <= {y[7], p[6:2], y == 1'b0, p[0]}; end // TYA
                8'b101_110_00: p[6] <= 1'b0; // CLV
                8'b11x_110_00: p[3] <= opcode[5]; // CLD, SED
                
                // Нет операндов
                default: begin 
                               

                    t <= 4'hC; // В некоторых случаях!

                end

            endcase
        
        end
        
        /*
         * Чтение операндов
         */
        
        // 1 - Indirect,X
        // 8 - Indirect,Y
        4'h1, 4'h8: case (am)

            3'h0: begin am <= 3'h1; addr <= {8'h00, i_data + (t == 4'h1 ? x : 1'b0)}; pc <= pc + 1'b1; alt <= 1'b1; end // Перейти к этому адресу (Addr + X)
            3'h1: begin am <= 3'h2; tmp8 <= i_data; addr[7:0] <= addr[7:0] + 1'b1; end // Прочитать младший байт
            3'h2: begin t  <= 4'hC; addr <= {i_data, tmp8} + (t == 4'h8 ? y : 1'b0); end // Проставить новый указатель для чтения операнда и переход к исполнению

        endcase

        // 2 - Zero Page
        // 6 - Zero Page,Y
        // 7 - Zero Page,X
        4'h2, 4'h6, 4'h7: begin alt <= 1'b1; addr <= zpx; t <= 4'hC; pc <= pc + 1'b1; end // Читать байт из указанной в ZP [+y, +x]
        
        // 3 - Absolute
        // 4 - Absolute,Y
        // 5 - Absolute,X
        4'h3, 4'h4, 4'h5: case (am)

            3'h0: begin am <= 3'h1; tmp8 <= i_data; pc <= pc + 1'b1; end // Читать младший байт
            3'h1: begin t  <= 4'hC; addr <= {i_data, tmp8} + (t == 4'h4 ? x : (t == 4'h5 ? y : 0)); pc <= pc + 1'b1; alt <= 1'b1; end // Старший байт [+X,Y]

        endcase  

        // BRANCH - Условный переход
        4'h9: begin
        
            casex (opcode[4:2])
            
                3'b00x: if (p[7] == opcode[0]) pc <= pc_rel; else pc <= pc + 1'b1; // BPL, BMI
                3'b01x: if (p[6] == opcode[0]) pc <= pc_rel; else pc <= pc + 1'b1; // BVC, BVS
                3'b10x: if (p[0] == opcode[0]) pc <= pc_rel; else pc <= pc + 1'b1; // BCC, BCS
                3'b11x: if (p[1] == opcode[0]) pc <= pc_rel; else pc <= pc + 1'b1; // BNE, BEQ
            
            endcase
            
            t <= 1'b0;

        end
        
        // RESET: Сброс параметров после записи в память
        4'hA: begin o_wr <= 1'b0; alt <= 1'b0; t <= 1'b0; end

        // Исполнение опкодов       
        4'hC: begin 
        
            // ЗАПИСЬ В РЕГИСТРЫ ОБЩЕГО ЗНАЧЕНИЯ   
            // ---------------------------------      
            casex (opcode) 

                // ORA
                8'b000_xxx_01: begin 

                    a   <= r_ora; 
                    p   <= {r_ora[7], p[6:2], r_ora == 1'b0, p[0]};
                    
                end

                // AND
                8'b001_xxx_01: begin 

                    a   <= r_and; 
                    p   <= {r_and[7], p[6:2], r_and == 1'b0, p[0]};

                end

                // EOR
                8'b010_xxx_01: begin 
                
                    a   <= r_eor; 
                    p   <= {r_eor[7], p[6:2], r_eor == 1'b0, p[0]};
                
                end

                // ADC
                8'b011_xxx_01: begin 
                
                    a   <= r_adc[7:0]; 
                    p   <= {r_adc[7], r_adc_v, p[5:2], r_adc == 1'b0, r_adc[8]};

                end

                // LDA
                8'b101_xxx_01: begin
                
                    a   <= i_data;
                    p   <= {i_data[7], p[6:2], i_data == 1'b0, p[0]};
                
                end
                
                // CMP, SBC
                8'b11x_xxx_01: begin
                    
                    p   <= {i_data[7], r_sbc_v, p[5:2], r_sbc == 1'b0, p[0] ^ 1'b1};
                    if (opcode[5]) a <= r_sbc; // 11_1_xxx01 SBC
                
                end

                // TODO OPERATIONS
            
            endcase

            // ЗАПИСЬ В РЕГИСТРЫ УПРАВЛЕНИЯ
            // ---------------------------------
            // Операция STA, писать данные из A в память
            if ({opcode[7:5], opcode[1:0]} == 5'b10001) begin
            
                t      <= 4'hA;
                o_data <= a;
                o_wr   <= 1'b1;
                
                if (~alt) pc <= pc + 1'b1; // Immediate PC+1

            end 
            // Сдвиг PC+1 при 7 типах АЛУ-операции
            else if (opcode[1:0] == 2'b01) begin 
                            
                alt <= 1'b0; 
                t   <= 1'b0; 

                if (~alt) pc <= pc + 1'b1; // Immediate PC+1

            end
        
        end

    endcase

end

endmodule
