#define SCRWIDTH    1024
#define SCRHEIGHT   768

#include "fonts.h"

SDL_Surface         *sdl_screen;

/* Инициализация */
void init_video() {
    
    SDL_Init(SDL_INIT_VIDEO);
    SDL_EnableUNICODE(1);
    
    sdl_screen = SDL_SetVideoMode(SCRWIDTH, SCRHEIGHT, 32, 0); 
    SDL_WM_SetCaption( "Упрощенный эмулятор IA32", 0 );      
}

/* Установка точки */
void pset(int x, int y, unsigned int color) {    
    ((Uint32*)sdl_screen->pixels)[ SCRWIDTH*y + x ] = color;
}

/* Пропечатать фонт */
void print(int x, int y, unsigned char* s, int color) {
    
    int i, j, ch, sym = 'C';
    
    while (*s) {
        
        sym = *s++;
        for (i = 0; i < 16; i++) {
            
            ch = font[16*sym + i];
            for (j = 0; j < 8; j++) 
                if (ch & (1 << j))
                    pset(x + 7 - j, y + i, color);             
        }
        
        x += 8;
        if (x >= SCRWIDTH) {
            x  = 0;
            y += 16;
        }
    }
    
}
