/*
 * Простой в использовании SDRAM-интерфейс
 * Включает в себя VGA 640x480, использует буферы
 * http://tinyvga.com/vga-timing/640x480@60Hz
 */

module sdramvga640(

    // 100 Mhz
    input   wire        clock,

    // SDRAM интерфейс
    output  wire        clksdram,
    output  wire [11:0] addr,
    output  reg  [1:0]  bank,
    inout   wire [15:0] dq,
    output  wire        ldqm,
    output  wire        udqm,
    output  wire        ras,
    output  wire        cas,
    output  wire        we,

    // VGA интерфейс
    output  wire [4:0]  vga_red,
    output  wire [5:0]  vga_green,
    output  wire [4:0]  vga_blue,
    output  wire        vga_hs,
    output  wire        vga_vs,

    // Интерфейс доступа к данным 
    input   wire [21:0] address,        // Адрес, по словам
    input   wire [15:0] i_data,         // Входящие данные
    output  wire [15:0] o_data,         // Исходящие данные
    input   wire        rdwr,           // =0 (Чтение), =1 (Запись)
    input   wire        clk,            // Такт на чтение, запись
    output  reg         lock            // =1 память недоступна на чтение/запись

);

assign dq = we ? 16'bZ : i_data;
assign clksdram = clock;

localparam debug_init_nl = 1'b0; // 1'b0 Default
localparam debug_init_sd = 1'b1; // 1'b1 Default

// Ожидание 100μs перед инициализацией
localparam iwaitc = 1250;

// Command modes                 RCW
localparam cmd_loadmode     = 3'b000;
localparam cmd_refresh      = 3'b001;
localparam cmd_precharge    = 3'b010;
localparam cmd_activate     = 3'b011;
localparam cmd_write        = 3'b100;
localparam cmd_read         = 3'b101;
localparam cmd_burst_term   = 3'b110;
localparam cmd_nop          = 3'b111;

// Статусы обработчика
`define SDRAM_WAIT      3'b000
`define SDRAM_READ3     3'b001
`define SDRAM_READ3A    3'b010
`define SDRAM_WRITE     3'b011
`define SDRAM_READ      3'b100

// FIRST, locked at INIT
initial initlock = debug_init_sd;
initial lock = 1'b1;
initial addrc = 10'b010000000000; // A[10]=1
initial cmdinit = cmd_nop;
initial cmd = cmd_nop;


// RAS/CAS/WE is SDRAM command
assign ras  = initlock ? cmdinit[2] : cmd[2];
assign cas  = initlock ? cmdinit[1] : cmd[1];
assign  we  = initlock ? cmdinit[0] : cmd[0];
assign addr = initlock ? addrc : addrw;

reg        initlock;        // Блокировка (1) при инициализации
reg [10:0] init = 1'b1;     // Счетчик [0..1250+21]

reg [2:0]  cmd;             // Команды к SDRAM
reg [11:0] addrw;           // Рабочий адрес

reg [2:0]  cmdinit;         // Команды для инициализации
reg [11:0] addrc;           // Command Address

/* Делитель частоты
 *  @posedge div[0] = 50,0 Mhz
 *  @posedge div[1] = 25,0 Mhz
 *  @posedge div[2] = 12,5 Mhz
 */

reg [2:0] div;
always @(posedge clock) div <= div + 1'b1;

// Блок инициализации SDRAM
always @(posedge div[2]) begin

    if (initlock) begin

        /* PRECHARGE */      if (init == iwaitc + 1)  begin cmdinit <= cmd_precharge; end
        /* REFRESH */   else if (init == iwaitc + 4)  begin cmdinit <= cmd_refresh; end
        /* LOADMODE */  else if (init == iwaitc + 18) begin cmdinit <= cmd_loadmode; addrc[9:0] <= 10'b0000100111; end
        /* START */     else if (init == iwaitc + 21) begin initlock <= 1'b0; end
        /* NOP */       else begin cmdinit <= cmd_nop; end

        init <= init + 1'b1;

    end

end

// Текущая позиция
reg [7:0] bank_cnt;

// Один банк = 128 байт
reg [2:0] bank_num;

// Буфер
reg [9:0]  aw;       // 2x1024 байт
reg [15:0] dw;       // 16 bit
reg        cb;       // Текущий буфер
reg        wb;       // Write Enabled

// Для переключения банков по 128 байт
wire [18:0] caddr = vaddr[18:0] + {bank_num[2:0],7'b0000000};

// ---------- TEST ZONE ------------------

assign hdqm = 1'b0; // 1'b0; 
assign ldqm = 1'b0; // 1'b0; 
        
// ---------- TEST ZONE ------------------

reg [3:0] state = `SDRAM_WAIT;
reg       nl    = debug_init_nl;
wire      x_accept = (x < 798);

