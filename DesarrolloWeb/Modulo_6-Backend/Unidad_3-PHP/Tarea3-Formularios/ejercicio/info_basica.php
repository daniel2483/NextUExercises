<?php

  include "c_Usuario.php";

  $nombre = $_POST['nombre'];
  $apellido = $_POST['apellido'];

  echo "Los datos del usuario ".$nombre." ".$apellido." han sido almacenados exitosamente";

 ?>
