#include "SDL.h"

#include "video.c"
#include "audio.c"
#include "event.c"

int main(int argc, char* argv[]) {
        
    init_video();
    init_audio();
    
    int x, y;
    for (x = 0; x < 640; x++) for (y = 0; y < 480; y++) 
        pset(x+4, y+4, 0xff);
        
    print(640 + 8, 16, "MOV   AX, BX", 0x00ff00);
        
    SDL_Flip(sdl_screen);
    
    /* Бесконечный цикл */
    while (1) {
        
        while (SDL_PollEvent(&event)) {

          switch (event.type) {
              
            // SDL_KEYUP
            
            /* Нажата какая-то клавиша */
            case SDL_KEYDOWN:
                        
                get_key_code(event);
                return 0;
                break;

            /* Дернута мышь */
            // case SDL_MOUSEMOTION:              
            // default:
              // printf("I don't know what this event is!\n");
          }
          
          /* Задержка, чтобы что-то было */
          SDL_Delay(5);
        }
    }

    SDL_CloseAudio();      
    return 0;
}
