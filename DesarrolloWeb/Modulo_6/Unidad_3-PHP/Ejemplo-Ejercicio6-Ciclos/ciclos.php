<?php
//
// $a = 0;
//
// while ($a <= 10) {
//   echo "<p>El valor de a es: ".$a."</p>";
//   $a++;
// }
//
// echo "---------";
//
// $b = 0;
//
// do {
//   echo "<p>El valor de b es: ".$b."</p>";
//   $b++;
// } while ($b<=5);


?>

<!-- <!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Ciclos</title>
  </head>
  <body>
    <h1>Ciclos</h1>

    <table border="1">
      <tr>
        <th>Número</th>
        <th>Mensaje</th>
      </tr>
      <?php //for ($i=0; $i < 10; $i++) { ?>
      <tr>
        <th><?php //echo $i ?></th>
        <th>Hola!</th>
      </tr>
      <?php //} ?>
    </table>
  </body>
</html> -->

<!-- ................................................................ -->



<?php $arreglo = ['Pedro', 'Juan', 'Santiago', 'Pablo']; ?>
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Ciclos</title>
  </head>
  <body>
    <h1>Ciclos</h1>

    <table border="1">
      <tr>
        <th>Número</th>
        <th>Nombre</th>
      </tr>
      <?php foreach ($arreglo as $posicion => $valor) { ?>
      <tr>
        <th><?php echo $posicion ?></th>
        <th><?php echo $valor; ?></th>
      </tr>
      <?php } ?>
    </table>
  </body>
</html>
