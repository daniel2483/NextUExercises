/*-- FUNCIONES PROPIAS DE LA VISTA --*/
function showNewSearch(){
  $('.back-container').delay(2000).show('slide', { direction: "right" }, 500);
}

function newSearchEvent(){
  $('input[type="text"]').val('');
  $('html, body').animate(
    {
      scrollTop: 0
    },1300, function(){$('.back-container').hide()});
}

/*-- ----------------------------- --*/



/* Función appendHTML que recibe la respuesta de la API como parámetro*/
function appendHTML(response){

  /*INGRESA AQUÍ EL CÓDIGO PARA REALIZAR EL PASO 7 DE LAS INSTRUCCIONES
  *
  *
  *
  *
  **/



/*-- ANIMACIÓN PROPIA DE LA VISTA, NO MODIFICAR --*/
  $('html, body').animate(
    {
      scrollTop: $("#page2").offset().top
    },1300, showNewSearch);
/*-- ------------------------------------------ --*/
}


/* FUNCIÓN DOCUMENT.READY */
$(function(){
  $(window).scrollTop(0)
  $('input[type="text"]').val('');
  $('.back-container').click(newSearchEvent);

})
