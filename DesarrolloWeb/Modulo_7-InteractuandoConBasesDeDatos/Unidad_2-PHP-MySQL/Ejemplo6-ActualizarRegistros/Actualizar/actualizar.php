<?php

  require('lib.php');

  $con = new ConectorBD();

  if ($con->initConexion('inventario_db')=='OK') {

    $datos['nombre'] = "'Pablo Garcia'";
    $datos['telefono'] = "'4328754'";

    if ($con->actualizarRegistro('usuarios', $datos, "id=1")) {
      echo "Se han actualizado los datos correctamente";
    }else echo "Se ha producido un error en la actualización";


    $con->cerrarConexion();

  }else {
    echo "Se presentó un error en la conexión";
  }




 ?>
