/*
 * PWM-модуль для преобразования числа 0..255 в PWM для канала аудио на шилде Марсоход2
 *
 * issue: Нет учёта логарифмической шкалы слышимости
 */

module audio_pwm(

    input  wire       clk25,  // 25 mhz
    input  wire [7:0] vol,    // 0..255
    output reg        pwm     // 0/1

);

reg [7:0] counter;

always @(posedge clk25) begin

    pwm <= counter < vol;           // (pwm=1) = counter < vol*2
    counter <= counter + 1'b1;

end

endmodule
