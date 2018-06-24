fasm bios.asm

if (gcc `sdl-config --cflags --libs` main.c -lSDL -Wall -o e8632)
then
    echo "OK"
    ./e8632 freedos.img
fi
