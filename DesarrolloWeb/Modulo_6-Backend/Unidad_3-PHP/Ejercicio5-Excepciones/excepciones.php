<?php

  include "excepciones_2.php";

  function dividir($num1,$num2){
    if($num2 == 0){
      //throw new Exception("No puedes hacer una división entre cero");
      throw new DivisionEntreCero();
    }

    if($num1 < 0 || $num2 < 0){
      //throw new Exception("No puedes hacer una división entre cero");
      throw new NumeroNegativo();
    }

    return $num1/$num2;
  }

  try{
    echo dividir(6,-4);

  }
  //catch(Exception $e){
  catch (DivisionEntreCero $ecero){
    //echo "Se presento un error: ".$e->getMessage();
    echo "Se presento un error: ".$ecero->mensajeError();
  }
  catch (NumeroNegativo $enegativo){
    echo "Se presento un error: ".$enegativo->mensajeError();
  }
  finally{
    echo "<p>Se realizó una división</p>";
  }

 ?>
