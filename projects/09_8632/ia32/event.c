SDL_KeyboardEvent   *eventkey;
SDL_Event           event;

// Получение клавиши
int get_key_code(SDL_Event event) {            
     
    eventkey = &event.key;
    
    printf( "Scancode: 0x%02X", eventkey->keysym.scancode );
    
    // https://www.libsdl.org/release/SDL-1.2.15/docs/html/sdlgetkeyname.html
    printf( ", Name: %s", SDL_GetKeyName( eventkey->keysym.sym ) );
    
    /* Получить скан-код клавиш */
    return eventkey->keysym.scancode;
}
