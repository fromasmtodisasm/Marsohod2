`ifndef __mod_initial
`define __mod_initial

initial begin

    pc = 16'h0000;
    
    // По умолчанию выбран главный набор регистров
    bank_r  = 1'b0;
    bank_af = 1'b0;
    
    // Машинное состояние
    t_state = 1'b0;

    // Главный набор    
    a  = 8'h03;
    f  = 8'b00000001;
    b  = 8'h04; c  = 8'h18;
    d  = 8'h7E; e  = 8'h5F;
    h  = 8'h61; l  = 8'h25;

    // Доп. набор
    a_ = 8'h22;
    f_ = 8'b00000000;
    b_ = 8'h03; c_ = 8'h06;
    d_ = 8'h04; e_ = 8'h07;
    h_ = 8'h05; l_ = 8'h08;
    
    xh = 8'h11; xl = 8'h22;
    yh = 8'h44; yl = 8'h33;
    
    sp = 16'h7FFE;
    
    o_data = 4'h0;
    mem  = 1'b0;
    w_reg = 1'b0;
    w_reg16 = 1'b0;
    w_num = 1'b0;
    w_num16 = 1'b0;
    w_r = 1'b0;
    w_r16 = 1'b0;
    flags = 1'b0;
    w_flag = 1'b0;
    w_r16af = 1'b0;
    ap = 1'b0;
    ie = 1'b1;
    prefix = 1'b0;
    opc_cb = 1'b0;
    prefixed = 1'b0;
    postpref = 1'b0;
    
    port_addr = 1'b0;
    port_data = 1'b0;
    port_clock = 1'b0;
    irq_38_timer = 1'b0;
    irq = 1'b0;

end

`endif
