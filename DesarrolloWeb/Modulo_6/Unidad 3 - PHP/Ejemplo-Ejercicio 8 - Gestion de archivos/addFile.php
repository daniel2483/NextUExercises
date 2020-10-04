<?php

  $titulo = "test_2.txt";
  $texto = "Esto es un nuevo texto de prueba para escritura sobre un archivo";

  $newfile = fopen("./".$titulo,'w') or die ("Error en la creación del archivo");

  fwrite($newfile, $texto);

  echo "Tu archivo se creo exitosamente...\n";
  echo "Con el nombre: ".$titulo;

  fclose($newfile);

 ?>
