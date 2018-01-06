module z80(

    input   wire        clk,            // 100 Mhz
    input   wire [7:0]  i_data,
    output  wire [7:0]  o_data,
    output  wire [15:0] o_addr

);

// Указатель на шину адреса (pc / ab)
assign o_addr = abus ? ab : pc;

// ---------------------------------------------------------------------

com_clock_divisor CCD(
    .clk        (clk),
    .clk_z80    (clk_z80),
    .param_div  (4'd0)      // 3.5 Mhz = 4'd13
);

// ---------------------------------------------------------------------

// Регистры общего назначения
reg [7:0] a; reg [7:0] f;
reg [7:0] b; reg [7:0] c;
reg [7:0] d; reg [7:0] e;
reg [7:0] h; reg [7:0] l;

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

// regsel указывает на определенный операнд из основного регистрового файла
wire [7:0]  operand =  rs == 3'b000 ? b : 
                       rs == 3'b001 ? c : 
                       rs == 3'b010 ? d : 
                       rs == 3'b011 ? e : 
                       rs == 3'b100 ? h : 
                       rs == 3'b101 ? l : 
                       // 6 = (hl), (ix+d), (iy+d)
                       rs == 3'b110 ? i_data : a;

initial begin

          a = 1;          b = 0;          c = 0;          d = 0; 
          e = 0;          h = 0;          l = 0;          f = 5;
    a_prime = 2;    b_prime = 0;    c_prime = 0;    d_prime = 0; 
    e_prime = 0;    h_prime = 0;    l_prime = 0;    f_prime = 4;
    
    ix      = 0; iy     = 0;
    i       = 0; r      = 0;
    pc      = 0; sp     = 16'hdff0; 
    imode   = 0; iff1   = 0; 
                 iff2   = 0;

end

// ---------------------------------------------------------------------
wire [6:0]  r_inc       = r[6:0] + 1;
wire [15:0] relative8   = {{8{i_data[7]}}, i_data[7:0]};

// ---------------------------------------------------------------------
always @(posedge clk_z80) begin

    // "Пустые инструкции", чтобы подогнать кол-во тактов на инструкцию
    if (t_state) begin t_state <= t_state - 1; end

    // Текущая исполнимая инструкция
    else if (m_state == 1'b0) begin

        pc <= pc + 1;
        r  <= {r[7], r_inc[6:0]};
        
        // "Отложенный" DI/EI. Они срабатывают через 1 инструкцию
             if (delay_di)  begin iff1 <= 0; iff2 <= 0; end
        else if (delay_ei)  begin iff1 <= 1; iff2 <= 1; end
        
        delay_di    <= 0;
        delay_ei    <= 0;
        m_state     <= 1;       // К декодеру инструкции (2-й такт)
        opcode      <= i_data;  // Записать опкод с шины данных
    
    end
    
    // Декодирование и исполнение инструкции
    else casex (opcode)
        
        // 4T NOP
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
        8'b00_000_000: begin 
        
            t_state <= 2; 
            m_state <= 0;
            
        end
        
        // 4T EX AF, AF'
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
        8'b00_001_000: begin 
        
            t_state <= 2;
            a       <= a_prime;
            f       <= f_prime;
            a_prime <= a;
            f_prime <= f;        
            m_state <= 0;
        
        end
        
        // 8T/13T DJNZ *
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
        8'b00_010_000: begin
                    
            // На следующем такте B=0, значит, 8Т и к следующему опкоду
            if (b == 1) begin
            
                t_state <= 6; // 8-2
                pc      <= pc + 1;
            
            end else begin
            
                t_state <= 11; // 13-2
                pc      <= pc + 1 + relative8;
            
            end

            m_state <= 0;
            b <= b - 1'b1;
        
        end
        
        // 12T JR *
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        8'b00_011_000: begin
        
            t_state <= 10; // 12-2
            m_state <= 0;
            pc      <= pc + 1 + relative8;
        
        end
        
    endcase
end

endmodule
