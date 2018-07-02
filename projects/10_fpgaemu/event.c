SDL_Event  event;

int get_key(SDL_Event event) {
     
    /* Получение ссылки на структуру с данными о нажатой клавише */
    SDL_KeyboardEvent * eventkey = &event.key;
         
    /* Получить скан-код клавиш */
    return eventkey->keysym.scancode;
}
