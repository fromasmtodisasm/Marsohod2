
        .org    $8000
        
        lda #$10
        sta $2000
        
        lda #$20
        sta $2006
        
        lda #$00
        sta $2006
        
        ldx #$05
AC        
        ldy #$BF
AB        
        lda #$40
        sta $2007
        dey
        bne AB
        dex
        bne AC
LP        
        jmp LP