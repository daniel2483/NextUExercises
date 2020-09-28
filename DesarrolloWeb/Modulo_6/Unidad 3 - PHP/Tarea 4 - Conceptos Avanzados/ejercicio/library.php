<?php

  function readUsers(){
    $fileUsers = "./data/users.json";
    $file = fopen($fileUsers,"r");
    //$response["contenido"] = fread($file,filesize("./".$titulo));
    //$response["titulo"] = $titulo;
    $fileRead = fread($file,filesize($fileUsers));
    $arrayUsers = json_decode($fileRead,true);
    //echo $arrayUsers;
    //echo json_encode($response);
    fclose($file);
    return $arrayUsers;
  }

  //readUsers();

  //$users_array = readUsers();

  function accessUser($username,$password,$users_array){
    $user_exist = 0;
    $password_correct = 0;
    $user_number = sizeof($users_array);
    $index = "";

    for ($i=0; $i<$user_number; $i++){
      //echo $users_array[$i]['username']."<br>";
      if ($users_array[$i]['username'] == $username){
        $user_exist = 1;
        if($users_array[$i]['password'] == $password){
          $password_correct = 1;
        }
        break;
      }
    }
    return array($user_exist,$password_correct);
  }


  function returnValue ($username,$field){
    $arrayUsers = readUsers();
    $key = ""; // To find the key in array List
    for($i=0;$i<sizeof($arrayUsers);$i++){
      if($arrayUsers[$i]['username'] == $username){
        $key = $i;
        break;
      }
    }
    $fieldValue = $arrayUsers[$key][$field];
    return $fieldValue;
  }


  function editFieldJSON($username,$field,$new_value){
    $arrayUsers = readUsers();
    $key = ""; // To find the key in array List
    for($i=0;$i<sizeof($arrayUsers);$i++){
      if($arrayUsers[$i]['username'] == $username){
        $key = $i;
        break;
      }
    }

    $arrayUsers[$key][$field] = $new_value;

    $fileUsers = "./data/users.json";
    $file = fopen($fileUsers,"w");
    fwrite($file,json_encode($arrayUsers));
    //echo $arrayUsers;
    //echo json_encode($response);
    fclose($file);
  }

  //$array = accessUser("juan.camilo@mail.com","12345",$users_array);

  //echo $array[0]."<br>";
  //echo $array[1];

  // Testing function
  //$value = returnValue("juan.camilo@mail.com",'nombre');
  //echo $value;

  // Testing Editing JSON
  //editFieldJSON("juan.camilo@mail.com",'apellido','Sánchez Sancho');

 ?>
