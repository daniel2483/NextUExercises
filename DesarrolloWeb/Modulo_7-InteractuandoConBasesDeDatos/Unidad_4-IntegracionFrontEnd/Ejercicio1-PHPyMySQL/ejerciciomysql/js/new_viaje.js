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

})


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
          $('#ciudad_origen').append("<option value='"+index+"'>"+value.nombre+"</option>");
          $('#ciudad_destino').append("<option value='"+index+"'>"+value.nombre+"</option>");
        })
        $.each(php_response.vehiculos,function(index,value){
          //console.log("Index: "+index+" | Value: "+value.nombre);
          $('#vehiculo').append("<option value='"+index+"'>"+value.placa+"("+ value.fabricante + " " + value.referencia + ")</option>");
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
