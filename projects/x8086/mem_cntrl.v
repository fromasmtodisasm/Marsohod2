/*
 * Контроллер памяти только на быструю внутрисхемную память
 * CAS Latency = 2
 */

module mem_cntrl(

    input   wire        clk,
    input   wire [19:0] i_addr,         // Адрес
    output  reg  [15:0] o_data,         // Исходящие данные
    input   wire [15:0] i_data,         // Входящие данные с CPU
    input   wire        i_write,        // Сигнал записи
    output  reg         o_ready,        // Готовность данных

    // Получение кеша инструкции (по CS:IP)
    input   wire [19:0] i_ip,
    output  wire [47:0] o_instr_cache,

    // Внешний интерфейс
    input   wire [15:0] i_mem_data,     // Входящие данные из памяти
    output  reg  [15:0] o_mem_data,     // Исходящие данные для записи
    output  reg         o_mem_write,    // Сигнал на запись в память
    output  reg  [19:0] o_mem_addr      // Адрес к внутрисхемной памяти

);

// Выборка смещения
assign o_instr_cache    = i_ip[0] ? o_icache[55:8] : o_icache[47:0];

initial o_ready         = 1'b0;
initial o_data          = 1'b0;
initial o_mem_write     = 1'b0;
initial o_mem_addr      = 20'h00000;

// Синхронизация
wire    ip_not_equal    = (i_ip != l_ip);
wire    ap_not_equal    = (i_addr != l_addr);

reg [55:0]  o_icache    = 56'h00000000000000;
reg  [3:0]  mem_state   = 1'b0;
reg [19:0]  l_ip        = 20'h00000;        // Адрес IP, который загружен в o_instr_cache
reg [19:0]  l_addr      = 20'h00000;        // Адрес Addr, который требуется прочитать

always @(posedge clk) begin

    case (mem_state)

        // Циклы ожидания
        4'h0: begin

            // Есть отличия, перезагрузить кеш-линию
            if (ip_not_equal) begin

                o_mem_addr  <= i_ip;
                l_ip        <= i_ip;
                mem_state   <= 4'h1;
                o_ready     <= 1'b0;

            end

            // Если отличия от адреса чтения
            else if (ap_not_equal) begin

                o_mem_addr  <= i_addr;
                l_addr      <= i_addr;
                mem_state   <= 4'h7;
                o_ready     <= 1'b0;

            end

            // Иначе, данные все готовы
            else o_ready <= 1'b1;

        end

        // На этом такте происходит закладка чтения i_addr
        4'h1: begin mem_state <= 4'h2; o_mem_addr <= o_mem_addr + 2'h2; end
        4'h2: begin mem_state <= 4'h3; o_mem_addr <= o_mem_addr + 2'h2; end
        4'h3: begin

            mem_state           <= 4'h4;
            o_mem_addr          <= o_mem_addr + 2'h2;
            o_icache[ 15:0 ]    <= i_mem_data;

        end

        4'h4: begin

            mem_state           <= 4'h5;
            o_mem_addr          <= o_mem_addr + 2'h2;
            o_icache[ 31:16 ]   <= i_mem_data;

        end

        // Чтение и запись данных совместно с изменением OPCACHE
        4'h5: begin

            o_mem_addr          <= i_addr;
            mem_state           <= i_ip[0] ? 4'h6 : (ap_not_equal ? 4'h7 : 4'h0);
            o_icache[ 47:32 ]   <= i_mem_data;
            l_addr              <= i_addr;

        end

        4'h6: begin

            mem_state           <= (ap_not_equal ? 4'h7 : 4'h0);
            o_icache[ 55:48 ]   <= i_mem_data[7:0];

        end

        // Чтение из памяти (или запись)
        4'h7: begin

            o_mem_addr  <= o_mem_addr + 2'h2;
            mem_state   <= 4'h8;

        end

        // Если тут была запись: выключить
        4'h8: begin

            mem_state   <= 4'h9;
            o_mem_write <= 1'b0;

        end

        // Либо чтение выровненного слова, либо запись не выровненного
        4'h9: begin

            o_data      <= i_addr[0] ? i_mem_data[15:8] : (i_write? i_data : i_mem_data);
            mem_state   <= i_addr[0] | i_write ? 4'hA : 4'h0;
            o_mem_addr  <= i_addr;

            // Запуск записи не выровненных данных
            if (i_write) begin

                if (i_addr[0])
                     o_mem_data  <= {i_data[7:0], i_mem_data[7:0]};
                else o_mem_data  <= i_data;

                o_mem_write <= 1'b1;

            end

        end

        // Нечетное попадание
        4'hA: begin

            if (i_write)
                 o_data <= i_data;
            else o_data[15:8] <=  i_mem_data[7:0];

            o_mem_addr  <= i_addr + 2'h2;
            o_mem_data  <= {i_mem_data[15:8], i_data[15:8]};
            mem_state   <= i_write & i_addr[0] ? 4'hB : 4'h0;
            o_mem_write <= i_addr[0];

        end

        4'hB: begin o_mem_write  <= 1'b0; mem_state <= 4'h0; end

    endcase

end

endmodule
