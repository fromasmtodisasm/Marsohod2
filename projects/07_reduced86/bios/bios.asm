
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xe000
        
bios_entry:
        
        mov     di, 0xb800
        mov     ax, 0x0741
@@:     mov     [di], ax    
        add     di, 2           ; lea?
        cmp     di, 0xc000
        jne     @b        
        jmp     $

; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:

        db      0x83, 0x06, 0x03, 0xe0, 0xee, 0xaa

        jmp     bios_entry
        db      (0x10000 - $) dup 0x00
        