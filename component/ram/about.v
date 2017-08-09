/*
 * Внутрисхемная память в ПЛИС
 */

wire cntl_w; // --> использовать кастомный контроллер

ram RAM(

    .clock   (clk),     // 100 Mhz
    
    // дрес на чтение (порт R)
    .addr_rd (),
    // Выход данных на (порт R)
    .q       (),
    
    // Порт RW. Адрес на установку на запись
    .addr_wr (),
    // ВХОДЯЩИЕ данные на запись
    .data_wr (),
    // Разрешение записи (вычисляется отдельно)
    .wren    (cntl_w),
    // Исходящие данные с порта RW. 
    .qw      ()

);

// --------------------------- ICARUS ------------------------


wire [7:0]  i_data;
wire [15:0] o_addr;
wire [7:0]  o_data;
wire [7:0]  o_data_wr; // Для соблюдения чётности
wire        o_wr;

// Контроллер: поиск восходящего фронта с задержкой в 1Т
reg [2:0] cntl_mw = 3'b000;
assign    cntl_w  = cntl_mw == 3'b011 && o_wr;
always @(posedge clk) cntl_mw <= {cntl_mw[1:0], clock_25};

// Включение модуля памяти в проект
memory DMEM(clk, o_addr, i_data, o_addr, o_data, cntl_w, o_data_wr);