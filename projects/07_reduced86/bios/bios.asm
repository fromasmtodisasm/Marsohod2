
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xc000
        macro   brk { xchg bx, bx }
        
TELETYPE        equ $000        ; dw положение курсора
COLOR_PRN       equ $002        ; db цвет курсора
SHIFT_TBL       equ $003        ; dw для keyb.asm

bios_entry:

        ; Выполнить очистку экрана
        mov     sp, $c000
        mov     ax, $0720
        call    CMD_CLS                

        ; Инициализация (улучшить)
        mov     [COLOR_PRN],  byte $07
        mov     [TELETYPE],   word 0
        mov     [SHIFT_TBL],  word keyb_dn

        ; Приветственное сообщение
        mov     bp, sGreets
        call    PRINT
    
; -----------------------------
@@:     call    GETCH        
        call    PRNCHR
        jmp     @b

include "inc/print.asm"        
include "inc/const.asm"        
include "inc/keyb.asm"        
       
; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:

        jmp     bios_entry 
        db      (0x10000 - $) dup 0x00
        
