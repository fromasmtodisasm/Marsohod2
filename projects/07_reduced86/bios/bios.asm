
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xe000
        macro   brk { xchg bx, bx }
        
bios_entry:
        
        brk
        mov     sp, 7800h
        mov     di, 0xb000
        mov     ax, 0x0741
@@:     mov     [di], ax    
        add     al, 1
        inc     al
        add     di, 2           ; lea?
        cmp     di, 0xbc00
        jne     @b
        jmp     $

; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:

        db      0xC3, 0x14, 0xFD, 0xFC, 0xee, 0xaa        
        ;jmp     bios_entry
        db      (0x10000 - $) dup 0x00
        
