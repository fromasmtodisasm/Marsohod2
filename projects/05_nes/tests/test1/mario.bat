@echo off

REM Копировать из NES-файла 16Кб для загрузки
dd if=mario.nes of=rom.bin skip=16 bs=1 count=32768
dd if=mario.nes of=chr.bin skip=32784 bs=1 count=8192

pause