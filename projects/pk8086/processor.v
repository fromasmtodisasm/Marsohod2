// Набор инструкции x8086
module processor(

    input   wire            clock,      // 10 mhz
    input   wire            locked,     // Если =0, PLL не сконфигурирован
    input   wire            m_ready,    // Готовность данных из памяти (=1 данные готовы)
    output  wire    [19:0]  o_addr,     // Указатель на память
    input   wire    [15:0]  i_data,     // Данные из памяти
    output  wire    [15:0]  o_data,     // Данные за запись
    output  reg             o_wr        // Строб записи в память

);

`define DECODE              3'h0        // Декодирование
`define FETCH_MODRM         3'h1
`define READ_UNALIGNED      3'h2
`define READ_ALIGNED_DISP   3'h3
`define READ_DATA           3'h4
`define READ_DATA_16        3'h5
`define EXECUTE             3'h6

// Выбор адреса. Адрес может указываться либо через READ=1, когда
// в cs:addr находится вычисленный эффективный адрес, либо READ=0, 
// когда указатель находится на CS:IP

assign o_addr = read ? {cs[15:0], 4'h0} + addr : 
                       {CS[15:0], 4'h0} + IP;

assign o_data = 1'b0;

// ---------------------------------------------------------------------
// Регистры процессора
// ---------------------------------------------------------------------

// Регистры Общего Назначения
// Регистры в регистровом файле идут именно в этом порядке

reg     [15:0]    AX = 16'h0000; // AH : AL
reg     [15:0]    CX = 16'h0000; // CH : CL
reg     [15:0]    DX = 16'h0000; // DH : DL
reg     [15:0]    BX = 16'h0000; // BH : BL
reg     [15:0]    SP = 16'h0000;
reg     [15:0]    BP = 16'h0000;
reg     [15:0]    SI = 16'h0000;
reg     [15:0]    DI = 16'h0000;

// Сегментные
reg     [15:0]    ES = 16'h0000;
reg     [15:0]    CS = 16'h0000;
reg     [15:0]    SS = 16'h0000;
reg     [15:0]    DS = 16'h0000;

// Специальные
reg     [11:0] FLAGS = 12'h000;
reg     [15:0]    IP = 16'h0000;

// ---------------------------------------------------------------------
// Состояния
// ---------------------------------------------------------------------

reg     [3:0]       state = `DECODE;      // Состояние процессора
reg     [15:0]      cs;                   // CS:ADDR Для чтений из памяти
reg     [15:0]      addr;
reg                 read = 1'b0;

// ---------------------------------------------------------------------
// Декодер
// ---------------------------------------------------------------------

// Поскольку из памяти читаются данные по словам, то текущий байт
// находится либо в нижнем байте слова (2 байта), либо в верхнем, это
// зависит от младшего бита o_addr

wire    [7:0]   current_byte = o_addr[0] ? i_data[15:8] : i_data[7:0];
wire    [7:0]   next_byte    = o_addr[0] ? i_data[7:0] : i_data[15:8];

