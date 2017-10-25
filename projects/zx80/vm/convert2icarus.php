<?php 

// php icarus_mem.php > ../trunk/icarus_memory.v

echo '`ifdef ICARUS' . "\n";

$f = file_get_contents('rom.bin');
for ($i = 0; $i < strlen($f); $i++) {

    echo "sdram[ 16'h".dechex($i)." ] = 8'h" . dechex(ord($f[$i])) . ";\n";

}

echo "`endif\n";
?>

