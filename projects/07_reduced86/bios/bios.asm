
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xc000
        macro   brk { xchg bx, bx }
        
TELETYPE        equ $800            ; положение курсора
COLOR_PRN       equ $802            ; цвет курсора

bios_entry:

        ; Выполнить очистку экрана
        mov     sp, $c000
        mov     ax, $0720
        call    CLS                
        call    MEMTST      

        ; Инициалиазация курсора для пропечатки
        mov     [COLOR_PRN],  byte $07
        mov     [TELETYPE],   word $B000 + 3*160 ; x=0, y=0
    
; -----------------------------
        mov     di, $b000 + 2*240
        mov     ah, 0Eh
@@:     in      al, 64h
        and     al, 1
        je      @b
        in      al, 60h
        mov     [di], ax
        inc     di
        inc     di

        call    PRNCHR        
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

MEMTST: ; Печатаем строку
        mov     ax, 071Fh
        mov     si, sMemoryTest
        mov     di, $B000
        call    RAWPRN
                
        ; Проверяем память
        mov     si, $0000
        mov     cx, $00B0
.mt:    mov     ax, $07B0
        mov     [si], word $55AA
        cmp     [si], word $55AA        
        jne     @f      ; если не равно, то тут 0
        mov     al, $FE ; иначе память есть
@@:     mov     [di], ax
        add     si, $100
        inc     di
        inc     di
        loop    .mt          
        mov     si, sMemoryComplete
        mov     ah, 07h
        call    RAWPRN
        ret

; ----------------------------------------------------------------------
; IN:  AL - символ для печати
; AFFECT: SI, DI, AH, BX, CX

PRNCHR: mov     ah, [COLOR_PRN]
        mov     di, [TELETYPE]
        mov     [di], ax            ; stosw
        inc     di
        inc     di
        mov     [TELETYPE], di
        cmp     di, $b000 + 4000
        je      .roll
        
        ; Установка курсора на новое место
.cset:  mov     bx, di
        sub     bx, $b000
        shr     bx, 1
        call    CURSET
        ret

        ; Скроллинг вверх
.roll:  mov     si, $b000 + 0
        mov     di, $b000 + 160
        mov     cx, 24*80
@@:     mov     ax, [di]        ; lodsw
        inc     di
        inc     di
        mov     [si], ax        ; stosw
        inc     si
        inc     si
        loop    @b    

        ; Вернуть курсор назад
        sub     di, 160
        
        ; Пропечатать пустую строку
        mov     cx, 80
        mov     ah, [COLOR_PRN]
        mov     al, $00
@@:     mov     [di], ax
        inc     di
        inc     di
        loop    @b
        
        ; Снова вернуть назад
        sub     di, 160        
        mov     [TELETYPE], di
        jmp     .cset     

; ----------------------------------------------------------------------
; Пропечатать строку из si на экране, ah - цвет, позиция DI

RAWPRN: mov     al, [si]
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
sMemoryComplete db " comleted!", 0

; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:
    
        jmp     bios_entry 
        db      (0x10000 - $) dup 0x00
        
