<?php // php loderom.php > ../init/rom.hex

// Прогрузить по полной программе то, что требуется доказать.
$C = substr(file_get_contents($argv[1]), 0, 16384);

$L = strlen($C);
$C[ 0x3FFA ] = chr(0x00); $C[ 0x3FFB ] = chr(0x00); // NMI
$C[ 0x3FFC ] = chr(0x00); $C[ 0x3FFD ] = chr(0x80); // RESET
$C[ 0x3FFE ] = chr(0x00); $C[ 0x3FFF ] = chr(0x00); // BRK

for ($i = 0; $i < 16384; $i++) echo sprintf("%02X\n", $i < $L || $i >= 0x3FFA ? ord($C[$i]) : 0x00);
