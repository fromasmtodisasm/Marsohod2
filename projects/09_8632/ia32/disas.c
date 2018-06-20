/*
 * Дизассемблер
 */
 
// Список мнемоник, используюстя в ops
const char* mnemonics[] = {
  
    /* 00 */ "add",     /* 01 */ "or",      /* 02 */ "adc",     /* 03 */ "sbb",
    /* 04 */ "and",     /* 05 */ "sub",     /* 06 */ "xor",     /* 07 */ "cmp",
    /* 08 */ "es:",     /* 09 */ "cs:",     /* 0A */ "ss:",     /* 0B */ "ds:",
    /* 0C */ "fs:",     /* 0D */ "gs:",     /* 0E */ "push",    /* 0F */ "pop",

    /* 10 */ "DAA",     /* 11 */ "DAS",     /* 12 */ "AAA",     /* 13 */ "AAS",
    /* 14 */ "INC",     /* 15 */ "DEC",     /* 16 */ "PUSHA",   /* 17 */ "POPA",
    /* 18 */ "BOUND",   /* 19 */ "ARPL",    /* 1A */ "IMUL",    /* 1B */ "INS",
    /* 1C */ "OUTS",    /* 1D */ "TEST",    /* 1E */ "XCHG",    /* 1F */ "LEA",

    /* 20 */ "JO",      /* 21 */ "JNO",     /* 22 */ "JB",      /* 23 */ "JNB",
    /* 24 */ "JZ",      /* 25 */ "JNZ",     /* 26 */ "JBE",     /* 27 */ "JNBE",
    /* 28 */ "JS",      /* 29 */ "JNS",     /* 2A */ "JP",      /* 2B */ "JNP",
    /* 2C */ "JL",      /* 2D */ "JNL",     /* 2E */ "JLE",     /* 2F */ "JNLE"    
    
    /* 30 */ "MOV",     /* 31 */ "NOP",     /* 32 */ "CBW",     /* 33 */ "CWD",    
    /* 34 */ "CWDE",    /* 35 */ "CDQ",     /* 36 */ "CALLF",   /* 37 */ "FWAIT",
    /* 38 */ "PUSHF",   /* 39 */ "POPF",    /* 3A */ "SAHF",    /* 3B */ "LAHF",
    /* 3C */ "MOVS",    /* 3D */ "CMPS",    /* 3E */ "STOS",    /* 3F */ "LODS",
    
    /* 40 */ "SCAS",    /* 41 */ "RET",     /* 42 */ "RETF",    /* 43 */ "LES",
    /* 44 */ "LDS",     /* 45 */ "LFS",     /* 46 */ "LGS",     /* 47 */ "ENTER",
    /* 48 */ "LEAVE",   /* 49 */ "INT",     /* 4A */ "INT1",    /* 4B */ "INT3",
    /* 4C */ "INTO",    /* 4D */ "IRET",    /* 4E */ "AAM",     /* 4F */ "AAD",
    
    /* 50 */ "SALC",    /* 51 */ "XLATB",   /* 52 */ "LOOPNZ",  /* 53 */ "LOOPZ",
    /* 54 */ "LOOP",    /* 55 */ "JCXZ",    /* 56 */ "IN",      /* 57 */ "OUT",
    /* 58 */ "CALL",    /* 59 */ "JMP",     /* 5A */ "JMPF",    /* 5B */ "LOCK:",
    /* 5C */ "REPNZ:",  /* 5D */ "REPZ:",   /* 5E */ "HLT",     /* 5F */ "CMC",
    
    /* 60 */ "CLC",     /* 61 */ "STC",     /* 62 */ "CLI",     /* 63 */ "STI",
    /* 64 */ "CLD",     /* 65 */ "STD",     /* 66 */ "ROL",     /* 67 */ "ROR",
    /* 68 */ "RCL",     /* 69 */ "RCR",     /* 6A */ "SHL",     /* 6B */ "SHR",
    /* 6C */ "SAL",     /* 6D */ "SAR",     /* 6E */ "NOT",     /* 6F */ "NEG",
    
    /* 70 */ "MUL",     /* 71 */ "DIV",     /* 72 */ "IDIV",    /* 73 */ "REP:",        
    /* 74 */ "",        /* 75 */ "",        /* 76 */ "",        /* 77 */ "",
    /* 78 */ "",        /* 79 */ "",        /* 7A */ "",        /* 7B */ "",
    /* 7C */ "",        /* 7D */ "",        /* 7E */ "",        /* 7F */ "",    
};
 
