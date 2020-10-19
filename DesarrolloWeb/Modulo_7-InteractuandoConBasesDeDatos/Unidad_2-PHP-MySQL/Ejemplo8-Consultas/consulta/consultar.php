<?php

  require('lib.php');
  
  $con = new ConectorBD();

  if ($con->initConexion('inventario_db')=='OK') {

    if ($con->consultar(['usuarios'], ['*'])) {
      echo "Se consultaron los registros exitosamente";
    }else echo "Hubo un problema y los registros no fueron consultados";



  }else {
    echo "Se presentó un error en la conexión";
  }




 ?>
