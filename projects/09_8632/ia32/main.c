#include "SDL.h"

// --------------------------

#include "declare.h"

#include "memory.c"
#include "event.c"
#include "audio.c"
#include "video.c"
#include "cpu.c"
#include "disas.c"

int main(int argc, char* argv[]) {

    init_video();
    init_audio();
    init_event();
        
    int x, y, kk;
    
    for (x = 0; x < 2000; x++) {
        RAM[ 0xB8000 + 2*x    ] = 0x40;
        RAM[ 0xB8000 + 2*x + 1] = 0x17;
    }    
    
    //redraw_graphics();
    redraw_textmode();
        
    /* Бесконечный цикл */
    while (1) {

        while (SDL_PollEvent(&event)) {
            
            switch (event.type) {

                // SDL_KEYUP
                
                /* Нажата кнопка выхода */
                case SDL_QUIT: 
                
                    exit(0);                

                /* Нажата какая-то клавиша */
                case SDL_KEYDOWN:

                    kk = get_key_code(event);
                    if (kk == 9) 
                    return 0;

                    break;

                /* Дернута мышь */
                // case SDL_MOUSEMOTION:              
                // default:
                // printf("I don't know what this event is!\n");
            }
        }
    } 

    SDL_CloseAudio();      
    return 0;
}
