<?php

  require "library.php";

  session_start();
  $username = $_SESSION['username'];

  // Getting the Values from AJAX
  if(isset($_POST['nombre'])){$nombre = $_POST['nombre'];editFieldJSON($username,'nombre',$nombre);}else{$nombre="";}
  if(isset($_POST['apellido'])){$apellido = $_POST['apellido'];editFieldJSON($username,'apellido',$apellido);}else{$apellido="";}
  if(isset($_POST['tipo_identificacion'])){$tipo_identificacion = $_POST['tipo_identificacion'];editFieldJSON($username,'tipo_id',$tipo_identificacion);}else{$tipo_identificacion="";}
  if(isset($_POST['identificacion'])){$identificacion = $_POST['identificacion'];editFieldJSON($username,'id',$identificacion);}else{$identificacion="";}
  if(isset($_POST['fecha_nacimiento'])){$fecha_nacimiento = $_POST['fecha_nacimiento'];editFieldJSON($username,'fecha_nacimiento',$fecha_nacimiento);}else{$fecha_nacimiento="";}
  if(isset($_POST['genero'])){$genero = $_POST['genero'];editFieldJSON($username,'genero',$genero);}else{$genero="";}
  if(isset($_POST['estado_civil'])){$estado_civil = $_POST['estado_civil'];editFieldJSON($username,'estado_civil',$estado_civil);}else{$estado_civil="";}
  if(isset($_POST['tipo_telefono'])){$tipo_telefono = $_POST['tipo_telefono'];editFieldJSON($username,'tipo_telefono',$tipo_telefono);}else{$tipo_telefono="";}
  if(isset($_POST['telefono'])){$telefono = $_POST['telefono'];editFieldJSON($username,'telefono',$telefono);}else{$telefono="";}
  if(isset($_POST['pais'])){$pais = $_POST['pais'];editFieldJSON($username,'pais',$pais);}else{$pais="";}
  if(isset($_POST['ciudad'])){$ciudad = $_POST['ciudad'];editFieldJSON($username,'ciudad',$ciudad);}else{$ciudad="";}

  if(isset($_POST['foto'])){$foto = $_POST['foto'];}else{$foto='undefined';};
  


  // Uploading image if, is defined
  if ($foto != 'undefined'){
    $directorio = "uploadedImgs/";
    $nombre_image = $_FILES["foto"]["name"];
    $archivo_a_subir = $directorio.basename($nombre_image);
    $tipo_de_archivo = pathinfo($archivo_a_subir, PATHINFO_EXTENSION);
    $file_size = $_FILES["foto"]["size"];
    $exito = true;
    $respuestas;

    if(file_exists($archivo_a_subir)){
      $respuestas["mensaje"] = "El archivo ya existe.";
      $exito = false;
    }

    if($file_size > 10000000){
      $respuestas["mensaje"] = "El archivo es demasiado grande.";
      $exito = false;
    }

    // jpg, jpeg, png, doc, txt, docx, pdf
    if($tipo_de_archivo != "jpg"
    && $tipo_de_archivo != "jpeg"
    && $tipo_de_archivo != "png"
    && $tipo_de_archivo != "doc"
    && $tipo_de_archivo != "txt"
    && $tipo_de_archivo != "docx"
    && $tipo_de_archivo != "pdf"){
      $respuestas["mensaje"] = "Solo se permiten archivos JPG, JPEG, PNG, DOC, TXT, DOCX o PDF.";
      $exito = false;
    }


    if ($exito == false){
      $respuestas["mensaje"] = "Lo sentimos, tu archivo no fue añadido.";
    }else{
      if(move_uploaded_file($_FILES["file"]["tmp_name"], $archivo_a_subir)){
        $respuestas["final"] = "El archivo ".basename($nombre_image)." ha sido añadido.";
        $respuestas["mensaje"] = "";
        $respuestas["newSource"] = $archivo_a_subir;
        editFieldJSON($username,'profile_img',$archivo_a_subir);
      }else{
        $respuestas["final"] = "Lo sentimos. tu archivo no fue añadido.";
      }
    }

    ##echo "console.log(".$nombre_image.")";
  }else {
    $respuestas["mensaje"] = "La imagen de perfil se encuentra vacía...";
  }

 ?>
