<?php
  error_reporting(0);
  require('lib.php');

  $con = new ConectorBD();
  $con->consultar(['personas'],['nombre','apellido','telefono'], ' where id < 10 ORDER BY nombre ASC');



 ?>
