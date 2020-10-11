<?php
  require "library.php";

  session_start();
  $username = $_SESSION['username'];
  $categoria = $_POST['categoria'];
  $descripcion = $_POST['descripcion'];

  #echo $username." " $categoria.;

  editFieldJSON($username,'categoria',$categoria);
  editFieldJSON($username,'descripcion',$descripcion);

 ?>
