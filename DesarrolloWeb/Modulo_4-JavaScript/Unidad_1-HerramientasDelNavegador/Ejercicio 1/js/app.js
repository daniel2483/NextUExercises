var calendarioObject = document.getElementById('calendario')
calendarioObject.addEventListener('click',mensajeConsola)

function mensajeConsola(event){
  var posicionx = event.clientX
  var posiciony = event.clientY
  var resuladoConsola = "Click en Imagen Exitosa"
  console.log(resuladoConsola + " X: " + posicionx + " Y: " + posiciony )
}
