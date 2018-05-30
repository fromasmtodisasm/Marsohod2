#include <stdlib.h>
#include <stdio.h>
#include "display.h"
#include "cpu.h"

#define INCRADDR            addr = (addr + 1) & 0xffff
#define SET_ZERO(x)         reg_P =  x         ? (reg_P & 0xFD) : (reg_P | 0x02)
#define SET_SIGN(x)         reg_P = (x & 0x80) ? (reg_P | 0x80) : (reg_P & 0x7F)
#define SET_OVERFLOW(x)     reg_P = x          ? (reg_P | 0x40) : (reg_P & 0xBF)
#define SET_CARRY(x)        reg_P = x          ? (reg_P | 0x01) : (reg_P & 0xFE)
#define SET_DECIMAL(x)      reg_P = x          ? (reg_P | 0x08) : (reg_P & 0xF7)
#define SET_BREAK(x)        reg_P = x          ? (reg_P | 0x10) : (reg_P & 0xEF)
#define SET_INTERRUPT(x)    reg_P = x          ? (reg_P | 0x04) : (reg_P & 0xFB)

#define IF_CARRY            (reg_P & 0x01 ? 1 : 0)
#define IF_ZERO             (reg_P & 0x02 ? 1 : 0)
#define IF_OVERFLOW         (reg_P & 0x40 ? 1 : 0)
#define IF_SIGN             (reg_P & 0x80 ? 1 : 0)

#define PUSH(x)             writeB(0x100 + reg_S, x & 0xff); reg_S = (reg_S - 1) & 0xff

// Текущий видео курсор
int video_cursor = 0x0000;

// Типы операндов для каждого опкода
unsigned char operandTypes[256] = {

    /*       00   01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F */
    /* 00 */ IMP, NDX, ___, ___, ___, ZP , ZP , ___, IMP, IMM, ACC, ___, ___, ABS, ABS, ___,
    /* 10 */ REL, NDY, ___, ___, ___, ZPX, ZPX, ___, IMP, ABY, ___, ___, ___, ABX, ABX, ___,
    /* 20 */ ABS, NDX, ___, ___, ZP , ZP , ZP , ___, IMP, IMM, ACC, ___, ABS, ABS, ABS, ___,
    /* 30 */ REL, NDY, ___, ___, ___, ZPX, ZPX, ___, IMP, ABY, ___, ___, ___, ABX, ABX, ___,
    /* 40 */ IMP, NDX, ___, ___, ___, ZP , ZP , ___, IMP, IMM, ACC, ___, ABS, ABS, ABS, ___,
    /* 50 */ REL, NDY, ___, ___, ___, ZPX, ZPX, ___, IMP, ABY, ___, ___, ___, ABX, ABX, ___,
    /* 60 */ IMP, NDX, ___, ___, ___, ZP , ZP , ___, IMP, IMM, ACC, ___, IND, ABS, ABS, ___,
    /* 70 */ REL, NDY, ___, ___, ___, ZPX, ZPX, ___, IMP, ABY, ___, ___, ___, ABX, ABX, ___,
    /* 80 */ ___, NDX, ___, ___, ZP , ZP , ZP , ___, IMP, ___, IMP, ___, ABS, ABS, ABS, ___,
    /* 90 */ REL, NDY, ___, ___, ZPX, ZPX, ZPY, ___, IMP, ABY, IMP, ___, ___, ABX, ___, ___,
    /* A0 */ IMM, NDX, IMM, ___, ZP , ZP , ZP , ___, IMP, IMM, IMP, ___, ABS, ABS, ABS, ___,
    /* B0 */ REL, NDY, ___, ___, ZPX, ZPX, ZPY, ___, IMP, ABY, IMP, ___, ABX, ABX, ABX, ___,
    /* C0 */ IMM, NDX, ___, ___, ZP , ZP , ZP , ___, IMP, IMM, IMP, ___, ABS, ABS, ABS, ___,
    /* D0 */ REL, NDY, ___, ___, ___, ZPX, ZPX, ___, IMP, ABY, ___, ___, ___, ABX, ABX, ___,
    /* E0 */ IMM, NDX, ___, ___, ZP , ZP , ZP , ___, IMP, IMM, IMP, ___, ABS, ABS, ABS, ___,
    /* F0 */ REL, NDY, ___, ___, ___, ZPX, ZPX, ___, IMP, ABY, ___, ___, ___, ABX, ABX, ___

};

