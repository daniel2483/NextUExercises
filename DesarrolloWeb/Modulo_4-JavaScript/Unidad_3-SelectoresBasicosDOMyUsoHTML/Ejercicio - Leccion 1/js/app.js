var usuario = {
  nombre:"",
  nombre_usuario:"",
  password:"",
  password_repetida:"",
  email:"",
  fecha_nacimiento:"",
  descripcion:"",
  suscripcion:"",
  ciudad_residencia:"",
  direccion:"",
  telefono:"",
  celular:"",
  nacionalidad:"",
  genero:"",
  tipo_pago:""
}

function PrintConsola(){
  var Nombre = document.getElementsByClassName('nombre');
  console.log('Nombre: ' + Nombre[0].value);
  var NombreUsuario = document.getElementsByClassName('nombre_usuario');
  console.log('Nombre de Usuario: ' + NombreUsuario[0].value);
  var Password = document.getElementsByClassName('password');
  console.log('Password: ' + Password[0].value);
  var PasswordRepetida = document.getElementsByName('password_repetida');
  console.log('Password Segunda Vez: ' + PasswordRepetida[0].value);
  var Email = document.getElementsByName('email');
  console.log('Email: ' + Email[0].value);
  var FechaNacimiento = document.getElementsByName('fecha_nacimiento');
  console.log('Fecha de Nacimiento: ' + FechaNacimiento[0].value);
  var Descripcion = document.getElementsByTagName('textarea');
  console.log('Descripcion: ' + Descripcion[0].value);
  var TipoSuscripcion = document.getElementsByTagName('select');
  console.log('Tipo de Suscripcion: ' + TipoSuscripcion[0].value);
  var CiudadResidencia = document.querySelector("input[name='ciudad_residencia']").value
  console.log('Ciudad de Residencia: ' + CiudadResidencia);
  var Direccion = document.querySelector("input[name='direccion']").value
  console.log('Direccion: ' + Direccion);
  var Telefono = document.querySelectorAll("input[name='telefono']")
  console.log('Telefono: ' + Telefono[0].value);
  var Celular = document.querySelectorAll("input[name='celular']")
  console.log('Celular: ' + Celular[0].value);
  var Nacionalidad = document.querySelectorAll("input[name='nacionalidad']")
  console.log('Nacionalidad: ' + Nacionalidad[0].value);
  var Masculino = document.getElementById("masculino").checked
  console.log('Masculino: ' + Masculino);
  var Femenino = document.getElementById("femenino").checked
  console.log('Femenino: ' + Femenino);
  var Efectivo = document.getElementById("efectivo").checked
  console.log('Efectivo: ' + Efectivo);
  var Credito = document.getElementById("credito").checked
  console.log('Credito: ' + Credito);
}


document.getElementById('submit').addEventListener("click", function(){
  PrintConsola();
})
