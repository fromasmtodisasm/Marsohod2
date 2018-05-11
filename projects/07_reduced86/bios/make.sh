if (fasm bios.asm)
then

    php hex.php bios.bin > ../init/bios.hex
    rm bios.bin
    cd ..
    sh make.sh

fi
