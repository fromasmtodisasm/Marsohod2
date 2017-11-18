module main(

    input   wire            clock,
    input   wire            clock_100,
    output  wire [19:0]     o_addr,
    input   wire [15:0]     i_data

);

`define AX 4'h0
`define CX 4'h1
`define DX 4'h2
`define BX 4'h3
`define SP 4'h4
`define BP 4'h5
`define SI 4'h6
`define DI 4'h7

assign o_addr = IP;

reg [15:0] IP;          // Instruction Pointer
reg [19:0] AR;          // Указатель текущего адреса
reg [15:0] SEG[6];      // ES: CS: SS: DS: FS: GS:

// Список регистров на запись или чтение
reg [2:0]  A_in;    reg [2:0]  B_in;    reg [2:0]  C_in;
reg [31:0] A_out;   reg [31:0] B_out;   reg [31:0] W_in;
reg regClock;

reg [4:0] ModRM_byte;      // ModRM, который будет тестироваться Mod/RM без Reg
reg [7:0] ModRM_info;      // Информация о данных 16-битного ModRM

initial begin

    IP = 1'b0;
    AR = 1'b0;
    
end

// ---------------------------------------------------------------------
// Регистровый файл на 8 x 32 битных значений

regfile REG(

    .clock  (regClock),
    .A_in   (A_in),
    .B_in   (B_in),
    .W_in   (W_in),
    .A_out  (A_out),
    .B_out  (B_out)

);

modrmbits ModrmBits(

    .clock_100  (clock_100),
    .mbyte      (ModRM_byte),
    .minfo      (minfo16)

);

// wire [15:0] tmp_effective = minfo16[7] ? 

// ---------------------------------------------------------------------

always @(posedge clock) begin

    // 1T Загрузка опкода
    // 1T Загрузка ModRM

    
    IP <= IP + 1'b1;
    
    // Загрузка опкода. Определение наличия ModRM
    // mbyte <= ModRM_byte
    
    // Загрузка ModRM
        
    //A_in <= minfo16[7] ? `BX : `BP;
    //B_in <= minfo16[5] ? `SI : `DI;
    

end

endmodule
