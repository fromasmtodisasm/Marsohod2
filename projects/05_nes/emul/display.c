#include <GL/freeglut.h>
#include <stdlib.h>
#include <stdio.h>

#include "display.h"
#include "cpu.h"

void setPalette(int id, int r, int g, int b) {
    
    globalPalette[id].r = r;
    globalPalette[id].g = g;
    globalPalette[id].b = b;
}

int initGlobalPal() {
    
    setPalette(0x00, 117, 117, 117);
    setPalette(0x01, 39,  27,  143);
    setPalette(0x02, 0,   0,   171);
    setPalette(0x03, 71,  0,   159);
    setPalette(0x04, 143, 0,   119);
    setPalette(0x05, 171, 0,   19);
    setPalette(0x06, 167, 0,   0);
    setPalette(0x07, 127, 11,  0);
    setPalette(0x08, 67,  47,  0);
    setPalette(0x09, 0,   71,  0);
    setPalette(0x0A, 0,   81,  0);
    setPalette(0x0B, 0,   63,  23);
    setPalette(0x0C, 27,  63,  95);
    setPalette(0x0D, 0,   0,   0);
    setPalette(0x0E, 0,   0,   0);
    setPalette(0x0F, 0,   0,   0);

    setPalette(0x10, 188, 188, 188);
    setPalette(0x11, 0,   115, 239);
    setPalette(0x12, 35,  59,  239);
    setPalette(0x13, 131, 0,   243);
    setPalette(0x14, 191, 0,   191);
    setPalette(0x15, 231, 0,   91);
    setPalette(0x16, 219, 43,  0);
    setPalette(0x17, 203, 79,  15);
    setPalette(0x18, 139, 115, 0);
    setPalette(0x19, 0,   151, 0);
    setPalette(0x1A, 0,   171, 0);
    setPalette(0x1B, 0,   147, 59);
    setPalette(0x1C, 0,   131, 139);
    setPalette(0x1D, 0,   0,   0);
    setPalette(0x1E, 0,   0,   0);
    setPalette(0x1F, 0,   0,   0);

    setPalette(0x20, 255, 255, 255);
    setPalette(0x21, 63,  191, 255);
    setPalette(0x22, 95,  151, 255);
    setPalette(0x23, 167, 139, 253);
    setPalette(0x24, 247, 123, 255);
    setPalette(0x25, 255, 119, 183);
    setPalette(0x26, 255, 119, 99);
    setPalette(0x27, 255, 155, 59);
    setPalette(0x28, 243, 191, 63);
    setPalette(0x29, 131, 211, 19);
    setPalette(0x2A, 79,  223, 75);
    setPalette(0x2B, 88,  248, 152);
    setPalette(0x2C, 0,   235, 219);
    setPalette(0x2D, 0,   0,   0);
    setPalette(0x2E, 0,   0,   0);
    setPalette(0x2F, 0,   0,   0);

    setPalette(0x30, 255, 255, 255);
    setPalette(0x31, 171, 231, 255);
    setPalette(0x32, 199, 215, 255);
    setPalette(0x33, 215, 203, 255);
    setPalette(0x34, 255, 199, 255);
    setPalette(0x35, 255, 199, 219);
    setPalette(0x36, 255, 191, 179);
    setPalette(0x37, 255, 219, 171);
    setPalette(0x38, 255, 231, 163);
    setPalette(0x39, 227, 255, 163);
    setPalette(0x3A, 171, 243, 191);
    setPalette(0x3B, 179, 255, 207);
    setPalette(0x3C, 159, 255, 243);
    setPalette(0x3D, 0,   0,   0);
    setPalette(0x3E, 0,   0,   0);
    setPalette(0x3F, 0,   0,   0);    
}

// Пиксель
void setPixel(int x, int y, int color, int scale) {

    int i, j;
    for (i = 0; i < scale; i++) {

        for (j = 0; j < scale; j++) {

            frame[ HEIGHT - 1 - y - i ][ x + j ].b =  color & 0xff;
            frame[ HEIGHT - 1 - y - i ][ x + j ].g = (color >> 8) & 0xff;
            frame[ HEIGHT - 1 - y - i ][ x + j ].r = (color >> 16) & 0xff;
        }
    }

}

// Печать строки
void printString(int x, int y, char* string, int fr, int bg) {

    int a, b, i, j, color, fo;
    int scale = 2;

    x *= scale * 8;
    y *= scale * 8;

    while (*string) {

        int ch = *string;

        for (a = 0; a < 8; a++) {

            fo = sram[ 0x14000 + ch*8 + a ];
            for (b = 0; b < 8; b++) {

                color = fo & (1 << (7 - b)) ? fr : bg;
                setPixel(x + scale*b, y + scale*a, color, scale);
            }
        }

        x += 8 * scale;

        string++;
    }

}

