module port_controller(

    input  wire         clock50,
    input  wire  [15:0] port_addr,  
    output reg   [15:0] port_in,
    input  wire  [15:0] port_out,
    input  wire         port_bit,   /* Битность */
    input  wire         port_clk,   /* Запись в порт */
    input  wire         port_read,  /* Чтение из порта */
    
    /* Данные с PS/2 контроллера */
    input  wire [7:0]   ps2_data,
    input  wire         ps2_data_clk
    
);
    
// Роутер
// ---------------------------------------------------------------------

always @* begin

    case (port_addr)
    
        16'h0060, 16'h0064: port_in = {8'h00, keyb_data};
        default: port_in = 1'b0;
        
    endcase
    
end

// ---------------------------------------------------------------------

/* Обработчик клавиатуры */
reg [7:0] keyb_char   = 8'h81;  /* Последний принятый байт */
reg       keyb_ready1 = 1'b0;   /* Асинхронный статус приема */
reg       keyb_ready2 = 1'b0;   /* Acknowlegde */
wire      keyb_ready = keyb_ready1 ^ keyb_ready2; /* Бит 0 порта 64h */
reg [1:0] keyb_jread = 2'b00;   /* Признак только что принятого байта из порта 60h */
reg [7:0] keyb_data = 8'h0;     /* Выходные данные для порта */

/* Принятие данных из PS/2 */
always @(posedge clock50) begin

    /* Регистрация фронта спада и подъема */
    keyb_jread <= {keyb_jread[0], port_read};

    // Новые данные присутствуют. Асинхронный прием.
    if (ps2_data_clk) begin
    
        keyb_char   <= ps2_data;
        keyb_ready1 <= keyb_ready1 ^ keyb_ready ^ 1'b1; /* Если keyb_ready=0, то перебросить в 1, иначе оставить как 1 */
        
    end
        
    // Только что было чтение из порта (на обратном фронте)
    if ({keyb_jread[0], port_read} == 2'b10) begin
    
        case (port_addr)
        
            /* Порт данных */
            16'h0060: begin
            
                /* Скопируем последний char */
                keyb_data   <= keyb_char;       
                
                /* Сброс статуса для порта 64h */
                keyb_ready2 <= keyb_ready2 ^ keyb_ready; 
                
            end
            
            /* Порт статуса */
            16'h0064: keyb_data <= {7'h0, keyb_ready};
            
        endcase
        
    end

end
// ---------------------------------------------------------------------

endmodule
