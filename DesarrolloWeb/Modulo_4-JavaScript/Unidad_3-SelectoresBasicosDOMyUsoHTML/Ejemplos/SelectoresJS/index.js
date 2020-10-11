// Varaibles
var nombre;
var apellido;
var email;
var usuario;
var password;
var boton;

// Asignacion
nombre = document.getElementById('nombre');
apellido = document.getElementById('apellido');
email = document.getElementById('email');
usuario = document.getElementById('usuario');
password = document.getElementById('password');
boton = document.getElementById('btn-guardar');

console.log(password);

function mostrarAlerta(mensaje){
  alert('El usuario realizo un click sobre el boton');
}

boton.addEventListener('click',mostrarAlerta)
