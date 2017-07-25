/*
 * Модуль аудиосинтеза 3-х компонентов - Square + Triangle + Noise
 * Аналог NES-синтезатора.
 */
 
module audio_synth AUDIO(

    // 25 Мгц опорная частота
	input wire          clock_25,

	// Прямоугольный
	input wire [14:0]   square_freq,        // 0..31767 Частота
	input wire [7:0]    square_vol,         // 0..255   Громкость

	// Треугольный 
	input wire [14:0]   triangle_freq,      // 0..31767 Частота
	input wire [7:0]    triangle_vol,       // 0..255   Громкость

	// Шум
	input wire [7:0]    noise_vol,          // 0..255   Громкость

	// Выходное значение громкости в данный момент времени
	output wire [7:0]   out

);

// Каждые 1000 тактов вычисляется деление 24 + 24 такта для вычисления square / triangle frequency