int operandNames[256] = {

    /*        00  01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F */
    /* 00 */ BRK, ORA, ___, ___, ___, ORA, ASL, ___, PHP, ORA, ASL, ___, ___, ORA, ASL, ___,
    /* 10 */ BPL, ORA, ___, ___, ___, ORA, ASL, ___, CLC, ORA, ___, ___, ___, ORA, ASL, ___,
    /* 20 */ JSR, AND, ___, ___, BIT, AND, ROL, ___, PLP, AND, ROL, ___, BIT, AND, ROL, ___,
    /* 30 */ BMI, AND, ___, ___, ___, AND, ROL, ___, SEC, AND, ___, ___, ___, AND, ROL, ___,
    /* 40 */ RTI, EOR, ___, ___, ___, EOR, LSR, ___, PHA, EOR, LSR, ___, JMP, EOR, LSR, ___,
    /* 50 */ BVC, EOR, ___, ___, ___, EOR, LSR, ___, CLI, EOR, ___, ___, ___, EOR, LSR, ___,
    /* 60 */ RTS, ADC, ___, ___, ___, ADC, ROR, ___, PLA, ADC, ROR, ___, JMP, ADC, ROR, ___,
    /* 70 */ BVS, ADC, ___, ___, ___, ADC, ROR, ___, SEI, ADC, ___, ___, ___, ADC, ROR, ___,
    /* 80 */ ___, STA, ___, ___, STY, STA, STX, ___, DEY, ___, TXA, ___, STY, STA, STX, ___,
    /* 90 */ BCC, STA, ___, ___, STY, STA, STX, ___, TYA, STA, TXS, ___, ___, STA, ___, ___,
    /* A0 */ LDY, LDA, LDX, ___, LDY, LDA, LDX, ___, TAY, LDA, TAX, ___, LDY, LDA, LDX, ___,
    /* B0 */ BCS, LDA, ___, ___, LDY, LDA, LDX, ___, CLV, LDA, TSX, ___, LDY, LDA, LDX, ___,
    /* C0 */ CPY, CMP, ___, ___, CPY, CMP, DEC, ___, INY, CMP, DEX, ___, CPY, CMP, DEC, ___,
    /* D0 */ BNE, CMP, ___, ___, ___, CMP, DEC, ___, CLD, CMP, ___, ___, ___, CMP, DEC, ___,
    /* E0 */ CPX, SBC, ___, ___, CPX, SBC, INC, ___, INX, SBC, NOP, ___, CPX, SBC, INC, ___,
    /* F0 */ BEQ, SBC, ___, ___, ___, SBC, INC, ___, SED, SBC, ___, ___, ___, SBC, INC, ___,

};

char* operandNamesString[57] = {

    "???",   //  0
    "BRK",   //  1
    "ORA",   //  2
    "AND",   //  3
    "EOR",   //  4
    "ADC",   //  5
    "STA",   //  6
    "LDA",   //  7
    "CMP",   //  8
    "SBC",   //  9
    "BPL",   // 10
    "BMI",   // 11
    "BVC",   // 12
    "BVS",   // 13
    "BCC",   // 14
    "BCS",   // 15
    "BNE",   // 16
    "BEQ",   // 17
    "JSR",   // 18
    "RTI",   // 19
    "RTS",   // 20
    "LDY",   // 21
    "CPY",   // 22
    "CPX",   // 23
    "ASL",   // 24
    "PHP",   // 25
    "CLC",   // 26
    "BIT",   // 27
    "ROL",   // 28
    "PLP",   // 29
    "SEC",   // 30
    "LSR",   // 31
    "PHA",   // 32
    "PLA",   // 33
    "JMP",   // 34
    "CLI",   // 35
    "ROR",   // 36
    "SEI",   // 37
    "STY",   // 38
    "STX",   // 39
    "DEY",   // 40
    "TXA",   // 41
    "TYA",   // 42
    "TXS",   // 43
    "LDX",   // 44
    "TAY",   // 45
    "TAX",   // 46
    "CLV",   // 47
    "TSX",   // 48
    "DEC",   // 49
    "INY",   // 50
    "DEX",   // 51
    "CLD",   // 52
    "INC",   // 53
    "INX",   // 54
    "NOP",   // 55
    "SED",   // 56
};