// Печать экрана из памяти
void printScreen() {

    int active_screen_id = 0x400 * 0;
    int active_chr       = (ctrl0 & 0x10) ? 0x1000 : 0x0;
    
    int i, j, a, b, ch, fol, foh, at, color, bn;

    // Обновление символов
    for (i = 0; i < 30; i++) {

        for (j = 0; j < 32; j++) {

            ch = sram[ active_screen_id + 0x12000 + (i*32) + j ];
            at = sram[ active_screen_id + 0x123C0 + (i>>2)*16 + (j>>2) ];
            
            // 0 1
            // 2 3
            bn = (i & 2) + (j >> 1) & 1; 
            at = (at >> (2*bn)) & 3;            

            for (a = 0; a < 8; a++) {

                fol = sram[ 0x10000 + ch*16 + a + 0 + active_chr ]; // low
                foh = sram[ 0x10000 + ch*16 + a + 8 + active_chr ]; // high bits                
                
                for (b = 0; b < 8; b++) {
                    
                    int s = 1 << (7 - b);

                    // Получение 4-х битов
                    color = (fol & s ? 1 : 0) | (foh & s ? 2 : 0); 
                    color = 4*at | color; 
                        
                    if (color & 3) {                    
                        color = sram[ 0x13F00 + color ]; // 16 цветов палитры фона
                    } else {
                        color = sram[ 0x13F00 ]; // "Прозрачный" цвет фона
                    }

                    color = 65536*globalPalette[ color ].r + 
                              256*globalPalette[ color ].g + 
                                  globalPalette[ color ].b;
                                
                    setPixel(0 + 2*(8*j + b), 0 + 2*(8*i + a), color, 2);
                }
            }
        }
    }
}

// Рисование линии (для проверки)
void drawLine(int x1, int y1, int x2, int y2, int color) {

    int deltax = x2 > x1 ? x2 - x1 : x1 - x2;
    int deltay = y2 > y1 ? y2 - y1 : y1 - y2;
    int error = 0, y = y1, x;
    int dir = y2 > y1 ? 1 : -1;

    for (x = x1; x < x2; x++) {

        setPixel(2*x, 2*y, color, 2);

        /*
        int a, b, i = y >> 3, j = x >> 3;
        for (a = 0; a < 8; a++) {
            for (b = 0; b < 8; b++) {
                setPixel(a*2 + 16*j, b*2 + 16*i, color, 2);
            }
        }
        */

        error += deltay;
        if (2 * error >= deltax) {
            y += dir;
            error -= deltax;
        }
    }

}

// Постоянное отображение информации на дисплее из буфера
void display() {

    int i, j;

    // Очистка буфера. В том числе и Z-буфера
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    nmi_exec();

    // Очистка экрана
    for (i = 0; i < HEIGHT; i++) {
    for (j = 0; j < WIDTH; j++) {
        frame[i][j].r = 0;
        frame[i][j].g = 0;
        frame[i][j].b = 0;
    } }

    // Знакогенератор встроенный
    printScreen();
    printRegisters();
    disassembleAll();

    // Обновление экрана
    glDrawPixels(WIDTH, HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, (void*)& frame);

    // Перерисовать
    glutReshapeWindow(WIDTH, HEIGHT);
    glutSwapBuffers();
}

// Печать hex-значений
void printHex(int x, int y, unsigned int value, int size, int fr, int bg) {

    char digs[5], a, b;

    if (size == 2) {

        a = (value & 0xF0) >> 4;
        b = (value & 0x0F);

        digs[0] = '0' + a + (a >= 10 ? 7 : 0);
        digs[1] = '0' + b + (b >= 10 ? 7 : 0);
        digs[2] = 0;
    }
    else {

        a = (value & 0xF000) >> 12;
        b = (value & 0x0F00) >> 8;

        digs[0] = '0' + a + (a >= 10 ? 7 : 0);
        digs[1] = '0' + b + (b >= 10 ? 7 : 0);

        a = (value & 0xF0) >> 4;
        b = (value & 0x0F);

        digs[2] = '0' + a + (a >= 10 ? 7 : 0);
        digs[3] = '0' + b + (b >= 10 ? 7 : 0);
        digs[4] = 0;

    }

    printString(x, y, digs, fr, bg);
}

// Пропечатка бинарного значения
void printBin(int x, int y, unsigned int value, int fr, int bg) {

    char s[2]; s[1] = 0;
    int i;

    for (i = 0; i < 8; i++) {

        s[0] = value & (1 << (7 - i)) ? '1' : '0';
        printString(x + i, y, s, fr, bg);
    }
}

