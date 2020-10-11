

function changeColor1(elemento){
  elemento.style.background = "#4d62d0";
  elemento.children[0].style.background = "inherit";
}

function changeColor2(elemento){
  elemento.style.background = "#149c5f";
  elemento.children[0].style.background = "inherit";
}

function changePanelSize(elemento)
{
  items = document.querySelectorAll("div[class^='item']");
  items.length;
  i=0;
  for (i; i < items.length ; i++){
    items[i].style.width = "4%";
    items[i].style.backgroundColor = "#4d62d0";
    var cantidadHijos = items[i].children.length;
    for (i2 = 0 ; i2 < items[i].children.length ; i2++){
      items[i].children[i2].style.display = "none";
    }
  }

  var elementoString = elemento;
  if(elementoString == null)
  {
    console.log("Elemento Nulo ...");
  }
  else
  {
    console.log("Elemento No Nulo ...");
    elementoString.style.width = "96%";
    elementoString.style.backgroundColor = "white";
    elementoString.children.length;

    for ( i = 0 ; i < elementoString.children.length; i++ )
    {
      elementoString.children[i].style.display = "block";
    }
  }

}

function Ancho18Porciento(elemento)
{
  elemento.style.width = "18%";
}


function Ancho20Porciento(elemento)
{
  elemento.style.width = "20%";
}

function h1ContenidoCentralSmall()
{

  var titulos = document.querySelectorAll(".contenido-container h1");
  for ( i=0 ; i < titulos.length ; i++){
    titulos[i].style.fontSize="small";
  }

}


function h1ContenidoCentralLarge()
{

  var titulos = document.querySelectorAll(".contenido-container h1");
  for ( i=0 ; i < titulos.length; i++){
    titulos[i].style.fontSize="xx-large";
  }

}

//changeColor1("div");
//changePanelSize(document.querySelectorAll("div[class^='item']")[1]);
//Ancho18Porciento(document.querySelectorAll("div[class^='item-']")[1]);
//Ancho20Porciento(document.querySelectorAll("div[class^='item-']")[1]);
//h1ContenidoCentralSmall();
//h1ContenidoCentralLarge();


function DesactivarSonido()
{
  //elmentoVideo.muted = true;

  document.getElementById("speaker-radio").checked = true;
  var elemento = document.getElementsByClassName('boton-speaker audio');
  elemento[0].children[0].setAttribute("src","img/mute.png");
}

function ActivarSonido()
{
  //elmentoVideo.muted = true;

  document.getElementById("speaker-radio").checked = false;
  var elemento = document.getElementsByClassName('boton-speaker audio');
  elemento[0].children[0].setAttribute("src","img/speaker.png");
}

function InputNameModal()
{
  var nombrePersona = document.getElementsByName("nombre")[0].value;
  //return nombrePersona;
  var newElement = document.createElement("h2");
  newElement.innerHTML = "Bienvenido: <br><br>" + nombrePersona ;
  var personaSaludo = document.getElementsByClassName("container-saludo")[0].appendChild(newElement);
  //document.getElementsByClassName('container-saludo')[0].children[0].innerHTML(nombrePersona);

}

function newParagraph(element){
  var newElementParagraph = document.createElement("p");
  newElementParagraph.innerHTML = "Esto es un nuevo Parrafo";
  element.appendChild(newElementParagraph);
}

function newText (element,stringChain)
{
  element.innerHTML = stringChain
}


