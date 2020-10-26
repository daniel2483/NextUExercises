<?php
  require('./conector.php');

  session_start();

  if (isset($_SESSION['username'])) {



    
  }else {
    $response['msg']= 'No se ha iniciado una sesión';
  }

  echo json_encode($response);


 ?>
