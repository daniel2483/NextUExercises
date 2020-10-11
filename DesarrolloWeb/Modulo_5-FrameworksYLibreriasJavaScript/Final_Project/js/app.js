$( document ).ready(function() {

  timer = new easytimer.Timer();
  firstGame = 0;

  function titleEffect(elemento){

  }

  jQuery.fn.swap = function(b){
    // method from: http://blog.pengoworks.com/index.cfm/2008/9/24/A-quick-and-dirty-swap-method-for-jQuery
    b = jQuery(b)[0];
    var a = this[0];
    var t = a.parentNode.insertBefore(document.createTextNode(''), a);
    b.parentNode.insertBefore(a, b);
    t.parentNode.insertBefore(b, t);
    t.parentNode.removeChild(t);
    return this;
  };

  function ramdomCandies (){

    countDownTimer();

    countingMovements = 0;
    $('#movimientos-text').html(countingMovements);
    $('.btn-reinicio').html("Reiniciar");
    columnCandies('.col-1','col-1');
    columnCandies('.col-2','col-2');
    columnCandies('.col-3','col-3');
    columnCandies('.col-4','col-4');
    columnCandies('.col-5','col-5');
    columnCandies('.col-6','col-6');
    columnCandies('.col-7','col-7');

    $("img").attr("width","90");

    //mouseOnCandy("img","img");
    //mouseOnCandy("img","img",'y');

    candiesAmount = $("img").length;
    // Making candies Draggable and Droppable with their limits
    for(i = 0 ; i < candiesAmount; i++){
      var candyElement = $("img")[i];
      //var parentCandy = $("img")[i].id;
      var parentCandy = ($(candyElement).parent()).attr("class");
      //console.log (parentCandy);
      var column =  column = (parseInt(parentCandy[parentCandy.length -1]));
      //var elementId = $("img")[i];
      var columnElement = $(".col-" + column + " img");
      var row = columnElement.index(candyElement);


      var candyUp = row - 1;
      var candyDown = row + 1;
      var candyLeft = column - 1;
      var candyRight = column + 1;

      if (candyUp < 0){candyUp = "notexist";}
      if (candyDown > 6){candyDown = "notexist";}
      if (candyLeft < 1){candyLeft = "notexist";}
      if (candyRight > 7){candyRight = "notexist";}

      //console.log("X Position: " + column + " Y Position: " + row);
      //console.log("Candy Up: " + candyUp + " Candy Down: " + candyDown + " Candy Left: " + candyLeft + " Candy Right: " + candyRight);
      mouseOnCandy($(candyElement),candyUp,candyDown,candyLeft,candyRight,column,row);
    }

    $("img").mousedown(function() {
      //console.log(this);
      //var parentCandy = ($(this).parent()).attr("class");
      //column = (parseInt(parentCandy[parentCandy.length -1]));
      //console.log($(this).attr('id'));
      //var elementId = $($(this))[0];
      //var columnElement = $(".col-" + column + " img");
      //row = columnElement.index(elementId);
      //console.log(elementId);
      //console.log(columnElement);
      //var candyUp = row - 1;
      //var candyDown = row + 1;
      //var candyLeft = column - 1;
      //var candyRight = column + 1;

      //if (candyUp < 0){candyUp = "notexist";}
      //if (candyDown > 6){candyDown = "notexist";}
      //if (candyLeft < 1){candyLeft = "notexist";}
      //if (candyRight > 7){candyRight = "notexist";}

      //console.log("X Position: " + column + " Y Position: " + row);
      //console.log("Candy Up: " + candyUp + " Candy Down: " + candyDown + " Candy Left: " + candyLeft + " Candy Right: " + candyRight);
      //mouseOnCandy($(this),candyUp,candyDown,candyLeft,candyRight,column,row);
    });
    //console.log(columnArray);
  }



  function mouseOnCandy(elementDrag,candyUp,candyDown,candyLeft,candyRight,column,row) {
    $(elementDrag).draggable({ opacity: 0.8,revert: true});
    if (candyUp < 0){console.log("Up does not Exist");}
    else{
      element = $(".col-" + column)[candyUp];
      console.log(element);
      candyDroppable(element,elementDrag);
    }
    if (candyDown > 6){console.log("Down does not Exist");}
    else {
      element = $(".col-" + column)[candyDown];
      console.log(element);
      candyDroppable(element,elementDrag);
    }
    if (candyLeft < 1){console.log("Left does not Exist");}
    else{
      element = $(".col-" + candyLeft)[row];
      console.log(element);
      candyDroppable(element,elementDrag);
    }
    if (candyRight > 7){console.log("Right does not Exist");}
    else{
      element = $(".col-" + candyRight)[row];
      console.log(element);
      candyDroppable(element,elementDrag);
    }
  }

  function candyDroppable(elementDrop,elementDrag){
    $(elementDrop).droppable({
    accept: elementDrag,
    activeClass: "ui-state-hover",
    hoverClass: "ui-state-active",
    drop: function( event, ui ) {
        countingMovements++;
        $('#movimientos-text').html(countingMovements);
        var draggable = ui.draggable, droppable = $(this),
            dragPos = draggable.position(), dropPos = droppable.position();

        draggable.css({
            //left: dropPos.left+'px',
            //top: dropPos.top+'px'
        });

        droppable.css({
            //left: dragPos.left+'px',
            //top: dragPos.top+'px'
        });
        draggable.swap(droppable);
    }
  });
  }

  function columnCandies(columnElement,col){
    var columnArray = [];
    var id = col;
    for ( i = 0 ; i < 7 ; i++ ){
      var value = Math.floor((Math.random() * 4)+1);
      //var column = columnElement;
      switch(value) {
        case 1:
          var candy = "<img src='image/1.png' id='"+ id + "-row-" + i + "'>";
          var htmlCandy = $(columnElement).append(candy);
          //fromTopAnimation(htmlCandy);
          columnArray.push(candy);
          break;
        case 2:
          var candy = "<img src='image/2.png' id='" + id + "-row-" + i + "'>";
          var htmlCandy = $(columnElement).append(candy);
          //fromTopAnimation(htmlCandy);
          columnArray.push(candy);
          break;
        case 3:
          var candy = "<img src='image/3.png' id='" + id + "-row-" + i + "'>";
          var htmlCandy = $(columnElement).append(candy);
          //fromTopAnimation(htmlCandy);
          columnArray.push(candy);
          break;
        default:
          var candy = "<img src='image/4.png' id='" + id + "-row-" + i + "'>";
          var htmlCandy = $(columnElement).append(candy);
          //fromTopAnimation(htmlCandy);
          columnArray.push(candy);
          // code block
      }
    }
  }

  function countDownTimer () {
    firstGame = 1;
    timer.start({countdown: true, startValues: {seconds: 120}});
    $('#timer').html(timer.getTimeValues().toString());
    timer.addEventListener('secondsUpdated', function (e) {
      $('#timer').html(timer.getTimeValues().toString());
      var timestamp = $('#timer').html();
      if(timestamp === "00:00:00"){}
    });
    timer.addEventListener('targetAchieved', function (e) {
      var options = {};
      $(".panel-tablero").hide('fold',options,1200, function(){
        var end_game = $(".panel-scoreEnd h2").length;
        if(end_game == 0){
          $(".panel-scoreEnd").prepend("<h2 class='titulo-over'>Juego Terminado</h2>");
        }
        });
      $(".time").hide('fold',options,1000);
      $(".panel-score").addClass("panel-scoreEnd",1000);
    });
  }

  function fromTopAnimation(element){
    $(elemento).animate(
      {
        top: "-=400"
      }, 500, function(){

      }
    )
  }

  $('.btn-reinicio').on('click', function(){
    // Inicializa el juego
    $('.col-1').html("");
    $('.col-2').html("");
    $('.col-3').html("");
    $('.col-4').html("");
    $('.col-5').html("");
    $('.col-6').html("");
    $('.col-7').html("");
    ramdomCandies();
    //$(".panel-tablero").hide();

    // The Game is restarting before the Game ends
    var htmlBoton = $(".btn-reinicio").html();
    if(htmlBoton === "Reiniciar"){
      timer.reset();
      timer.addEventListener('reset', function (e) {
        $('#timer').html(timer.getTimeValues().toString());
      });
    }

    // If the game is restarted after the Game ends
    if(firstGame != 0){
      var options = {};
      //$(".panel-score > .titulo-over").hide('explode',options,1000);
      $(".panel-scoreEnd > h2").fadeOut('fast');
      $(".panel-score").removeClass("panel-scoreEnd",1000);
      $(".time").show('fold',options,1000);
      $(".panel-tablero").show('slide',options,500);
    }
  });

});
