`ifndef __mod_regs_write
`define __mod_regs_write

// Нумерация регистров в регистровом файле
`define REG_C   3'b000
`define REG_B   3'b001
`define REG_E   3'b010
`define REG_D   3'b011
`define REG_L   3'b100
`define REG_H   3'b101
`define REG_RES 3'b110
`define REG_A   3'b111

// Запись в регистры на обратном фронте CLOCK \_ из АЛУ-результата
always @(negedge clock) begin

    // Писать результат в AF
    if (w_r16af) begin
    
        if (bank_af) begin f_ <= w_r16[7:0]; a_ <= w_r16[15:8]; end
                else begin f  <= w_r16[7:0]; a  <= w_r16[15:8]; end

    end

    // Сохранение в 16-разрядные регистры
    else if (w_reg16) begin
    
        case (w_num16)

            /* BC */ 2'b00: if (bank_r) begin c_ <= w_r16[7:0]; b_ <= w_r16[15:8]; end
                            else        begin c  <= w_r16[7:0]; b  <= w_r16[15:8]; end
        
            /* DE */ 2'b01: if (bank_r) begin e_ <= w_r16[7:0]; d_ <= w_r16[15:8]; end
                            else        begin e  <= w_r16[7:0]; d  <= w_r16[15:8]; end

            /* HL, IX, IY */ 

                     // Было выбрано сохранение в IX/IY
                     2'b10: if (postpref) begin 
            
                                if (prefix) begin yl <= w_r16[7:0]; yh <= w_r16[15:8]; end
                                else        begin xl <= w_r16[7:0]; xh <= w_r16[15:8]; end
                                
                            end else begin
            
                                if (bank_r) begin l_ <= w_r16[7:0]; h_ <= w_r16[15:8]; end
                                else        begin l  <= w_r16[7:0]; h  <= w_r16[15:8]; end
                            
                            end

            /* SP */ 2'b11: begin sp <= w_r16; end

        endcase
    
    end

    // Разрешено сохранять 8-битный регистр
    else if (w_reg) begin
    
        // Что сохранять
        case (w_num)

            // Обратный порядок 0=C, 1=B, 2=E, 3=D, 4=L, 5=H
            `REG_C: if (bank_r) c_ <= w_r; else c <= w_r;
            `REG_B: if (bank_r) b_ <= w_r; else b <= w_r;
            `REG_E: if (bank_r) e_ <= w_r; else e <= w_r;
            `REG_D: if (bank_r) d_ <= w_r; else d <= w_r;

            `REG_L: if (postpref) begin if (prefix) yl <= w_r; else xl <= w_r; end 
                                   else if (bank_r) l_ <= w_r; else l <= w_r;
                                   
            `REG_H: if (postpref) begin if (prefix) yh <= w_r; else xh <= w_r; end 
                                   else if (bank_r) h_ <= w_r; else h <= w_r;

            // При сохранении может использоваться обратный порядок младшего бита 
            default: if (bank_af) a_ <= w_r; else a <= w_r;

        endcase
        
    end

    // Запись флагов при разрешенном w_flag
    if (w_flag)  if ( bank_af ) f_[7:0] <= flags; else f [7:0] <= flags;
   
end

`endif