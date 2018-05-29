dd if=/dev/zero of=rom.bin bs=1 count=16384
a6 -fb test.asm -o test.bin
dd if=test.bin of=rom.bin conv=notrunc

mode com8 baud=460800 data=8
copy rom.bin /b com8 
rm test.bin

pause