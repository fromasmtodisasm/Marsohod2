module cpu(

    input  wire        clk,             // 1.71 МГц
    input  wire        ce,              // Chip Enabled
    output wire [15:0] address,         // Указатель адреса
    input  wire [7:0]  i_data,          // Входящие данные
    output reg  [7:0]  o_data,          // Исходящие данные
    output reg         mreq             // Строб записи в память,

);

assign address = eptr ? ea : PC;

// ---------------------------------------------------------------------
// Методы адресации
parameter NDX = 4'h1;       /* Indirect, X */
parameter NDY = 4'h2;       /* Indirect, Y */
parameter IMM = 4'h3;       /* Immediate */
parameter ABS = 4'h4;       /* Absolute */
parameter ABX = 4'h5;       /* Absolute,X */
parameter ABY = 4'h6;       /* Absolute,Y */
parameter ZP  = 4'h7;       /* Zero Page */
parameter ZPX = 4'h8;       /* Zero Page, X */
parameter ZPY = 4'h9;       /* Zero Page, Y */
parameter REL = 4'hA;       /* Relative */
parameter ACC = 4'hB;       /* Accumulator */
parameter IMP = 4'hC;       /* Implied */

// АЛУ режимы
parameter ALU_ADD  = 4'b1000; /* Режим сложение АЛУ A + B => C, 8 бит */
parameter ALU_LDA  = 4'b0101; /* Res = B */

/* Режим работы с EA, TR */
parameter EA_WL     = 1;    /* ea <= AluRes */
parameter EA_WH     = 2;    /* ea[15:8] <= AluRes */
parameter EA_INC    = 3;    /* ea[7:0]++ */
parameter EA_WLH    = 4;    /* ea <= {i_data, tr} */
parameter EA_WTR    = 5;    /* tr <= i_data */
parameter EA_TAL    = 6;    /* tr <= AluRes; ea[7:0]++ */
parameter EA_TAH    = 7;    /* tr <= AluRes; ea[7:0]++ */

/* Указатели регистров */
// Первый операнд
parameter REG_A     = 0;
parameter REG_X     = 1;
parameter REG_Y     = 2;
parameter REG_COUT  = 3;

// Второй операнд
parameter REG_DIN   = 0;

// ---------------------------------------------------------------------

/* Регистры */
reg  [7:0] A  = 8'h80;
reg  [7:0] X  = 8'h00;
reg  [7:0] Y  = 8'h00;
reg  [7:0] S  = 8'h00;
reg  [7:0] P  = 8'b00000000;
reg [15:0] PC = 16'h8000;
reg [15:0] ea = 16'h0000;


/* Управление состоянием процессора */
reg  [3:0] m_cycle = 1'b0;  /* Стадия исполнения опкодов */
reg  [7:0] opcache;         /* Кеш опкода */
wire [7:0] opcode = m_cycle ? opcache : i_data; /* Опкод */
reg  [3:0] addrm;
reg [15:0] pc_addr;  /* Новый адрес PC */

/* Микрокод */
reg        eptr;        /* Если =1, указатель на EA, иначе на PC */
reg [1:0]  pcinc;       /* Ситуации, которые работают с PC */
reg        stageinc;    /* Работа с stage+1 */
reg        fin;         /* =1 Следующий такт обнулит stage => 0 */
reg        wreg;        /* =1 Запись в регистр RA */
reg [3:0]  alu;         /* Режимы ALU: 0-7 Стандарт, 8-15 Расширенный */
reg [2:0]  eamod;       /* Операция с регистром ea, tr */
reg [7:0]  tr;          /* Temp Register */
reg [2:0]  ex;          /* Дополнительный опкод, расширение */
reg        latency;     /* =1 если так, то смотря что в latcnt */
reg        latcnt = 1'b0; /* =1 stageinc+1, =0 stageinc+2 */

/* АЛУ */
reg  [3:0] alu_mode;
wire [7:0] alu_res;
wire [7:0] alu_flags;
reg        Cout = 1'b0;

/* Источники данных для операнда A и B */
reg  [1:0] ra;      /* 0: A,  1: X, 2: Y, 3: Cout */
reg  [1:0] rb;      /* 0: Din */
reg        fw;      /* =1 Писать флаги из alu_flag */

/* Операнд A */
wire [7:0] A_op = ra[1:0] == 2'b00 ? A :
                  ra[1:0] == 2'b01 ? X :
                  ra[1:0] == 2'b10 ? Y : Cout;

/* Операнд B */
wire [7:0] B_op = rb[1:0] == 2'b00 ? i_data : 8'h00; 
                  //rb[1:0] == 2'b01 ? ea[7:0] 

/* Модуль АЛУ */
alu ALU(

    A_op,       /* < Значение A */
    B_op,       /* < Значение B */
    alu_mode,   /* < Режим АЛУ */
    P,          /* < Флаги на вход */
    alu_res,    /* > Результат */
    alu_flags   /* > Флаги */

);

