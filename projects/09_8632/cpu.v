module cpu(

    input   wire        clk25,
    output  wire [19:0] address,    // 20 проводов
    input   wire [ 7:0] din,        // Входящие данные
    output  reg  [ 7:0] dout,       // Исходящие
    output  reg         we          // Write Enabled Signal

);

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

// M9K будут регистры общего назначения : AX, CX, DX, BX, SP, BP, SI, DI

reg [15:0] es = 16'h0000;
reg [15:0] cs = 16'h0000;
reg [15:0] ss = 16'h0000;
reg [15:0] ds = 16'h0000;

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

reg        flag_override;
reg [15:0] segment;
reg        osize;
reg        asize;
reg        repnz;
reg        repz;

always @(posedge clk25) begin

    case (m) 
    
        // Инициализация инструкции перед выполнением
        1'b0: begin

            m         <= 1'b1; 
            opcode[8] <= 1'b0; // Опкод
            segment   <= ds;   // Сегмент по умолчанию
            flag_override <= 1'b0; // Перегружен ли сегмент в этой инструкции
            osize <= 1'b0; // 0 - 16bit, 1 - 32bit
            asize <= 1'b0; // 0 - 16bit, 1 - 32bit
            repnz <= 1'b0;
            repz  <= 1'b0;

        end

        // Чтение и разбор, декодирование префиксов и самого опкода
        1'b1: begin
        
            case (din)
            
                8'h0F: begin opcode[8] <= 1'b1; end
                8'h26: begin segment <= es; flag_override <= 1'b1; end
                8'h2E: begin segment <= cs; flag_override <= 1'b1; end
                8'h36: begin segment <= ss; flag_override <= 1'b1; end
                8'h3E: begin                flag_override <= 1'b1; end
                8'h66: begin osize <= osize ^ 1'b1; end
                8'h67: begin asize <= asize ^ 1'b1; end
                8'hF0, 8'h64, 8'h65: begin /* тут ничего не будет делаться */ end
                8'hF2: begin repnz <= 1'b1; end
                8'hF3: begin repz  <= 1'b1; end
                default: begin 
                
                    opcode[7:0] <= din;
                    
                    casex (din)
                    
                        9'b0_00_xxx_0xx, 
                        9'b0_10_00_xxxx,
                        9'b0_1100_01xx, // C4-C7
                        9'b0_1101_00xx, // D0-D3
                        9'b0_1101_1xxx, // D8-DF                        
                        9'b0_1111_x11x, // F6-F7, FE-FF
                        9'h62, 9'h63, 9'h69, 
                        9'h6B, 9'hC0, 9'hC1: m <= 2'h2;

                        default: m <= 2'h3;
                    
                    endcase
                    
                end
            
            endcase
            
            ip <= ip + 1'b1;
        
        end
        
        // Исполнение ModRM
        2'h2: begin

            // ... Всякая магия ...
        
        end
        
        // Исполнение микрокода
    
    endcase

end

endmodule
