
        .org    $8000
                
        lda #$10
        sta $2000

        lda #$20
        sta $2006

        lda #$00
        sta $2006
       
        ; ---
        lda #$45
        sta $2007
                  
        lda #$59
        sta $2007
        
FILLSTA        
        sta $2007
        dex 
        bne FILLSTA
        
INFLOOP        
        jmp INFLOOP