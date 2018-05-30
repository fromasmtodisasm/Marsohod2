# Компиляция модулей
gcc -c cpu.c -o cpu.o
gcc -c keyboard.c -o keyboard.o
gcc -c display.c -o display.o
gcc -c debugger.c -o debugger.o

if (gcc display.o keyboard.o cpu.o debugger.o -Os -lglut -lGL -o d6502)
then
    rm *.o
    cp d6502 /usr/local/bin
    ./d6502 loderunner.nes
fi