void initCPU() {

    int i;

    reg_A  = 0x41;
    reg_X  = 0x11;
    reg_Y  = 0x00;
    reg_S  = 0xFF;
    reg_P  = 0x01;
    reg_PC = 0xC000;

    deb_top  = reg_PC;
    deb_addr = reg_PC;
    deb_bottom = -1;
    dump_mode = DUMP_ZP;
    zp_base = 0;
    cpu_running = 0;

    for (i = 0; i < 64; i++) {
        debAddr[i] = 0;
    }

    breakpointsMax = 0;
    for (i = 0; i < 256; i++) {
        breakpoints[i] = -1;
    }
    
    // ---
    //breakpointsMax = 1;
    //breakpoints[0] = 0xC240;
}

// Извлечение из стека
unsigned char PULL() {

    reg_S = (reg_S + 1) & 0xff;
    return readB(0x100 + reg_S);
}

// Чтение байта из памяти
unsigned char readB(int addr) {
    
    int tmp, olddat;
    
    if (addr >= 0x2000 && addr < 0x3F00) {
        
        switch (addr & 7) {
            
            case 2: 

                /* Предыдущее значение */
                tmp = ppu_status;

                /* Сброс при чтении */
                ppu_status = ppu_status & 0b00111111;            
                
                return tmp;
            
            /* Чтение из видеопамяти (кроме STA) */
            case 7:
            
                olddat = objvar;
                objvar = sram[ 0x10000 + video_cursor ];
                video_cursor += (ctrl0 & 0x04 ? 32 : 1);
                
                return olddat;
        }            
    }
    
    return sram[ addr & 0xffff ];
}

// Чтение слова из памяти
unsigned int readW(int addr) {
    return readB(addr) + 256 * readB(addr + 1);
}

// Запись байта в память
void writeB(int addr, unsigned char data) {
    
    if (addr >= 0x2000 && addr <= 0x3FFF) {
        
        switch (addr & 7) {
            
            case 0: ctrl0 = data; break;
            case 1: ctrl1 = data; break;
            // 2
            case 3: spraddr = data; break;
            case 4: sprite[ spraddr ] = data; spraddr = (spraddr + 1) & 0xff; break;
            case 5: 
            
                video_scroll = ((video_cursor << 8) | data) & 0xffff;
                break;
            
            case 6: // Запись адреса курсора в память
            
                video_cursor = ((video_cursor << 8) | data) & 0xffff;
                break;            
            
            case 7: // Запись данных в видеопамять

                sram[ 0x10000 + video_cursor ] = data;            
                video_cursor += (ctrl0 & 0x04 ? 32 : 1);
                break;
        }
        
        
    } else {        
        sram[ addr & 0xffff ] = data;
    }
}

