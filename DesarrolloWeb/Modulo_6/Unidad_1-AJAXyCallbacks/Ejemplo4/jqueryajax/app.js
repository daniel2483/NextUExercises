// URL http://pokeapi.co/api/v2/pokemon-form/#pokemon
for (var i=1;i<=80;i++){
  $.ajax({
    url: 'http://pokeapi.co/api/v2/pokemon-form/' + i,
    type: 'GET',
    data: {},
    success: function(data){
      $('.pokemons').append('<li><img src="" ></img>' + data.name + '</li>')
    }
  })
}
