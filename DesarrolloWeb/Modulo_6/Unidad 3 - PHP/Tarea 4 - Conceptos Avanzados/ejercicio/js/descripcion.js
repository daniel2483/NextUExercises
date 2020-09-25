$(document).ready(function() {
    $('select').material_select();

    $('.preloader-wrapper').hide()
    $( document ).ajaxStart(function() {
      $( ".preloader-wrapper" ).show();
    });
    $( document ).ajaxStop(function() {
      $( ".preloader-wrapper" ).hide();
    });


});