// Печать содержания регистров
void printRegisters() {

    int  baseline = 31;
    char s[2]; s[1] = 0;
    int  i, j;
    int  color;
    char sym[16] = "nv_bdizcNV_BDIZC";

    // Болванка
    printString(1, baseline + 0, "\x04  HEX  BINARY", 0xffff00, 0);
    printString(1, baseline + 1, "A  00   00000000", 0x00ff00, 0);
    printString(1, baseline + 2, "X  00   00000000", 0x00ff00, 0);
    printString(1, baseline + 3, "Y  00   00000000", 0x00ff00, 0);
    printString(1, baseline + 4, "S  00   00000000", 0x00ff00, 0);
    printString(1, baseline + 5, "P  00   Nv_bdIzc", 0x00ff00, 0);
    printString(1, baseline + 6, "PC 0000", 0x00ff00, 0);
    printString(1, baseline + 7, "EA 0000", 0x00ff00, 0);

    // Значение регистров
    printHex(4, baseline + 1, reg_A, 2, 0xffffff, 0);
    printHex(4, baseline + 2, reg_X, 2, 0xffffff, 0);
    printHex(4, baseline + 3, reg_Y, 2, 0xffffff, 0);
    printHex(4, baseline + 4, reg_S, 2, 0xffffff, 0);
    printHex(4, baseline + 5, reg_P, 2, 0xffffff, 0);
    printHex(4, baseline + 6, reg_PC, 4, 0xffffff, 0);

    // Значение регистров (бинарное)
    printBin(9, baseline + 1, reg_A, 0xc0c0c0, 0);
    printBin(9, baseline + 2, reg_X, 0xc0c0c0, 0);
    printBin(9, baseline + 3, reg_Y, 0xc0c0c0, 0);
    printBin(9, baseline + 4, reg_S, 0xc0c0c0, 0);
    printBin(9, baseline + 5, reg_P, 0xc0c0c0, 0);

    for (i = 0; i < 8; i++) {

        int bit = reg_P & (1 << (7 - i)) ? 1 : 0;
        int color = bit ? 0x00ff00 : 0x008000;

        s[0] = sym[i + 8*bit];
        printString(9 + i, baseline + 6, s, color, 0);
    }

    unsigned int iaddr = getEffectiveAddress(deb_addr) & 0xffff;

    // Показать текущий эффективный адрес
    printHex(4, baseline + 7, iaddr, 4, 0xffffff, 0);

    // Значения в этой точке
    for (i = 0; i < 7; i++) {

        sprintf(sym, "%02X", sram[ iaddr + i ]);
        printString(9 + i*3, baseline + 7, sym, i == 0 ? 0x00ffff : 0x00c0c0, 0);
    }

    // Таб
    printString(1, baseline + 9, "ZP",    dump_mode == DUMP_ZP ? 0xffffff : 0x00a0a0, 0);
    printString(4, baseline + 9, "Stack", dump_mode == DUMP_STACK ? 0xffffff : 0x00a0a0, 0);

    // Памятка
    printString(1,  baseline + 21, "F3 Seek F5 Run F6 Tab F7 Step", 0x808080, 0);
    printString(1,  baseline + 21, "F3", 0xC0A000, 0);
    printString(16, baseline + 21, "F6", 0xC0A000, 0); 
    printString(23, baseline + 21, "F7", 0xC0A000, 0);

    if (cpu_running) {
        printString(9, baseline + 21, "F5 RUN",  0x80FF00, 0);
    } else {
        printString(9, baseline + 21, "F5",  0xC0A000, 0);
    }

    //printString(1, 47, "", 0x808080, 0);

    int zp;
    printString(6, baseline + 11, "+0 +1 +2 +3 +4 +5 +6 +7", 0xffffff, 0);
    switch (dump_mode) {

        case DUMP_ZP:

            zp = zp_base;
            for (i = 0; i < 8; i++) {

                printHex(1, baseline + i + 12, zp + i*8, 4, 0xffffff, 0);
                for (j = 0; j < 8; j++) {

                    sprintf(sym, "%02X", readB( zp + j + i * 8 ));
                    printString(6 + j*3, baseline + 12 + i, sym, 0xc0c0c0, 0);
                }
            }

            break;

        case DUMP_STACK:

            zp = 0x0100 + reg_S + 1;
            for (i = 0; i < 8; i++) {

                printHex(1, baseline + i + 12, ((zp + i*8) & 0xff | 0x100), 4, 0xffffff, 0);
                for (j = 0; j < 8; j++) {

                    sprintf(sym, "%02X", readB( (zp + i * 8 + j) & 0xff | 0x100 ));
                    printString(6 + j*3, baseline + 12 + i, sym, 0xc0c0c0, 0);
                }
            }

            break;
    }
}

// Загрузка шрифта
void fontsLoad() {

    FILE* f = fopen("8x8cp1251.fnt", "rb");

    if (f == NULL) {

        printf("Lost file: 8x8cp1251.fnt\n");
        exit(1);
    }

    // Основные шрифты
    fseek(f, 0, SEEK_SET);
    fread(sram + 0x14000, 1, 2048, f);

    fclose(f);
}