var Eventos = {
  MouseEncimaBoton1: function(){
    document.getElementsByClassName("boton-accion")[0].style.backgroundColor = "#0CAEFD";
  },
  MouseEncimaBoton2: function(){
    document.getElementsByClassName("boton-speaker")[0].style.backgroundColor = "#0CAEFD";
  },
  MouseEncimaBoton3: function(){
    document.getElementsByClassName("boton-accion")[1].style.backgroundColor = "#0CAEFD";
  },
  MouseEncimaBoton4: function(){
    document.getElementsByClassName("boton-accion")[2].style.backgroundColor = "#0CAEFD";
  },
  MouseEncimaRetroceso: function(){
    document.getElementsByClassName("boton-next")[0].style.backgroundColor = "#0CAEFD";
  },
  MouseEncimaSiguiente: function(){
    document.getElementsByClassName("boton-next")[1].style.backgroundColor = "#0CAEFD";
  },
  MouseFueraBoton1: function(){
    document.getElementsByClassName("boton-accion")[0].style.backgroundColor = "#149c5f";
  },
  MouseFueraBoton2: function(){
    document.getElementsByClassName("boton-speaker")[0].style.backgroundColor = "#149c5f";
  },
  MouseFueraBoton3: function(){
    document.getElementsByClassName("boton-accion")[1].style.backgroundColor = "#149c5f";
  },
  MouseFueraBoton4: function(){
    document.getElementsByClassName("boton-accion")[2].style.backgroundColor = "#149c5f";
  },
  MouseFueraRetroceso: function(){
    document.getElementsByClassName("boton-next")[0].style.backgroundColor = "#149c5f";
  },
  MouseFueraSiguiente: function(){
    document.getElementsByClassName("boton-next")[1].style.backgroundColor = "#149c5f";
  },
  ClickOnMain1: function(){
    changePanelSize(document.querySelectorAll("div[class^='item']")[0]);
  },
  ClickOnMain2: function(){
    changePanelSize(document.querySelectorAll("div[class^='item']")[1]);
  },
  ClickOnMain3: function(){
    changePanelSize(document.querySelectorAll("div[class^='item']")[2]);
  },
  DblClickOnMain1: function(){
    newParagraph(document.querySelectorAll("div[class^='item']")[0]);
  },
  DblClickOnMain2: function(){
    newParagraph(document.querySelectorAll("div[class^='item']")[1]);
  },
  DblClickOnMain3: function(){
    newParagraph(document.querySelectorAll("div[class^='item']")[2]);
  },
  SonidoTecla: function(event){
    var tecla = event.which || event.keyCode;
    tecla = String.fromCharCode(tecla);
    console.log(tecla);
    if (tecla == 0){
      ActivarSonido();
    }
    if (tecla == 9){
      DesactivarSonido();
    }
  },
  LetraSizeSmall: function(){
    h1ContenidoCentralSmall();
  },
  LetraSizeLarge: function(){
    h1ContenidoCentralLarge();
  },
  EnviarNombre: function (){
    InputNameModal();
    var modal = document.getElementById("myModal");
    modal.hidden = true;
    modal.style.display = "none";
    modal.style.disabled = true;
  },
  init: function(){
    document.getElementsByClassName("boton-accion")[0].onmouseover = this.MouseEncimaBoton1;
    document.getElementsByClassName("boton-accion")[0].onmouseout = this.MouseFueraBoton1;
    document.getElementsByClassName("boton-speaker")[0].onmouseover = this.MouseEncimaBoton2;
    document.getElementsByClassName("boton-speaker")[0].onmouseout = this.MouseFueraBoton2;
    document.getElementsByClassName("boton-accion")[1].onmouseover = this.MouseEncimaBoton3;
    document.getElementsByClassName("boton-accion")[1].onmouseout = this.MouseFueraBoton3;
    document.getElementsByClassName("boton-accion")[2].onmouseover = this.MouseEncimaBoton4;
    document.getElementsByClassName("boton-accion")[2].onmouseout = this.MouseFueraBoton4;

    document.getElementsByClassName("boton-next")[0].onmouseover = this.MouseEncimaRetroceso;
    document.getElementsByClassName("boton-next")[0].onmouseout = this.MouseFueraRetroceso;
    document.getElementsByClassName("boton-next")[1].onmouseover = this.MouseEncimaSiguiente;
    document.getElementsByClassName("boton-next")[1].onmouseout = this.MouseFueraSiguiente;


    document.querySelectorAll("div[class^='item']")[0].onclick = this.ClickOnMain1;
    document.querySelectorAll("div[class^='item']")[1].onclick = this.ClickOnMain2;
    document.querySelectorAll("div[class^='item']")[2].onclick = this.ClickOnMain3;

    document.querySelectorAll("div[class^='item']")[0].ondblclick = this.DblClickOnMain1;
    document.querySelectorAll("div[class^='item']")[1].ondblclick = this.DblClickOnMain2;
    document.querySelectorAll("div[class^='item']")[2].ondblclick = this.DblClickOnMain3;

    document.onkeypress = this.SonidoTecla;

    document.querySelectorAll("div[class='boton-accion']")[1].onclick = this.LetraSizeLarge;
    document.querySelectorAll("div[class='boton-accion']")[2].onclick = this.LetraSizeSmall;

    document.querySelector(".boton-check").onclick= this.EnviarNombre;
  }
}

Eventos.init();

//elemento[0].children[0].setAttribute("src","img/speaker.png");
