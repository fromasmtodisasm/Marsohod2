if (fasm bios.asm)
then

    cat bios.bin | hexdump -e '/1 "%02X" "\n"' > ../bios.hex
    rm bios.bin
    cd ..
    sh make.sh

fi
