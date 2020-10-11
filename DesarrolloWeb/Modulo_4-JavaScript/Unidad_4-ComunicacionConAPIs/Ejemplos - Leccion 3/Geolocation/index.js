var map, infoWindow, pos

if(navigator.geolocation){
  navigator.geolocation.getCurrentPosition(function (position){
    pos = {
      lat: position.coords.latitude,
      lng: position.coords.longitude
    }
    initMap();
  })
}
else {
  alert("Este navegador no soporta Geolocalizacion");
}

function initMap (){
  var mapContainer = document.getElementById('map')
  var config = {
    center:{lat:-36.397, lng: -84.0},
    zoom: 5
  }
  map = new google.maps.Map(mapContainer,config);
  infoVentana = new google.maps.InfoWindow({map: map})
}

var button = document.getElementById("btn-geo");

button.addEventListener("click", function(){
  alert("Se Procedera a buscar la ubicacion en el mapa...");
  map.setCenter(pos);
  map.setZoom(15);
  infoVentana.setPosition(pos);
  infoVentana.setContent('Ubicacion Encontrada');
})
