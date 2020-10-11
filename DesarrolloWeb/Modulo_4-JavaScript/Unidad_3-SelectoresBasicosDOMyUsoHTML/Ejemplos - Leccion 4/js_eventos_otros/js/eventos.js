function cambiarRadioButtons()
{
  var estadoRB=document.getElementById('activar_rb').checked;
  if(estadoRB)
  {
    var estado = "true";
    document.getElementById('animales').disabled=false;
    document.getElementById('postres').disabled=false;
    document.getElementById('musica').disabled=false;
  }
  else
  {
    document.getElementById('animales').disabled=true;
    document.getElementById('postres').disabled=true;
    document.getElementById('musica').disabled=true;
  }
}


function cargarPagina()
{
  alert("Se ha cargado toda la pagina");
}

function eventoOnFocus(event)
{
  var seleccion=event.currentTarget.id;
  console.log("Habilitando Lista: " + seleccion);
  switch (seleccion){
    case "animales":
      document.getElementById('sel_animales').disabled=false;
      $(document).ready(function(){$('select').material_select();});
      break;
    case "postres":
      document.getElementById('sel_postres').disabled=false;
      $(document).ready(function(){$('select').material_select();});
      break;
    case "musica":
      document.getElementById('sel_musica').disabled=false;
      $(document).ready(
        function(){$('select').material_select();});
      break;
    default:
  }
}


function eventoOnBlur(event)
{
  var seleccion=event.currentTarget.id;
  console.log("Deshabilitando Listas");
  switch (seleccion){
    case "animales":
      document.getElementById('sel_animales').disabled=true;
      $(document).ready(function(){$('select').material_select();});
      break;
    case "postres":
      document.getElementById('sel_postres').disabled=true;
      $(document).ready(function(){$('select').material_select();});
      break;
    case "musica":
      document.getElementById('sel_musica').disabled=true;
      $(document).ready(function(){$('select').material_select();});
      break;
    default:
  }
}

function asignarEventoRB()
{
  document.getElementById('animales').onfocus=eventoOnFocus;
  document.getElementById('postres').onfocus=eventoOnFocus;
  document.getElementById('musica').onfocus=eventoOnFocus;

  document.getElementById('animales').onblur=eventoOnBlur;
  document.getElementById('postres').onblur=eventoOnBlur;
  document.getElementById('musica').onblur=eventoOnBlur;
}

document.getElementById('activar_rb').onchange = cambiarRadioButtons;
//document.getElementsByTagName('body')[0].onload=cargarPagina;
asignarEventoRB();