const int ops[512] = {
    
    /* Основной набор */
    /* 00 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0E, 0x0F,
    /* 08 */ 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x0E, 0xFF,
    /* 10 */ 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x0E, 0x0F,
    /* 18 */ 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x0E, 0x0F,
    /* 20 */ 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x10,
    /* 28 */ 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x09, 0x11,
    /* 30 */ 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x0A, 0x12,
    /* 38 */ 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x0B, 0x13,    
    /* 40 */ 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
    /* 48 */ 0x15, 0x15, 0x15, 0x15, 0x15, 0x15, 0x15, 0x15,
    /* 50 */ 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E,
    /* 58 */ 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    /* 60 */ 0x16, 0x17, 0x18, 0x19, 0x0C, 0x0D, 0xFF, 0xFF,
    /* 68 */ 0x0E, 0x1A, 0x0E, 0x1A, 0x1B, 0x1B, 0x1C, 0x1C,    
    /* 70 */ 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
    /* 78 */ 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
    /* 80 */ 0xFF, 0xFF, 0xFF, 0xFF, 0x1D, 0x1D, 0x1E, 0x1E,
    /* 88 */ 0x30, 0x30, 0x30, 0x30, 0x30, 0x1F, 0x30, 0x0F,
    /* 90 */ 0x31, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E,    
    /* 98 */ 0x32, 0x33, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B,    
    /* A0 */ 0x30, 0x30, 0x30, 0x30, 0x3C, 0x3C, 0x3D, 0x3D,
    /* A8 */ 0x1D, 0x1D, 0x3E, 0x3E, 0x3F, 0x3F, 0x40, 0x40,
    /* B0 */ 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
    /* B8 */ 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
    /* C0 */ 0xFF, 0xFF, 0x41, 0x41, 0x43, 0x44, 0x30, 0x30,
    /* C8 */ 0x47, 0x48, 0x42, 0x42, 0x4B, 0x49, 0x4C, 0x4D,
    /* D0 */ 0xFF, 0xFF, 0xFF, 0xFF, 0x4E, 0x4F, 0x50, 0x51,
    /* D8 */ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    /* E0 */ 0x52, 0x53, 0x54, 0x55, 0x56, 0x56, 0x57, 0x57,
    /* E8 */ 0x58, 0x59, 0x5A, 0x59, 0x56, 0x56, 0x57, 0x57,
    /* F0 */ 0x5B, 0x4A, 0x5C, 0x5D, 0x5E, 0x5F, 0xFF, 0xFF,
    /* F8 */ 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0xFF, 0xFF,
    
    /* Дополнительный набор */
    /* 00 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 08 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 10 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 18 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 20 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 28 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 30 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 38 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 40 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 48 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 50 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 58 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 60 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 68 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 70 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 78 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 80 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 88 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 90 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 98 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* A0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* A8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* B0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* B8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* C0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* C8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* D0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* D8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* E0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* E8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* F0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* F8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    
};

const char* regnames[] = {
    
    /* 00 */ "al",  "cl",  "dl",  "bl",  "ah",  "ch",  "dh",  "bh",
    /* 08 */ "ax",  "cx",  "dx",  "bx",  "sp",  "bp",  "si",  "di",
    /* 10 */ "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi",
    /* 18 */ "es",  "cs",  "ds",  "ss",  "fs",  "gs",  "",    ""    

};

const char* rm16names[] = {
    
    /* 0 */ "bx+si",
    /* 1 */ "bx+di",
    /* 2 */ "bp+si",
    /* 3 */ "bp+di",
    /* 4 */ "si",
    /* 5 */ "di",
    /* 6 */ "bp",
    /* 7 */ "bx"
    
};

char tmps[256];
char dis_row[256];
int  dis_visline;

char dis_rg[32];        /* Rm-часть Modrm */
char dis_rm[32];        /* Rm-часть Modrm */
char dis_px[32];        /* Префикс */

void init_disas() {
    dis_visline = 0;    
}

/* Дизассемблирование одной инструкции */
// ---------------------------------------------------------------------

