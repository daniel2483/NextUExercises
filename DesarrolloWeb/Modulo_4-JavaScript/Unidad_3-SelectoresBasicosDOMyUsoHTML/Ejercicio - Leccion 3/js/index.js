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


function DesactivarSonido(elmentoVideo)
{
  elmentoVideo.muted = true;

  document.getElementById("speaker-radio").checked = true;
  var elemento = document.getElementsByClassName('boton-speaker audio');
  elemento[0].children[0].setAttribute("src","img/mute.png");
}

function ActivarSonido(elmentoVideo)
{
  elmentoVideo.muted = true;

  document.getElementById("speaker-radio").checked = false;
  var elemento = document.getElementsByClassName('boton-speaker audio');
  elemento[0].children[0].setAttribute("src","img/speaker.png");
}

function InputNameModal()
{
  var nombrePersona = document.getElementsByName("nombre")[0].value;
  var newElement = document.createElement("h2");
  newElement.innerHTML = nombrePersona ;
  var personaSaludo = document.getElementsByClassName("container-saludo")[0].appendChild(newElement);
}

function newParagraph(element){
  var newElementParagraph = document.createElement("p");
  newElementParagraph.innerHTML = "Esto es un nuevo Parrafo";
  element.appendChild(newElementParagraph);
}

function newText (element,stringChain)
{
  element.innerHTML = stringChain;
}
