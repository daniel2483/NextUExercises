<?php

  #$titulo = $_POST("titulo");
  $titulo = "test.txt";
  $file = fopen("./".$titulo,"r");
  //$response["contenido"] = fread($file,filesize("./".$titulo));
  //$response["titulo"] = $titulo;

  echo fread($file,filesize("./".$titulo));

  //echo json_encode($response);
  fclose($file);

 ?>
