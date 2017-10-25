WIDTH=8;
DEPTH=16384;

ADDRESS_RADIX=HEX;
DATA_RADIX=HEX;

CONTENT BEGIN
<?php 

// php tomif.php > ../trunk/rom.mif
$f = file_get_contents('binary/rom.bin');
for ($i = 0; $i < 16384; $i++) {

    $b = ord(@$f[$i]);
    echo "    " . dechex($i) . " : " . dechex($b) . ";\n";
}
?>
END;