wire            state_decode = state == `DECODE;
reg     [15:0]  opcode_cache = 8'h00;
wire    [7:0]   opcode       = state_decode ? current_byte : opcode_cache;

// Индикатор наличия ModRM-байта
reg             opcode_modrm;       

// Блок для определения, есть ли у данного опкода [current_byte] байт
// ModRM. Если есть, будет запущен процесс его считывания.

always @* begin

    /*   Опкоды, у которых есть ModRM    
         0 1 2 3  4 5 6 7  8 9 A B  C D E F
     00  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,   00xx_x0xx
     10  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,
     20  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,
     30  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,
     40  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     50  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     60  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     70  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     80  1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,   1000_xxxx
     90  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     A0  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     B0  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     C0  1,1,-,-, 1,1,1,1, -,-,-,-, -,-,-,-,   1100_01xx 1100_000x 
     D0  1,1,1,1, -,-,-,-, 1,1,1,1, 1,1,1,1,   1101_00xx 1101_1xxx
     E0  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     F0  -,-,-,-, -,-,1,1, -,-,-,-, -,-,1,1,   1111_x11x
     */
     
    // Определить, имеет ли ModRM-байт данный опкод
    casex (opcode) 
    
        8'b00_xxx0xx, // 
        8'b10_00xxxx, // 80-8F
        8'b11_00000x, // C0-C1
        8'b11_0001xx, // C4-C7
        8'b11_0100xx, // D0-D3 Сдвиговые
        8'b11_011xxx, // D8-DF Сопроцессор 
        8'b11_11x11x: // F6-F7, FE-FF Групповые         
            opcode_modrm = 1'b1;
        default:        
            opcode_modrm = 1'b0;
    
    endcase
       
end

// Основные индексные регистры
// ---------------------------------------------------------------------

reg             seg_overlap;        // Сигнализирует о том, что есть префикс сегмента
reg             seg_overlap_cache;  // .. на сеанс
reg     [1:0]   seg_number = 2'h3;  // Указатель номера 0..3 сегмента
reg     [1:0]   seg_number_cache;   // 

reg     [1:0]   disp;               // Количество байт на Displacement
reg     [1:0]   disp_cache;
reg     [15:0]  segp;               // Значение сегмента-префикса
reg     [15:0]  sege;               // Вычисленный сегмент с учетом DEFAULT ds:ss: либо PREFIX
reg     [15:0]  addrx;              // Вычисленный эффективный адрес ДО +displacement
reg     [15:0]  op1t;               // Значение регистра из ModRM[2:0] 
reg     [15:0]  op1;                // - конечное
reg     [15:0]  op2t;               // Значение регистра из ModRM[5:3]
reg     [15:0]  op2;                // - конечное

wire    [15:0]  si_bx = SI + BX;
wire    [15:0]  di_bx = DI + BX;
wire    [15:0]  si_bp = SI + BP;
wire    [15:0]  di_bp = DI + BP;

// В зависимости от того, какой исполняется сейчас этап
wire            seg_override = (state_decode ? seg_overlap : seg_overlap_cache);
wire            seg_id       = (state_decode ? seg_number  : seg_number_cache);

// Вычисление эффективного адреса ModRM
always @* begin
    
    // Перегруженный, либо дефолтный сегмент 
    case (seg_id) 

        3'h0: segp = ES;
        3'h1: segp = CS;
        3'h2: segp = SS;
        3'h3: segp = DS;

    endcase
    
    // Рассчитанный сегмент по умолчанию
    casex (next_byte) 
        
        8'b00_xxx_11x: sege = seg_override ? segp : DS; // DS: по умолчанию
        8'bxx_xxx_x0x: sege = seg_override ? segp : DS;            
        8'bxx_xxx_110: sege = seg_override ? segp : SS; // SS: по умолчанию
        8'bxx_xxx_01x: sege = seg_override ? segp : SS;
        default:       sege = DS;
    
    endcase

    // Эффективный адрес
    casex (next_byte) 

        8'bxx_xxx_000: addrx = si_bx;
        8'bxx_xxx_001: addrx = di_bx;
        8'bxx_xxx_010: addrx = si_bp;
        8'bxx_xxx_011: addrx = di_bp;
        8'bxx_xxx_100: addrx = SI;
        8'bxx_xxx_101: addrx = DI;
        8'b00_xxx_110: addrx = 16'h0000;
        8'bxx_xxx_110: addrx = BP;
        8'bxx_xxx_111: addrx = BX;
    
    endcase
    
    // Количество байт 0/1/2 на displacement
    casex (next_byte)     
        
        8'b01_xxx_xxx: disp = 2'b01; // disp-8        
        8'b00_xxx_110: disp = 2'b10; // disp-16
        8'b10_xxx_xxx: disp = 2'b10; 
        default:       disp = 2'b00; // disp-0

    endcase

    // Операнд 1: reg/m8
    case (opcode[1] ? next_byte[5:3] : next_byte[2:0])
    
        3'b000: op1t = opcode[0] ? AX : AX[7:0];
        3'b001: op1t = opcode[0] ? CX : CX[7:0];
        3'b010: op1t = opcode[0] ? DX : DX[7:0];
        3'b011: op1t = opcode[0] ? BX : BX[7:0];
        3'b100: op1t = opcode[0] ? SP : AX[15:8];
        3'b101: op1t = opcode[0] ? BP : CX[15:8];
        3'b110: op1t = opcode[0] ? SI : DX[15:8];
        3'b111: op1t = opcode[0] ? DI : BX[15:8];
    
    endcase
    
    // Операнд 2: reg
    case (opcode[1] ? next_byte[2:0] : next_byte[5:3])
    
        3'b000: op2t = opcode[0] ? AX : AX[7:0];
        3'b001: op2t = opcode[0] ? CX : CX[7:0];
        3'b010: op2t = opcode[0] ? DX : DX[7:0];
        3'b011: op2t = opcode[0] ? BX : BX[7:0];
        3'b100: op2t = opcode[0] ? SP : AX[15:8];
        3'b101: op2t = opcode[0] ? BP : CX[15:8];
        3'b110: op2t = opcode[0] ? SI : DX[15:8];
        3'b111: op2t = opcode[0] ? DI : BX[15:8];
    
    endcase

end

// ---------------------------------------------------------------------
// Модули исполнения инструкции
// ---------------------------------------------------------------------

always @(posedge clock) begin

    case (state)    
    
    // =================================================================
    // Полный декодер инструкции: ModRM, Imm. После декодинга кеш сдвигается.
    // =================================================================
    
    `DECODE: begin
    
        casex (opcode)

            8'b001x_x110: /* Префикс сегментов ES: CS: SS: DS: */ begin 

                seg_overlap <= 1'b1; 
                seg_number  <= current_byte[4:3];
                IP          <= IP + 1'b1;

            end
            
            // 8'b0110_01xx, // 32-bit 64 FS: 65 GS: 66 Op32 67 Addr32            
            // 8'b1001_1011, // WAIT
            // 8'b1111_0000, // LOCK
            // 8'b1001_001x, // REP/REPZ
            // 8'b0000_1111: // Opcode Extension

            default: /* Чтение опкода */ begin
            
                if /* Опкод имеет ModRM */ (opcode_modrm) begin
                
                    if /* Байт ModRM ещё не получен */ (IP[0]) begin

                        state <= `FETCH_MODRM;
                    
                    end else begin
                    
                        // Переписать данные с декодера ModRM
                        op1  <= op2t;
                        op2  <= op2t;
                        cs   <= sege;
                        addr <= addrx;
                        disp_cache <= disp;

                        if /* Сразу выполнить код */ (next_byte[7:6] == 2'b11) begin

                            state <= `EXECUTE;
                        
                        end else /* Читать операнд из памяти (+d8/16) */ case (disp) 

                            // Прочитать Disp8/16
                            2'b01, 2'b10: state <= `READ_ALIGNED_DISP; 
                            
                            // Иначе к чтению операнда
                            default: begin  

                                read    <= 1'b1; 
                                state   <= `READ_DATA; 

                            end

                        endcase

                    end
                    
                    IP <= IP + 2'h2; // Опкод(1) + ModRm(1)

                // Без ModRM байта, перейти к исполнению кода
                end else begin
                
                    state   <= `EXECUTE;
                    IP      <= IP + 1'b1;

                end

                // Сохранить опкод
                opcode_cache <= current_byte;

                // Сохранить информацию об overlap / seg_id
                seg_overlap_cache   <= seg_overlap;
                seg_number_cache    <= seg_number;

                // Сброс значений для следующего сеанса
                seg_overlap         <= 1'b0;
                seg_number          <= 2'h3;

            end

        endcase
        
    end   
    
    // =================================================================
    // ЧТЕНИЕ DISPLACEMENT 8 ИЛИ 16.     
    // Поскольку тут ВЫРОВНЕННЫЕ данные, то читается за 1 раз
    // =================================================================
    
    `READ_ALIGNED_DISP: begin
    
        if /* 8-bit */ (disp_cache[0]) begin

            addr <= addr + {{8{current_byte[7]}}, current_byte};
            IP   <= IP + 1'b1;
            
        end
        else /* 16-bit */  begin
        
            addr <= addr + {next_byte, current_byte};
            IP   <= IP + 2'h2;
            
        end
        
        read  <= 1'b1;
        state <= `READ_DATA;
    
    end
    
    // =================================================================
    // Чтение НЕВЫРОВНЕННОГО ModRM +d8 если он задан
    // =================================================================
    
    `FETCH_MODRM: begin

        // Переписать данные с декодера ModRM
        op1  <= op2t;
        op2  <= op2t;
        cs   <= sege;

        if /* Сразу выполнить код */ (next_byte[7:6] == 2'b11) begin
        
            state <= `EXECUTE;
        
        end else /* Читать операнд из памяти (+d8/16) */ begin

            case (disp)
                     
                // Прочитать Disp8 и перейти к чтению опкода
                2'b01: begin 
                
                    addr    <= addrx + {{8{current_byte[7]}}, current_byte};
                    state   <= `READ_DATA; 
                    read    <= 1'b1; 
                    IP      <= IP + 1'b1;
                    
                end
                
                // Писать младшую часть Disp16
                2'b10: begin 
                
                    addr    <= addrx + current_byte; 
                    state   <= `READ_UNALIGNED; 
                    IP      <= IP + 2'h2;

                end
                
                // Начать чтение сразу же, если нет displacement 8/16
                default: begin 
                
                    read    <= 1'b1; 
                    addr    <= addrx;
                    state   <= `READ_DATA; 
                    
                end
                
            endcase

        end    
    end
    
    // =================================================================
    // Чтение НЕВЫРОВНЕННОГО +d16
    // =================================================================
    
    `READ_UNALIGNED: begin
    
        state       <= `READ_DATA; 
        read        <= 1'b1; 
        addr[15:8]  <= addr[15:8] + next_byte;
    
    end
    
    // =================================================================
    // Чтение 8 или 16 битных данных (в зависимости от выравнивания)
    // =================================================================
    
    `READ_DATA: begin
    
        if /* WORD: Читать слово */ (opcode[0]) begin
        
            if /* Не выровнено */ (addr[0]) begin

                if (opcode[1]) op2 <= i_data[15:8];
                          else op1 <= i_data[15:8];
                          
                addr  <= addr + 1'b1;
                state <= `READ_DATA_16;
            
            end else /* Выровнено */ begin

                if (opcode[1]) op2 <= i_data[15:0];
                          else op1 <= i_data[15:0];
                          
                state <= `EXECUTE;
                          
            end

        end else /* BYTE: Читать байт */ begin
        
            if (opcode[1]) op2 <= current_byte;
                      else op1 <= current_byte;
                      
            state <= `EXECUTE;

        end
    
    end
    
    // Прочитать старший байт слова данных
    `READ_DATA_16: begin
    
        if (opcode[1]) op2[15:8] <= i_data[7:0];
                  else op1[15:8] <= i_data[7:0];

        addr  <= addr - 1'b1;
        state <= `EXECUTE;

    end

    endcase
end

endmodule
