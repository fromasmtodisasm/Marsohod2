# Компиляция и линковка в `main`
if (gcc `sdl-config --cflags --libs` main.c -lSDL -Wall -o main)
then

    echo "OK"
    ./main
fi
