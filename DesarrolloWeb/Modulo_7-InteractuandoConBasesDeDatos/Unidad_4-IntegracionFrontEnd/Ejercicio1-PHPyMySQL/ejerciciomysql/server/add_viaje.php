<?php
  require('./conector.php');
  error_reporting(0);

  session_start();

  if (isset($_SESSION['username'])) {

    $con = new ConectorBD('localhost', 'nextu', '12345');
    $response['conexion'] = $con->initConexion('transporte_db');

    $ciudad_orig_id = $POST['ciudad_orig_id'];
    $ciudad_dest_id = $POST['ciudad_dest_id'];
    $vehiculo_placa = $POST['vehiculo_placa'];
    $conductor_id = $POST['conductor_id'];
    $fecha_salida = $POST['fecha_salida'];
    $hora_salida = $POST['hora_salida'];

    $ciudad_orig = $con->consultar(['ciudades'],['nombre'], 'WHERE id=7'."");

    $response['ciudad_origen'] = $ciudad_orig;
    $response['msg']= "Se ha agregado un nuevo registro de viaje";




    $con->cerrarConexion();
  }else {
    $response['msg']= 'No se ha iniciado una sesión';
  }

  echo json_encode($response);

 ?>
