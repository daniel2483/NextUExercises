<?php
  require('./conector.php');

  session_start();

  if (isset($_SESSION['username'])) {

    $con = new ConectorBD('localhost','nextu','12345');
    $con->initConexion("transporte_db");

    $resultado = $con->getCiudades();
    $i=0;
    while ($fila = $resultado->fetch_assoc()) {
      $response['ciudades'][$i]['id']=$fila['id'];
      $response['ciudades'][$i]['nombre']=$fila['nombre'];
      $i++;
    }

    $resultado = $con->getVehiculos();
    $i=0;
    while ($fila = $resultado->fetch_assoc()) {
      $response['vehiculos'][$i]['placa']=$fila['placa'];
      $response['vehiculos'][$i]['fabricante']=$fila['fabricante'];
      $response['vehiculos'][$i]['referencia']=$fila['referencia'];
      $i++;
    }

    $resultado = $con->getConductores();
    $i=0;
    while ($fila = $resultado->fetch_assoc()) {
      $response['conductores'][$i]['id']=$fila['id'];
      $response['conductores'][$i]['nombre']=$fila['nombre'];
      $i++;
    }

    $response['msg']= 'OK';

    $con->cerrarConexion();


  }else {
    $response['msg']= 'No se ha iniciado una sesión';
  }

  echo json_encode($response);


 ?>
