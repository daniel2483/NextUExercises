$(function(){

  $('#login-form').submit(function(event){
  //console.log("TEST")
  var user = $('#user').val();
  var passwd = $('#password').val();
  console.log("User: "+user);
  console.log("Constraseña: "+passwd);
  event.preventDefault(); // Para evitar que el formulario se envíe por defecto
  $.ajax(
    {
      url:'login.php',
      type:'post',
      data: {user:user,passwd:passwd},
      success: function(value) {
                //value = JSON.parse(value);
                console.log(value.msg);
                //window.location.assign("http://localhost:8080/ejercicio5/index.html");
                if (value.msg == 'true') {
                  //alert("El usuario si existe!");
                  window.location.assign("http://localhost:8080/ejercicio5/index.html");
                }
                else{
                  alert("El usuario no existe o has digitado mal el usuario o contraseña!");
                  //window.location.assign("http://localhost:8080/ejercicio5/index.html");
                      //alert("El usuario no se encuentra registrado o has digitado mal la contraseña!");
                }
      }
    }
  )
})

})
