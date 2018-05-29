
        .org    $8000
                
        lda #$10
        sta $2000
        
        lda #$5B
        jsr CLRSCR        
TS
        ; --------
        lda #$20
        sta $2006
        lda #$00
        sta $2006

        ldx #$00
WRTI        
        lda MESG,X
        beq INFLOOP
        sta $2007
        inx
        jmp WRTI        

MESG
        .text "debug monitor", 0
        
        
INFLOOP        
        jmp INFLOOP

CLRSCR  ; (Y,X) = 3C0h очистка экрана 

        pha
        lda #$20
        sta $2006
        lda #$00
        sta $2006
        ldy #$04
        ldx #$C0
        pla
FSTA
        sta $2007
        dex 
        bne FSTA
        dey
        bne FSTA
        rts