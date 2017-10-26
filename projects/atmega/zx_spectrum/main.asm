
        #define Xl 26
        #define Xh 27
        #define Yl 28
        #define Yh 29
        #define Zl 30
        #define Zh 31

        ; Эмулятор ZX-Spectrum через AVR-ядро
    
        ; X -- указатель в память 64 Кб (RAM/ROM)
        ; Y,Z - другие указатели
        
        ldi     Zh, 0
        ldi     Zl, 0       ; Z=0000

NEXT_Z80_INSTRUCTION:

        ; Следующая инструкция
        ld      r30, X+
        ldi     r31, 0
        add     r30, r30
        adc     r31, r31
        subi    r30, (0 - #low-addr-codetable)
        sbci    r31, (0 - #hi-addr-codetable)
        ; lpm
        icall
