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
    default_reg = 0;    
}
