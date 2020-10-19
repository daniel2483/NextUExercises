<?php
  require('lib.php');

  $con = new database_con();

  $con->buildTable('personas',['id'=>'INT','name'=>'VARCHAR(45)']);

 ?>
