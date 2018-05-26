module cpu(

    input  wire        CLK,     // 1.71 МГц
    input  wire        CE,      // Готовность
    output wire [15:0] ADDR,    // Адрес программы или данных
    input  wire [7:0]  DIN,     // Входящие данные
    output wire [7:0]  DOUT,    // Исходящие данные
    output reg  [15:0] EA,      // Эффективный адрес
    output reg         WREQ     // =1 Запись в память по адресу EA

);

assign ADDR = AM ? EA : PC;
assign DOUT = 1'b0; /* AR[7:0] */

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
`define REL     5'h11
`define IMP     5'h11
`define ACC     5'h11

initial begin EA = 16'h0000; WREQ = 1'b0; end

/* Регистры */
reg  [7:0] A  = 8'h80;
reg  [7:0] X  = 8'hFF;
reg  [7:0] Y  = 8'hF9;
reg  [7:0] S  = 8'h00;
reg  [7:0] P  = 8'b00000000;
reg [15:0] PC = 16'h8000;

/* Состояние процессора */
reg         AM     = 1'b0;  /* 0=PC, 1=EA */
reg  [4:0]  MS     = 3'h0;  /* Исполняемый цикл */
reg  [7:0]  TR     = 3'h0;  /* Temporary Register */
reg         Cout   = 1'b0;  /* Переносы при вычислении адреса */
reg  [7:0]  opcode = 8'h0;  /* Текущий опкод */

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
wire [4:0]  LATADDR = Latency ? `LAT1 : `EXEC; /* Код адреса при Latency */

/* Исполнение микрокода */
always @(posedge CLK) begin

    case (MS) 
    
        /* ИНИЦИАЛИЗАЦИЯ */
        4'h0: begin
        
            casex (DIN)

                8'bxxx_000_x1: begin MS <= `NDX; end // Indirect, X
                8'bxxx_010_x1, // Immediate
                8'b1xx_000_x1: begin MS <= `IMM; end
                8'bxxx_100_x1: begin MS <= `NDY; end // Indirect, Y
                8'bxxx_110_x1: begin MS <= `ABY; end // Absolute, Y
                8'bxxx_001_xx: begin MS <= `ZP; end  // ZeroPage
                8'bxxx_011_xx, // Absolute
                8'b001_000_00: begin MS <= `ABS; end
                8'b10x_101_1x: begin MS <= `ZPY; end // ZeroPage, Y
                8'bxxx_101_xx: begin MS <= `ZPX; end // ZeroPage, X
                8'b10x_111_1x: begin MS <= `ABY; end // Absolute, Y
                8'bxxx_111_xx: begin MS <= `ABX; end // Absolute, X
                8'bxxx_100_00: begin MS <= `REL; end // Relative
                8'b0xx_010_10: begin MS <= `ACC; end // Accumulator
                default: MS <= `IMP;

            endcase
            
            PC      <= PCINC; /* PC++ */ 
            WREQ    <= 1'b0;  /* Отключение записи в память EA */
            opcode  <= DIN;   /* Принять новый опкод */
            
        end
        
        /* АДРЕСАЦИЯ */
        
        /* Indirect, X */
        // -------------------------------------------------------------
        4'h1: begin MS <= MSINC;   EA <= XDin[7:0]; AM <= 1'b1; end
        4'h2: begin MS <= MSINC;   EA <= EAINC;     TR <= DIN; end
        4'h3: begin MS <= `LAT1;   EA <= EADIN; end
        
        /* Indirect, Y */
        // -------------------------------------------------------------
        4'h4: begin MS <= MSINC;   EA <= DIN;   AM <= 1'b1; end
        4'h5: begin MS <= MSINC;   EA <= EAINC; TR <= YDin[7:0]; Cout <= YDin[8]; end
        4'h6: begin MS <= LATADDR; EA <= EADIH; end
        
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
        4'hA: begin MS <= MSINC; TR <= DIN;     PC <= PCINC;  end
        4'hB: begin MS <= `EXEC; EA <= EADIN;   AM <= 1'b1; end

        /* Absolute,X */
        // -------------------------------------------------------------
        4'hC: begin MS <= MSINC;   PC <= PCINC; TR <= XDin[7:0]; Cout <= XDin[8]; end
        4'hD: begin MS <= LATADDR; EA <= EADIH; AM <= 1'b1;end

        /* Absolute,Y */
        // -------------------------------------------------------------
        4'hE: begin MS <= MSINC;   PC <= PCINC; TR <= YDin[7:0]; Cout <= YDin[8]; end
        4'hF: begin MS <= LATADDR; EA <= EADIH; AM <= 1'b1; end
        
        /* Отложенный такт (для адресации) */
        `LAT1: MS <= `EXEC;
        
        /* Исполнение инструкции */
        // -------------------------------------------------------------
        
        /* Исполнение инструкции */
        `EXEC: begin        
        
            PC <= PCINC; /* Инкремент PC по завершении разбора адреса */
    
            MS <= 1'b0; // ! временно !
        
        end

    endcase
    
end

endmodule

