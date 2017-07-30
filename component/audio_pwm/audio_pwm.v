/*
 * PWM-модуль для преобразования числа 0..255 в PWM для канала аудио на шилде Марсоход2
 */

module audio_pwm(

    input  wire       clk,    // 100 mhz
    input  wire [7:0] vol,    // 0..255
    output reg        pwm     // 0/1

);
       
    reg [9:0] DeltaAdder; // Output of Delta adder
    reg [9:0] SigmaAdder; // Output of Sigma adder
    reg [9:0] SigmaLatch; // Latches output of Sigma adder
    reg [9:0] DeltaB;     // B input of Delta adder
    
    always @(SigmaLatch) 
        DeltaB = {SigmaLatch[9], SigmaLatch[9]} << (8);
    
    always @(vol or DeltaB) 
        DeltaAdder = vol + DeltaB;
        
    always @(DeltaAdder or SigmaLatch) 
        SigmaAdder = DeltaAdder + SigmaLatch;
        
    always @(posedge clk)
    begin
        SigmaLatch <= SigmaAdder;
        pwm <=  SigmaLatch[9];
    end

endmodule
