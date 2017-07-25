/*
 * PWM-модуль для преобразования числа 0..255 в PWM для канала аудио на шилде Марсоход2
 */

module audio_pwm(

    input  wire       clk,  // 25 mhz
    input  wire [7:0] vol,  // 0..255
    output wire       pwm   // 0/1

);


endmodule
