$(function(){
   $('.datepicker').pickadate({
      selectMonths: true,
      format: 'yyyy-mm-dd'
    });

  $('.timepicker').timepicker({
    timeFormat: 'H:mm',
    interval: 30,
    minTime: '5',
    maxTime: '9:00pm',
    defaultTime: '11',
    startTime: '5:00',
    dynamic: false,
    dropdown: true,
    scrollbar: true
  });

  $('#logout').click(function(){
    logoutRequest();
  })

  $('#ciudad_origen').on('change', function(){
    var selected = $('#ciudad_origen option:selected').text();
    $(`#ciudad_destino option:contains(${selected})`).attr('disabled', 'disabled');
    $("#ciudad_destino").material_select();
  })

  $('form').on('submit', function(event){
    event.preventDefault();

  })

  getSelects();

  // Function use when click on new viaje button
  $('#enviar').on('click', function(){
    var ciudad_orig_id = $('#ciudad_origen').val();
    var vehiculo_placa = $('#vehiculo').val();
    var ciudad_dest_id = $('#ciudad_destino').val();
    var conductor_id = $('#conductor').val();
    var fecha_salida = $('#fecha_salida').val();
    var hora_salida = $('#hora_salida').val();
    alert("Ingresando nuevos datos a la tabla:<br>Ciudad Origen: "+ciudad_orig_id+"<br>Ciudad Destino: "+ciudad_dest_id+"<br>Vehiculo: "+vehiculo_placa+"<br>Condutor: "+conductor_id+"<br>Fecha Salida: "+fecha_salida+"<br>Hora Salida: "+hora_salida );
    $.ajax({
      url: 'server/add_viaje.php',
      dataType: 'json',
      data: {ciudad_orig_id: ciudad_orig_id,ciudad_dest_id: ciudad_dest_id,vehiculo_placa: vehiculo_placa,conductor_id:conductor_id,fecha_salida:fecha_salida,hora_salida:hora_salida},
      cache: false,
      type: 'POST',
      success: function(php_response){

      },
      error: function(){
        alert("No se ha ingresado el nuevo viaje.");
      }

    })
  })

})


// Function used to get the dropdown list
function getSelects(){
  $.ajax({
    url: 'server/select_info.php',
    dataType: 'json',
    cache: false,
    type: 'POST',
    success: function(php_response){
      // Si el usuario se encuentra logueado
      if (php_response.msg == 'OK'){
        //alert(php_response.ciudades.length);
        //alert(php_response.ciudades[0].nombre);
        $.each(php_response.ciudades,function(index,value){
          //console.log("Index: "+index+" | Value: "+value.nombre);
          $('#ciudad_origen').append("<option value='"+value.id+"'>"+value.nombre+"</option>");
          $('#ciudad_destino').append("<option value='"+value.id+"'>"+value.nombre+"</option>");
        })
        $.each(php_response.vehiculos,function(index,value){
          //console.log("Index: "+index+" | Value: "+value.nombre);
          $('#vehiculo').append("<option value='"+value.placa+"'>"+value.placa+"("+ value.fabricante + " " + value.referencia + ")</option>");
        })
        $.each(php_response.conductores,function(index,value){
          //console.log("Index: "+index+" | Value: "+value.nombre);
          $('#conductor').append("<option value='"+value.id+"'>"+value.nombre+"</option>");
        })

      }
      else{
        alert("Error: " + php_response.msg);
        window.location.href = 'index.html';
      }

    },
    error: function(){
      alert("Ha habido un error con el servidor, obtiendo los valores de las listas.");
    }
  })
}





function logoutRequest(){
  $.ajax({
    url: 'server/logout.php',
    dataType: "text",
    cache: false,
    processData: false,
    contentType: false,
    type: 'GET',
    success: function(php_response){
      window.location.href = 'index.html';
    },
    error: function(){
      alert("error en la comunicación con el servidor");
    }
  })
}
