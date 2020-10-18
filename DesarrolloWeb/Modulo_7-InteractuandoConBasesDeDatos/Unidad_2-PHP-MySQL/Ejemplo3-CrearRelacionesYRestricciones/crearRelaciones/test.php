<?php
  require('lib.php');



  $conector = new ConectorBD();

  if ($conector->initConexion('inventario_db')=='OK') {

    //if ($conector->nuevaRestriccion('usuarios', 'ADD PRIMARY KEY (id)')){
    //  echo "Se añadió una nueva restriccion exitosamente";
    //}else echo "Se presento un error al añadir una restriccion";

    if ($conector->nuevaRelacion('usuarios','ciudades','fk_ciudad','id')){
      echo "Se añadió una nueva relacion exitosamente";
    }else echo "Se presento un error al añadir una relacion";

    $conector->cerrarConexion();
  }else {
    echo $conector->initConexion();
  }


 ?>