// По адресу, определить эффективный адрес (если он есть)
unsigned int getEffectiveAddress(int addr) {

    int opcode, src, iaddr;

    opcode  = readB(addr);
    INCRADDR;

    switch (operandTypes[ opcode ]) {

        /* Indirect, X (b8,X) */
        case NDX: return readW( (readB(addr) + reg_X) & 0x00ff );

        /* Indirect, Y (b8),Y */
        case NDY: return (readW( readB(addr) ) + reg_Y) & 0xffff;

        /* Zero Page */
        case ZP:  return readB(addr);

        /* Zero Page, X */
        case ZPX: return (readB(addr) + reg_X) & 0x00ff;

        /* Zero Page, Y */
        case ZPY: return (readB(addr) + reg_Y) & 0x00ff;

        /* Absolute */
        case ABS: return readW(addr);

        /* Absolute, X */
        case ABX: return (readW(addr) + reg_X) & 0xffff;

        /* Absolute, Y */
        case ABY: return (readW(addr) + reg_Y) & 0xffff;

        /* Indirect */
        case IND: return readW( readW(addr) );

        /* Relative */
        case REL:

            iaddr = readB(addr);
            return (iaddr + addr + 1 + (iaddr < 128 ? 0 : -256)) & 0xffff;
    }

    return -1;
}

