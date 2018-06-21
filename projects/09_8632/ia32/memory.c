#define MAX_PHYSMEM     4 * 1024 * 1024

/* Количество памяти 4 Мб */
unsigned char RAM[ MAX_PHYSMEM ];

/* Чтение байта памяти */
unsigned char readb(Uint32 address) {
    
    if (address >= MAX_PHYSMEM) {
        return 0;
    }
    
    return RAM[ address ];
}

/* Чтение слова (16 бит) */
unsigned int readw(Uint32 address) {    
    return readb(address) + (readb(address + 1) << 8);
}

// Прочитать байт из cs:ip / cs:eip
unsigned int fetchb() {
    
    int fd;
    
    switch (processor_mode) {
        
        /* RM */ 
        case 0: 
        
            fd = cs * 0x10 + (eip & 0xffff);
            eip++; 
            eip &= 0xffff;
            break;
    
    }
    
    return readb( fd );
};

unsigned int fetchw() {
    
    int a = fetchb();
    int b = fetchb();
    return a + b*256;
}

unsigned int fetchd() {

    int a = fetchw();
    int b = fetchw();
    return a + b*65536;

}
