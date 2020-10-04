<?php

  require "library.php";

  session_start();
  $username = $_SESSION['username'];

  $nombre = returnValue ($username,'nombre');
  $apellido = returnValue ($username,'apellido');
  $tipo_identificacion = returnValue ($username,'tipo_id');
  $id = returnValue ($username,'id');
  $fecha_nacimiento = returnValue ($username,'fecha_nacimiento');
  $genero = returnValue ($username,'genero');
  $estado_civil = returnValue ($username,'estado_civil');
  $tipo_telefono = returnValue ($username,'tipo_telefono');
  $telefono = returnValue ($username,'telefono');
  $pais = returnValue ($username,'pais');
  $ciudad = returnValue ($username,'ciudad');
  $img = returnValue ($username,'profile_img');

  $value = array('nombre' => $nombre,
                  'apellido' => $apellido,
                  'tipo_id' => $tipo_identificacion,
                  'id' => $id,
                  'fecha_nacimiento' => $fecha_nacimiento,
                  'genero' => $genero,
                  'estado_civil' => $estado_civil,
                  'tipo_telefono' => $tipo_telefono,
                  'telefono' => $tipo_telefono,
                  'pais' => $pais,
                  'ciudad' => $ciudad,
                  'img' => $img);

  header('Content-Type: application/json');
  echo json_encode($value);
 ?>
