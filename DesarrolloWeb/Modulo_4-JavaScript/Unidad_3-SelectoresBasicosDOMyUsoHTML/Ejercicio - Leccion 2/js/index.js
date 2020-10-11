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
  console.log("Arreglo de Items: " + document.querySelectorAll("div[class^='item']"));
  items.length;
  console.log("Numero de Items: " + items.length);
  i=0;
  for (i; i < items.length ; i++){
    console.log("Iteracion: " + (i+1))
    items[i].style.width = "4%";
    items[i].style.backgroundColor = "#4d62d0";
    var cantidadHijos = items[i].children.length;
    console.log("Cantidad de hijos: " + cantidadHijos)
    for (i2 = 0 ; i2 < items[i].children.length ; i2++){
      console.log("Modificando Elemento Hijo");
      items[i].children[i2].style.display = "none";
    }
  }



  var elementoString = elemento;
  console.log("Elemento a modificar: " + elementoString);

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
    console.log("Cantidad de Hijos: " + elementoString.children.length);

    for ( i = 0 ; i < elementoString.children.length; i++ )
    {
      console.log("Modificando Hijo: " + (i+1));
      elementoString.children[i].style.display = "block";
    }
  }

}

function Ancho18Porciento(elemento)
{
  console.log("Elemento Objeto: " + elemento);
  elemento.style.width = "18%";
}


function Ancho20Porciento(elemento)
{
  console.log("Elemento Objeto: " + elemento);
  elemento.style.width = "20%";
}

function h1ContenidoCentralSmall()
{

  var titulos = document.querySelectorAll(".contenido-container h1");
  console.log("Longitud del arreglo h1: " + titulos.length);
  for ( i=0 ; i < titulos.length ; i++){
    titulos[i].style.fontSize="small";
    console.log("Cambiando tamano de h1 a small: " + (i+1) );
  }

}


function h1ContenidoCentralLarge()
{

  var titulos = document.querySelectorAll(".contenido-container h1");
  console.log("Longitud del arreglo h1: " + titulos.length);
  for ( i=0 ; i < titulos.length; i++){
    titulos[i].style.fontSize="xx-large";
    console.log("Cambiando tamano de h1 a xx-large: " + (i+1) );
  }

}

//changeColor1("div");
//changePanelSize(document.querySelectorAll("div[class^='item']")[1]);
//Ancho18Porciento(document.querySelectorAll("div[class^='item-']")[1]);
//Ancho20Porciento(document.querySelectorAll("div[class^='item-']")[1]);
//h1ContenidoCentralSmall();
//h1ContenidoCentralLarge();
