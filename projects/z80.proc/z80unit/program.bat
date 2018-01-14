dd if=/dev/random of=rom.bin bs=1 count=32768
dd if=/dev/zero of=rom.bin bs=1 count=16384
dd if=unit.bin of=rom.bin bs=1

mode com9 baud=460800 data=8
copy rom.bin /b com9

pause