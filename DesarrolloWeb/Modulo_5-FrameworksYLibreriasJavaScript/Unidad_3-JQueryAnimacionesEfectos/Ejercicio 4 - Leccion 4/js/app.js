$( function() {
  $( "#menu" ).menu();

  $( "#todos").on('click', function(){
    $( ".flor" ).show("drop",500);
    $( ".deporte" ).show("drop",500);
    $( ".carro" ).show("drop",500);
    $( ".avion" ).show("drop",500);
    $( ".paisaje" ).show("drop",500);
  });

  $( "#flores").on('click', function(){
    $( ".flor" ).show("drop",500);
    $( ".deporte" ).hide("drop",500);
    $( ".carro" ).hide("drop",500);
    $( ".avion" ).hide("drop",500);
    $( ".paisaje" ).hide("drop",500);
  });

  $( "#deportes").on('click', function(){
    $( ".flor" ).hide("drop",500);
    $( ".deporte" ).show("drop",500);
    $( ".carro" ).hide("drop",500);
    $( ".avion" ).hide("drop",500);
    $( ".paisaje" ).hide("drop",500);
  });

  $( "#autos").on('click', function(){
    $( ".flor" ).hide("drop",500);
    $( ".deporte" ).hide("drop",500);
    $( ".carro" ).show("drop",500);
    $( ".avion" ).hide("drop",500);
    $( ".paisaje" ).hide("drop",500);
  });

  $( "#aviones").on('click', function(){
    $( ".flor" ).hide("drop",500);
    $( ".deporte" ).hide("drop",500);
    $( ".carro" ).hide("drop",500);
    $( ".avion" ).show("drop",500);
    $( ".paisaje" ).hide("drop",500);
  });

  $( "#paisajes").on('click', function(){
    $( ".flor" ).hide("drop",500);
    $( ".deporte" ).hide("drop",500);
    $( ".carro" ).hide("drop",500);
    $( ".avion" ).hide("drop",500);
    $( ".paisaje" ).show("drop",500);
  });


  $( "#accordion" ).accordion();

  $(".imgBox")
    .on("dblclick", function(){

      var html = $(this).html();
      console.log(html);
      $("#zoomImg").html(html);
      $("#zoomImg img").addClass("imgBoxDialog");

      $( "#zoomImg" ).dialog({
          autoOpen: true,
          show: {
            effect: "blind",
            duration: 800
          },
          hide: {
            effect: "explode",
            duration: 800
          }
        });
    });

  $( ".imgBox" ).draggable();

  $(".trash")
    .droppable({
      accept: ".imgBox",
      drop: function(event, ui){
        $(".imgBox").hide("fold");
      }
    })
    .resizable({
      animate: true
    })

} );
