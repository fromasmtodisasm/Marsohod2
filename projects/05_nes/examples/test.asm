
        .org    $8000
        
        lda #$10
        sta $2000
        
        lda #$20
        sta $2006
        
        lda #$00
        sta $2006
        
        ldy #$41
        
        sty $2007
        
        ldx #$05
AC        
        ldy #$C0
AB       
        lda #$40
        sta $2007
        dey
        bne AB
        dex
        bne AC
LP        
        jmp LP