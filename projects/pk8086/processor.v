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
assign o_addr = xa ? {XS, 4'h0} + ea : {CS, 4'h0} + IP;

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

reg         xa;                         // Указатель на XS:EA
reg [3:0]   m;
reg [7:0]   opc;

// Префиксы
reg repnz;      reg t_RepNZ;            // Префикс RepNZ
reg repz;       reg t_RepZ;             // Префикс RepZ
reg override;   reg t_Override;         // Сегментный префикс есть

// ---------------------------------------------------------------------
initial begin

    m  = 1'b0;
    xa = 1'b0;
    o8_data = 8'h00;

    // Стартовый адрес всегда тут :FFFF0
    CS = 16'h0000; // @TODO ---- 16'hFFFF;
    IP = 16'h0000;
    
    DS = 16'h1111;
    ES = 16'h2222;
    SS = 16'hAAAA;
    
    BX = 16'h0002;
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
wire [15:0] disp8_aligned = ~IP[0] ? { {8{i_data[15]}}, i_data[15:8] } : 1'b0;

// Если данные были выровнены, то переход сразу +2 
wire [15:0] ip_align = (IP + 1'b1) + !IP[0];

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ОСНОВНОЙ ПРОЦЕССОРНЫЙ ТАКТ
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

always @(posedge clock) if (locked) begin

    case (m)
    
        // Разбор инструкции или их выполнение в 1Т
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
                    8'b00_xxx_0xx: m <= 4'h1;
                    
                    // Nop Operation (NOP)
                    8'h90: m <= 1'b0;
                    
                    // Неизвестная инструкция. Сообщить об этом!
                    default: m <= 1'b0;
                
                endcase         
            
            end
        
        end

        // Декодирование ModRM
        4'h1: begin

            // Первичное декодирование - вычисление effective address (ea)
            casex (i8_data)
            
                // Без displacement
                8'b00_xxx_000: begin IP <= IP + 1'b1; ea <= SI + BX; end
                8'b00_xxx_001: begin IP <= IP + 1'b1; ea <= DI + BX; end
                8'b00_xxx_010: begin IP <= IP + 1'b1; ea <= SI + BX; XS <= override ? XS : SS; end
                8'b00_xxx_011: begin IP <= IP + 1'b1; ea <= DI + BX; XS <= override ? XS : SS; end
                8'b00_xxx_100: begin IP <= IP + 1'b1; ea <= SI; end
                8'b00_xxx_111: begin IP <= IP + 1'b1; ea <= DI; end
                8'b00_xxx_110: begin IP <= ip_align;  ea <= disp8_aligned[7:0]; end
                8'b00_xxx_111: begin IP <= IP + 1'b1; ea <= BX;  end

                // +disp8/+disp16 (или регистры)
                8'bxx_xxx_000: begin IP <= ip_align; ea <= disp8_aligned + SI + BX; end
                8'bxx_xxx_001: begin IP <= ip_align; ea <= disp8_aligned + DI + BX; end
                8'bxx_xxx_010: begin IP <= ip_align; ea <= disp8_aligned + SI + BP; XS <= override ? XS : SS; end
                8'bxx_xxx_011: begin IP <= ip_align; ea <= disp8_aligned + DI + BP; XS <= override ? XS : SS; end
                8'bxx_xxx_100: begin IP <= ip_align; ea <= disp8_aligned + SI;      end
                8'bxx_xxx_101: begin IP <= ip_align; ea <= disp8_aligned + DI;      end            
                8'bxx_xxx_110: begin IP <= ip_align; ea <= disp8_aligned + BP;      XS <= override ? XS : SS; end
                8'bxx_xxx_111: begin IP <= ip_align; ea <= disp8_aligned + BX;      end

            endcase
        
        end
        
        // Невыровненные данные - добавить disp8/disp16
        4'h2: begin
        
        end

    endcase    
end

endmodule

