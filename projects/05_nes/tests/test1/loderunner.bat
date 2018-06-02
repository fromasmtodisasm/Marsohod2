@echo off

REM Копировать из NES-файла 16Кб для загрузки
dd if=loderunner.nes of=rom.bin skip=16 bs=1 count=16384

REM Установить отладочный опкод
php setkil.php c054

REM Загрузить программу в память ПЛИС
mode com8 baud=460800 data=8
copy rom.bin /b com8 

pause