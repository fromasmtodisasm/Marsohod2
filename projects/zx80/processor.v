// Набор инструкции x8086
module processor(

    input   wire            clock,      // 10 mhz
    input   wire            locked,     // Если =0, PLL не сконфигурирован
    input   wire            m_ready,    // Готовность данных из памяти (=1 данные готовы)
    output  wire    [19:0]  o_addr,     // Указатель на память
    input   wire    [15:0]  i_data,     // Данные из памяти
    output  reg     [15:0]  o_data,     // Данные за запись
    output  reg             o_wr        // Строб записи в память

);

`define INIT         4'h0
`define MODM         4'h1
`define MODM_DISP    4'h2
`define MODM_GET     4'h3
`define MODM_GET2    4'h4
`define INSTRUCTION  4'h5       // Исполнение инструкции
`define SUB_PUSH     4'h6       // Операция помещения в стек
`define SUB_POP      4'h7       // Извлечение из стека
`define RES_SAVE     4'h8       // Сохранение результата в регистр или в память

// Текущий указатель на память
assign o_addr = rd ? {WS, 4'h0} + ea : {CS, 4'h0} + IP;

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
    reg [15:0] WS; reg [15:0] ea;

    // Регистры общего назначения
    reg [15:0] AX; reg [15:0] BP;
    reg [15:0] CX; reg [15:0] SP; 
    reg [15:0] DX; reg [15:0] SI;
    reg [15:0] BX; reg [15:0] DI;
    
    // Флаги :: https://ru.wikipedia.org/wiki/Регистр_флагов
    reg [11:0] flags;

// ---------------------------------------------------------------------

// Байт для записи
reg  [7:0]  o8_data;

// Байт для чтения
wire [7:0]  i8_data = o_addr[0] ? i_data[15:8] : i_data[7:0];

// Управляющие регистры
// ---------------------------------------------------------------------

reg         rd;             // Указатель на WS:EA
reg [3:0]   m;              // Текущий статус
reg [2:0]   sub;            // Положение суб-процедуры
reg [3:0]   n;              // Следующий статус
reg [7:0]   opc;
reg [7:0]   modrm;

// Префиксы
reg repnz;      reg t_RepNZ;            // Префикс RepNZ
reg repz;       reg t_RepZ;             // Префикс RepZ
reg override;   reg t_Override;         // Сегментный префикс есть

// Операнд 1 и 2 (8 или 16 бит)
reg [15:0] op1;
reg [15:0] op2;

// ---------------------------------------------------------------------
initial begin

    m  = 1'b0;
    n  = 1'b0;
    sub = 1'b0;
    rd = 1'b0;
    o_wr = 1'b0;
    o8_data = 8'h00;
    modrm   = 8'h00;
    flags   = 12'h000;

    // Стартовый адрес всегда тут :FFFF0
    CS = 16'h0000; // @TODO ---- 16'hFFFF;
    IP = 16'h0000;
    
    DS = 16'h0000;
    ES = 16'h0000;
    SS = 16'hAAAA;
    WS = 16'h0000;
    DI = 16'hA000;
    
    AX = 16'hA0B0;
    BX = 16'h0002;
    SI = 16'h0011;
    DI = 16'h0202;
    BP = 16'h4003;
    
    opc = 1'b0;
    ea = 1'b0;
    
    m_align = 1'b0;
    t_RepNZ = 1'b0;
    t_RepZ  = 1'b0;
    t_Override = 1'b0;

end

// В разборе ModRM, данные могут быть выровнены - и тогда disp8 берется сразу
wire [15:0] disp8_aligned  = IP[0] ? 1'b0 : { {8{i_data[15]}}, i_data[15:8] };
wire [15:0] disp16_aligned = IP[0] ? 1'b0 : i_data[15:8];

// Если данные были выровнены, то переход сразу +2 
wire [15:0] IP_align = (IP + 1'b1) + !IP[0];

// +Disp8 Вычислени
wire [3:0] m8_stage = IP[0] ? `MODM_DISP : `MODM_GET;
wire       r8_stage = (m8_stage == `MODM_GET);

// Запись предыдущего состояния IP[0]
reg        m_align;

// Данные, которые нужно записать (8 или 16 бит)
reg [15:0] r_write;

// Immediate
reg  [7:0]  imm8;            // Временное значение Immediate
wire [15:0] imm16 = m_align ? i_data : {i_data[7:0], imm8}; // 16 битное значение

