<?php
  $directorio = "./uploadedDocs/";
  $nombre_archivo = $_FILES["file"]["name"];
  $archivo_a_subir = $directorio.basename($nombre_archivo);
  $tipo_de_archivo = pathinfo($archivo_a_subir, PATHINFO_EXTENSION);
  $tamanio_archivo = $_FILES['file']['size'];

  //if(file_exists($archivo_a_subir)){
  //  echo "El archivo con ese nombre ya se ha ";
  //}

  if(move_uploaded_file($_FILES["file"]["tmp_name"],$archivo_a_subir)){
    echo "Se ha subido el archivo exitosamente";
  }else{
    echo "A ocurrido un error al intentar subir el archivo ".$nombre_archivo;
  }

  /*header('Content-Type: application/json');
  $arrayInfo = array('nombre_archivo' => $nombre_archivo,
                      'size' => $tamanio_archivo,
                      'extension' => $tipo_de_archivo);
  echo json_encode($arrayInfo);
  */


 ?>
