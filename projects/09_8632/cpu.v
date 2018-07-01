module cpu(

    input   wire        clk25,
    output  wire [19:0] address,    // 20 проводов
    input   wire [ 7:0] din,        // Входящие данные
    output  reg  [ 7:0] dout,       // Исходящие
    output  reg         we          // Write Enabled Signal

);

// Состояния процессора
// -------------------------------------------------

`define  INIT       1'b0
`define  FETCH      1'b1
`define  MODRM      2'h2
`define  EXEC       2'h3
`define  SAVERES    2'h4

// -------------------------------------------------

/*
 * 00 11 35 32 56
 *
 * [префиксы] <опкод> [байт modrm / sib] [операнды] [непосредственное значение]
 *
 * 66 05 33 44 12 44  ADD EAX, 0x44124433
 *    05 33 44        ADD  AX, 0x4433
 */

// 20 bit = 16 * cs + ip
assign address = {cs, 4'b0000} + ip;

// ------------------------------------
reg [31:0] eax = 32'h0000_0000; // 0
reg [31:0] ecx = 32'h0000_0000; // 1
reg [31:0] edx = 32'h0000_0000; // 2
reg [31:0] ebx = 32'h0000_0000; // 3
reg [31:0] esp = 32'h0000_0000; // 4
reg [31:0] ebp = 32'h0000_0000; // 5
reg [31:0] esi = 32'h0000_0000; // 6
reg [31:0] edi = 32'h0000_0000; // 7

// ------------------------------------
reg [15:0] es = 16'h0000;
reg [15:0] cs = 16'h0000;
reg [15:0] ss = 16'h0000;
reg [15:0] ds = 16'h0000;
// fs, gs -- не используются

reg [15:0] ip = 16'h0000;

/*
  0  CF    Флаг переноса
  1   1
  2  PF    Флаг чётности
  3   0
  4  AF    Вспомогательный флаг переноса
  5   0
  6  ZF    Флаг нуля
  7  SF    Флаг знака
  8  TF    Флаг трассировки
  9  IF    Флаг разрешения прерываний
  10 DF    Флаг направления
  11 OF    Флаг переполнения
*/
                    // OIDT SZ A  P C
reg [11:0] flags = 12'b0000_0000_0000;

// Текущее состояние
reg [ 7:0] m = 1'b0;

// 9 bit на опкод. Расширение опкода 0Fh
reg [ 8:0] opcode;
reg [ 7:0] modrm;

// Состояние выполнения считывания операндов
reg        mm;

reg        flag_override;
reg [15:0] segment;
reg        osize;
reg        asize;
reg        repnz;
reg        repz;

// Указатели на регистры. На следующем такте будут значения регистров
reg        Bit = 0;  // 0=8, 1=16/32
reg [2:0]  A   = 0;
reg [2:0]  B   = 0;

reg [31:0] RA; // RA = Registers[ A ]
reg [31:0] RB; // RB = Registers[ B ]

always @(posedge clk25) begin

    case (m)

        // Инициализация инструкции перед выполнением
        `INIT: begin

            m         <= 1'b1;
            opcode[8] <= 1'b0; // Опкод
            segment   <= ds;   // Сегмент по умолчанию
            flag_override <= 1'b0; // Перегружен ли сегмент в этой инструкции
            osize <= 1'b0; // 0 - 16bit, 1 - 32bit
            asize <= 1'b0; // 0 - 16bit, 1 - 32bit
            repnz <= 1'b0;
            repz  <= 1'b0;
            modrm <= 8'h00;
            mm    <= 1'b0;

        end

        // Чтение и разбор, декодирование префиксов и самого опкода
        `FETCH: begin

            case (din)

                /* Расширение опкода */
                8'h0F: begin opcode[8] <= 1'b1; end
                /* Префиксы для принудительного задания сегмента */
                8'h26: begin segment <= es; flag_override <= 1'b1; end
                8'h2E: begin segment <= cs; flag_override <= 1'b1; end
                8'h36: begin segment <= ss; flag_override <= 1'b1; end
                8'h3E: begin                flag_override <= 1'b1; end
                8'h66: begin osize <= osize ^ 1'b1; end /* Переключение 16/32 регистров */
                8'h67: begin asize <= asize ^ 1'b1; end /* Переключения 16/32 метода адресации */
                8'hF0, 8'h64, 8'h65: begin /* тут ничего не будет делаться */ end
                8'hF2: begin repnz <= 1'b1; end
                8'hF3: begin repz  <= 1'b1; end
                default: begin

                    opcode[7:0] <= din;

                    // Дополнительный набор
                    if (opcode[8])

                        casex (din)

                            8'b0000_01xx, // 04-07
                            8'b0000_10xx, // 08-0B
                            8'b0010_01x1, // 25,27
                            8'b0011_10x1, // 39,3B
                            8'b0011_0xxx, // 30-37
                            8'b0011_11xx, // 3C-3F
                            8'b1000_xxxx, // 80-8F
                            8'b1010_x00x, // A0-A1, A8-A9
                            8'b1010_x010, // A2,AA
                            8'b1010_011x, // A6,A7
                            8'b1100_1xxx, // C8-CF
                            8'h0C, 8'h0E, 8'hFF,
                            8'h77, 8'h7A, 8'h7B: m <= `EXEC;
                            default: m <= `MODRM;

                        endcase

                    else // Основной набор инструкции

                        casex (din)

                            8'b00xx_x0xx, // АЛУ
                            8'b1000_xxxx, // 80-8F
                            8'b1100_01xx, // C4-C7
                            8'b1101_00xx, // D0-D3
                            8'b1101_1xxx, // D8-DF Сопроцессор
                            8'b1111_x11x, // F6-F7, FE-FF
                            8'h62, 8'h63, 8'h69,
                            8'h6B, 8'hC0, 8'hC1: m <= `MODRM;
                            default: m <= `EXEC;

                        endcase

                end

            endcase

            ip <= ip + 1'b1;

        end

        // Исполнение ModRM
        `MODRM: begin

            modrm <= din;
            
            case (mm)
            
                1'b0: begin
                
                    // ... 
                
                end
            
            endcase

        end

        // Исполнение микрокода

    endcase

