#!/bin/sh

# Компиляция Boot
if (fasm boot.asm >> /dev/null)
then

    echo "Y BOOT.ASM"
    
    # Сохранение в MBR (old = 446)    
    if (dd conv=notrunc if=boot.bin of=disk.img bs=512 count=1 2> /dev/null)
    then

        echo "Y WRITTEN MBR"
        
        # Компиляция KSearch
        if (fasm main.asm8 >> /dev/null)
        then
        
            echo "Y KSEARCH.ASM"
            
            # Сохранение в POST-boot Area
            if (dd conv=notrunc if=main.bin of=disk.img seek=1 bs=512 2> /dev/null)
            then
            
                echo "Y WRITTEN KSEARCH"
                
                # Запуск эмулятора
                bochs -f a.bxrc -q
            
            else 
            
                echo "N KSEARCH BAD"            

            fi
    
        fi    
    
    fi

fi