// Блок считывания и обработки
always @(posedge clock) begin

    nl <= y[0];

    if (initlock == 1'b0) begin
    
        // Когда Y'=Y+1, запускается процедура считывания в буфер
        if (nl ^ y[0]) begin 
        
            state    <= `SDRAM_READ3;             
            cb       <= y[0];
            aw       <= -1;
            bank_cnt <= 1'b0;
            bank_num <= 1'b0;
            lock     <= 1'b1;
            
        end
        // Обработка очередей, буферы и т.д.
        else case (state)
        
            // Распределение для операции с памятью
            `SDRAM_WAIT: begin

                /*
                 * Операции доступны только до какого-то момента
                 * Это связано с тем, что 4*5 = 20Т на чтение может быть
                 * Поскольку при x=800, произойдет выборка `SDRAM_READ3
                 * и операции чтения или записи не будут завершены вовремя                 
                 *
                 * 1. Блокируется, если получен clk (r/w) x < X_MAX
                 * 2. Либо же x >= X_MAX 
                 */ 
                 
                lock <= (x_accept & clk) | (!x_accept);
            
                // queue 
                // ecc correction
                // auto precharge
                
                if (clk && x_accept) state <= rdwr ? `SDRAM_WRITE : `SDRAM_READ;
                
                // Nop: ничего не делать
                bank_cnt    <= 1'b0;    
                cmd         <= cmd_nop;

            end
            
            // ACTIVATE ROW
            `SDRAM_READ3: begin

                bank        <= 2'b00;
                addrw       <= {1'b0, caddr[18:8]};
                cmd         <= cmd_activate;
                bank_cnt    <= 1'b0;            
                state       <= `SDRAM_READ3A;

            end
            
            // Считывание блока
            `SDRAM_READ3A: begin
            
                // 0,1,2 -- NOP
                if (bank_cnt < 3) begin
                
                    cmd   <= cmd_nop;
                
                end
            
                // Запустить чтение 
                if (bank_cnt == 3) begin
                
                    addrw <= {4'b0000, caddr[7:0]};
                    cmd   <= cmd_read;
                
                end
                
                // CAS Latency=2: пропуск 2-х тактов
                else if (bank_cnt == 4 || bank_cnt == 5) begin
                    
                    addrw[7:0] <= addrw[7:0] + 1'b1; 
                    
                end
                
                // Начать чтение после CAS
                else if (bank_cnt > 5 && bank_cnt < 6 + 128) begin
                
                    dw <= dq;
                    wb <= 1'b1;
                    aw <= aw + 1'b1;

                    addrw[7:0] <= addrw[7:0] + 1'b1;
                
                end
                
                // Закрыть строку, записав 128-й байт
                else if (bank_cnt == 6 + 128) begin 
                
                    cmd       <= cmd_precharge;
                    addrw[10] <= 1'b1;
                    wb        <= 1'b0;
                
                end
                
                // Прочитать еще 128 байт (если доступно)
                else if (bank_cnt == 7 + 128) begin
                
                    cmd         <= cmd_nop;
                    state       <= bank_num == 3'd4 ? `SDRAM_WAIT : `SDRAM_READ3;
                    bank_num    <= bank_num + 1'b1;

                end
                
                // Постепенное увеличение
                bank_cnt <= bank_cnt + 1'b1;
            
            end            
        
            // Одиночная запись (6T)
            `SDRAM_WRITE: begin
            
                case (bank_cnt)
                
                    // Переключение строки
                    3'h0: begin
                    
                        bank  <= address[21:20];
                        addrw <= {address[19:8]};
                        cmd   <= cmd_activate;

                    end
                    
                    // Включение записи
                    3'h3: begin
                    
                        addrw <= {4'b0100, address[7:0]};
                        cmd   <= cmd_write;

                    end
                    
                    // Перезаряд
                    3'h5: begin cmd <= cmd_precharge;  end
                    
                    // Выход
                    3'h6: begin cmd <= cmd_nop; state <= `SDRAM_WAIT; end
                    
                
                endcase
                
                bank_cnt <= bank_cnt + 1'b1;
            
            end
            
            // Одиночное считывание
            `SDRAM_READ: begin
            
            end
            
        endcase

    end

end

// ---------------------------------------------------------------------
// ВИДЕОАДАПТЕР
// использует буфер, который прочитался из SDRAM
// ---------------------------------------------------------------------

reg     [10:0]  x = 1'b0;
reg     [9:0]   y = 1'b0;

// Адрес для считывания новой линии в новый буфер y[0]
reg     [18:0]  vaddr = 1'b0;

// Указатель на предыдущий заполненный буфер ~y[0] (640 WORD)
reg     [10:0]  ar;
reg     [15:0]  dr;

assign  vga_red   = display ? dr[15:11] : 1'b0;
assign  vga_green = display ? dr[10:5] : 1'b0;
assign  vga_blue  = display ? dr[4:0] : 1'b0;

assign  vga_hs  = x > 10'd688 && x <= 10'd784; 
assign  vga_vs  = y > 10'd513 && y <= 10'd515; 
wire    display = x < 10'd640 && y < 10'd480;

wire    xend = x == 11'd800;
wire    yend = y == 10'd525;

// Видеоразрешение 640x480 [800 x 525] 25 MHz
always @(posedge div[1]) begin    

    // Позиция "курсора" в текущем фрейме
    x <= xend ?         1'b0 : x + 1'b1;
    y <= xend ? (yend ? 1'b0 : y + 1'b1) : y;
    
    ar <= {y[0] ^ 1'b1, x[9:0]};
    
    // Новая строка
    if (xend) vaddr <= y * 640;

end

// ---------------------------------------------------------------------
// Буфер на 2 линии - текущая ~Y[0], и новая Y[0] (cb)
// ---------------------------------------------------------------------

vidbuf VIDBUF(

    .clock   (clksdram),
    .addr_rd (ar),          // адрес на чтение (R)
    .q       (dr),          // Выход данных на (R)
    .addr_wr ({cb, aw}),    // Адрес на установку на запись
    .data_wr (dw),          // Входящие данные на запись (W)
    .wren    (wb),          // Разрешение записи (W)

);

endmodule
