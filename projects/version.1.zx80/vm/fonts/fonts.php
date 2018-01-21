<?php 

$m = imagecreatefrompng('font8.png');
$u = '';

for ($y = 9*2; $y < 9*8; $y += 9) {
for ($x = 0; $x < 128; $x += 8) {

    for ($i = 0; $i < 8; $i++) {

        $k = 0;
        for ($j = 0; $j < 8; $j++) {

           $n = imagecolorat($m, $x + $j, $y + $i) & 255;
           $k |= ($n > 128) ? (1 << (7 - $j)) : 0;

        }

        $u .= chr($k);
    }
} }

file_put_contents("font8.bin", $u);