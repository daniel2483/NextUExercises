$(document).ready(function() {
    $('select').material_select();

    $('.preloader-wrapper').hide()
    $( document ).ajaxStart(function() {
      $( ".preloader-wrapper" ).show();
    });
    $( document ).ajaxStop(function() {
      $( ".preloader-wrapper" ).hide();
    });

    // Código para el uso de AJAX para envio de datos de un form POST
    $('.desc-form').submit(function(event){
      //console.log("TEST")
      var categoria = $("select#categoria").children("option:selected").val();
      var descripcion = $.trim($('#descripcion').val());
      console.log("Categoria: "+categoria);
      console.log("Descripción: "+descripcion);

      event.preventDefault(); // Para evitar que el formulario se envíe por defecto

      $.ajax(
        {
          url:'./descripcion.php',
          type:'post',
          data: {categoria:categoria, descripcion:descripcion}
        }
      ).done(function(data){
        alert("La categoría y Descripción han sido actualizadas");
      })
    })


});
