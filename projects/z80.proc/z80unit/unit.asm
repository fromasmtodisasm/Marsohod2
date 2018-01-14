
        LD      HL, $4000
CYCLE:
        LD      A, H
        CP      $5B
        JR      Z, EXIT
        
        CP      $58
        LD      A, $00
        JR      C, BELOW    
        LD      A, $38
        
BELOW:  LD      (HL), A
        INC     HL
        JR      CYCLE
        
EXIT:
        JR      EXIT
        
