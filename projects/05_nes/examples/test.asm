
        .org    $8000

        lda #$10
        sta $2000
        
        lda #$20
        sta $2006
        lda #$80
        sta $2006
        
        lda #$3F
        ldx #$00
        sta $2006
        stx $2006        
        
; --------        
        lda #$12 ; --
        sta $2007
        
        lda #$16
        sta $2007
        
        lda #$30
        sta $2007
        
        lda #$38
        sta $2007
; --------
LP        
        jmp LP