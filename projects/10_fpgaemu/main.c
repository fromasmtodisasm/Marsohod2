#include "SDL.h"

#include "graph.c"
#include "event.c"

int main(int argc, char* argv[]) {
    
    int keycode;
    
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER);
    SDL_EnableUNICODE(1);

    init_graphics();
    
    while (1) {

        /* Снижение нагрузки на процессор */
        SDL_Delay(1); 

        /* Опрос событий, произошедших за 1 мс */
        while (SDL_PollEvent(& event)) {
            
            switch (event.type) {

                /* Если нажата на крестик, то приложение будет закрыто */
                case SDL_QUIT: { 

                    return 0;
                }
                    
                /* Нажата какая-то клавиша */
                case SDL_KEYDOWN: {

                    keycode = get_key(event);
                    
                    switch (keycode) {
                        
                        /* ESC */ case 9: return 0;                        
                    }
                    
                    break;   
                }                 
            }
        }        
    }
    
    return 0;
}
