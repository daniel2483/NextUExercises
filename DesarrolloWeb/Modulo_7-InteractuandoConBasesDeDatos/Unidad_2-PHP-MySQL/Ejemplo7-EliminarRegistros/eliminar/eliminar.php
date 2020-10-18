<?php
  require('lib.php');

  $con = new ConectorBD();

  if($con->initConexion('inventario_db') == 'OK'){

    if ($con->eliminarRegistro('usuarios',"telefono LIKE '4%'")){
      echo "Se eliminaron los registros exitosamente";
    }else echo "Hubo un problema y los registros no fueron eliminados";


    $con->cerrarConexion();

  }else{
    echo "Se presentó un problema en la conexión";
  }



 ?>
