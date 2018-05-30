#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <GL/glut.h>

#include "keyboard.h"
#include "display.h"
#include "cpu.h"

void keyboard(unsigned char key, int x, int y) {

    if (key == 27) {
        exit(0);
    }
}

void keyboard_func(int key, int x, int y) {

    usleep(100);

    int i, current_id = 0, debugOn = 0;

    // Посмотреть, в какой позиции сейчас стоит deb_addr
    for (i = 0; i < 64; i++) {
        if (debAddr[i] == deb_addr) {
            current_id = i;
        }
    }

    // Выполнить 1 шаг
    if (key == GLUT_KEY_F7) {

        exec();
        display();
    }

    // Переключение режима отладчика
    if (key == GLUT_KEY_F2) {

        // Поиск точек останова, чтобы удалить ее
        for (i = 0; i < breakpointsMax; i++) {
            if (breakpoints[i] == deb_addr) {
                breakpoints[i] = -1;
                debugOn = 1;
                break;
            }
        }

        // Точка останова не была найдена - установить новую
        if (debugOn == 0) {
            for (i = 0; i < 256; i++) {
                if (breakpoints[i] == -1) {
                    breakpoints[i] = deb_addr;
                    break;
                }
            }
        }

        // Может быть 0
        breakpointsMax = 0;

        // Пересчитать новую позицию
        for (i = 255; i >= 0; i--) {
            if (breakpoints[i] != -1) {
                breakpointsMax = i + 1;
                break;
            }
        }
    }

    // Переключение режима отладчика
    if (key == GLUT_KEY_F5) {
        cpu_running = 1 - cpu_running;
    }

    if (key == GLUT_KEY_F6) {

        switch (dump_mode) {

            case DUMP_ZP: dump_mode = DUMP_STACK; break;
            case DUMP_STACK: dump_mode = DUMP_ZP; break;
        }

        display();
    }

    // Просмотр ZP
    if (key == GLUT_KEY_F3) {

        zp_base = getEffectiveAddress(deb_addr) & 0xffff;
        display();
    }

    // Кнопка "вверх"
    if (key == GLUT_KEY_UP) {

        if (current_id > 0) {
            deb_addr = debAddr[ current_id - 1 ];
        } else {
            deb_addr = debAddr[ 0 ] - 1;
        }
    }

    // Кнопка "вниз"
    if (key == GLUT_KEY_DOWN) {

        if (current_id < 45) {
            deb_addr = debAddr[ current_id + 1 ];
        }
    }

    // Постраничник вниз
    if (key == GLUT_KEY_PAGE_DOWN) {
        deb_addr = debAddr[45];
    }

    // Постраничник вверх
    if (key == GLUT_KEY_PAGE_UP) {

        deb_addr -= (debAddr[44] - debAddr[0]);
        deb_addr = deb_addr > 0 ? deb_addr : 0;
    }

}
