module z80(
    
    input   wire        clk,            // 100 Mhz
    input   wire        turbo,          // 1-турборежим
    input   wire [7:0]  i_data,
    output  reg  [7:0]  o_data,
    output  wire [15:0] o_addr,
    output  reg         o_wr

);

// Указатель на шину адреса (pc / ab)
assign o_addr = abus ? ab : pc;

com_clock_divisor CCD(
    .clk        (clk),
    .clk_z80    (clk_z80),
    .param_div  (turbo ? 4'd1 : 4'd13)
);

// SZ-H-PNC ФЛаги
// 76543210

// Регистры общего назначения
reg [7:0] a; reg [7:0] f;
reg [7:0] b; reg [7:0] c;
reg [7:0] d; reg [7:0] e;
reg [7:0] h; reg [7:0] l;

// H/L зависит от префикса
wire [7:0] H =  prefix == 1 ? ix[15:8] : 
                prefix == 2 ? iy[15:8] : h;                 
wire [7:0] L =  prefix == 1 ? ix[7:0] : 
                prefix == 2 ? iy[7:0] : l; 

// Дополнительные регистры
reg [7:0] a_prime; reg [7:0] f_prime;
reg [7:0] b_prime; reg [7:0] c_prime;
reg [7:0] d_prime; reg [7:0] e_prime;
reg [7:0] h_prime; reg [7:0] l_prime;

// Индексные регистры
reg [15:0]  ix; 
reg [15:0]  iy;

// Управляющие регистры
reg [7:0]   i;
reg [7:0]   r;
reg [15:0]  sp;
reg [15:0]  pc;
reg [1:0]   imode;  // Режим прерывания
reg         iff1;   // Маскируемое прерывание #1
reg         iff2;   // Маскируемое прерывание #2

// ---------------------------------------------------------------------
reg         abus     = 1'b0;        // address_bus: 0=pc, 1=ab
reg [15:0]  ab       = 1'b0;
reg [2:0]   rs       = 3'b000;      // текущий выбранный регистр (0-7)
reg         delay_di = 1'b0;        // предыдущая инструкция была DI
reg         delay_ei = 1'b0;        // предыдущая инструкция была EI
reg [3:0]   m_state  = 1'b0;        // машинное состояние исполнения кода
reg [3:0]   t_state  = 1'b0;        // инструкции для ожидания
reg [7:0]   opcode   = 1'b0;        // код операции
reg [1:0]   prefix   = 1'b0;        // 1-IX, 2-IY
reg [1:0]   lazy_prefix = 1'b0;     //
reg [15:0]  tmp      = 1'b0;        // временный регистр

// regsel указывает на определенный операнд из основного регистрового файла
wire [7:0]  operand =  rs == 3'b000 ? b : 
                       rs == 3'b001 ? c : 
                       rs == 3'b010 ? d : 
                       rs == 3'b011 ? e : 
                       rs == 3'b100 ? H : 
                       rs == 3'b101 ? L : 
                       // 6 = (hl), (ix+d), (iy+d)
                       rs == 3'b110 ? i_data : a;

initial begin

          a = 1;          b = 0;          c = 3;          d = 0; 
          e = 0;          h = 0;          l = 8;          f = 0;
    a_prime = 2;    b_prime = 0;    c_prime = 0;    d_prime = 0; 
    e_prime = 0;    h_prime = 0;    l_prime = 0;    f_prime = 4;
    
    ix      = 0; iy     = 0;
    i       = 0; r      = 0;
    pc      = 0; sp     = 16'hdff0; 
    imode   = 0; iff1   = 0; 
                 iff2   = 0;
                 
    o_wr    = 0;

end

// Работа с 16-битными операндами
wire [16:0] addhl_r16    = {H, L} + tmp[15:0];
wire [12:0] addhl_r16_hf = {H, L} + tmp[11:0];
wire [15:0] inc_r16      = tmp + 1;
wire [15:0] dec_r16      = tmp - 1;

