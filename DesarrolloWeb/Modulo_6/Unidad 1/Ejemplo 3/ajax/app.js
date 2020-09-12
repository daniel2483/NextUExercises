$(document).ready(function(){

  var inputUser = $('#username');
  //console.log("Input User: " + inputUser)
  var URL = 'https://api.github.com/users/'
  inputUser.on('keypress',function(e){
    if (e.which === 13){
      ajaxAsync()
    }
  })

  function ajaxAsync(){
    var URL = 'https://api.github.com/users/'
    var username = inputUser.val().trim().toLowerCase()
    if (username !== ""){
      var URLUser = URL + username
      $.ajax({
        url: URLUser,
        type: 'GET',
        async: true,
        success: function(response){
          var data = response
          if(data.message && data.message == "Not Found"){
            alert('El usuario no existe en Github')
          }
          else{
            $('img').attr('src', data.avatar_url)
            $('.name').text(data.name)
            $('.username').text(data.login)
            $('.email').text(data.email)
            $('.company').text(data.company)
            $('.location').text(data.location)
            $('.followers').text(data.followers)
          }
        }
      })
    }
    else {
      alert('Debe ingresar un nombre de usuario')
    }
  }

})
