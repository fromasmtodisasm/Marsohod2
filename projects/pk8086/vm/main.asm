
WORK_SEGMENT    EQU 0x0800 ; 0xC000 - PRODUCTION

        org 0000h
        
        macro   brk { xchg bx, bx }

        cli
        cld

        xor     ax, ax
        mov     es, ax
        call    Interrupt_Setup    
        
        brk
        int     10h
        
        ; Возможно, что не нужно        
        mov     cx, 2000
        mov     ax, 0x1700
        rep     stosw
        
        jmp     $
        
; Video Interrupt
; ----------------------------------------------------------------------
Int10_TeletypeChar:

        iret
        
; Disk Interrupt
; ----------------------------------------------------------------------
Int13_DiskService:

        iret

irq_DivideZero:
irq_SingleStep:
irq_NonMasking:
irq_Breakpoint:
irq_OverflowTp:
    
        iret

; Установка прерываний
; ----------------------------------------------------------------------
Interrupt_Setup:

        mov     ax, WORK_SEGMENT
        mov     ds, ax

        ; Очистить таблицу прерываний
        mov     cx, 256 * 2
        xor     di, di
        mov     ax, irq_DivideZero
@@:     rep     stosw

        mov     cx, 20                  ; Количество полезных прерываний
        mov     si, .Listing
        xor     di, di
@@:     movsw
        stosw
        loop    @b        
        ret        

.Listing: ; http://stanislavs.org/helppc/int_table.html

        ; IRQ Routines
        dw      irq_DivideZero      ; 00 Divide by zero
        dw      irq_SingleStep      ; 01 Single step
        dw      irq_NonMasking      ; 02 Non-maskable  (NMI)
        dw      irq_Breakpoint      ; 03 Breakpoint
        dw      irq_OverflowTp      ; 04 Overflow trap
        dw      0                   ; 05 Print Screent
        dw      0                   ; 06 
        dw      0                   ; 07 
        dw      0                   ; 08 Timer (55ms intervals, 18.2 per second)
        dw      0                   ; 09 Keyboard
        dw      0                   ; 0A 
        dw      0                   ; 0B COM2 or COM4
        dw      0                   ; 0C COM1 or COM3
        dw      0                   ; 0D Fixed Disk
        dw      0                   ; 0E Floppy Disk
        dw      0                   ; 0F 
        
        ; Список прерываний BIOS
        dw      Int10_TeletypeChar  ; 10
        dw      0                   ; 11
        dw      0                   ; 12
        dw      Int13_DiskService   ; 13
                
; ----------------------------------------------------------------------
BiosCopyrights:
    
        db "Tiny-8086 Microprocessor by V.Foxtail", 0
        