// Исполнение инструкции
void exec() {

    int temp, optype, opname, ppurd = 1;
    int addr = reg_PC, opcode, src;

    // Определение эффективного адреса
    int iaddr = getEffectiveAddress(addr);

    opcode = readB(addr);
    optype = operandTypes[ opcode ];
    opname = operandNames[ opcode ];
    
    if (opname == STA || opname == STX || opname == STY) {
        ppurd = 0;
    }

    INCRADDR;

    // Тип операнда
    switch (optype) {

        case NDX: /* Indirect X (b8,X) */
        case NDY: /* Indirect, Y */
        case ZP:  /* Zero Page */
        case ZPX: /* Zero Page, X */
        case ZPY: /* Zero Page, Y */
        case REL: /* Relative */

            INCRADDR;
            if (ppurd) src = readB( iaddr );
            break;

        case ABS: /* Absolute */
        case ABX: /* Absolute, X */
        case ABY: /* Absolute, Y */
        case IND: /* Indirect */

            INCRADDR;
            INCRADDR;
            if (ppurd) src = readB( iaddr );
            break;

        case IMM: /* Immediate */

            if (ppurd) src = readB(addr);
            INCRADDR;
            break;

        case ACC: /* Accumulator source */

            src = reg_A;
            break;
    }

    /* Разбор инструкции и исполнение */
    switch (opname) {

        /* Сложение с учетом переноса */
        case ADC: {

            temp = src + reg_A + (reg_P & 1);
            SET_ZERO(temp & 0xff);
            SET_SIGN(temp);
            SET_OVERFLOW(((reg_A ^ src ^ 0x80) & 0x80) && ((reg_A ^ temp) & 0x80) );
            SET_CARRY(temp > 0xff);
            reg_A = temp & 0xff;
            break;
        }

        /* Логическое умножение */
        case AND: {

            src &= reg_A;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = src;
            break;
        }

        /* Логический сдвиг вправо */
        case ASL: {

            SET_CARRY(src & 0x80);
            src <<= 1;
            src &= 0xff;
            SET_SIGN(src);
            SET_ZERO(src);

            if (optype == ACC) reg_A = src; else writeB(iaddr, src);
            break;
        }

        /* Переход если CF=0 */
        case BCC: if (!IF_CARRY) addr = iaddr; break;

        /* Переход если CF=1 */
        case BCS: if ( IF_CARRY) addr = iaddr; break;

        /* Переход если ZF=0 */
        case BNE: if (!IF_ZERO) addr = iaddr; break;

        /* Переход если ZF=1 */
        case BEQ: if ( IF_ZERO) addr = iaddr; break;

        /* Переход если NF=0 */
        case BPL: if (!IF_SIGN) addr = iaddr; break;

        /* Переход если NF=1 */
        case BMI: if ( IF_SIGN) addr = iaddr; break;

        /* Переход если NF=0 */
        case BVC: if (!IF_OVERFLOW) addr = iaddr; break;

        /* Переход если NF=1 */
        case BVS: if ( IF_OVERFLOW) addr = iaddr; break;

        /* Копированиь бит 6 в OVERFLOW флаг. */
        case BIT: {

            SET_SIGN(src);
            SET_OVERFLOW(0x40 & src);
            SET_ZERO(src & reg_A);
            break;
        }

        /* Программное прерывание */
        case BRK: {

            reg_PC = (reg_PC + 1) & 0xffff;
            PUSH((reg_PC >> 8) & 0xff);	     /* Вставка обратного адреса в стек */
            PUSH(reg_PC & 0xff);
            SET_BREAK(1);                    /* Установить BFlag перед вставкой */
            PUSH(reg_P);
            SET_INTERRUPT(1);
            addr = readW(0xFFFE);
            break;
        }

        /* Флаги */
        case CLC: SET_CARRY(0); break;
        case SEC: SET_CARRY(1); break;
        case CLD: SET_DECIMAL(0); break;
        case SED: SET_DECIMAL(1); break;
        case CLI: SET_INTERRUPT(0); break;
        case SEI: SET_INTERRUPT(1); break;
        case CLV: SET_OVERFLOW(0); break;

        /* Сравнение A, X, Y с операндом */
        case CMP:
        case CPX:
        case CPY: {

            src = (opname == CMP ? reg_A : (opname == CPX ? reg_X : reg_Y)) - src;
            SET_CARRY(src >= 0);
            SET_SIGN(src);
            SET_ZERO(src & 0xff);
            break;
        }

        /* Уменьшение операнда на единицу */
        case DEC: {

            src = (src - 1) & 0xff;
            SET_SIGN(src);
            SET_ZERO(src);
            writeB(iaddr, src);
            break;
        }

        /* Уменьшение X на единицу */
        case DEX: {

            reg_X = (reg_X - 1) & 0xff;
            SET_SIGN(reg_X);
            SET_ZERO(reg_X);
            break;
        }

        /* Уменьшение Y на единицу */
        case DEY: {

            reg_Y = (reg_Y - 1) & 0xff;
            SET_SIGN(reg_Y);
            SET_ZERO(reg_Y);
            break;
        }

        /* Исключающее ИЛИ */
        case EOR: {

            src ^= reg_A;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = src;
            break;
        }

        /* Увеличение операнда на единицу */
        case INC: {

            src = (src + 1) & 0xff;
            SET_SIGN(src);
            SET_ZERO(src);
            writeB(iaddr, src);
            break;
        }

        /* Уменьшение X на единицу */
        case INX: {

            reg_X = (reg_X + 1) & 0xff;
            SET_SIGN(reg_X);
            SET_ZERO(reg_X);
            break;
        }

        /* Уменьшение Y на единицу */
        case INY: {

            reg_Y = (reg_Y + 1) & 0xff;
            SET_SIGN(reg_Y);
            SET_ZERO(reg_Y);
            break;
        }

        /* Переход по адресу */
        case JMP: addr = iaddr; break;

        /* Вызов подпрограммы */
        case JSR: {

            addr = (addr - 1) & 0xffff;
            PUSH((addr >> 8) & 0xff);	/* Вставка обратного адреса в стек (-1) */
            PUSH(addr & 0xff);
            addr = iaddr;
            break;
        }

        /* Загрузка операнда в аккумулятор */
        case LDA: {

            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = (src);
            break;
        }

        /* Загрузка операнда в X */
        case LDX: {

            SET_SIGN(src);
            SET_ZERO(src);
            reg_X = (src);
            break;
        }

        /* Загрузка операнда в Y */
        case LDY: {

            SET_SIGN(src);
            SET_ZERO(src);
            reg_Y = (src);
            break;
        }

        /* Логический сдвиг вправо */
        case LSR: {

            SET_CARRY(src & 0x01);
            src >>= 1;
            SET_SIGN(src);
            SET_ZERO(src);
            if (optype == ACC) reg_A = src; else writeB(iaddr, src);
            break;
        }

        /* Логическое побитовое ИЛИ */
        case ORA: {

            src |= reg_A;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = src;
            break;
        }

        /* Стек */
        case PHA: PUSH(reg_A); break;
        case PHP: PUSH(reg_P); break;
        case PLP: reg_P = PULL(); break;

        /* Извлечение из стека в A */
        case PLA: {

            src = PULL();
            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = src;
            break;
        }

        /* Циклический сдвиг влево */
        case ROL: {

            src <<= 1;
            if (IF_CARRY) src |= 0x1;
            SET_CARRY(src > 0xff);
            src &= 0xff;
            SET_SIGN(src);
            SET_ZERO(src);
            if (optype == ACC) reg_A = src; else writeB(iaddr, src);
            break;
        }

        /* Циклический сдвиг вправо */
        case ROR: {

            if (IF_CARRY) src |= 0x100;
            SET_CARRY(src & 0x01);
            src >>= 1;
            SET_SIGN(src);
            SET_ZERO(src);
            if (optype == ACC) reg_A = src; else writeB(iaddr, src);
            break;
        }

        /* Возврат из прерывания */
        case RTI: {

            reg_P = PULL();
            src   = PULL();
            src  |= (PULL() << 8);
            addr  = src;
            break;
        }

        /* Возврат из подпрограммы */
        case RTS: {

            src  = PULL();
            src += ((PULL()) << 8) + 1;
            addr = (src);
            break;
        }

        /* Вычитание */
        case SBC: {

            temp = reg_A - src - (IF_CARRY ? 0 : 1);

            SET_SIGN(temp);
            SET_ZERO(temp & 0xff);
            SET_OVERFLOW(((reg_A ^ temp) & 0x80) && ((reg_A ^ src) & 0x80));
            SET_CARRY(temp >= 0);
            reg_A = (temp & 0xff);
            break;
        }

        /* Запись содержимого A,X,Y в память */
        case STA: writeB(iaddr, reg_A); break;
        case STX: writeB(iaddr, reg_X); break;
        case STY: writeB(iaddr, reg_Y); break;

        /* Пересылка содержимого аккумулятора в регистр X */
        case TAX: {

            src = reg_A;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_X = (src);
            break;
        }

        /* Пересылка содержимого аккумулятора в регистр Y */
        case TAY: {

            src = reg_A;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_Y = (src);
            break;
        }

        /* Пересылка содержимого S в регистр X */
        case TSX: {

            src = reg_S;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_X = (src);
            break;
        }

        /* Пересылка содержимого X в регистр A */
        case TXA: {

            src = reg_X;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = (src);
            break;
        }

        /* Пересылка содержимого X в регистр S */
        case TXS: reg_S = reg_X; break;

        /* Пересылка содержимого Y в регистр A */
        case TYA: {

            src = reg_Y;
            SET_SIGN(src);
            SET_ZERO(src);
            reg_A = (src);
            break;
        }

    }

    // Установка нового адреса
    reg_PC      = addr;
    deb_addr    = addr;
}

