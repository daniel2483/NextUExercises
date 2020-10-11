$(function(){
  $('select').material_select();
  $('.datepicker').pickadate({
  selectMonths: true,
  selectYears: 200,
  months_full: [ 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre' ],
  months_short: [ 'En', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic' ],
  weekdays_full: [ 'Domingo', 'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sábado' ],
  weekdays_short: [ 'Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab' ],
});
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
    var nombre = $("input[name=nombre]").val();
    var apellido = $("input[name=apellido]").val();
    var tipo_identificacion = $("select[name=tipo_id]").children("option:selected").val();
    var identificacion = $("input[name=identificacion]").val();
    var fecha_nacimiento = $("input[name=fecha_nacimiento]").val();
    var genero = $("input[name=genero]:checked"). val();
    var estado_civil = $("select[name=estado_civil]").children("option:selected").val();
    var tipo_telefono = $("select[name=tipo_telefono]").children("option:selected").val();
    var telefono = $("input[name=telefono]").val();
    var pais = $("input[name=pais]").val();
    var ciudad = $("input[name=ciudad]").val();
    //var foto = $("input[name=profile-img]")


    console.log("Nombre: "+nombre+" "+apellido);
    console.log("ID Tipo: "+tipo_identificacion);
    console.log("ID: "+identificacion);
    console.log("Fecha de Nacimiento: "+fecha_nacimiento);
    console.log("Género: "+genero);
    console.log("Estado Civil: "+estado_civil);
    console.log("Tipo de Teléfono: "+tipo_telefono + " | Número: "+telefono);
    console.log("País: "+pais + " | Ciudad: "+ciudad);
    //console.log("Foto: "+foto);

    event.preventDefault(); // Para evitar que el formulario se envíe por defecto

    $.ajax(
      {
        url:'./info_basica.php',
        type:'post',
        data: {nombre:nombre,
                apellido:apellido,
                tipo_identificacion:tipo_identificacion,
                identificacion:identificacion,
                fecha_nacimiento:fecha_nacimiento,
                genero:genero,
                estado_civil:estado_civil,
                tipo_telefono:tipo_telefono,
                telefono:telefono,
                pais:pais,
                ciudad:ciudad
                }
      }
    ).done(function(data){
      alert(data);
    })
  })

})
