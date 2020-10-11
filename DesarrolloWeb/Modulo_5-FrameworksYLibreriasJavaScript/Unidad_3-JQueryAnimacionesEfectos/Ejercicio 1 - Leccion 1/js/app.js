$(function(){

  $("#btn-vaca").click(function(){
    $("#vaca").toggle("slow","swing",function(){
      var mensajeShow = $(this).css("display");
      if(mensajeShow !== "none"){$("#mensaje").text("La vaca hace muuu")}
      else{$("#mensaje").text("")}
    });
    $("#cerdo").hide("slow","swing");
    $("#gallina").hide("slow","swing");
    $("#oveja").hide("slow","swing");
  });

  $("#btn-cerdo").click(function(){
    $("#vaca").hide("slow","swing");
    $("#cerdo").toggle("slow","swing",function(){
      var mensajeShow = $(this).css("display");
      if(mensajeShow !== "none"){$("#mensaje").text("El cerdo hace oink")}
      else{$("#mensaje").text("")}
    });
    $("#gallina").hide("slow","swing");
    $("#oveja").hide("slow","swing");
  });

  $("#btn-gallina").click(function(){
    $("#vaca").hide("slow","swing");
    $("#cerdo").hide("slow","swing");
    $("#gallina").toggle("slow","swing",function(){
      var mensajeShow = $(this).css("display");
      if(mensajeShow !== "none"){$("#mensaje").text("La gallina hace cloac")}
      else{$("#mensaje").text("")}
    });
    $("#oveja").hide("slow","swing");
  });

  $("#btn-oveja").click(function(){
    $("#vaca").hide("slow","swing");
    $("#cerdo").hide("slow","swing");
    $("#gallina").hide("slow","swing");
    $("#oveja").toggle("slow","swing",function(){
      var mensajeShow = $(this).css("display");
      if(mensajeShow !== "none"){$("#mensaje").text("La oveja hace beee")}
      else{$("#mensaje").text("")}
    });
  });


  /////////////////////// Cambiando icono de tijeras y apareciendo cerca y animales //////////////
  $("#bCorte").click(function(){
    console.log("Elijo cursor de corte");
    $("body").css("cursor","cell");
  });

  /////////////////////// Cambiando icono herramientas y apareciendo cerca y animales ////////////
  $("#bConstruir").click(function(){
    console.log("Elijo cursor de herramientas");
    $("body").css("cursor","copy");
    $(".cerca").show("fast");
    $(".animalP").show("fast");
    $("h1").text("Construye una cerca");
  });

  /////////////////////// Borrando arbustos //////////////////////////////////////////////////////
  $(".arbusto").hover(function(){
    var cualCursor= $("body").css('cursor');

    if(cualCursor !== "auto"){
      $(this).hide("fast");
      console.log("Removiendo arbusto: " + $(this).attr('id'));
    }
  });

  //////////////////////// Funcion de Drag and Drop de animales y cerca //////////////////////////
  $(".cerca,.animalP").mousedown(function(event){
    var self = $(this);
    $(this).on('dragstart', function(event) {
      event.preventDefault();
    });
    var positionXIni = event.pageX;
    var positionYIni = event.pageY;
    var windowWidth = $(window).width();


    console.log("Window Width: " + windowWidth + " " + positionXIni + "  " + positionYIni);
    //Función anidada que cambia la posición de la pieza si se presiona el click y se mueve
    $("body").mousemove(function(event){
      self.css("left", function(positionXIni){
        var newPositionX = event.pageX - positionXIni;
        return newPositionX+"px";
      });
      self.css("top", function(positionYIni){
        var newPositionY = event.pageY - positionYIni;
        return newPositionY+"px";
      });
    });

  });

  $("body").mouseup(function(event){
    $(this).off("mousemove");
    var x = parseFloat($(event.target).css("left"));
    var y = parseFloat($(event.target).css("top"));
    if(x !== "NaN" && y !== "NaN"){
      //console.log("Soltando " + " Nuevo X: " + x + " Nuevo Y: " + y);
    }

  });

  ////////////////////////////////// Icono de listo //////////////////////////////////////////////
  $("#bCursor").click(function(){
    console.log("Todo esta listo");
    $("body").css("cursor","auto");



    $(".cerca").hide(5400,'swing');
    $(".animal").hide("fast");
    $(".animalP").hide(6000,'linear');
    $(".animalP").animate('text',0,'linear',function(){
      $("h1").text("Muy bien!");
    });


  });



})
