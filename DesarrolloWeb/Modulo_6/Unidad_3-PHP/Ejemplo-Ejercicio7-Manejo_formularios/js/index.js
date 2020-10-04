$(function(){

  $('select').material_select();
  $('.datepicker').pickadate({
    selectMonths: true,
    selectYears: 50
  });

  //$('form').submit(function(){
  //  $('select').material_select('destroy');
  //  $('.datepicker').pickadate('destroy');
  //});

  // Código para el uso de AJAX para envio de datos de un form
  $('#formulario').submit(function(event){
    console.log("TEST")
    var nombre = $('form').find('input[name="nombre_usuario"]').val();
    console.log(nombre);
    event.preventDefault(); // Para evitar que el formulario se envíe por defecto
    $.ajax(
      {
        url:'./recepcion_formulario.php',
        type:'post',
        data: {nombre:nombre}
      }
    ).done(function(data){
      alert(data);
    })
  })
})
