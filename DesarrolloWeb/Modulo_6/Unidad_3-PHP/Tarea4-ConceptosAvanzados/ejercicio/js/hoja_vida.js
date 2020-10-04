$(function(){

  $('.desc-form').submit(function(event){
    console.log("Test");
    event.preventDefault(); // Para evitar que el formulario se envíe por defecto
    var file_data = $('#document').prop('files')[0];
    //console.log(file_data);
    var form_data = new FormData();
    form_data.append('file',file_data);
    $.ajax({
      url:'./hoja_vida.php',
      dataType: 'json',
      data: form_data,
      cache: false,
      contentType: false,
      processData: false,
      type: 'post',
      success: function(data){
        //console.log(data.nombre_archivo);
        alert(data);
      },
      error: function(){
      }
    })

  });

})
