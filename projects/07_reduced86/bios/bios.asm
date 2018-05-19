
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xc000
        macro   brk { xchg bx, bx }

bios_entry:

        brk
        mov     sp, $c000
        mov     ax, $0720
        call    clearscreen   
        
        ; Тест памяти
        mov     si, $B000
        mov     di, $B000
        mov     cx, $0010
.mt:    mov     bx, $55AA
        mov     ax, [si]
        mov     [si], bx
        ;xor     [si], bx
        mov     dx, [si]
        ;xor     [si], bx
        cmp     ax, dx      ; если память не изменилась
        mov     ax, $072E
        je      @f
        mov     al, $40
@@:     mov     [di], ax
        add     si, $100
        inc     di
        inc     di
        loop    .mt                
        
kb:
; -----------------------------
        mov     di, $b000 + 160*4
        mov     ah, 0Eh
@@:     in      al, 64h ; call    getch   
        cmp     al, 1
        jne     @b
        ;and     al, 1
        ;je      @b
        in      al, 60h
        mov     [di], ax
        inc     di
        inc     di
        jmp     @b
; -----------------------------


clearscreen: 

        mov     di, $b000
        mov     cx, 2000
@@:     mov     [di], ax
        inc     di
        inc     di
        loop    @b
        ret

; ----------------------------------------
; Установка курсора
; bx = X + Y*80
; ----------------------------------------

cursor_set:

        mov     dx, $3d4
        mov     al, $0f
        out     dx, al      ; outb(0x3D4, 0x0F)
        inc     dx
        mov     al, bl
        out     dx, al      ; outb(0x3D5, pos[7:0])
        dec     dx
        mov     al, $0e
        out     dx, al      ; outb(0x3D4, 0x0E)
        inc     dx
        mov     al, bh
        out     dx, al      ; outb(0x3D5, pos[15:8])
        ret
        
; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:

        jmp     bios_entry        
        db      (0x10000 - $) dup 0x00
        
