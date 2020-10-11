$( document ).ready(function() {
  $("body").click(function(){
    //Realiza las selecciones en este bloque de código

    $("h1").css("color","yellow"); //
    $(".icon-arrow-down2").css("color","yellow");
    $("nav").find(":contains('Home')").css("color","yellow");

    $($("span.fh5co-meta:nth-child(1)")[1]).css("color","yellow");
    $($(".row p")[3]).css("color","yellow");
    $(".btn.btn-primary.btn-lg").css("color","yellow");
    $("cite").css("color","yellow");

  });
});
