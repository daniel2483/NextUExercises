<?php

  class database_con{
    private $host = 'localhost';
    private $usuario = 'nextu';
    private $contrasenia = '12345';
    private $conexion;

    function __construct(){
      $this->$host = $host;
      $this->$usuario = $usuario;
      $this->$constrasenia = $contrasenia;
      $this->$conexion = $conexion;
    }

    function connectDB($db){
      $this->conexion = new mysqli($this->host, $this->user, $this->password, $db);
      if ($this->conexion->connect_error) {
        // Return Error if the connection has something wrong
        return "Error:" . $this->conexion->connect_error;
      }else {
        // Return OK if the connection is OK
        return "OK";
      }
    }

    function executeSQL($sql){
      return $this->conexion->query($sql);
    }

    function closeCon(){
      $this->conexion->close();
    }

    function buildTable($tabla, $fields){
      $sql = 'CREATE TABLE '.$tabla.' (';
      $length_array = count($fields);
      $i = 1;
      foreach ($fields as $key => $value) {
        $sql .= $key.' '.$value;
        if ($i!= $length_array) {
          $sql .= ', ';
        }else {
          $sql .= ');';
        }
        $i++;
      }
      echo $sql;
      //return $this->executeSQL($sql);
    }


  }


 ?>
