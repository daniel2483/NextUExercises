
var formRegistro = document.getElementsByClassName('registro')[0],
    formReserva  = document.getElementsByClassName('reserva')[0];

// Almacenamos el objeto localStorage en una variable
var Storage = window.localStorage
// Verificar si localStorage tiene alguna
if (Storage.length > 0 && Storage.hasOwnProperty('usuario')) {
  // Si la llave usuario existe en localStorage mostrar el formulario de reserva
  formReserva.className = "reserva"
  formRegistro.className = "registro hide"
} else {
  // Si no existe se debe mostrar el formulario de regisro
  formRegistro.className = "registro"
  formReserva.className += "reserva hide"
}


var botonRegistro = document.getElementById('registrar'),
    botonReserva  = document.getElementById('reservar')
    inputDocumento = document.getElementById('numDocRes');

    var usuario = {
      nDocumento: "",
      nombreCompleto: "",
      email:"",
      nombreUsuario:"",
      password:""
    }

    var reservacion = {
      nDocumento :"",
      nombreUsuaio:"",
      nombreCompleto:"",
      email:"",
      destino:""
    }

botonRegistro.addEventListener('click', function(e) {
  e.preventDefault()

  usuario.nDocumento = document.getElementById('numDoc').value;
  usuario.nombreCompleto = document.getElementById('nombreCom').value;
  usuario.email = document.getElementById('correo').value; // nombreUsuario
  usuario.nombreUsuario = document.getElementById('nombreUsuario').value;
  usuario.password = document.getElementById('password').value;

  localStorage.setItem('usuario',JSON.stringify(usuario));
  formRegistro.className = "registro hide";
  formReserva.className = "reserva";
})

botonReserva.addEventListener('click', function(e) {
  e.preventDefault()

  reservacion.destino = document.getElementById('destino').value;

  if(reservacion.destino == "" ){
    alert("Debes ingresar el Destino...");
  }
  else{
    reservacion.nDocumento = document.getElementById('numDocRes').value;
    reservacion.nombreUsuario = document.getElementById('nombreUsuarioRes').value;
    reservacion.nombreCompleto = document.getElementById('nombreComRes').value;
    reservacion.email = document.getElementById('correoRes').value;
    reservacion.destino = document.getElementById('destino').value;
    localStorage.setItem('reservacion',JSON.stringify(reservacion));

    formReserva.className = "reserva hide";
    alert("Se ha reservado exitosamente!");
  }

})

inputDocumento.addEventListener('keypress', function(e) {
  if (e.which === 13) {
    var datosUsuario = JSON.parse(localStorage.getItem('usuario'));
    if(document.getElementById('numDocRes').value == datosUsuario.nDocumento){
    document.getElementById('nombreUsuarioRes').value = datosUsuario.nombreUsuario;
    document.getElementById('nombreComRes').value = datosUsuario.nombreCompleto;
    document.getElementById('correoRes').value = datosUsuario.email;
    }
    else{
      alert("Ingrese el numero de documento previamente registrado");
    }
  }
})
