
        org     0
        inc     byte [bx + si]
        dec     word [$0022]
        call    word [bx]
        call    eax
        call    dword [bx]
        jmp     bx
        jmp     ebx
        jmp     dword [bx]
        push    word [bx]
        push    dword [bx]
