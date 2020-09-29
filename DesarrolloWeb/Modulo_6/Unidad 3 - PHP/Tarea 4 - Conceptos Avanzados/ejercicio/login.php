<?php

  require "library.php";

  header('Content-Type: application/json');

  if(isset($_POST['user'])){$username = $_POST['user'];}else{$username = "";}

  if(isset($_POST['passwd'])){$password = $_POST['passwd'];}else{$password="";}

  // Obtengo lista de usuarios existentes
  $arrayUsers = readUsers();
  //$verification =

  // Verificacion de usuarios
  $userAccess  = accessUser($username,$password,$arrayUsers);

  if ($userAccess[0] == 0){
    $value =  array('msg' => 'false' );
    echo json_encode($value);
  }

  if ($userAccess[0] == 1){
    if($userAccess[1] == 0){
      //echo $username." has digitado mal la contraseña!";
      $value =  array('msg' => 'false' );
      echo json_encode($value);
      exit;
    }
    else{
      // Se crea una variable de sesión
      //Setcookie(“nombre”,”valor”,”tiempo”,”directorio_donde_sera_almacenada”)
      session_start();
      $_SESSION['username'] =  $username;
      //$_SESSION['nombre'] =  $arrayUsers[$key]['nombre'];

      $value =  array('msg' => 'true' );
      echo json_encode($value);
      exit;
      // Se redirecciona a la página principal
      //header("Location: http://localhost:8080/ejercicio5/index.html");
      //exit();
    }
  }



 ?>