end

// Результат не зависит от тактовой частоты и выдается наиболее быстро
always @* begin

    // Таблица соответствий битностей
    // ------------------------------
    // osize   Bit   Битность
    //     0     0   8
    //     0     1   16
    //     1     0   8
    //     1     1   32
    // ------------------------------

    // Операнд 1: Извлечение значения регистра А из регистрового файла
    case (A)
    
        //                        32 bit      16 bit       8 bit
        3'h0: RA = Bit ? (osize ? eax[31:0] : eax[15:0]) : eax[7:0];  // eax | ax | al
        3'h1: RA = Bit ? (osize ? ecx[31:0] : ecx[15:0]) : ecx[7:0];  // ecx | cx | cl
        3'h2: RA = Bit ? (osize ? edx[31:0] : edx[15:0]) : edx[7:0];  // edx | dx | dl
        3'h3: RA = Bit ? (osize ? ebx[31:0] : ebx[15:0]) : ebx[7:0];  // ebx | bx | bl
        3'h4: RA = Bit ? (osize ? esp[31:0] : esp[15:0]) : eax[15:8]; // esp | sp | ah
        3'h5: RA = Bit ? (osize ? ebp[31:0] : ebp[15:0]) : ecx[15:8]; // ebp | bp | ch
        3'h6: RA = Bit ? (osize ? esi[31:0] : esi[15:0]) : edx[15:8]; // esi | si | dh
        3'h7: RA = Bit ? (osize ? edi[31:0] : edi[15:0]) : ebx[15:8]; // edi | di | bh
    
    endcase
    
    // Операнд 1: Извлечение значения регистра B из регистрового файла
    case (B) 
    
        //                        32 bit      16 bit       8 bit
        3'h0: RB = Bit ? (osize ? eax[31:0] : eax[15:0]) : eax[7:0];  // eax | ax | al
        3'h1: RB = Bit ? (osize ? ecx[31:0] : ecx[15:0]) : ecx[7:0];  // ecx | cx | cl
        3'h2: RB = Bit ? (osize ? edx[31:0] : edx[15:0]) : edx[7:0];  // edx | dx | dl
        3'h3: RB = Bit ? (osize ? ebx[31:0] : ebx[15:0]) : ebx[7:0];  // ebx | bx | bl
        3'h4: RB = Bit ? (osize ? esp[31:0] : esp[15:0]) : eax[15:8]; // esp | sp | ah
        3'h5: RB = Bit ? (osize ? ebp[31:0] : ebp[15:0]) : ecx[15:8]; // ebp | bp | ch
        3'h6: RB = Bit ? (osize ? esi[31:0] : esi[15:0]) : edx[15:8]; // esi | si | dh
        3'h7: RB = Bit ? (osize ? edi[31:0] : edi[15:0]) : ebx[15:8]; // edi | di | bh
    
    endcase

end

// Запись в регистры на негативном фронте
always @(negedge clk25) begin // 20 нс 

    // ... 

end

endmodule
