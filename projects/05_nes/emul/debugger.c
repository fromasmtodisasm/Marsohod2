/*
 * Упрощенный графический отладчик 6502 NES модели процессора
 * Лицензия как обычно, никакая
 * 
 * ./debugger [filename [start_load [PC]]]
 */

#include <stdlib.h>
#include <stdio.h>
#include <GL/freeglut.h>

#include "display.h"
#include "keyboard.h"
#include "cpu.h"

#include "load.c"

int main(int argc, char* argv[]) {

    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_RGB | GLUT_DEPTH | GLUT_DOUBLE);
    glutInitWindowSize(WIDTH, HEIGHT);
    glutCreateWindow("C6502-light");
    glClearColor(0.0f, 0.25f, 0.5f, 1.0f);
    
    fontsLoad();
    initGlobalPal();
    initCPU();

    if (argc > 1) {
        
        // Загрузить файл NES
        if (is_nes_file(argv[1])) {
            load_nes_file(argv[1]);
        } else {
            load_own_file(argv[1]);
        }
        
        deb_top  = reg_PC;
        deb_addr = reg_PC;        
    }
    
    // http://grafika.me/node/130
    glutKeyboardFunc(& keyboard );
    glutSpecialFunc(& keyboard_func );

    glutDisplayFunc(& display);
    glutMainLoop();
    return 0;
}