// Декодирование линии, указанной по адресу
int decodeLine(int addr) {

    int t;
    int regpc = addr;
    unsigned char op, type;
    char operand[32];

    op   = readB(addr);
    addr = (addr + 1) & 0xffff;

    // Получение номера опкода
    int op_name_id = operandNames[ op ];
    int op_oper_id = operandTypes[ op ];

    // Декодирование операнда
    switch (op_oper_id) {

        /* IMMEDIATE VALUE */
        case IMM: t = readB(addr); addr++; sprintf(operand, "#%02X", t); break;

        /* INDIRECT X */
        case NDX: t = readB(addr); addr++; sprintf(operand, "($%02X,X)", t); break;

        /* ZEROPAGE */
        case ZP: t = readB(addr); addr++; sprintf(operand, "$%02X", t); break;

        /* ABSOLUTE */
        case ABS: t = readW(addr); addr += 2; sprintf(operand, "$%04X", t); break;

        /* INDIRECT Y */
        case NDY: t = readB(addr); addr++; sprintf(operand, "($%02X),Y", t); break;

        /* ZEROPAGE X */
        case ZPX: t = readB(addr); addr++; sprintf(operand, "$%02X,X", t); break;

        /* ABSOLUTE Y */
        case ABY: t = readW(addr); addr += 2; sprintf(operand, "$%04X,Y", t); break;

        /* ABSOLUTE X */
        case ABX: t = readW(addr); addr += 2; sprintf(operand, "$%04X,X", t); break;

        /* RELATIVE */
        case REL: t = readB(addr); addr++; sprintf(operand, "$%04X", addr + (t < 128 ? t : t - 256));  break;

        /* ACCUMULATOR */
        case ACC: sprintf(operand, "A"); break;

        /* ZEROPAGE Y */
        case ZPY: t = readB(addr); addr++; sprintf(operand, "$%02X,Y", t); break;

        /* INDIRECT ABS */
        case IND: t = readW(addr); addr += 2; sprintf(operand, "($%04X)", t);  break;

        /* IMPLIED, UNDEFINED */
        default: operand[0] = 0;
    }

    addr &= 0xffff;
    sprintf(debLine, "%s %s", operandNamesString[ op_name_id ], operand);
    return addr - regpc;
}

