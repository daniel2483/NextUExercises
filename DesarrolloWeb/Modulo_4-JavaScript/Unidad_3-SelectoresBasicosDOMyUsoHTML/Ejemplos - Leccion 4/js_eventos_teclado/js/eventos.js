
function mostrar_tecla(event){
  var tecla = event.which || event.keyCode;
  document.querySelector("#tarjeta_muestra_tecla #texto_tarjeta")
    .innerHTML = "Presionaste la tecla: " + String.fromCharCode(tecla);
}

function cambiarTituloVerde(){
  document.querySelector("#tarjeta_cambia_color .card-image span").className = "card-title green";
}

function cambiarTituloNegro(){
  document.querySelector("#tarjeta_cambia_color .card-image span").className = "card-title black";
}

function teclaTextBox(event){
  var tecla = event.which || event.keyCode;
  document.querySelector("#tarjeta_presiona_input_text .card-action a")
    .innerHTML = "Presionaste la tecla: " + String.fromCharCode(tecla);
}

document.onkeypress = mostrar_tecla;
document.onkeydown = cambiarTituloVerde;
document.onkeyup = cambiarTituloNegro;
document.querySelector("#tarjeta_presiona_input_text #tecla_texto").onkeypress = teclaTextBox;
