; RST$00

        JP      MAIN
        NOP
        NOP
        NOP
        NOP
        NOP
        
; RST$08

        CALL    CALC_PLOT   ; 3
        OR      (HL)        ; 1
        LD      (HL), A     ; 1
        RET                 ; 1
        NOP
        NOP
        
        defb    0, 0, 0, 0, 0, 0, 0, 0  ; $10
        defb    0, 0, 0, 0, 0, 0, 0, 0  ; $18
        defb    0, 0, 0, 0, 0, 0, 0, 0  ; $20
        defb    0, 0, 0, 0, 0, 0, 0, 0  ; $28
        defb    0, 0, 0, 0, 0, 0, 0, 0  ; $30
        defb    0, 0, 0, 0, 0, 0, 0, 0  ; $38

BITABLE:
        
        defb    1, 2, 4, 8, 16, 32, 64, 128

; ------------------------------------------------------        
                
MAIN:   

        ; CLEAR SCREEN
        LD      HL, $4000
        LD      A, 7
        OUT     ($FE), A
CYCLE:  LD      A, H
        CP      $5B
        JR      Z, CLRQ
        CP      $58
        LD      A, $00
        JR      C, BELOW    
        LD      A, $38       
BELOW:  LD      (HL), A
        INC     HL
        JR      CYCLE          
        
CLRQ:   ; --------------------------

        LD      HL, $4000
        LD      DE, $3D18
        LD      B, 8

CHRI:
        
        LD      A, (DE)
        LD      (HL), A
        INC     H
        INC     DE
        DJNZ    CHRI        
        
        LD      BC, $0000
CP:     CALL    CALC_PLOT
        XOR     (HL)
        LD      (HL), A
        INC     BC
        LD      A, B
        CP      $C0
        JR      NZ, CP
        JR      CLRQ

; -----------------------------------
CALC_PLOT:

        LD      A, C
        AND     $07
        XOR     $07
        ADD     $40
        LD      H, 0
        LD      L, A
        LD      A, (HL)
        EX      AF, AF'        
        LD      A, B
        AND     $07
        LD      H, A
        LD      A, B
        AND     $38
        ADD     A
        ADD     A
        LD      L, A
        LD      A, C
        SRL     A
        SRL     A
        SRL     A
        OR      L
        LD      L, A
        LD      A, B
        AND     $C0
        SRL     A
        SRL     A
        SRL     A
        OR      H
        OR      $40
        LD      H, A
        EX      AF, AF'
        RET
        