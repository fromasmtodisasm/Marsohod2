SDL_Event  event;

// https://www.libsdl.org/release/SDL-1.2.15/docs/html/sdlevent.html
/*
typedef union{
  Uint8 type;
  SDL_ActiveEvent       active;
  SDL_KeyboardEvent     key;
  SDL_MouseMotionEvent  motion;
  SDL_MouseButtonEvent  button;
  SDL_JoyAxisEvent      jaxis;
  SDL_JoyBallEvent      jball;
  SDL_JoyHatEvent       jhat;
  SDL_JoyButtonEvent    jbutton;
  SDL_ResizeEvent       resize;
  SDL_ExposeEvent       expose;
  SDL_QuitEvent         quit;
  SDL_UserEvent         user;
  SDL_SysWMEvent        syswm;
} SDL_Event;
*/

int get_key(SDL_Event event) {
     
    /* Получение ссылки на структуру с данными о нажатой клавише */
    SDL_KeyboardEvent * eventkey = &event.key;
         
    /* Получить скан-код клавиш */
    return eventkey->keysym.scancode;
}
