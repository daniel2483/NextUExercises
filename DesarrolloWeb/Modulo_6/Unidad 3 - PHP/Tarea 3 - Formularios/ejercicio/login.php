<?php
  // PHP que diligencia los datos de login
  //echo "Success!!!"

  $user = $_POST['user'];
  $password= $_POST['password'];

  function valid_email($str) {
    return (!preg_match("/^([a-z0-9\+_\-]+)(\.[a-z0-9\+_\-]+)*@([a-z0-9\-]+\.)+[a-z]{2,6}$/ix", $str)) ? FALSE : TRUE;
  }

  if(!valid_email($user)){
    echo "No se envío un nombre de usuario válido";
  }else{
    echo "Se recibieron los datos adecuadamente. El usuario ingresado fue ".$user;
  }



  //if ($user =~ "/^([a-z0-9\+_\-]+)(\.[a-z0-9\+_\-]+)*@([a-z0-9\-]+\.)+[a-z]{2,6}$/ix"){
  //  echo "Se recibieron los datos adecuadamente. El usuario ingresado fue ".$user;
  //}else{
  //  echo "No se envío un nombre de usuario válido";
  //}



 ?>
