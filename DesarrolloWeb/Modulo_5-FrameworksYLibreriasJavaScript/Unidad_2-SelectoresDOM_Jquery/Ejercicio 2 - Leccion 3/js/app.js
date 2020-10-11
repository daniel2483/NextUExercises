$( document ).ready(function() {

  //Evento para el botón mas (+)
  idImg = 1;
  $("#mas").click(function(){
    if($(".zona-juego img").length <= 4){
    $(".zona-juego").append('<img id=' + idImg + ' src="image/back.jpg" class="carta"/>');
    idImg = idImg + 1;
    }
  });

  //Evento para el botón menos (-)
  $("#menos").click(function(){
    var cantidadCartas = $(".zona-juego img").length;
    if(cantidadCartas-1 >=0){$($(".zona-juego img"))[cantidadCartas-1].remove();
    idImg = idImg - 1;
    }
  });

  //Evento al hacer click en una carta
  $(document).on("click", "img.carta", function(){
    //var = $()
    var randomCarta = Math.floor(Math.random() * 52) + 1 ;

    console.log(randomCarta);
    $(this).attr("src",function(){
      var imagen = "image/" + randomCarta + ".png";
      return imagen;
    });

    $("#contenido-pantalla").html("La carta es la <b>" + randomCarta + "</b> de la baraja");

  });

  //Evento de hover
  $(document).on({
    //Función al mouse estar sobre la carta
    mouseenter: function(){
      $(this).addClass("carta-seleccionada");
      $(this).attr("style","border: 2px solid yellow")
    },

    //Función al mouse dejar la carta
    mouseleave: function(){
      $(this).removeClass("carta-seleccionada");
      $(this).attr("style","border: 0px solid yellow");
    }
  }, "img.carta");


});