wire [6:0]  r_inc       = r[6:0] + 1;
wire [15:0] relative8   = {{8{i_data[7]}}, i_data[7:0]};

// Декодер инструкции
always @(posedge clk_z80) begin

    // "Пустые инструкции", чтобы подогнать кол-во тактов на инструкцию
    if (t_state & !turbo) begin t_state <= t_state - 1; end 
    else 
    // Текущая исполнимая инструкция
    if (m_state == 0) begin

        pc <= pc + 1;
        r  <= {r[7], r_inc[6:0]};
        
        // ПРЕФИКС IX:
        if (i_data == 8'hDD) begin
            
            lazy_prefix <= 2'b01;
            t_state     <= 3;
            
        end
        else
        // ПРЕФИКС IY:
        if (i_data == 8'hFD) begin
        
            lazy_prefix <= 2'b10;  
            t_state     <= 3;

        end 
        // ОПЕРАЦИЯ
        else begin        
        
            // "Отложенный" DI/EI. Они срабатывают через 1 инструкцию
            if (delay_di) begin iff1 <= 0; iff2 <= 0; end
            else 
            if (delay_ei) begin iff1 <= 1; iff2 <= 1; end
            
            prefix      <= lazy_prefix;        
            lazy_prefix <= 1'b0;
            opcode      <= i_data;  // Записать опкод с шины данных
            m_state     <= 1;       // К декодеру инструкции (2-й такт)
            delay_di    <= 0;
            delay_ei    <= 0;
            
        end
    
    end

    // Декодирование и исполнение инструкции
    else     
    casex (opcode)
        
        // 4T NOP
        8'b00_000_000: begin 
        
            t_state <= 4-2; 
            m_state <= 0;
            
        end
        
        // 4T EX AF, AF'        
        8'b00_001_000: begin 
        
            t_state <= 4-2;
            a       <= a_prime;
            f       <= f_prime;
            a_prime <= a;
            f_prime <= f;        
            m_state <= 0;
        
        end
        
        // 8T/13T DJNZ *
        8'b00_010_000: begin
                    
            // На следующем такте B=0, значит, 8Т и к следующему опкоду
            if (b == 1) begin
            
                t_state <= 8-2;
                pc      <= pc + 1;
            
            end else begin
            
                t_state <= 13-2;
                pc      <= pc + 1 + relative8;
            
            end

            m_state <= 0;
            b <= b - 1'b1;
        
        end
        
        // 12T JR *
        8'b00_011_000: begin
        
            t_state <= 12-2;
            m_state <= 0;
            pc      <= pc + 1 + relative8;
        
        end
        
        // 12/7T JR (NZ,Z,NC,C), *
        8'b00_1xx_000: begin
        
            // 00 NZ  10 NC
            // 01 Z   11 C
               
            // CF: если выбран NC (opcode[3] = 0), то срабатывает при f[0] = 0
            // ZF: если выбран NZ (opcode[3] = 0), то срабатывает при f[6] = 0
            if ((opcode[4] & (opcode[3] ^ f[0] ^ 1)) | (!opcode[4] & (opcode[3] ^ f[6] ^ 1))) begin
                            
                t_state <= 12-2;
                pc      <= pc + 1 + relative8;
                
            end else begin
            
                t_state <= 7-2;
                pc      <= pc + 1;
            
            end
        
            m_state <= 0;

        end

        // 10T LD r16, **
        8'b00_xx0_001: begin
        
            case (m_state) 
            
                1: begin tmp[7:0] <= i_data; m_state <= 2; pc <= pc + 1; end
                2: begin 
                
                    case (opcode[5:4])
                    
                        2'b00: begin b <= i_data; c <= tmp[7:0]; end
                        2'b01: begin d <= i_data; e <= tmp[7:0]; end
                        2'b10: begin 
                        
                            case (prefix)
                            
                                0: begin h <= i_data; l <= tmp[7:0]; end
                                1: ix <= {i_data, tmp[7:0]}; 
                                2: iy <= {i_data, tmp[7:0]}; 
                                
                            endcase
                            
                        end
                        2'b11: begin sp <= {i_data, tmp[7:0]}; end
                    
                    endcase

                    pc <= pc + 1;
                    m_state <= 0;
                    t_state <= 10-3;
                    
                end
            
            endcase
        
        end
                
        // 11T ADD HL, r16
        8'b00_xx1_001: begin
        
            case (m_state) 
            
                // (1) Вычисление
                1: begin 
                
                    tmp <= opcode[5:4] == 2'b00 ? {b, c} :
                           opcode[5:4] == 2'b01 ? {d, e} :
                           opcode[5:4] == 2'b10 ? {H, L} : sp;
                        
                    m_state <= 2;

                end
                
                // (2) Запись результата
                2: begin
                
                    case (prefix)
                            
                        0: begin h <= addhl_r16[15:8]; l <= addhl_r16[7:0]; end
                        1: ix <= addhl_r16[15:0]; 
                        2: iy <= addhl_r16[15:0];
                        
                    endcase
                    
                    f[0] <= addhl_r16[16];
                    f[1] <= 1'b0;
                    f[3] <= addhl_r16[11];
                    f[4] <= addhl_r16_hf[12];
                    f[5] <= addhl_r16[13];
                    
                    m_state <= 0;
                    t_state <= 11-3;
                
                end
                                
            
            endcase
        
        end
        
        // 7T LD (BC|DE), A
        8'b00_0x0_010: begin
        
            case (m_state)
            
                // Выставить данные на шину данных, и установить шину адреса
                1: begin o_data <= a; abus <= 1; ab <= opcode[4] ? {d,e} : {b,c}; m_state <= 2; end
                // Запись
                2: begin o_wr <= 1; m_state <= 3; end 
                // Завершение
                3: begin o_wr <= 0; abus <= 0; m_state <= 0; t_state <= 7-4; end
            
            endcase
        
        end
                
        // 7T LD A, (BC|DE)
        8'b00_0x1_010: begin
        
            case (m_state)
            
                // Выставить данные на шину данных, и установить шину адреса
                1: begin abus <= 1; ab <= opcode[4] ? {d,e} : {b,c}; m_state <= 2; end
                // Чтение
                2: begin abus <= 0; a <= i_data; m_state <= 0; t_state <= 7-3; end
            
            endcase
        
        end
        
        // 16T LD (**), (HL|IX|IY)
        8'b00_100_010: begin
        
            case (m_state)
            
                1: begin ab[7:0] <= i_data; pc <= pc + 1; m_state <= 2;  end
                2: begin 
                
                    ab[15:8]    <= i_data; 
                    pc          <= pc + 1; 
                    abus        <= 1;                    
                    m_state     <= 3;
                     
                    case (prefix)
                    
                        0: o_data <= l;
                        1: o_data <= ix[7:0];
                        2: o_data <= iy[7:0];
                    
                    endcase
                    
                end
                
                3: begin o_wr <= 1; m_state <= 4; end
                4: begin o_wr <= 0; ab <= ab + 1; m_state <= 5; end
                5: begin
                
                    m_state <= 6; 
                    case (prefix)
                    
                        0: o_data <= h;
                        1: o_data <= ix[15:8];
                        2: o_data <= iy[15:8];
                    
                    endcase
                
                end
                
                6: begin o_wr <= 1; m_state <= 7; end
                7: begin o_wr <= 0; abus <= 0; m_state <= 0; t_state <= 16 - 8; end
            
            endcase
        
        end
        
        // 16T LD (HL|IX|IY), (**)
        8'b00_101_010: begin
        
            case (m_state)
            
                1: begin ab[ 7:0] <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin ab[15:8] <= i_data; pc <= pc + 1; m_state <= 3; abus <= 1; end
                3: begin tmp[7:0] <= i_data; ab <= ab + 1; m_state <= 4; end
                4: begin 
                
                    case (prefix)
                    
                        0: begin h <= i_data; l <= tmp[7:0]; end
                        1: ix <= {i_data, tmp[7:0]};
                        2: iy <= {i_data, tmp[7:0]};
                    
                    endcase
                
                    m_state <= 0; 
                    t_state <= 16 - 5;
                    abus    <= 0;
                    
                end
            
            endcase
        
        end
        
        // 13T LD (**), A
        8'b00_110_010: begin
        
            case (m_state)
            
                1: begin ab[ 7:0] <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin ab[15:8] <= i_data; pc <= pc + 1; m_state <= 3; o_data <= a; abus <= 1; end
                3: begin m_state <= 4; o_wr <= 1; end
                4: begin m_state <= 0; o_wr <= 0; abus <= 0; t_state <= 13 - 5; end
            
            endcase
        
        end
        
        // 13T LD A, (**)
        8'b00_111_010: begin
        
            case (m_state)
            
                1: begin ab[ 7:0] <= i_data; pc <= pc + 1; m_state <= 2; end
                2: begin ab[15:8] <= i_data; pc <= pc + 1; m_state <= 3; abus <= 1; end
                3: begin a <= i_data; m_state <= 0; o_wr <= 0; abus <= 0; t_state <= 13 - 4; end
            
            endcase
        
        end

        // 6T INC/DEC r16
        8'b00_xxx_011: begin
        
            case (m_state)
            
                // Чтение
                1: begin 
                    
                    case (opcode[5:4])
                    
                        0: tmp <= {b, c};
                        1: tmp <= {d, e};
                        2: tmp <= {H, L};
                        3: tmp <= sp;
                    
                    endcase
                    
                    m_state <= 2;
                
                end
                
                // Вычисление
                2: begin tmp <= opcode[3] ? dec_r16 : inc_r16; m_state <= 3; end
                
                // Запись результата
                3: begin
                
                    case (opcode[5:4])
                    
                        0: begin b <= tmp[15:8]; c <= tmp[7:0]; end
                        1: begin d <= tmp[15:8]; e <= tmp[7:0]; end
                        2: begin 
                        
                            case (prefix)
                            
                                0: begin h <= tmp[15:8]; l <= tmp[7:0]; end
                                1: ix <= tmp;
                                2: iy <= tmp;
                            
                            endcase

                        end
                        
                            
                        3: begin sp <= tmp; end
                    
                    endcase
                    
                    m_state <= 0;
                    t_state <= 6 - 4;
                
                end
            
            endcase
        
        end
           
        // 4T/11T INC/DEC r8
        8'b00_xxx_10x: begin
        
            case (m_state)
            
                // если (HL/IX+d/IY+d), то включение режима address bus
                1: begin

                    rs      <= opcode[5:3];
                    abus    <= (opcode[5:3] == 3'd6) && (!prefix);
                    ab      <= {H, L}; 
                    m_state <= 2;
                    
                end
                   
                // Вычисление / Переход
                2: begin
                
                    f[1] <= opcode[0];

                    // Используется обращение к (HL), IX+d, IY+d
                    if (opcode[5:3] == 3'd6) begin
                    
                        // IX: IY: Использ
                        if (prefix) begin
                        
                            abus    <= 1;
                            ab      <= ab + relative8;
                            pc      <= pc + 1;
                            t_state <= 8;
                            prefix  <= 0;

                        // Вычисление и подготовка к записи в память
                        end else begin
                        
                            tmp[8:0]    <= opcode[0] ? i_data - 1 : i_data + 1;
                            o_data[7:0] <= opcode[0] ? i_data - 1 : i_data + 1;
                            m_state     <= 4;

                        end

                    end
                    
                    // INC/DEC r
                    else begin
                    
                        tmp[8:0]    <= opcode[0] ? operand - 1 : operand + 1;
                        m_state     <= 3;
                                        
                    end
                
                end      
                
                // Сохранение
                3: begin
                
                    case (rs)
                    
                        0: b <= tmp[7:0];
                        1: c <= tmp[7:0];
                        2: d <= tmp[7:0];
                        3: e <= tmp[7:0];
                        4: case (prefix) 
                        
                            0: h        <= tmp[7:0];
                            1: ix[15:8] <= tmp[7:0];
                            2: iy[15:8] <= tmp[7:0];
                            
                        endcase
                        5: case (prefix) 
                        
                            0: l        <= tmp[7:0];
                            1: ix[7:0]  <= tmp[7:0];
                            2: iy[7:0]  <= tmp[7:0];
                            
                        endcase
                        7: a <= tmp[7:0];
                    
                    endcase
                    
                    /* C */ f[0] <= tmp[8];
                    /* P */ f[2] <= 0; // !! tmp[7] ^ tmp[6] ^ tmp[5] ^ tmp[4] ^ tmp[3] ^ tmp[2] ^ tmp[1] ^ tmp[0] ^ 1'b1;
                    /* Y */ f[3] <= tmp[3];
                    /* H */ f[4] <= tmp[3:0] == (f[1] ? 4'b1111 : 4'b0000);
                    /* X */ f[5] <= tmp[5];
                    /* Z */ f[6] <= tmp[7:0] == 0;
                    /* S */ f[7] <= tmp[7];
                    
                    m_state <= 0;

                end  
                
                // Запись в память
                4: begin o_wr <= 1; m_state <= 5; end   
                
                // Выход к сохранению флагов
                5: begin o_wr <= 0; abus <= 0; m_state <= 3; t_state <= 11 - 6; end            
                
            endcase
        
        end
           
        // 7/10T LD r8, *
        8'b00_xxx_110: begin
        
            case (m_state)
            
                // Загрузка Immediate
                1: begin
                
                    tmp[7:0] <= i_data;
                    pc      <= pc + 1;
                    m_state <= 2;
                    ab      <= {H, L};
                
                end
                
                // Запись в регистр
                2: begin
                
                    case (opcode[5:3])
                    
                        0: b <= tmp[7:0];
                        1: c <= tmp[7:0];
                        2: d <= tmp[7:0];
                        3: e <= tmp[7:0];
                        4: case (prefix)                        

                            0: h         <= tmp[7:0];
                            1: ix[15:8]  <= tmp[7:0];
                            2: iy[15:8]  <= tmp[7:0];                            

                        endcase                        
                        5: case (prefix)                        

                            0: l        <= tmp[7:0];
                            1: ix[7:0]  <= tmp[7:0];
                            2: iy[7:0]  <= tmp[7:0];                            

                        endcase                        
                        6: begin 
                            
                            abus <= 1;
                            
                            if (prefix) begin
                                
                                o_data  <= i_data; 
                                ab      <= ab + {{8{tmp[7]}}, tmp[7:0]};
                                pc      <= pc + 1; 
                                
                            end else begin
                                o_data  <= tmp[7:0];
                            end
                            
                        end
                        7: a <= tmp[7:0];                        
                    
                    endcase
                    
                    t_state <= 7 - 3;
                    m_state <= opcode[5:3] == 6 ? 3 : 0;
                
                end
                
                // Запись в память
                3: if (prefix) begin
                                    
                    prefix  <= 0;
                    t_state <= 9;
                
                end else begin

                    o_wr    <= 1;
                    m_state <= 4;

                end
                
                // Завершить запись
                4: begin o_wr <= 0; m_state <= 0; abus <= 0; t_state <= 1; end
            
            endcase
        
        end
                
    endcase
end


endmodule
