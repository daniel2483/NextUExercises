<?php

  class DivisionEntreCero extends Exception{

    function mensajeError(){
      return "No puedes hacer una división entre cero";
    }

  }

  class NumeroNegativo extends Exception{
    function mensajeError(){
      return "No puedes usar números negativos en esta división";
    }
  }

 ?>
