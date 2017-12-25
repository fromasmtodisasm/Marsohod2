/*
 * 6T for READ/WRITE
 */
 
module sdram (

    // Hardware Interface
    input   wire        clock, // 100 Mhz
    output  wire        sdclk, // 100 Mhz
    output  reg  [11:0] addr,  // 4096 x 2 byte address
    output  reg  [1:0]  bank,  // Bank(0-3)
    inout   wire [15:0] dq,    // Data 16-bit
    output  reg         ldqm,  // Low  DQ Mask DQ[7:0]  If LOW,  DQ[7:0] = Z-Impedance
    output  reg         udqm,  // High DQ Mask DQ[15:8] If LOW, DQ[15:8] = Z-Impedance
    output  reg         ras,   // Row Access Signal
    output  reg         cas,   // Column Access Signal
    output  reg         we,    // Write Enabled
    
    // FPGA interface
    // 00 - Nop
    // 01 - Read
    // 10 - Write
    // 11 - ??
    input   wire        rden,     // Read Enabled
    input   wire        wren,     // Write Enabled (After Read)
    input   wire [21:0] address,  // Required address (2 x 4mb)
    input   wire [15:0] data_wr,  // Data for Write
    output  reg  [15:0] data_rd,  // Data for Read
    output  reg         busy      // SDRAM fetch Read/Write (=1)
);

// Internal states for this module
`define STATE_INIT     4'b0000
`define STATE_WAIT     4'b0001
`define STATE_RW       4'b0010
`define STATE_RW_2     4'b0011
`define STATE_RW_3     4'b0100
`define STATE_RW_4     4'b0101

// ---
`define PRE_TIME       0 // 2500

initial begin

    we   = 1'b1;
    cas  = 1'b1;
    ras  = 1'b1;
    ldqm = 1'b1;
    udqm = 1'b1;
    busy = 1'b1;
    
end

// DQ=Write, if we#=0, else - read from DQ
assign dq = we ? 16'bZ : data_wr;
assign sdclk = clock; // div25[1];

// State Machine
reg [3:0]  state = `STATE_INIT;
reg [11:0] init_counter = 1'b0;

reg [1:0] div25 = 2'b00;

always @(posedge clock) div25 <= div25 + 1'b1;

// State Machine to entering commands (25 Mhz)
always @(posedge div25[0]) begin

    case (state)
    
        `STATE_INIT: begin
        
            // (1) PRECHARGE
            if (init_counter == `PRE_TIME + 1) begin ras <= 1'b0; cas <= 1'b1; we <= 1'b0; addr[10] <= 1'b1; end 
            
            // (2) REFRESH
            else if (init_counter == `PRE_TIME + 4) begin ras <= 1'b0; cas <= 1'b0; we <= 1'b1; end
        
            // (3) LOADMODE: Burst Lenght[2:0] = b111, FULL; Sequential[3]; CAS Latency[6:4]=2T;
            else if (init_counter == `PRE_TIME + 18) begin ras <= 1'b0; cas <= 1'b0; we <= 1'b0; addr[9:0] <= 10'b0000100111; end
            
            // (4) END of INIT
            else if (init_counter == `PRE_TIME + 21) begin state <= `STATE_WAIT; end
            
            // NOP
            else begin ras <= 1'b1; cas <= 1'b1; we <= 1'b1; end
                                        
            init_counter <= init_counter + 1'b1;        
        end
    
        // WAIT
        `STATE_WAIT: begin

            // 0. INIT, set ACTIVATE CMD
            if (rden | wren) begin

                state <= `STATE_RW;
                bank  <= address[21:20]; // Select 0-4 banks
                addr  <= address[19:8];  // Select 4096 rows [19:8]
                ras   <= 1'b0;
                busy  <= 1'b1;
                ldqm  <= 1'b1;
                udqm  <= 1'b1;

            end
            // NOP
            else begin ras <= 1'b1; end

            cas <= 1'b1;
            we  <= 1'b1;

        end
        
        // 1. ACTIVATE
        `STATE_RW: begin
        
            // Enabled Autoprecharge (0100)
            addr  <= {4'b0100, address[7:0]};
            ras   <= 1'b1;
            cas   <= 1'b0; 
            we    <= wren ^ 1'b1;
            ldqm  <= 1'b0; 
            udqm  <= 1'b0; 
            state <= `STATE_RW_2;

        end
        
        // 4. WAIT, READ/WRITE CAS=2
        `STATE_RW_2: begin state <= `STATE_RW_3; end   
        
        // PRECHARGE
        `STATE_RW_3: begin
  
            data_rd <= we ? dq : 1'b0; 
            we      <= 1'b0; 
            cas     <= 1'b1;
            ras     <= 1'b0;
            state   <= `STATE_WAIT;  
            
        end

    endcase

end

endmodule