/* Разбор микрокода */
always @* begin

    pcinc       = ~|m_cycle;  /* В любом stage=0 будет PC++ */
    stageinc    = 1'b1;       /* По умолчанию stage++ */
    alu_mode    = 1'b0;       /* 0=ORA */
    fin         = 1'b0;       /* Финализация */
    eamod       = 1'b0;       /* 0 Ничего не делать с EA, TR */
    wreg        = 1'b0;       /* 1 Запись в регистр RA */
    mreq        = 1'b0;       /* 1 Запись в память o_data */
    fw          = 1'b0;       /* 1 Запись флагов */    
    ex          = 1'b0;       /* Исполнение одинаковых блоков */
    latency     = 1'b0;       /* =1 то тогда если Cout=1, stage+1, иначе stage+2 */

    if (m_cycle) begin

        case (addrm)

            /* (Indirect, X) */
            NDX: case (m_cycle)

                // 2 ADD(RA=X, RB=Din) -> ea, pc++ [fetch pointer address, increment PC]
                4'h1: begin eamod = EA_WL; ra = REG_X; rb = REG_DIN; alu_mode = ALU_ADD; pcinc = 1'b1; end

                // 3 tr = i_data, A=1 [fetch effective address low]
                4'h2: begin eamod = EA_WTR; eptr = 1'b1; end

                // 4 ea++ (8 bit), A=1 
                3'h3: begin eamod = EA_INC; end

                // 5 ea = {i_data, tr} [fetch effective address high]
                3'h4: begin eamod = EA_WLH; end

                // 6 АЛУ(RA=A, RB=Din) -> A
                3'h5: begin ex = 1; end
                
            endcase

            /* (Indirect), Y */
            NDY: case (m_cycle)

                // 2 LDA(0, Din) -> ea, PC++
                4'h1: begin eamod = EA_WL; rb = REG_DIN;   alu_mode = ALU_LDA; pcinc = 1'b1; end
                
                // 3 ADD(X, Din) -> TR; ea++
                4'h2: begin eamod = EA_TAL; ra = REG_Y;    rb = REG_DIN; alu_mode = ALU_ADD; eptr = 1; end
                
                // 4 ADD(Cout, Din) -> {ea,tr}
                4'h3: begin eamod = EA_TAH; ra = REG_COUT; rb = REG_DIN; alu_mode = ALU_ADD; latency = 1; latcnt = Cout | (opcode[7:5] == 3'b100); end
                
                // 5/6T
                3'h5: begin ex = 1; end                
            
            endcase

        endcase
        
        /*
         * Исполнение кода, который находится за пределами считывания адреса
         */
         
        case (ex)
        
            3'h1: begin

                ra       = REG_A;                  /* Первый операнд - A */
                rb       = REG_DIN;                /* Второй операнд - память */                                
                wreg     = ~opcode[7] | (opcode[7] & opcode[5]); /* Запись, кроме CMP, STA */                
                fw       = 1;                      /* Писать флаги */
                alu_mode = {1'b0, opcode[7:5]};    /* Выбор АЛУ */
                fin      = opcode[7:5] != 3'b100;  /* Завершение операции, кроме STA */
                mreq     = opcode[7:5] == 3'b100;  /* Сохранить результат */
                o_data   = alu_res;                /* Для STA */
                fin      = 1;                      /* Завершить такт */

            end
            
        endcase
        

    end
    
    /* stage=0, указатель на PC */
    else begin eptr = 0; end

end

/* Расчет метода адресации */
always @* begin

    addrm = IMP;
    casex (opcode)

        8'bxxx_000_x1: begin addrm = NDX; end // Indirect, X
        8'bxxx_010_x1, // Immediate
        8'b1xx_000_x1: begin addrm = IMM; end
        8'bxxx_100_x1: begin addrm = NDY; end // Indirect, Y
        8'bxxx_110_x1: begin addrm = ABY; end // Absolute, Y
        8'bxxx_001_xx: begin addrm = ZP; end // ZeroPage
        8'bxxx_011_xx, // Absolute
        8'b001_000_00: begin addrm = ABS; end
        8'b10x_101_1x: begin addrm = ZPY; end // ZeroPage, Y
        8'bxxx_101_xx: begin addrm = ZPX; end // ZeroPage, X
        8'b10x_111_1x: begin addrm = ABY; end // Absolute, Y
        8'bxxx_111_xx: begin addrm = ABX; end // Absolute, X
        8'bxxx_100_00: begin addrm = REL; end // Relative
        8'b0xx_010_10: begin addrm = ACC; end // Accumulator

    endcase

end

/* Исполнение микрокода */
always @(posedge clk) begin

    /* Оперирование с PC: 00 - ничего, 01 - PC++; 10 - PC=Addr */
    case (pcinc)

        2'b01: PC <= PC + 1'b1;
        2'b10: PC <= pc_addr;

    endcase

    /* Работа с EA */
    case (eamod)

        3'b001: ea       <= alu_res;
        3'b010: ea[15:8] <= alu_res;
        3'b011: ea[7:0]  <= ea[7:0] + 1'b1;
        3'b100: ea       <= {i_data, tr};
        3'b101: tr       <= i_data;
        3'b110: begin tr <= alu_res; ea[7:0] <= ea[7:0] + 1'b1; end
        3'b111: ea       <= {alu_res, tr};

    endcase

    /* Писать в регистр RA значения из АЛУ */
    if (wreg)
        case (ra)
            2'b00: A <= alu_res;
            2'b01: X <= alu_res;
            2'b10: Y <= alu_res;
        endcase

    /* Писать флаги если fw = 1 */
    if (fw)
        P <= alu_flags;

    /* Сохранить опкод */
    if (~|m_cycle) opcache <= i_data;

    /* Сигнал увеличения стадии */
    if (fin)
        m_cycle <= 1'b0;
    else if (stageinc)
        m_cycle <= m_cycle + (latency ? (latcnt ? 1'b1 : 2'h2) : 1'b1);

    /* Для переноса при вычислении эффективного адреса */
    Cout <= alu_flags[0];
    
end

endmodule
