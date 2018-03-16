/*
    GNU GPL ГНУ ГПЛ ЛИЦЕНЗИЯ ДРЕВНЕГО ЕГИПТА
    Силой данной лицензии объявляю вас... кошкой и котом.
    Итак. Эта программа создает MIF-файл с русским шрифтом 8x8
    Компиляция производится так:  gcc mif.c -o c2mif
*/

typedef unsigned char ubyte;

#include <stdio.h>
#include "font8x8.h"

int main() {

    int i, j;
    printf("WIDTH=8;\nDEPTH=2048;\nADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n");
    for (i = 0; i < 256; i++) {
        for (j = 0; j < 8; j++) {
            ubyte a = Font8x8Table[i][j];
            printf("   %x: %x;\n", 8*i + j, a);
        }
    }
    printf("END;\n");

    return 0;
}