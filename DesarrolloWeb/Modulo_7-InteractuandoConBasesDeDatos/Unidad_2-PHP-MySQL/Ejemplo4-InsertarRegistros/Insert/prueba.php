<?php

  require('lib.php');

  //echo "Testing script...<br>";

  $con = new ConectorBD();

  $datos['nombre'] = 'Carol';
  $datos['telefono']= '3348976';

  $con->insertData('personas',$datos);

 ?>
