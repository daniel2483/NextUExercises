// URL http://pokeapi.co/api/v2/pokemon-form/#pokemon
for (var i=1;i<=80;i++){
  fetch('http://pokeapi.co/api/v2/pokemon-form/' + i, {
      method: 'GET'
  }).then(function (data){
    return data.json();
  }).then(function (json){
    $('.pokemons').append('<li><img src="" ></img>' + json.name + '</li>');
  })

}
