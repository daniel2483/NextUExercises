
document.observe("dom:loaded", function(){

  // var cuadros = $$('.cuadro');
  //
  // for (var i = 0; i < cuadros.length; i++) {
  //   cuadros[i].observe('click',function(){
  //     this.down().setStyle({display: 'block'});
  //   })
  // }

  $('tablero').observe('click', function(event){
    var bloqueClickeado = event.findElement();
    bloqueClickeado.down().setStyle({display: 'block'});
  })


})
