<?php

  include "operaciones.php";
  include "vista/tablero.php";
  //include "archivo.php";
  //require "require.php";

  $a = 4;
  $b = 6;
  $imp = new Visualizador("La suma de ".$a." mas ".$b." Es igual a: ".sumar($a,$b));
  $imp->mostrarTitulo();

  $imp = new Visualizador("La resta de ".$a." menos ".$b." Es igual a: ".restar($a,$b));
  $imp->mostrarTitulo();

  $imp = new Visualizador("La multiplicación de ".$a." por ".$b." Es igual a: ".multiplicar($a,$b));
  $imp->mostrarTitulo();

  $imp = new Visualizador("La división de ".$a." entre ".$b." Es igual a: ".dividir($a,$b));
  $imp->mostrarTitulo();

  $imp = new Visualizador("La potencia de ".$a." elevado a la ".$b." Es igual a: ".elevar($a,$b));
  $imp->mostrarTitulo();

 ?>
