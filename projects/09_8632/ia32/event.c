/*
 * События
 */

SDL_KeyboardEvent   *eventkey;
SDL_Event           event;
SDL_TimerCallback   fps60;

int fps;

// Получение клавиши
int get_key_code(SDL_Event event) {            
     
    eventkey = &event.key;
    
    printf( "Scancode: 0x%02X", eventkey->keysym.scancode );
    
    // https://www.libsdl.org/release/SDL-1.2.15/docs/html/sdlgetkeyname.html
    printf( ", Name: %s\n", SDL_GetKeyName( eventkey->keysym.sym ) );
    
    /* Получить скан-код клавиш */
    return eventkey->keysym.scancode;
}

void init_event() {
    
    // 60 FPS
    fps = 0;
    SDL_SetTimer(1000 / 60, fps60);    
}
