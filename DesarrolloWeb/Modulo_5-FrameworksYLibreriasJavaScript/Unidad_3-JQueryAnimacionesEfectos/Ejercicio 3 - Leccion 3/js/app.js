
function derecha(elemento){
  var doubleTime=1;
  var leftVal = "";
  if($(elemento).attr('id') == "arquero")
  {
    doubleTime=2;
    leftVal = "+=240"
  }
  else{
    doubleTime=1;
    leftVal = "+=750"
  }
  $(elemento).animate(
    {
      left: leftVal
    }, 500*doubleTime, function(){
      izquierda(elemento)
    }
  )
}

function izquierda(elemento){
  var doubleTime=1;
  var leftVal = "";
  if($(elemento).attr('id') == "arquero")
  {
    doubleTime=2;
    leftVal = "-=240"
  }
  else {
    doubleTime=1;
    leftVal = "-=750"
  }
  $(elemento).animate(
    {
      left: leftVal
    }, 500*doubleTime, function(){
      derecha(elemento)
    }
  )
}

function arriba(elemento){
  $(elemento).animate(
    {
      top: "-=400"
    }, 500, function(){
      abajo(elemento)
    }
  )
}

function abajo(elemento){
  $(elemento).animate(
    {
      top: "+=400"
    }, 500, function(){
      arriba(elemento)
    }
  )
}


