<?php

  session_start();
  Session_destroy();

  header("Location: http://localhost:8080/ejercicio5/login.html");
  exit();

 ?>
