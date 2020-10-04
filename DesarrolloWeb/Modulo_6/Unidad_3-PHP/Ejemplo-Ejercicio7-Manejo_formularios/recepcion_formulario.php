<?php

  //echo "<h1>Se han recibido los datos del formulario exitosamente</h1>";

  //$nombre = $_GET['nombre_usuario']; // --> Con metodo GET
  //$nombre = $_POST['nombre_usuario']; // --> Con metodo POST
  $nombre = $_POST['nombre']; // --> Con AJAX y método POST
  $numeroLetras = strlen($nombre);
  echo "El nombre recibido del formulario es: ".$nombre." y tiene ".$numeroLetras." letras";

 ?>
