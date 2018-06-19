if (gcc `sdl-config --cflags --libs` main.c -lSDL -o e8632)
then
    echo "OK"
    ./e8632
fi
