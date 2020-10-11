$(document).ready(function() {
  $('select').material_select();
  $('.nombre-user').html("")
  $('li > a.dropdown-button').html("<i class='material-icons right'>face</i>")

  // AJAX to check if session already start
  $.ajax(
    {
      url:'./checkSession.php',
      type:'post',
      data: {user:null},
      success: function(value) {
                console.log(value.session);
                console.log(value.username);
                if (value.session == false){
                  // Return to login site
                  window.location.assign("http://localhost:8080/ejercicio5/login.html");
                }
                else{
                    $('.nombre-user').html(value.nombre+" "+value.apellido);
                    $('li > a.dropdown-button').html(value.nombre+" "+value.apellido
                                                      +"<i class='material-icons right'>face</i>");

                    if(value.descripcion === ""){console.log("Descripcion Vacía...")}
                    else{$('.states > li:nth-child(1)').html("<i class='material-icons'>check</i>");
                        $('p').html(value.descripcion);
                        }

                    if(value.id === ""){console.log("Información Básica Vacía...")}
                    else{$('.states > li:nth-child(2)').html("<i class='material-icons'>check</i>");}

                    if(value.hoja_vida === ""){console.log("Hoja de Vida Vacía...")}
                    else{$('.states > li:nth-child(1)').html("<i class='material-icons'>check</i>");}



                }
      }
    }
  )


 });
