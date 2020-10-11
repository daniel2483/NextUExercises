$(function(){
  $( window ).scroll(function(){
    //console.log($(window).scrollTop());
    if($(window).scrollTop() >= 200){
      $("body").css("background-image", "url('img/background2.jpg'");
    };
  });

$("#color-favorito").change(function(){
  console.log("Cambio de color favorito... " + $("#color-favorito").children("option:selected").val());

  switch ($("#color-favorito").children("option:selected").val()) {
    case "azul":
      $(".cuadrado-color").css("background","blue");
      break;
    case "verde":
      $(".cuadrado-color").css("background","green");
      break;
    case "amarillo":
      $(".cuadrado-color").css("background","yellow");
      break;
    case "rojo":
      $(".cuadrado-color").css("background","red");
      break;
    case "morado":
      $(".cuadrado-color").css("background","purple");
      break;
    case "cafe":
      $(".cuadrado-color").css("background","brown");
      break;
    default:
      // No hay color
      $(".cuadrado-color").css("background","#BCB0AD");
  }
})


$("#nombre").focus(function(){
  $($(".info")[0]).css("display", "block");
  $($(".error")[0]).css("display", "none");
})

$("#nombre").blur(function(){
  $($(".info")[0]).css("display", "none");
  if($("#nombre").val() === "" ){$($(".error")[0]).css("display", "block");}
})

$("#apellido").focus(function(){
  $($(".info")[1]).css("display", "block");
  $($(".error")[1]).css("display", "none");
})

$("#apellido").blur(function(){
  $($(".info")[1]).css("display", "none");
  if($("#apellido").val() === "" ){$($(".error")[1]).css("display", "block");}
})

$("#psw").focus(function(){
  $($(".info")[2]).css("display", "block");
  $($(".error")[2]).css("display", "none");
})

$("#psw").blur(function(){
  $($(".info")[2]).css("display", "none");
  $($(".errPsw")[0]).css("display", "none");
  if($("#psw").val() === "" ){$($(".error")[2]).css("display", "block");}
})

$("#pswRepeat").focus(function(){
  $($(".info")[3]).css("display", "block");
  $($(".error")[3]).css("display", "none");
  $(".errPswRepeat").css("display", "none");
})

$("#pswRepeat").blur(function(){
  $($(".info")[3]).css("display", "none");
  if($("#pswRepeat").val() === "" ){$($(".error")[3]).css("display", "block");}
  if($("#pswRepeat").val() === $("#psw").val()){$($(".errPswRepeat")[0]).css("display", "none");}
  else{$($(".errPswRepeat")[0]).css("display", "block");}
})

$("#fecha-nacimiento").focus(function(){
  $($(".info")[4]).css("display", "block");
  $($(".error")[4]).css("display", "none");
})

$("#fecha-nacimiento").blur(function(){
  $($(".info")[4]).css("display", "none");
  if($("#fecha-nacimiento").val() === "" ){$($(".error")[4]).css("display", "block");}
})

$("#ciudad-residencia").focus(function(){
  $($(".info")[5]).css("display", "block");
  $($(".error")[5]).css("display", "none");
})

$("#ciudad-residencia").blur(function(){
  $($(".info")[5]).css("display", "none");
  if($("#ciudad-residencia").val() === "" ){$($(".error")[5]).css("display", "block");}
})

$("#color-favorito").focus(function(){
  $($(".info")[6]).css("display", "block");
  $($(".error")[6]).css("display", "none");
})

$("#color-favorito").blur(function(){
  $($(".info")[6]).css("display", "none");
  if($("#color-favorito").val() === "" ){$($(".error")[6]).css("display", "block");}
})

$("#email").focus(function(){
  $($(".info")[7]).css("display", "block");
  $($(".error")[7]).css("display", "none");
  $($(".errMail")[0]).css("display", "none");
})

$("#email").blur(function(){
  $("#email").attr("value",$("#email").val());
  // Patron de email a validar
  var validacionEmail = /^[a-zA-Z0-9\._-]+@[a-zA-Z0-9-]{2,}[.][a-zA-Z]{2,4}$/;
  $($(".info")[7]).css("display", "none");
  if($("#email").val() === "" ){$($(".error")[7]).css("display", "block");}
  else if(validacionEmail.test($("#email").val()) == true ){$($(".errMail")[0]).css("display", "none");}
  else{$($(".errMail")[0]).css("display", "block");}
})

$("#psw").select(function (){
  alert("No puedes copiar la contraseña debes repetirla!");
})

$('#psw').keypress(function(key) {

  if((key.charCode < 97 || key.charCode > 122) && (key.charCode < 65 || key.charCode > 90) && (key.charCode != 45))
    {
      $($(".info")[2]).css("display", "none");
      $($(".errPsw")[0]).css("display", "block");
      console.log("Num tecla: " + key.charCode + " Validacion: " + false);
      return false;
    }
  else
    {
      $($(".info")[2]).css("display", "block");
      $($(".errPsw")[0]).css("display", "none");
      console.log("Num tecla: " + key.charCode + " Validacion: " + true);
      return true;
    }
});


//////////////////// Drag and Drop //////////////////////////77
var positionXIni = 0;
var positionYIni = 0;
var clickOnP1 = false;
var clickOnP2 = false;
var clickOnP3 = false;
var clickOnP4 = false;

$(".imagen").mousedown(function(){
  var self = $(this);
  $(this).addClass("imagen-seleccionada");
  $(this).on('dragstart', function(event) {
    event.preventDefault();
  });
  //Función anidada que cambia la posición de la pieza si se presiona el click y se mueve
  $(".prueba-container").mousemove(function(event){
    self.css("left", function(){
      var newLeft = event.pageX - 234;
      return newLeft+"px";
    });
    self.css("top", function(){
      var newTop = event.pageY - 591;
      return newTop+"px";
    });
  })
});

//Variable para verificar que todas las piezas se hayan ubicado correctamente
var contador=0;

//Función que ubica las piezas del rompecabezas correctamente si se dejan en puntos cercanos a los adecuedos en el molde
$(".imagen").mouseup(function(event){
  $(event.target).removeClass("imagen-seleccionada");
  $(this).off("mousemove");
  var x = parseFloat($(event.target).css("left"));
  var y = parseFloat($(event.target).css("top"));
  if($(event.target).attr("id")=="p1"){
    if ((x>800&&x<860)&&(y>55&&y<69)) {
      $(event.target).css("left","840px");
      $(event.target).css("top","68px");
      $(event.target).addClass("imagen-correcta");
      $(event.target).off("mousedown");
      contador++;
    }
  }
  if($(event.target).attr("id")=="p2"){
    if ((x>900&&x<965)&&(y>45&&y<80)) {
      $(event.target).css("left","924px");
      $(event.target).css("top","65px");
      $(event.target).addClass("imagen-correcta");
      $(event.target).off("mousedown");
      contador++;
    }
  }
  if($(event.target).attr("id")=="p3"){
    if ((x>798&&x<870)&&(y>150&&y<180)) {
      $(event.target).css("left","844px");
      $(event.target).css("top","160px");
      $(event.target).addClass("imagen-correcta");
      $(event.target).off("mousedown");
      contador++;
    }
  }
  if($(event.target).attr("id")=="p4"){
    if ((x>920&&x<980)&&(y>130&&y<160)) {
      $(event.target).css("left","948px");
      $(event.target).css("top","138px");
      $(event.target).addClass("imagen-correcta");
      $(event.target).off("mousedown");
      contador++;
    }
  }
});


})
