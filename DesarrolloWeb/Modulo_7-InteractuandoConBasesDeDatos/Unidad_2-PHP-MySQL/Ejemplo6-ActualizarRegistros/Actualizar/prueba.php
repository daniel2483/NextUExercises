<?php

  require('lib.php');
  $con = new ConectorBD();

  $datos['nombre'] = "'Luis'";

  $con->actualizarRegistro('Personas', $datos, "id=4");

 ?>
