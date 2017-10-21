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

`define INIT         4'h0
`define MODM         4'h1
`define MODM_DISP    4'h2
`define MODM_GET     4'h3
`define INSTRUCTION  4'h4


// Текущий указатель на память
assign o_addr = rd ? {XS, 4'h0} + ea : {CS, 4'h0} + IP;

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
    reg [15:0] XS; reg [15:0] ea;

    // Регистры общего назначения
    reg [15:0] AX; reg [15:0] BP;
    reg [15:0] CX; reg [15:0] SP; 
    reg [15:0] DX; reg [15:0] SI;
    reg [15:0] BX; reg [15:0] DI;

// ---------------------------------------------------------------------

// Байт для записи
reg  [7:0]  o8_data;

// Байт для чтения
wire [7:0]  i8_data = o_addr[0] ? i_data[15:8] : i_data[7:0];

// Управляющие регистры
// ---------------------------------------------------------------------

reg         rd;                         // Указатель на XS:EA
reg [3:0]   m;
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
    rd = 1'b0;
    o8_data = 8'h00;
    modrm   = 8'h00;

    // Стартовый адрес всегда тут :FFFF0
    CS = 16'h0000; // @TODO ---- 16'hFFFF;
    IP = 16'h0000;
    
    DS = 16'h1000;
    ES = 16'h0000;
    SS = 16'hAAAA;
    
    BX = 16'h51FE;
    SI = 16'h0011;
    DI = 16'h0202;
    BP = 16'h4003;
    
    opc = 1'b0;
    ea = 1'b0;
    
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

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ОСНОВНОЙ ПРОЦЕССОРНЫЙ ТАКТ
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

always @(posedge clock) if (locked) begin

    case (m)

        // Разбор инструкции или их выполнение в 1Т
        `INIT: begin 
        
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

                // Выбор рабочего сегмента
                XS <= t_Override ? XS : DS;

                // Перенос "теневых" к исполняемым
                // Сброс временных флагов исполнения
                override <= t_Override;  t_Override <= 1'b0;
                repnz    <= t_RepNZ;     t_RepNZ    <= 1'b0;
                repz     <= t_RepZ;      t_RepZ     <= 1'b0;

                // Для последующего использования                
                opc <= i8_data;   
                
                // Определить те поля, которые пойдут на ModRM
                casex (i8_data)

                    // Арифметические инструкции с ModRM
                    8'b00_xxx_0xx: m <= `MODM;
                    
                    // Nop Operation (NOP)
                    8'h90: m <= `INIT;
                    
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
            
            // Segment Override
            casex (i8_data)
            
                8'b00_xxx_01x,
                8'b01_xxx_01x, 8'b01_xxx_110,
                8'b10_xxx_01x, 8'b10_xxx_110:

                    XS <= override ? XS : SS;
            
            endcase
            
            // Следующее состояние
            casex (i8_data)
            
                // Offset-16
                8'b00_xxx_110: begin m <= `MODM_DISP;   IP <= IP_align;  end
                
                // Без Displacement
                8'b00_xxx_xxx: begin m <= `MODM_GET;    IP <= IP + 1'b1; rd <= 1'b1; end
                
                // Disp8
                8'b01_xxx_xxx: begin m <= m8_stage;     IP <= IP_align;  rd <= r8_stage; end
                
                // Disp16
                // ...

                // Используются регистры в обеих частях: переход к исполнению инструкции
                8'b11_xxx_xxx: begin m <= `INSTRUCTION; IP <= IP + 1'b1; end
            
            endcase
            
            // Регистровая часть A
            // Если 1-й бит = 0, то используется [0:2] вместо memory-destination для операнда 1
            case (opc[1] ? i8_data[5:3] : i8_data[2:0])
            
                3'b000: begin op1 <= opc[0] ? AX[15:0] : AX[ 7:0]; end
                3'b001: begin op1 <= opc[0] ? CX[15:0] : AX[15:8]; end
                3'b010: begin op1 <= opc[0] ? DX[15:0] : CX[ 7:0]; end
                3'b011: begin op1 <= opc[0] ? BX[15:0] : CX[15:8]; end
                3'b100: begin op1 <= opc[0] ? SP[15:0] : DX[ 7:0]; end
                3'b101: begin op1 <= opc[0] ? BP[15:0] : DX[15:8]; end
                3'b110: begin op1 <= opc[0] ? SI[15:0] : BX[ 7:0]; end
                3'b111: begin op1 <= opc[0] ? DI[15:0] : BX[15:8]; end

            endcase    
            
            // Регистровая часть B
            // Аналогично, то [5:3] является обычным местоположением регистровой части
            case (opc[1] ? i8_data[2:0] : i8_data[5:3])
            
                3'b000: begin op2 <= opc[0] ? AX[15:0] : AX[ 7:0]; end
                3'b001: begin op2 <= opc[0] ? CX[15:0] : AX[15:8]; end
                3'b010: begin op2 <= opc[0] ? DX[15:0] : CX[ 7:0]; end
                3'b011: begin op2 <= opc[0] ? BX[15:0] : CX[15:8]; end
                3'b100: begin op2 <= opc[0] ? SP[15:0] : DX[ 7:0]; end
                3'b101: begin op2 <= opc[0] ? BP[15:0] : DX[15:8]; end
                3'b110: begin op2 <= opc[0] ? SI[15:0] : BX[ 7:0]; end
                3'b111: begin op2 <= opc[0] ? DI[15:0] : BX[15:8]; end

            endcase        
        
        end
        
        // Невыровненные данные - добавить disp8/disp16
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
            
            endcase
        
            // К чтению из памяти
            m  <= `MODM_GET;   
            rd <= 1'b1;        
        
        end
        
        // Извлечение данных из памяти
        `MODM_GET: begin
        
            // op1 <= ...
        
        end
        
        // Исполнение операции
        `INSTRUCTION: begin
        
        end

    endcase    
end

endmodule

