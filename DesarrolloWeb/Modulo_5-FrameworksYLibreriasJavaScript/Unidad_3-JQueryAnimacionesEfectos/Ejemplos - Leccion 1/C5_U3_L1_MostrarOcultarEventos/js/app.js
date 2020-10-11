$(function(){


  $("#btn-vaca").click(function(){
    $("#vaca").show("slow","swing",function(){$("#mensaje").text("Esta es una Vaca!")});
    $("#cerdo").hide("slow","swing");
    $("#gallina").hide("slow","swing");
    $("#oveja").hide("slow","swing");
  });

  $("#btn-cerdo").click(function(){
    $("#vaca").hide("slow","swing");
    $("#cerdo").show("slow","swing",function(){$("#mensaje").text("Este es un cerdo!")});
    $("#gallina").hide("slow","swing");
    $("#oveja").hide("slow","swing");
  });

  $("#btn-gallina").click(function(){
    $("#vaca").hide("slow","swing");
    $("#cerdo").hide("slow","swing");
    $("#gallina").show("slow","swing",function(){$("#mensaje").text("Esto es una gallina!")});
    $("#oveja").hide("slow","swing");
  });

  $("#btn-oveja").click(function(){
    $("#vaca").hide("slow","swing");
    $("#cerdo").hide("slow","swing");
    $("#gallina").hide("slow","swing");
    $("#oveja").show("slow","swing",function(){$("#mensaje").text("Esto es una oveja!")});
  });

  //CODIGO PARA LA CAPTURA
  //
  // $("selectorDisparador").evento(function(){
  //
  //   $("selectorObjetivo").show();
  //
  // });
  //
  //
  // function funcionDefinida(){
  //   $("selectorObjetivo").show();
  // };
  //
  // $("selectorDisparador").evento(funcionDefinida());
  //


  // $("selectorDisparador").evento(function(){
  //
  //   $(this).show();
  //
  // });



})
