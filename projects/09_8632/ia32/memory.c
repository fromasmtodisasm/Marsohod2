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
