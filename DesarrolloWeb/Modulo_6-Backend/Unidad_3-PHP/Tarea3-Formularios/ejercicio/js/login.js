$(function(){
  // jquery con AJAX

  //console.log("TEST");

  // Código para el uso de AJAX para envio de datos de un form POST
  $('#login-form').submit(function(event){
    //console.log("TEST")
    var user1 = $('#login-form').find('input[name="user"]').val();
    var password1 = $('#login-form').find('input[name="pwd"]').val();
    console.log(user1);
    event.preventDefault(); // Para evitar que el formulario se envíe por defecto
    $.ajax(
      {
        url:'./login.php',
        type:'post',
        data: {user:user1, password:password1}
      }
    ).done(function(data){
      alert(data);
    })
  })


})
