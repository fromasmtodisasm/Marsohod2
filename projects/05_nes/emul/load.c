/* Протестировать, что это - nes-файл */
int is_nes_file(char* file) {
    
    int i, l = 0; while (file[l]) l++;   
    for (i = 0; i < l - 3; i++) {
        if (file[i] == '.' && file[i+1] == 'n' && file[i+2] == 'e' && file[i+3] == 's' && file[i+4] == 0) {
            return 1;
        }
    }
   
    return 0;     
}

// Загрузка NES-файла
// $FFFA – NMI (VBlink)
// $FFFC – RESET
// $FFFE - IRQ/BRK

void load_nes_file(char* file) {
    
    int size;
    FILE* f = fopen(file, "rb");
    
    if (f == NULL) {
        printf("File %s not found\n", file);
        exit(1);
    }
    
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    
    // 16-кб ROM
    if (size == 0x6010) {
        
        fseek(f, 0x10, SEEK_SET);
        fread(sram + 0xc000, 1, 0x4000, f);  // PRG-ROM(0)
        fseek(f, 0x10, SEEK_SET);
        fread(sram + 0x8000, 1, 0x4000, f);  // зеркало
        
        fseek(f, 0x4010, SEEK_SET);
        fread(sram + 0x10000, 1, 0x2000, f); // CHR-ROM (8 кб)        
        
    } else {
        
        fseek(f, 0x10, SEEK_SET);
        fread(sram + 0x8000, 1, 0x8000, f);  // PRG-ROM(0,1)  
        fseek(f, 0x8010, SEEK_SET);
        fread(sram + 0x10000, 1, 0x2000, f); // CHR-ROM (8 кб)    
    }
    
    // #RESET
    mapper = MAPPER_NES;        
    reg_PC = sram[0xFFFC] + (sram[0xFFFD]<<8);
    
    fclose(f);    
}

// Загрузка собственного файла
void load_own_file(char* file) {
    
    FILE* f = fopen(file, "rb");
    
    if (f == NULL) {
        printf("File %s not found\n", file);
        exit(1);
    }
    
    // 16K PRG-ROM(1)/(0)
    fread(sram + 0x8000, 1, 32*1024, f);
    fclose(f);
    
    // Первичное заполнение
    int i, j; 
    for (i = 0; i < 1024; i++) {
        
        // Атрибуты знакоместа = b00_00_00_00
        sram[0x12000 + i] = (i >= 0x3C0) ? 0x00 : 0x20;     
    }
    
    // Копировать системные шрифты
    for (i = 0; i < 256; i++) {
        
        for (j = 0; j < 8; j++) {
            sram[0x10000 + i*16 + j + 0x00] = sram[0x14000 + i*8 + j];
            sram[0x10000 + i*16 + j + 0x08] = sram[0x14000 + i*8 + j];
        }
        
    }
    
    // Инициализация палитры
    for (i = 0; i < 32; i++) {        
        sram[0x13F00 + i] = 0;
    }
    
    // Палитра фона
    sram[0x13F00] = 0x3F; // Черный цвет
    sram[0x13F01] = 0x00; // Серый
    sram[0x13F02] = 0x20; // Белый
    sram[0x13F03] = 0x10; // Светло-серый

    mapper = MAPPER_OWN;
    reg_PC = 0x8000;
}
