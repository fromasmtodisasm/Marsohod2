// Размеры окна
#define SCREEN_W    1280 // 640 x 2
#define SCREEN_H    800  // 400 x 2

SDL_Surface * sdl_screen;

void init_graphics() {
    sdl_screen = SDL_SetVideoMode(SCREEN_W, SCREEN_H, 32, SDL_HWSURFACE | SDL_DOUBLEBUF);
    SDL_WM_SetCaption( "Симулятор ПЛИС Cyclone III", 0 );          
}

// Рисуем точку
void pset(int x, int y, uint color) {
    if (x >= 0 && x < SCREEN_W && y >= 0 && y < SCREEN_H) {
        ( (Uint32*)sdl_screen->pixels )[ x + SCREEN_W*y ] = color;
    }    
}

// Рисуем закрашенный прямоугольник на экране
void blockf(int x1, int y1, int x2, int y2, uint color) {
    
    int x, y;    
    for (y = y1; y <= y2; y++) {
        for (x = x1; x <= x2; x++) {
            pset(x, y, color);
        }
    }    
}

// Незакрашенный прямоугольник
void block(int x1, int y1, int x2, int y2, uint color) {
        
    int i;
    
    // Горизонтальные линии
    for (i = x1; i <= x2; i++) {        
        pset(i, y1, color);
        pset(i, y2, color);        
    }

    // Вертикальные линии
    for (i = y1; i <= y2; i++) {
        pset(x1, i, color);
        pset(x2, i, color);        
    }
    
}

void flip() { 
    SDL_Flip(sdl_screen);   
}
