
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xc000
        macro   brk { xchg bx, bx }

bios_entry:

        ; Выполнить очистку экрана
        mov     sp, $c000
        mov     ax, $0720
        call    CLS
        
        brk
        
        call    MEMTST
        

; -----------------------------
        mov     di, $b000 + 160*4
        mov     ah, 0Eh
@@:     in      al, 64h
        and     al, 1
        je      @b
        in      al, 60h
        mov     [di], ax
        inc     di
        inc     di
        jmp     @b

; ----------------------------------------------------------------------
; Очистка экрана в [AX]

CLS:    mov     di, $b000
        mov     cx, 2000
@@:     mov     [di], ax
        inc     di
        inc     di
        loop    @b
        ret

; ----------------------------------------------------------------------
; Проверка памяти

MEMTST: mov     ax, 071Fh
        mov     si, sMemoryTest
        mov     di, $B000
        call    RAWPRN
        
        mov     si, $0000
        mov     cx, $00B0
.mt:    mov     ax, [si]
        mov     bx, ax
        xor     bx, $55AA
        mov     [si], bx
        mov     dx, [si]
        mov     [si], ax
        cmp     ax, dx
        mov     ax, $07B0
        je      @f
        mov     al, $B2
@@:     mov     [di], ax
        add     si, $100
        inc     di
        inc     di
        loop    .mt  
        ret

; ----------------------------------------------------------------------
; Пропечатать строку из si на экране, ah - цвет, позиция DI

RAWPRN: 
        mov     al, [si]
        inc     si          ; lodsb надо бы сделать позже
        and     al, al
        je      .fin
        mov     [di], ax    ; stosw
        inc     di
        inc     di
        jmp     RAWPRN        
.fin:   ret

; ----------------------------------------------------------------------
; Установка курсора
; bx = X + Y*80

CURSET: mov     dx, $3d4
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

; Стринги        
; ----------------------------------------------------------------------       
sMemoryTest     db "Memory test...", 0

; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:
    
        jmp     bios_entry 
        db      (0x10000 - $) dup 0x00
        
