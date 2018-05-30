@echo off

dd if=loderunner.nes of=rom.bin skip=16 bs=1 count=16384

mode com8 baud=460800 data=8
copy rom.bin /b com8 

pause