self.addEventListener("message",function(e){
  // Almacenamos el objeto localStorage en una variable
  var Storage = JSON.parse(e.data)
  console.log(Storage);
  // Verificar si localStorage tiene alguna
  if (Storage.length > 0 && Storage.hasOwnProperty('usuario')) {
    // Si la llave usuario existe en localStorage mostrar el formulario de reserva
    valor = true
  } else {
    // Si no existe se debe mostrar el formulario de regisro
    valor = false
  }
  self.postMessage(valor);
}
