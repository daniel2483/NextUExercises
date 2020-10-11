<?php

  $categoria = $_POST['categoria'];
  $descripcion= $_POST['descripcion'];

  if($descripcion != "" && $categoria != ""){
    echo "Se recibieron los datos exitosamente";
  }

  if($descripcion == "" ){
    echo "No se recibió una descripcion";
  }

 ?>