// reg32 - расширение регистра, mem32 - метода адресации
// reg32 = 0x08 8 бит           mem32 = 0x00 16 бит
//       = 0x10 16 бит                = 0x20 32 бит
//       = 0x20 32 бит

int disas_modrm(Uint32 address, int reg32, int mem32) {
    
    int n = 0, b, w, reg, mod, rm;
    
    /* Очистка */
    dis_rg[0] = 0;
    dis_rm[0] = 0;
    
    // 16 бит
    if (mem32 == 0) {
        
        b = readb(address++); 
        n++;
        
        rm  = (b & 0x07);
        reg = (b & 0x38) >> 3;
        mod = (b & 0xc0);
        
        /* Печать регистра 8/16/32 */        
        switch (reg32) {
            case 0x08: sprintf(dis_rg, "%s", regnames[ reg ]); break;
            case 0x10: sprintf(dis_rg, "%s", regnames[ reg + 0x08 ]); break;
            case 0x20: sprintf(dis_rg, "%s", regnames[ reg + 0x10 ]); break;
            default:   sprintf(dis_rg, "<unknown>"); break;
        }
                
        /* Rm-часть */
        switch (mod) {
            
            /* Индекс без disp или disp16 */
            case 0x00: 
            
                if (rm == 6) {
                    w = readw(address); address += 2; n += 2;
                    sprintf(dis_rm, "[%04x]", w);
                } else {
                    sprintf(dis_rm, "[%s]", rm16names[ rm ]);
                }
                
                break;

            /* + disp8 */  
            case 0x40: 
            
                b = readb(address++); n++;
                if (b & 0x80) {
                    sprintf(dis_rm, "[%s-%02x]", rm16names[ rm ], (0xff ^ b) + 1);
                } else {
                    sprintf(dis_rm, "[%s+%02x]", rm16names[ rm ], b);            
                }
                
                break;

            /* + disp16 */
            case 0x80: 
            
                w = readw(address); address += 2; n += 2;
                if (w & 0x8000) {
                    sprintf(dis_rm, "[%s-%04x]", rm16names[ rm ], (0xFFFF ^ w) + 1); 
                } else {
                    sprintf(dis_rm, "[%s+%04x]", rm16names[ rm ], w); 
                }
                
                break;

            /* Регистровая часть */
            case 0xc0: 
            
                switch (reg32) {
                    case 0x08: sprintf(dis_rm, "%s", regnames[ rm ]); break;
                    case 0x10: sprintf(dis_rm, "%s", regnames[ rm + 0x08 ]); break;
                    case 0x20: sprintf(dis_rm, "%s", regnames[ rm + 0x10 ]); break;
                }

                break;        
        }    
    } 
    // 32 бит
    else {
        
        // todo
        
    }    
    
    return n;
}

/* Дизассемблер полной строки */
int disas(Uint32 address) {


RAM[0] = 0x87;
RAM[1] = 0x00;
RAM[2] = 0x80;

    // Если есть modrm
    disas_modrm(address, 16, 0); 
    
    dis_px[0] = 0;    
    // sprintf(dis_px, "%s", "ds:");
    
    
    sprintf(dis_row, "00000000 0000             add     %s%s, %s", dis_px, dis_rm, dis_rg);    
    return 0;
} 
// ---------------------------------------------------------------------

