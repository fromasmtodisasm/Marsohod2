
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xe000
        macro   brk { xchg bx, bx }
        
bios_entry:
        
        brk                    
        mov     sp, 0C000h      ; 48 байт сверху для стека
        mov     di, 0xb000
        mov     ax, 0x0741
@@:     mov     [di], ax    
        add     al, 1
        inc     al
        add     di, 2           ; lea?
        cmp     di, 0xbc00
        jne     @b
bk:        
        jmp     $+2
        ret

; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:

        push    si
        pop     bp
        
        db      0x40, 0x41, 0x48, 0x49, 0xee, 0xaa        
        ;jmp     bios_entry
        db      (0x10000 - $) dup 0x00
        