$(function(){
  var vecesPresionada=0;
  var posHorizontal;
  var posVertical;
  $(document).on("keypress",function(e){

    if (e.which==32) {
      e.preventDefault();
      vecesPresionada++;
      if (vecesPresionada==1) {
        derecha($("#fHorizontal"));
      }else if (vecesPresionada==2) {
        $("#fHorizontal").stop();
        arriba($("#fVertical"));
      }else if (vecesPresionada==3) {
        $("#fVertical").stop();
        posHorizontal = $("#fHorizontal").css("left");
        posVertical = $("#fVertical").css("top");
        console.log("Horizontal: " + posHorizontal + " Vertical: " + posVertical);
      }
    }
  });

  $("#balon").on("click", function(){
    var posHorizontalpx = (posHorizontal.substring(0, posHorizontal.length - 2));
    var posVerticalpx = (posVertical.substring(0, posVertical.length - 2));
    console.log("Horizontal: " + posHorizontalpx + " Vertical: " + posVerticalpx);
    posHorizontalpx = parseFloat(posHorizontalpx) + 9.5;
    posVerticalpx = parseFloat(posVerticalpx) + 10.5;
    console.log("Horizontal Corregido: " + posHorizontalpx + " Vertical Corregido: " + posVerticalpx);
    if(parseFloat(posHorizontalpx) <= 1010
      && parseFloat(posHorizontalpx)  >= 478
      && parseFloat(posVerticalpx) <= 410.5
      && parseFloat(posVerticalpx) >= 70.5){
      console.log("Por dentro!!!"); // Es Gool
      $(this)
      .animate(
        {
          top: posVerticalpx + "px",
          left: posHorizontalpx + "px"
        },600)
        .animate(
            {
              width: "-=70"
            },
            {
              step: function(now){
                $(this).css("transform","rotate("+now*10+"deg)")
              },
              queue: false,
              duration: 800,
              complete: function(){
                var x= parseFloat(posHorizontalpx);
                var y= parseFloat(posVerticalpx);
                var centro = parseFloat($("#arquero").css("left"))+235;
                  if(((x>(centro-55))&&(x<(centro+23)))&&(y>154&&y<236)){ //Validaciones si pega en el arquero
                    $(this)
                      .css("zIndex","4")
                      .animate(
                        {
                          top: "-50px"
                        },{
                          step: function(now, fx){
                            $(this).css("transform","rotate("+now*2+"deg)");
                          },
                          duration: 500
                        }
                      )
                  }else if(((x>(centro-128))&&(x<(centro+95)))&&(y>280&&y<362)){
                    $(this)
                      .css("zIndex","4")
                      .animate(
                        {
                          top: "-50px"
                        },{
                          step: function(now, fx){
                            $(this).css("transform","rotate("+now*2+"deg)");
                          },
                          duration: 500
                        }
                      )
                  }else if(((x>(centro-185))&&(x<(centro+143)))&&(y>226&&y<280)){
                    $(this)
                      .css("zIndex","4")
                      .animate(
                        {
                          top: "-50px"
                        },{
                          step: function(now, fx){
                            $(this).css("transform","rotate("+now*2+"deg)");
                          },
                          duration: 500
                        }
                      )
                  }else if(((x>(centro-122))&&(x<(centro-88)))&&(y>362&&y<432)){
                    $(this)
                      .css("zIndex","4")
                      .animate(
                        {
                          top: "380px",
                          left: "-50px"
                        },{
                          step: function(now, fx){
                            $(this).css("transform","rotate("+now*2+"deg)");
                          },
                          duration: 500
                        }
                      )
                  }else if (((x>(centro+63))&&(x<(centro+97)))&&(y>362&&y<432)) {
                    $(this)
                      .css("zIndex","4")
                      .animate(
                        {
                          top: "380px",
                          left: "1600px"
                        },{
                          step: function(now, fx){
                            $(this).css("transform","rotate("+now*2+"deg)");
                          },
                          duration: 500
                        }
                      )
                  }else{
                    $(this).css("zIndex","3"); //Si no sucede nada de lo anterior se indica que se marco el Gol
                    $("#arquero").css("zIndex","4");
                    $(this)
                      .animate(
                        {
                          top: "400px",
                        },{
                          step: function(now, fx){
                            $(this).css("transform","rotate("+now*2+"deg)")
                          },
                          duration: 1000,
                          complete: function() {
                            $("h1").fadeIn(1000, function(){
                              $(this)
                                .css("color","green")
                            })
                          }
                        }
                      )
                  }

              }
            }
          )
        .delay(1000)
        .animate(
          {
            top: "400px"
          }, 1000
        )
      }
      else if(parseFloat(posHorizontalpx) >= 1011
          || parseFloat(posHorizontalpx)  <= 478
          || parseFloat(posVerticalpx) <= 56){
        console.log("Not DONE outside!!!"); // Fuera del marco
        $(this)
        .animate(
          {
            top: posVerticalpx + "px",
            left: posHorizontalpx + "px"
          },600)
          .animate(
              {
                width: "-=96"
              },
              {
                step: function(now){
                  $(this).css("transform","rotate("+now*10+"deg)")
                },
                queue: false,
                duration: 1200
              }
            )
          .delay(1000)
          .animate(
            {
              top: "400px"
            }, 1000
          )
        }
        else if(parseFloat(posHorizontalpx) >= 460
            && parseFloat(posHorizontalpx)  <= 478
            && parseFloat(posVerticalpx) >= 70.5){
          console.log("Palo izquierdo!!!"); // Palo izquierdo
          $(this)
          .animate(
            {
              top: posVerticalpx + "px",
              left: posHorizontalpx + "px"
            },600)
            .animate(
                {
                  width: "-=70"
                },
                {
                  step: function(now){
                    $(this).css("transform","rotate("+now*10+"deg)")
                  },
                  queue: false,
                  duration: 1200
                }
              )
            .delay(500)
            .animate(
              {
                left: "-=600px"
              }, 250
            )
          }
          else if(parseFloat(posHorizontalpx) >= 1010
              && parseFloat(posHorizontalpx)  <= 1028
              && parseFloat(posVerticalpx) >= 70.5){
            console.log("Palo derecho!!!"); // Palo Derecho
            $(this)
            .animate(
              {
                top: posVerticalpx + "px",
                left: posHorizontalpx + "px"
              },600)
              .animate(
                  {
                    width: "-=70"
                  },
                  {
                    step: function(now){
                      $(this).css("transform","rotate("+now*10+"deg)")
                    },
                    queue: false,
                    duration: 1200
                  }
                )
              .delay(500)
              .animate(
                {
                  left: "+=600px"
                }, 250
              )
            }
            else if(parseFloat(posHorizontalpx) >= 460
                && parseFloat(posHorizontalpx)  <= 1028
                && parseFloat(posVerticalpx) <= 70.5
                && parseFloat(posVerticalpx) >= 56){
              console.log("Palo de arriba!!!"); // Palo Derecho
              $(this)
              .animate(
                {
                  top: posVerticalpx + "px",
                  left: posHorizontalpx + "px"
                },600)
                .animate(
                    {
                      width: "-=70"
                    },
                    {
                      step: function(now){
                        $(this).css("transform","rotate("+now*10+"deg)")
                      },
                      queue: false,
                      duration: 1200
                    }
                  )
                .delay(500)
                .animate(
                  {
                    top: "-=600px"
                  }, 250
                )
              }
      else{
        console.log("NOT DONE!!!");
      }
  });

  // Movimiento al arquero
  derecha($("#arquero"));

  $(".iniciar").on("click", function(){
    console.log("Reload Page!!!!");
     location.reload();
  });

});
