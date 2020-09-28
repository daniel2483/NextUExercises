<?php

  if ($_SESSION['username']){
    // Return to index.html
    $main = true;
    $value =  array('session' => $main );
    header('Content-Type: application/json');
    echo json_encode(main $main);
    exit;
  }
  else{
    $main = false;
    $value =  array('session' => $main );
    header('Content-Type: application/json');
    echo json_encode($main);
    exit;
  }




 ?>
