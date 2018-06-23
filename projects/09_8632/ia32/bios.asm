
        org     0
        
        not     edx
        neg     bx
        mul     al
        imul    ah
        div     si
        idiv    ebp
        test    ebx, $44555512
        cmp     bx, $4123
        cmp     esp, $46633123
        and     bl, -1
        and     cx, -1
        and     edx, -4
        
        test    al, 13
k:  
