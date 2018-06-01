# Компиляция 
if (gcc debugger.c -Os -lglut -lGL -o d6502)
then        
    cp d6502 /usr/local/bin
    
    # Исполнение
    ./d6502 loderunner.nes
fi