/* Вывод общего дизассемблера */
void update() {
    
    int i;
    linebf(0, 16,  1280, 783, dac[3]); // Общий фон
    
    linebf(0, 0,   1280, 15,  dac[7]); // Верхняя строка
    print(0, 0, "  \xF0  File  Edit  View  Run  Breakpoints  Data  Options  Window  Help", 0);
    print(0, 0, "  \xF0  F     E     V     R    B            D     O        W       H   ", dac[4]);

    linebf(0, 784, 1280, 799, dac[7]); // Нижняя строка
    print(0, 784, "F1-Help F2-Bkpt F3-Mod F4-Here F5-Zoom F6-Next F7-Trace F8-Step F9-Run F10-Menu", 0);
    print(0, 784, "F1      F2      F3     F4      F5      F6      F7       F8      F9     F10", dac[4]);
        
    // Обрамления
    // ------------------------------
    print_char(0, 16, 0xc9, dac[15] );    print_char(0,    16*48, 0xc8, dac[15] );
    print_char(8*62, 16, 0xd1, dac[15] ); print_char(8*62, 16*48, 0xcf, dac[15] );
    print_char(8*75, 16, 0xd1, dac[15] ); print_char(8*75, 16*48, 0xcf, dac[15] ); 
    print_char(8*79, 16, 0xbb, dac[15] ); print_char(8*79, 16*48, 0xbc, dac[15] );
    
    for (i = 1; i < 79; i++) {        
        
        if (i == 62 || i == 75) continue;
        
        print_char(8*i, 16, 0xcd, dac[15] );
        print_char(8*i, 16*48, 0xcd, dac[15] );
    }
    
    // Вертикальные линии
    for (i = 2; i < 48; i++) {        
        
        print_char(0,    16*i, 0xba, dac[15] );
        print_char(62*8, 16*i, 0xb3, dac[15] );
        if (i < 18) print_char(75*8, 16*i, 0xb3, dac[15] );
        print_char(79*8, 16*i, 0xba, dac[15] );
    }
    
    // Сделать строку перемотки
    //if (i > 2 && i < 47)
    //print_char(62*8, 16*i, 0xb1, dac[1] );
    // ------------------------------

    /* Вывод флагов */
    print(76*8, 16*2, eflags & 0x001 ? "c=1" : "c=0", dac[0]);
    print(76*8, 16*3, eflags & 0x040 ? "z=1" : "z=0", dac[0]);
    print(76*8, 16*4, eflags & 0x080 ? "s=1" : "s=0", dac[0]);
    print(76*8, 16*5, eflags & 0x800 ? "o=1" : "o=0", dac[0]);
    print(76*8, 16*6, eflags & 0x004 ? "p=1" : "p=0", dac[0]);
    print(76*8, 16*7, eflags & 0x010 ? "a=1" : "a=0", dac[0]);
    print(76*8, 16*8, eflags & 0x200 ? "i=1" : "i=0", dac[0]);
    print(76*8, 16*9, eflags & 0x400 ? "d=1" : "d=0", dac[0]);        
    print(76*8, 16*10, eflags & 0x100 ? "t=1" : "t=0", dac[0]);   
    
    /* Вывод регистров */
    sprintf(tmps, "eax %08x", eax); print(63*8, 16*2, tmps, dac[0]);     
    sprintf(tmps, "ebx %08x", ebx); print(63*8, 16*3, tmps, dac[0]);     
    sprintf(tmps, "ecx %08x", ecx); print(63*8, 16*4, tmps, dac[0]);     
    sprintf(tmps, "edx %08x", edx); print(63*8, 16*5, tmps, dac[0]);     
    sprintf(tmps, "esp %08x", esp); print(63*8, 16*6, tmps, dac[0]);     
    sprintf(tmps, "ebp %08x", ebp); print(63*8, 16*7, tmps, dac[0]);     
    sprintf(tmps, "esi %08x", esi); print(63*8, 16*8, tmps, dac[0]);     
    sprintf(tmps, "edi %08x", edi); print(63*8, 16*9, tmps, dac[0]);     
    sprintf(tmps, "eip %08x", eip); print(63*8, 16*10, tmps, dac[0]);     
    
    /* Сегментные */
    sprintf(tmps, " es %04x", es); print(63*8, 16*12, tmps, dac[0]);     
    sprintf(tmps, " cs %04x", cs); print(63*8, 16*13, tmps, dac[0]);     
    sprintf(tmps, " ds %04x", ds); print(63*8, 16*14, tmps, dac[0]);     
    sprintf(tmps, " ss %04x", ss); print(63*8, 16*15, tmps, dac[0]);     
    sprintf(tmps, " fs %04x", fs); print(63*8, 16*16, tmps, dac[0]);     
    sprintf(tmps, " gs %04x", gs); print(63*8, 16*17, tmps, dac[0]);     
    
    /* Вывод отладчика */
    for (i = 0; i < 46; i++) {

        int dis_color = dac[0];
        
        /* Текущая линия выбрана */
        if (dis_visline == i) {
            
            linebf(8*1, 16*(i + 2), 8*62 - 1, 16*(i + 2) + 15, dac[1]);
            dis_color = dac[15];
            
        }
        
        disas(0); print(16, 16*(i + 2), dis_row, dis_color);        
    }
    
    SDL_Flip(sdl_screen);
}
