module cpu(

    input  wire        CLK,     // 1.71 МГц
    input  wire        CE,      // Готовность
    output wire [15:0] ADDR,    // Адрес программы или данных
    input  wire [7:0]  DIN,     // Входящие данные
    output reg  [7:0]  DOUT,    // Исходящие данные
    output reg  [15:0] EA,      // Эффективный адрес
    output reg         WREQ     // =1 Запись в память по адресу EA

);

assign ADDR = AM ? EA : PC;

// ---------------------------------------------------------------------

/* Ссылки на микрокод */
`define NDX     5'h01
`define NDY     5'h04
`define ZP      5'h07
`define ZPX     5'h08
`define ZPY     5'h09
`define ABS     5'h0A
`define ABX     5'h0C
`define ABY     5'h0E
`define LAT1    5'h10

// Везде переход к исполнению
`define EXEC    5'h11
`define IMM     5'h11
`define IMP     5'h11
`define ACC     5'h11

`define REL     5'h12 // --- отдельная тема

initial begin EA = 16'h0000; WREQ = 1'b0; DOUT = 8'h00; end

/* Регистры */
reg  [7:0] A  = 8'h81;
reg  [7:0] X  = 8'hFF;
reg  [7:0] Y  = 8'h8F;
reg  [7:0] S  = 8'h00;
reg  [7:0] P  = 8'b01000000;
reg [15:0] PC = 16'h8000;

/* Состояние процессора */
reg         AM     = 1'b0;  /* 0=PC, 1=EA */
reg  [4:0]  MS     = 3'h0;  /* Исполняемый цикл */
reg  [7:0]  TR     = 3'h0;  /* Temporary Register */
reg         WR     = 1'b0;  /* Записать в регистр RA из АЛУ */
reg         FW     = 1'b0;  /* Записать в регистр P из АЛУ */
reg         Cout   = 1'b0;  /* Переносы при вычислении адреса */
reg  [7:0]  opcode = 8'h0;  /* Текущий опкод */
reg         HOP    = 1'b0;  /* =1 Операнду требуется PC++ */

/* Некоторые часто употребляемые выражения */
wire [15:0] PCINC   = PC + 1'b1;         /* Инкремент PC */
wire [5:0]  MSINC   = MS + 1'b1;         /* Инкремент MS */
wire [7:0]  EAINC   = EA[7:0] + 1'b1;    /* Инкремент EA */
wire [8:0]  XDin    = X + DIN;           /* Для преиндексной адресации */
wire [8:0]  YDin    = Y + DIN;           /* Для постиндексной адресации */
wire [7:0]  HIDin   = DIN + Cout;        /* Перенос */
wire [15:0] EADIN   = {DIN,   TR};
wire [15:0] EADIH   = {HIDin, TR};
wire        Latency = Cout | opcode[7:5] == 3'b100; /* STA или Cout */
wire [4:0]  LATAD   = Latency ? `LAT1 : `EXEC; /* Код адреса при Latency */

