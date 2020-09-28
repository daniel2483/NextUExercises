<?php
  require "library.php";

  // This PHP return a JSON values
  header('Content-Type: application/json');

  session_start();
  if (isset($_SESSION['username'])){
    // Return to index.html
    $main = true;
    //returnValue("juan.camilo@mail.com",'nombre');
    $nombre=returnValue($_SESSION['username'],'nombre');
    $apellido=returnValue($_SESSION['username'],'apellido');
    $descripcion = returnValue ($_SESSION['username'],"descripcion");
    $id = returnValue ($_SESSION['username'],"id");
    $hoja_vida = returnValue ($_SESSION['username'],"hoja_vida");
    $profile_img = returnValue ($_SESSION['username'],"profile_img");

    $value =  array('session' => $main,
                    'username' => $_SESSION['username'],
                    'nombre' => $nombre,
                    'apellido' => $apellido,
                    'descripcion' => $descripcion,
                    'id' => $id,
                    'hoja_vida' => $hoja_vida,
                    'profile_img' => $profile_img);
    echo json_encode($value);
    exit;
  }
  else{
    $main = false;
    $value =  array('session' => $main );
    echo json_encode($value);
    exit;
  }

 ?>
