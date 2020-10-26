$(function(){

  $('#login-form').submit(function(event){
    var username = $('#login-form').find('#username').val();
    var passw = $('#login-form').find('#passw').val();
    event.preventDefault();

    $.ajax({
      url: '',
      data: {username: username, passw: passw},
      type: 'POST',
      success: function(){

      },
      error: function(){
        alert("error in ajax form submission");
      }
    });



  });



})
