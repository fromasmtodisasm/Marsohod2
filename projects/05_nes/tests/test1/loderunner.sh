
# Копировать из NES-файла 16Кб для загрузки
dd if=loderunner.nes of=rom.bin skip=16 bs=1 count=16384
dd if=loderunner.nes of=rom.bin skip=16 bs=1 seek=16384 count=16384 conv=notrunc
dd if=loderunner.nes of=rom.bin skip=16400 bs=1 seek=32768 count=8192 conv=notrunc

# Загрузить программу в память ПЛИС
#mode com8 baud=460800 data=8
#copy rom.bin /b com8 

stty -F /dev/ttyUSB1 460800 cs8 -cstopb -parenb raw
cat rom.bin > /dev/ttyUSB1
