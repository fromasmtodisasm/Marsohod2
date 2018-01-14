
        LD      HL, $4000
CYCLE:  LD      A, H
        CP      $5B
        JR      Z, ROT
        CP      $58
        LD      A, $01
        JR      C, BELOW    
        LD      A, $38       
BELOW:  LD      (HL), A
        INC     HL
        JR      CYCLE          
ROT:    LD      HL, $4000
CYCLE2: LD      A, H
        CP      $58
        JR      Z, ROT
        RRC     (HL)
        LD      A, L
        OUT     ($FE),A
        INC     HL
        JR      CYCLE2

        
