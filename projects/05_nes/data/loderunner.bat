@echo off

dd if=loderunner.nes of=rom.bin skip=16 bs=1 count=16384
dd if=rom.bin of=kil.bin bs=1 skip=64 count=1

rem DD63 - C000 = 1D62 (7522)
dd if=kil.bin of=rom.bin bs=1 seek=7522 conv=notrunc

mode com8 baud=460800 data=8
copy rom.bin /b com8 

pause