/* Исполнение микрокода */
always @(posedge CLK) begin

    case (MS)

        /* ИНИЦИАЛИЗАЦИЯ */
        4'h0: begin

            casex (DIN)

                8'bxxx_000_x1: begin MS <= `NDX; HOP <= 1'b1; end // Indirect, X
                8'bxxx_010_x1, // Immediate
                8'b1xx_000_x1: begin MS <= `IMM; HOP <= 1'b1; end
                8'bxxx_100_x1: begin MS <= `NDY; HOP <= 1'b1; end // Indirect, Y
                8'bxxx_110_x1: begin MS <= `ABY; HOP <= 1'b1; end // Absolute, Y
                8'bxxx_001_xx: begin MS <= `ZP;  HOP <= 1'b1; end  // ZeroPage
                8'bxxx_011_xx, // Absolute
                8'b001_000_00: begin MS <= `ABS; HOP <= 1'b1; end
                8'b10x_101_1x: begin MS <= `ZPY; HOP <= 1'b1; end // ZeroPage, Y
                8'bxxx_101_xx: begin MS <= `ZPX; HOP <= 1'b1; end // ZeroPage, X
                8'b10x_111_1x: begin MS <= `ABY; HOP <= 1'b1; end // Absolute, Y
                8'bxxx_111_xx: begin MS <= `ABX; HOP <= 1'b1; end // Absolute, X
                8'bxxx_100_00: begin MS <= `REL; HOP <= 1'b1; end // Relative
                8'b0xx_010_10: begin MS <= `ACC; HOP <= 1'b0; end // Accumulator
                default:       begin MS <= `IMP; HOP <= 1'b0; end

            endcase

            PC      <= PCINC; /* PC++ */
            WREQ    <= 1'b0;  /* Отключение записи в память EA */
            opcode  <= DIN;   /* Принять новый опкод */

        end

        /* АДРЕСАЦИЯ */

        /* Indirect, X */
        // -------------------------------------------------------------
        4'h1: begin MS <= MSINC; EA <= XDin[7:0]; AM <= 1'b1; end
        4'h2: begin MS <= MSINC; EA <= EAINC;     TR <= DIN; end
        4'h3: begin MS <= `LAT1; EA <= EADIN; end

        /* Indirect, Y */
        // -------------------------------------------------------------
        4'h4: begin MS <= MSINC; EA <= DIN;   AM <= 1'b1; end
        4'h5: begin MS <= MSINC; EA <= EAINC; TR <= YDin[7:0]; Cout <= YDin[8]; end
        4'h6: begin MS <= LATAD; EA <= EADIH; end

        /* ZP */
        // -------------------------------------------------------------
        4'h7: begin MS <= `EXEC; EA <= DIN;       AM <= 1'b1; end

        /* ZP,X */
        // -------------------------------------------------------------
        4'h8: begin MS <= `LAT1; EA <= XDin[7:0]; AM <= 1'b1; end

        /* ZP,Y */
        // -------------------------------------------------------------
        4'h9: begin MS <= `LAT1; EA <= YDin[7:0]; AM <= 1'b1; end

        /* Absolute */
        // -------------------------------------------------------------
        4'hA: begin MS <= MSINC; TR <= DIN;    PC <= PCINC;  end
        4'hB: begin MS <= `EXEC; EA <= EADIN;  AM <= 1'b1; end

        /* Absolute,X */
        // -------------------------------------------------------------
        4'hC: begin MS <= MSINC; TR <= XDin[7:0]; PC <= PCINC; Cout <= XDin[8]; end
        4'hD: begin MS <= LATAD; EA <= EADIH;     AM <= 1'b1;end

        /* Absolute,Y */
        // -------------------------------------------------------------
        4'hE: begin MS <= MSINC; TR <= YDin[7:0]; PC <= PCINC; Cout <= YDin[8]; end
        4'hF: begin MS <= LATAD; EA <= EADIH;     AM <= 1'b1; end

        /* Отложенный такт (для адресации) */
        `LAT1: MS <= `EXEC;

        /* Исполнение инструкции */
        // -------------------------------------------------------------

        /* Исполнение инструкции */
        `EXEC: begin

            /* Инкремент PC по завершении разбора адреса */
            if (HOP) PC <= PCINC; 

            casex (opcode)

                /* STA/STY/STX для АЛУ */
                8'b100_xxx_01, 
                8'b100_xx1_x0: {AM, MS, WREQ, DOUT} <= {3'b001, AR[7:0]};

                // По умолчанию, завершение инструкции
                default: {AM, MS} <= 2'b00;

            endcase

        end

        /* Исполнение инструкции B<cc> */
        `REL: begin


        end

    endcase

end

/* Подготовка данных на этапах исполнения */
// ---------------------------------------------------------------------

always @* begin

    alu = {1'b0, opcode[7:5]}; /* По умолчанию */
    RA  = 2'b00; /* A */
    RB  = 2'b00; /* DIN */
    WR  = 1'b0;
    FW  = 1'b0;

    if (MS == `EXEC) casex (opcode)

        /* STA, CMP */
        8'b1x0_xxx_01: FW = opcode[6];

        /* ADC, SBC, AND, ORA, EOR, LDA */
        8'bxxx_xxx_01: {WR, FW} = 2'b11;

        /* STY, STX */
        8'b100_xx1_00: {RA} = 2'b10; // Y
        8'b100_xx1_10: {RA} = 2'b01; // X
        /* LDY */
        8'b101_xx1_00,
        8'b101_000_00: {WR, RA, FW} = 4'b1_10_1;
        /* LDX */
        8'b101_xx1_10,
        8'b101_000_10: {WR, RA, FW} = 4'b1_01_1;
        /* CPY */
        8'b110_xx1_00,
        8'b110_000_00: {RA, FW} = 3'b10_1;
        /* CPX */
        8'b111_xx1_00,
        8'b111_000_00: {alu, RA, FW} = 7'b0110_01_1;
        /* TYA */
        8'b100_110_00: {alu, RB, FW, WR} = 8'b0101_10_11;
        /* CLC, SEC, CLI, SEI, CLV, CLD, SED */
        8'bxxx_110_00: {alu, FW} = 5'b1100_1;

    endcase

end

/* Запись результата */
// ---------------------------------------------------------------------

always @(posedge CLK) begin

    /* Писать результат АЛУ */
    if (WR) case (RA)
        2'b00: A <= AR;
        2'b01: X <= AR;
        2'b10: Y <= AR;
    endcase

    /* Писать флаги */
    if (FW) P <= AF;

end

/* Вычислительное устройство */
// ---------------------------------------------------------------------

reg [3:0] alu = 4'h0;
reg [1:0] RA = 2'b00;
reg [1:0] RB = 2'b00;
reg [7:0] Ax;
reg [7:0] Bx;
reg [7:0] AR;
reg [7:0] AF;

always @* begin

    case (RA)
        2'b00: Ax = A;
        2'b01: Ax = X;
        2'b10: Ax = Y;
        2'b11: Ax = 0;
    endcase

    case (RB)
        2'b00: Bx = DIN;
        2'b01: Bx = X;
        2'b10: Bx = Y;
        2'b11: Bx = S;
    endcase

end

alu ALU(

    /* Вход */  Ax, Bx, alu, P, opcode[7:5],
    /* Выход */ AR, AF

);

endmodule