// Режим получения ModRM
// 8C MOV rm16, sreg
// 8E MOV sreg, rm16
// C4 LES r16, rm
wire  modm_bits = opc[0] | (opc == 8'h8C) | (opc == 8'h8E) | (opc == 8'hC4);

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ОСНОВНОЙ ПРОЦЕССОРНЫЙ ТАКТ
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

always @(posedge clock) if (locked) begin

    case (m)

        // Разбор инструкции или их выполнение в 1Т
        `INIT: begin 
        
            sub     <= 1'b0;
            m_align <= IP[0];
            o_wr    <= 1'b0;

            // Префиксы
            if      (i8_data == 8'h26) begin IP <= IP + 1'b1; t_Override <= 1'b1; WS <= ES; end
            else if (i8_data == 8'h2E) begin IP <= IP + 1'b1; t_Override <= 1'b1; WS <= CS; end
            else if (i8_data == 8'h36) begin IP <= IP + 1'b1; t_Override <= 1'b1; WS <= SS; end
            else if (i8_data == 8'h3E) begin IP <= IP + 1'b1; t_Override <= 1'b1; WS <= DS; end  
            else if (i8_data == 8'hF2) begin IP <= IP + 1'b1; t_RepNZ <= 1'b1; end
            else if (i8_data == 8'hF3) begin IP <= IP + 1'b1; t_RepZ  <= 1'b1; end
            // Исполнение опкода
            else begin
            
                // Запись в кеш "попадания" выровненных данных
                imm8    <= i_data[15:8];

                // Выбор рабочего сегмента
                WS <= t_Override ? WS : DS;

                // Перенос "теневых" к исполняемым
                // Сброс временных флагов исполнения
                override <= t_Override;  t_Override <= 1'b0;
                repnz    <= t_RepNZ;     t_RepNZ    <= 1'b0;
                repz     <= t_RepZ;      t_RepZ     <= 1'b0;

                // Для последующего использования                
                opc <= i8_data;   
                
                // Определить те поля, которые пойдут на ModRM
                casex (i8_data)
                    
                    8'b00_xxx0xx, //       Арифметические
                    8'b10_00xxxx, // 80-8F Разные арифметические
                    8'b11_0001xx, // C4-C7
                    8'b11_0100xx, // D0-D3 Сдвиговые
                    8'b11_011xxx, // D8-DF Сопроцессор
                    8'b11_11x11x: // F6-F7, FE-FF Групповые
                    begin IP <= IP + 1'b1; m <= `MODM; end
                    
                    // Nop Operation (NOP)
                    8'h90: begin IP <= IP + 1'b1; m <= `INIT; end
                    
                    // Быстрые флаговые операции
                    8'b1111_100x: begin IP <= IP + 1'b1; flags[0]  <= i8_data[0]; m <= `INIT;  end // CLC/STC
                    8'b1111_101x: begin IP <= IP + 1'b1; flags[9]  <= i8_data[0]; m <= `INIT;  end // CLI/STI
                    8'b1111_110x: begin IP <= IP + 1'b1; flags[10] <= i8_data[0]; m <= `INIT; end // CLD/STD
                    
                    // JMP rel16
                    // CALL rel16                    
                    8'hE8, 8'hE9: begin IP <= IP + 2'h2; m <= `INSTRUCTION; end

                    // JMP rel8
                    8'hEB: begin
                        
                        // Приплюсовать тут же
                        IP <= IP + 2'h2 + (IP[0] ? 1'b0 : {{8{i_data[15]}}, i_data[15:8]});

                        // Невыровненный rel8 дособрать
                        if (IP[0]) m <= `INSTRUCTION;

                    end
                    
                    // Неизвестная инструкция. Сообщить об этом!
                    default: m <= `INIT;
                
                endcase         
            
            end
        
        end

        // Декодирование ModRM
        `MODM: begin
        
            modrm   <= i8_data;
            m_align <= IP[0];

            // Первичное декодирование - вычисление effective address (ea)
            casex (i8_data)

                // Без displacement: сразу к извлечению из памяти данных
                8'b00_xxx_000: ea <= SI + BX;
                8'b00_xxx_001: ea <= DI + BX;
                8'b00_xxx_010: ea <= SI + BP;
                8'b00_xxx_011: ea <= DI + BP;
                8'b00_xxx_100: ea <= SI;
                8'b00_xxx_101: ea <= DI;
                8'b00_xxx_110: ea <= i_data[15:8];
                8'b00_xxx_111: ea <= BX;
                
                // Displacement 8
                8'b01_xxx_000: ea <= SI + BX + disp8_aligned;
                8'b01_xxx_001: ea <= DI + BX + disp8_aligned;
                8'b01_xxx_010: ea <= SI + BP + disp8_aligned;
                8'b01_xxx_011: ea <= DI + BP + disp8_aligned;
                8'b01_xxx_100: ea <= SI      + disp8_aligned;
                8'b01_xxx_101: ea <= DI      + disp8_aligned;
                8'b01_xxx_110: ea <= BP      + disp8_aligned;
                8'b01_xxx_111: ea <= BX      + disp8_aligned;

                // Displacement 16
                8'b10_xxx_000: ea <= SI + BX + disp16_aligned;
                8'b10_xxx_001: ea <= DI + BX + disp16_aligned;
                8'b10_xxx_010: ea <= SI + BP + disp16_aligned;
                8'b10_xxx_011: ea <= DI + BP + disp16_aligned;
                8'b10_xxx_100: ea <= SI      + disp16_aligned;
                8'b10_xxx_101: ea <= DI      + disp16_aligned;
                8'b10_xxx_110: ea <= BP      + disp16_aligned;
                8'b10_xxx_111: ea <= BX      + disp16_aligned;

            endcase
            
            // Перегрузка сегментного регистра SS:
            casex (i8_data)
            
                8'b00_xxx_01x,
                8'b01_xxx_01x, 8'b01_xxx_110,
                8'b10_xxx_01x, 8'b10_xxx_110:

                    WS <= override ? WS : SS;
            
            endcase
            
            // Следующее состояние процессора
            casex (i8_data)
            
                // Offset-16
                8'b00_xxx_110: begin m <= `MODM_DISP;   IP <= IP_align;  end
                
                // Без Displacement
                8'b00_xxx_xxx: begin m <= `MODM_GET;    IP <= IP + 1'b1; rd <= 1'b1; end
                
                // Disp8
                8'b01_xxx_xxx: begin m <= m8_stage;     IP <= IP_align;  rd <= r8_stage; end
                
                // Disp16
                8'b10_xxx_xxx: begin m <= `MODM_DISP;   IP <= IP_align;  end

                // Используются регистры в обеих частях: переход к исполнению инструкции
                8'b11_xxx_xxx: begin m <= `INSTRUCTION; IP <= IP + 1'b1; end
            
            endcase

            // Регистровая часть A
            // Если 1-й бит = 0, то используется [0:2] вместо memory-destination для операнда 1
            case (opc[1] ? i8_data[5:3] : i8_data[2:0])
            
                3'b000: begin op1 <= modm_bits ? AX[15:0] : AX[ 7:0]; end
                3'b001: begin op1 <= modm_bits ? CX[15:0] : AX[15:8]; end
                3'b010: begin op1 <= modm_bits ? DX[15:0] : CX[ 7:0]; end
                3'b011: begin op1 <= modm_bits ? BX[15:0] : CX[15:8]; end
                3'b100: begin op1 <= modm_bits ? SP[15:0] : DX[ 7:0]; end
                3'b101: begin op1 <= modm_bits ? BP[15:0] : DX[15:8]; end
                3'b110: begin op1 <= modm_bits ? SI[15:0] : BX[ 7:0]; end
                3'b111: begin op1 <= modm_bits ? DI[15:0] : BX[15:8]; end

            endcase    
            
            // Регистровая часть B
            // Аналогично, то [5:3] является обычным местоположением регистровой части
            case (opc[1] ? i8_data[2:0] : i8_data[5:3])
            
                3'b000: begin op2 <= modm_bits ? AX[15:0] : AX[ 7:0]; end
                3'b001: begin op2 <= modm_bits ? CX[15:0] : AX[15:8]; end
                3'b010: begin op2 <= modm_bits ? DX[15:0] : CX[ 7:0]; end
                3'b011: begin op2 <= modm_bits ? BX[15:0] : CX[15:8]; end
                3'b100: begin op2 <= modm_bits ? SP[15:0] : DX[ 7:0]; end
                3'b101: begin op2 <= modm_bits ? BP[15:0] : DX[15:8]; end
                3'b110: begin op2 <= modm_bits ? SI[15:0] : BX[ 7:0]; end
                3'b111: begin op2 <= modm_bits ? DI[15:0] : BX[15:8]; end

            endcase        
        
        end
        
        // Добавить +disp8 или +disp16
        `MODM_DISP: begin
        
            casex (modrm)
                
                8'b00_xxx_110: begin 
                
                    // m_align = 1, если байт ModRM был считан из IP[0] = 1 (нечетное)
                    // Это означает, что следуюшие 2 байта [OFFSET] находятся на выровненной позиции
                    IP <= m_align ? IP + 2'h2 : IP + 2'h1;
                    ea <= m_align ? i_data : {i_data[7:0], ea[7:0]};

                end
                
                // Disp8
                8'b01_xxx_xxx: begin
                
                    IP <= IP + 1'b1;
                    ea <= ea + { {8{i_data[7]}}, i_data[7:0] };
                
                end       
                
                // Disp16
                8'b10_xxx_xxx: begin

                    // Если данные выровнены - добавить +16 бит
                    // Иначе добавить старший байт EA
                    ea <= ea + (m_align ? i_data : {i_data[7:0], 8'h00});
                    IP <= IP_align;
                
                end
            
            endcase
        
            // К чтению операнда из памяти
            m  <= `MODM_GET;   
            rd <= 1'b1;        
        
        end
        
        // Извлечение данных из памяти (8/16 бит)
        `MODM_GET: begin
        
            // =======================
            // opc[1] = 0 --> rm, reg
            //        = 1 --> reg, rm
            // =======================
        
            // 16 bit
            if (modm_bits) begin
            
                // Не выровнено
                if (ea[0]) begin
                
                    m  <= `MODM_GET2;
                    ea <= ea + 1'b1;
                    if (opc[1]) op2 <= i_data[15:8]; else op1 <= i_data[15:8];
                
                end else begin
                
                    m <= `INSTRUCTION;
                    if (opc[1]) op2 <= i_data; else op1 <= i_data;
                
                end

            // 8 bit
            end else begin
            
                m <= `INSTRUCTION;
                if (opc[1]) op2 <= i8_data; else op1 <= i8_data;
                    
            end
        
        end
        
        // В случае невыровненных 16-битных данных
        `MODM_GET2: begin
        
            ea <= ea - 1'b1;
            m  <= `INSTRUCTION;
            if (opc[1]) op2[15:8] <= i_data[7:0]; else op1[15:8] <= i_data[7:0];
        
        end
        
        // Исполнение операции
        `INSTRUCTION: begin
        
            casex (opc)
            
                // CALL rel16
                8'hE8: begin 
                    
                    m <= `SUB_PUSH;
                    n <= `INIT;
                    IP <= imm16;
                    r_write <= IP + 1'b1;

                end
            
                // JMP rel16
                8'hE9: begin IP <= IP + 1'b1 + imm16; m <= `INIT; end

                // JMP rel8
                8'hEB: begin IP <= IP + {{8{i_data[7]}}, i_data[7:0]}; m <= `INIT; end
            
            endcase

        end
        
        // Сохранение данных в стеке
        `SUB_PUSH: begin
        
            case (sub)
            
                // Позиционирование
                3'h0: begin
                
                    WS   <= SS;
                    ea   <= SP - 2'h2;
                    SP   <= SP - 2'h2;

                    rd   <= 1'b1;
                    o_wr <= 1'b1;
                    sub  <= 1'b1;
                    
                    // Пишется либо 1 байт, либо 2-й в этом такте
                    o_data <= SP[0] ? {r_write[7:0], o_data[7:0]} : r_write[15:0];
                
                end
                
                // Запись оставшегося байта, либо выход
                3'h1: begin
                
                    if (SP[0]) begin
                    
                        o_data <= {o_data[15:8], r_write[7:0]};
                        sub    <= 3'h2;
                        
                    end 
                    
                    // A. Выход к предыдущему
                    else begin o_wr <= 1'b0; m <= n; rd <= 1'b0; sub <= 1'b0; end                
                
                end
                
                // B. Выход к предыдущему
                3'h2: begin o_wr <= 1'b0; m <= n; rd <= 1'b0; sub <= 1'b0; end                
                        
            endcase

        end

    endcase    
end

endmodule

