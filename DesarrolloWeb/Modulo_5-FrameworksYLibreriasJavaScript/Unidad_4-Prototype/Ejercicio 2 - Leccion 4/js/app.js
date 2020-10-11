
var $j = jQuery.noConflict();

function bloqueHandler(){
  if ($('activarJuego').getValue()=='on') {

      $('tablero').observe('click', function(event){
        counter++;
        clickInicial++;
        imagen2 = "";
        //console.log(counter);
        if(counter <= 2 ){
        var bloqueClickeado = event.findElement();
        bloqueClickeado.down().show();
        if (counter == 1){
          //console.log(bloqueClickeado);
          cuadro1 = bloqueClickeado
          imagen1 = bloqueClickeado.childElements()[0].readAttribute('src');
        }
        if (counter == 2){
          //console.log(bloqueClickeado);
          cuadro2 = bloqueClickeado
          imagen2 = bloqueClickeado.childElements()[0].readAttribute('src');
        }
        if (imagen1 === imagen2 && counter == 2){
          alreadyFound.delay(1);
          pairsFoundedCounter++;
          console.log(pairsFoundedCounter);
          }
        }
        if (check2Clicks()) {
          hideAll.delay(1);
        }

        if(clickInicial== 1){

          //timer = new Timer();
          timer.start({precision: 'secondTenths'});
          timer.addEventListener('secondTenthsUpdated', function (e) {
          //horasInput = timer.getTimeValues().hours;
          $$('.clock-panel #Horas')[0].update(timer.getTimeValues().hours);
          $$('.clock-panel #Minutos')[0].update(timer.getTimeValues().minutes);
          $$('.clock-panel #Segundos')[0].update(timer.getTimeValues().seconds);
          $$('.clock-panel #Centesimas')[0].update(timer.getTimeValues().secondTenths);
          });
        }

        if(pairsFoundedCounter == 10){
          console.log("End Game! You Won!");
          timer.stop();
        }


      });

  }else{
    pairsFoundedCounter = 0;
    clickInicial = 0;
    changeSwitchOff();
    ramdomGame();
    //timer.stop();
    timer.reset();
    timer.stop();
    //console.log("Now is Off");
    $('tablero').stopObserving('click');
  }
}






document.observe("dom:loaded", function(){
  counter = 0;
  clickInicial = 0;
  lastPairFlag = 0;
  pairsFoundedCounter = 0;
  timer = new easytimer.Timer();
  hideAll();
  bloqueHandler();
  $('activarJuego').observe('change', bloqueHandler);

  //console.log(imagenArray.length);
  ramdomGame();
  //myArray = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  //console.log(shuffle(myArray));

})





//Estas funciones no hay que codificarlas durante la captura, ya deben estar creadas antes de capturar

function hideAll(){
  $$('.contenido').each(function(item){
    item.hide();
    //console.log(item);
  })
  counter=0;
}

function check2Clicks(){
  if (getMostrados().length==2) {
    return true;
  }else return false;
  if(pairsFoundedCounter == 9){lastPairFlag=1}
}

function getMostrados(){

  var imgMostradas = new Array()
  var i = 0;
  $$('.contenido').each(function(item, index){
    if(item.visible()){
      imgMostradas[i]=item;
      i++;
    }
  });

  return imgMostradas;
}

function alreadyFound(){
  cuadro1.setStyle({opacity: 0});
  cuadro2.setStyle({opacity: 0});
}


function changeSwitchOff(){
  $$('.cuadro').each(function(item){
    item.setStyle({opacity: 1});
  })
}


function ramdomGame(){
  imagenArray = [];
  $$('.contenido').each(function(item){
    imagenArray.push(item);
    //item.remove();
  });

  //console.log(imagenArray);
  shuffle(imagenArray);
  //cuadros = "";
  //console.log(imagenArray);
  for ( i = 0 ; imagenArray.length > i ; i++){
    //console.log(imagenArray[i]);
     //cuadros = cuadros.concat(imagenArray[i])
    //$$('.cuadro')[i].remove();
    $$('.cuadro')[i].update(imagenArray[i]);
  }

}

function shuffle(array) {
    var ctr = array.length, temp, index;

// While there are elements in the array
    while (ctr > 0) {
// Pick a random index
        index = Math.floor(Math.random() * ctr);
// Decrease ctr by 1
        ctr--;
// And swap the last element with it
        temp = imagenArray[ctr];
        array[ctr] = array[index];
        array[index] = temp;
    }
    return array;
}