// Печать дампа
void disassembleAll() {

    int bytes, i, j, current_bg, addr, breakOn = 0;

    // Выровнять по верхней границе
    if (deb_addr < deb_top) {
        deb_top = deb_addr;
    }

    // Проверить выход за нижнюю границу
    if (deb_bottom >= 0 && deb_addr > deb_bottom) {
        deb_top = deb_addr;
    }

    addr = deb_top;
    for (i = 0; i < 52; i++) {

        // Записать текущую линию в буфер линии
        debAddr[ i ] = addr;

        // Текущий фон
        current_bg = 0;

        // Декодировать линию
        bytes = decodeLine(addr);

        // Поиск точек останова
        for (j = 0; j < breakpointsMax; j++) {
            if (breakpoints[j] == addr) {
                current_bg = 0xFF0000;
                printString(32, 1 + i, "                                ", 0x00ff00, current_bg);
                breakOn = 1;
                break;
            }
        }

        // Выделение текущей линии
        if (deb_addr == addr) {
            current_bg = 0x0000FF;
            printString(33, 1 + i, "                               ", 0x00ff00, current_bg);
        }

        // Показать текущую позицию исполнения
        if (reg_PC == addr) {
            printString(32, 1 + i, breakOn ? "\x0F" : "\x10", 0xffffff, 0);
        }

        // Пропечатать адрес
        printHex(33, 1 + i, addr, 4, 0xffffff, current_bg);

        // Пропечать байты
        for (j = 0; j < bytes; j++) {
            printHex(38 + 3*j, 1 + i, readB(addr + j), 2, 0xf0f000, current_bg);
        }

        // Печатать саму строку
        printString(47, 1 + i, debLine, 0x00ff00, current_bg);

        // Почти нижняя граница?
        if (i == 44) {
            deb_bottom = addr;
        }

        addr += bytes;
    }
}

// Исполнение кванта инструкции по NMI (1/60)
void nmi_exec() {

    int i, j;
    if (cpu_running) {

        /* Установка статуса кадрового синхроимпульса */
        ppu_status |= 0b10000000;
        
        for (i = 0; i < EXEC_QUANT; i++) {

            unsigned char bt = readB(reg_PC);

            // Программная точка останова (BRK и KIL)
            if (bt == 0x00 || bt == 0x02) {
                cpu_running = 0;

            } else {

                // Поиск точек останова
                for (j = 0; j < breakpointsMax; j++) {

                    if (breakpoints[ j ] == reg_PC) {

                        deb_addr = reg_PC;
                        cpu_running = 0;
                        break;
                    }
                }
            }

            // Может быть отключено при точке останова
            if (cpu_running) {
                exec();
            }
        }
        
        /* Кадровый синхроимпульс */
        if ((ctrl0 & 0x80) && 1)  {
            
            PUSH((reg_PC >> 8) & 0xff);	     /* Вставка обратного адреса в стек */
            PUSH(reg_PC & 0xff);
            SET_BREAK(1);                    /* Установить BFlag перед вставкой */
            PUSH(reg_P);
            SET_INTERRUPT(1);
            reg_PC = readW(0xFFFA);                        
        }
    }

}
