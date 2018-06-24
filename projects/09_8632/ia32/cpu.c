int opcode, cpu_repnz, cpu_repe, cpu_segid, cpu_reg32, 
    cpu_mem32,  cpu_lock, effective, cpu_modrm;

    
/*
 * Процессор
 */

void init_cpu() {
    
    eax = 0x00000000; esp = 0x00000000;
    ebx = 0x00000000; ebp = 0x00000000; 
    ecx = 0x00000000; esi = 0x00000000; 
    edx = 0x00000000; edi = 0x00000000;
    eip = 0x00000000;
    
    es = 0x0000;
    cs = 0x0000;
    ds = 0x0000;
    ss = 0x0000;
    fs = 0x0000;
    gs = 0x0000;
    
    processor_mode = 0;
    default_reg    = 0;    
}

/* Шаг процессора */
void step() {
    
    int i, stop = 0;
    
    opcode      = 0;
    cpu_repnz   = 0;
    cpu_repe    = 0;
    cpu_segid   = 0;
    cpu_reg32   = 0;
    cpu_mem32   = 0;
    cpu_lock    = 0;
    effective   = 0;
    cpu_modrm   = 0;
    
    /* Декодирование префиксов (макс 6) */
    for (i = 0; i < 6; i++) {

        int D = fetchb();

        switch (D) {
            case 0x0F: opcode |= 0x100; break;
            case 0x26: cpu_segid = 0; break;
            case 0x2E: cpu_segid = 1; break;
            case 0x36: cpu_segid = 2;  break;
            case 0x3E: cpu_segid = 3; break;
            case 0x64: cpu_segid = 4; break;
            case 0x65: cpu_segid = 5; break;
            case 0x66: cpu_reg32 = cpu_reg32 ^ 1; break;
            case 0x67: cpu_mem32 = cpu_mem32 ^ 1; break;
            case 0xf0: cpu_lock = 1; break;
            case 0xf2: cpu_repnz = 1; break;
            case 0xf3: cpu_repe  = 1; break;
            default:   opcode |= D; stop = 1; break;
        }

        if (stop) break;
    }
    
    // Ошибка инструкции. Вызов Exception.
    if (stop == 0) {
        // exception();
    }
    
    // Декодировать ModRM
    if (modrm_lookup[ opcode ]) {
                
        cpu_modrm = fetchb();
        // .. всяко разно это не заразно
        
    }
    
    
}
