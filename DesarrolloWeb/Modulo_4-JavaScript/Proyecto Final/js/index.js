
// Objeto calculadora
var calculadora = {
  arrayNumber1:[],
  arrayNumber2:[],
  arrayNumber2Copia:[],
  operacion: [],
  stringDisplay : "",
  signoArrayN1:["+"],
  signoArrayN2:["+"],
  resultado: "",
  banderaIgual: false,
  operacionCopia: [],
  init: function (){
    document.getElementById("on").onmousedown = this.BotonOn;
    document.getElementById("on").onmouseup = this.BotonOnUp;
    document.getElementById("sign").onmousedown = this.BotonSigno;
    document.getElementById("sign").onmouseup = this.BotonSignoUp;
    document.getElementById("raiz").onmousedown = this.BotonRaiz;
    document.getElementById("raiz").onmouseup = this.BotonRaizUp;
    document.getElementById("dividido").onmousedown = this.BotonDividido;
    document.getElementById("dividido").onmouseup = this.BotonDivididoUp;
    document.getElementById("por").onmousedown = this.BotonPor;
    document.getElementById("por").onmouseup = this.BotonPorUp;
    document.getElementById("menos").onmousedown = this.BotonMenos;
    document.getElementById("menos").onmouseup = this.BotonMenosUp;
    document.getElementById("mas").onmousedown = this.BotonMas;
    document.getElementById("mas").onmouseup = this.BotonMasUp;
    document.getElementById("1").onmousedown = this.Boton1;
    document.getElementById("1").onmouseup = this.Boton1Up;
    document.getElementById("2").onmousedown = this.Boton2;
    document.getElementById("2").onmouseup = this.Boton2Up;
    document.getElementById("3").onmousedown = this.Boton3;
    document.getElementById("3").onmouseup = this.Boton3Up;
    document.getElementById("4").onmousedown = this.Boton4;
    document.getElementById("4").onmouseup = this.Boton4Up;
    document.getElementById("5").onmousedown = this.Boton5;
    document.getElementById("5").onmouseup = this.Boton5Up;
    document.getElementById("6").onmousedown = this.Boton6;
    document.getElementById("6").onmouseup = this.Boton6Up;
    document.getElementById("7").onmousedown = this.Boton7;
    document.getElementById("7").onmouseup = this.Boton7Up;
    document.getElementById("8").onmousedown = this.Boton8;
    document.getElementById("8").onmouseup = this.Boton8Up;
    document.getElementById("9").onmousedown = this.Boton9;
    document.getElementById("9").onmouseup = this.Boton9Up;
    document.getElementById("0").onmousedown = this.Boton0;
    document.getElementById("0").onmouseup = this.Boton0Up;
    document.getElementById("punto").onmousedown = this.BotonPunto;
    document.getElementById("punto").onmouseup = this.BotonPuntoUp;
    document.getElementById("igual").onmousedown = this.BotonIgual;
    document.getElementById("igual").onmouseup = this.BotonIgualUp;

    //calculadora.BotonOn();
  },
  BotonOn: function(){
    calculadora.ReduceSize("on");
    // Borramos los arreglos
    calculadora.arrayNumber1 = [];
    calculadora.arrayNumber2 = [];
    calculadora.arrayNumber2Copia = [];
    calculadora.stringDisplay = "";
    calculadora.operacion=[];
    calculadora.operacionCopia=[];
    calculadora.signoArrayN1=["+"];
    calculadora.signoArrayN2=["+"];
    calculadora.resultado="";
    calculadora.banderaIgual = false;
    console.clear();
    document.getElementById('display').innerHTML = "0";
  },
  BotonOnUp: function(){
    calculadora.OriginalSize("on");
  },
  BotonSigno: function(){
    calculadora.ReduceSize("sign");
    if(!calculadora.operacion[0]){calculadora.InsertarQuitarSigno(calculadora.arrayNumber1);}
    else{calculadora.InsertarQuitarSigno(calculadora.arrayNumber2);}

  },
  BotonSignoUp: function(){
    calculadora.OriginalSize("sign");
  },
  BotonRaiz: function(){
    calculadora.ReduceSize("raiz");
  },
  BotonRaizUp: function(){
    calculadora.OriginalSize("raiz");
  },
  BotonDividido: function(){
    calculadora.ReduceSize("dividido");
    calculadora.DisplayVacio();
    calculadora.operacion.push("/");
    calculadora.operacionCopia.push("/");
    console.log("Operacion: " + calculadora.operacion[0]);
    calculadora.banderaIgual = false;
  },
  BotonDivididoUp: function(){
    calculadora.OriginalSize("dividido");
  },
  BotonPor: function(){
    calculadora.ReduceSize("por");
    calculadora.DisplayVacio();
    calculadora.operacion.push("*");
    calculadora.operacionCopia.push("*");
    console.log("Operacion: " + calculadora.operacion[0]);
    calculadora.banderaIgual = false;
  },
  BotonPorUp: function(){
    calculadora.OriginalSize("por");
  },
  BotonMenos: function(){
    calculadora.ReduceSize("menos");
    calculadora.DisplayVacio();
    calculadora.operacion.push("-");
    calculadora.operacionCopia.push("-");
    console.log("Operacion: " + calculadora.operacion[0]);
    calculadora.banderaIgual = false;
  },
  BotonMenosUp: function(){
    calculadora.OriginalSize("menos");
  },
  BotonMas: function(){
    calculadora.ReduceSizeMas("mas");
    calculadora.DisplayVacio();
    calculadora.operacion.push("+");
    calculadora.operacionCopia.push("+");
    console.log("Operacion: " + calculadora.operacion[0]);
    calculadora.banderaIgual = false;
  },
  BotonMasUp: function(){
    calculadora.OriginalSize("mas");
  },
  Boton1: function(){
    calculadora.ReduceSize("1");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(1,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(1,calculadora.arrayNumber2);}
  },
  Boton1Up: function(){
    calculadora.OriginalSize("1");
  },
  Boton2: function(){
    calculadora.ReduceSize("2");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(2,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(2,calculadora.arrayNumber2);}
  },
  Boton2Up: function(){
    calculadora.OriginalSize("2");
  },
  Boton3: function(){
    calculadora.ReduceSize("3");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(3,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(3,calculadora.arrayNumber2);}
  },
  Boton3Up: function(){
    calculadora.OriginalSize("3");
  },
  Boton4: function(){
    calculadora.ReduceSize("4");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(4,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(4,calculadora.arrayNumber2);}
  },
  Boton4Up: function(){
    calculadora.OriginalSize("4");
  },
  Boton5: function(){
    calculadora.ReduceSize("5");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(5,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(5,calculadora.arrayNumber2);}
  },
  Boton5Up: function(){
    calculadora.OriginalSize("5");
  },
  Boton6: function(){
    calculadora.ReduceSize("6");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(6,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(6,calculadora.arrayNumber2);}
  },
  Boton6Up: function(){
    calculadora.OriginalSize("6");
  },
  Boton7: function(){
    calculadora.ReduceSize("7");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(7,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(7,calculadora.arrayNumber2);}
  },
  Boton7Up: function(){
    calculadora.OriginalSize("7");
  },
  Boton8: function(){
    calculadora.ReduceSize("8");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(8,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(8,calculadora.arrayNumber2);}
  },
  Boton8Up: function(){
    calculadora.OriginalSize("8");
  },
  Boton9: function(){
    calculadora.ReduceSize("9");
    if(!calculadora.operacion[0]){calculadora.ValorRegistrado(9,calculadora.arrayNumber1);}
    else{calculadora.ValorRegistrado(9,calculadora.arrayNumber2);}
  },
  Boton9Up: function(){
    calculadora.OriginalSize("9");
  },
  Boton0: function(){
    calculadora.ReduceSize("0");
    if(document.getElementById('display').innerHTML !== "0"){
      if(!calculadora.operacion[0]){calculadora.ValorRegistrado(0,calculadora.arrayNumber1);}
      else{calculadora.ValorRegistrado(0,calculadora.arrayNumber2);}
    }
  },
  Boton0Up: function(){
    calculadora.OriginalSize("0");
  },
  BotonPunto: function(){
    calculadora.ReduceSize("punto");
    if(!calculadora.operacion[0]){calculadora.InsertaPunto(calculadora.arrayNumber1);}
    else{calculadora.InsertaPunto(calculadora.arrayNumber2);}
  },
  BotonPuntoUp: function(){
    calculadora.OriginalSize("punto");
  },
  BotonIgual: function(){ //////////////////////////////////////////////////////// Boton Igual /////////////////////////////////////////////////////
    calculadora.ReduceSize("igual");
    if(calculadora.banderaIgual == false && calculadora.operacion[0])
      {
        console.log("Calcula Operacion...");
        calculadora.OperacionMatematica();
      }
    else
    {
        console.log("Operaciones consecutivas 2do operando, Ultima Operacion: " + calculadora.operacionCopia[0]);
        calculadora.operacion = calculadora.operacionCopia[calculadora.operacionCopia.length-1];
        calculadora.arrayNumber2 = calculadora.arrayNumber2Copia;
        calculadora.OperacionMatematica();
      }
  },
  BotonIgualUp: function(){
    calculadora.OriginalSize("igual");
  },
  ValorRegistrado: function(valor,arrayNumber){

    if(arrayNumber.length < 8){
      arrayNumber.push(valor);
      console.log(arrayNumber +" :" + arrayNumber.length);
      calculadora.ImprimirEnDisplay(arrayNumber);
    }
  },
  ReduceSize: function (id){
    var boton = document.getElementById(id);
    //boton.style="height:58px !important";
    boton.style="border: 7px solid #999999";
  },
  ReduceSizeMas: function (id){
    var boton = document.getElementById(id);
    boton.style="height:95% !important";
    //boton.style="border: 1px solid #999999";
  },
  OriginalSize: function (id){
    var botonOn = document.getElementById(id);
    botonOn.style="";
  },
  InsertarQuitarSigno: function(arrayNumber){
    var valorIngresado = document.getElementById('display').innerHTML;

    // Cambio signo al Numero 1 signoArrayN1
    if(calculadora.signoArrayN1[0] !== "-" && !calculadora.operacion[0] && valorIngresado !== "0" && valorIngresado !== ""){
      calculadora.signoArrayN1=["-"];
      console.log("Cambia a numero negativo Array1");
    }
    else{
      if(valorIngresado !== "" && !calculadora.operacion[0]){
        calculadora.signoArrayN1=["+"];
        console.log("Cambia a numero positivo Array1");
      }
    }
    // Cambio signo al Numero 2 signoArrayN2
    if(calculadora.signoArrayN2[0] !== "-" && calculadora.operacion[0] && valorIngresado !== "0" && valorIngresado !== ""){
      calculadora.signoArrayN2=["-"];
      console.log("Cambia a numero negativo Array2");
    }
    else{
      calculadora.signoArrayN2=["+"];
      console.log("Cambia a numero positivo Array2");
    }

    if(!calculadora.operacion[0]){console.log("Digitos Array1: " + calculadora.signoArrayN1.concat(arrayNumber));}
    else{console.log("Digitos Array2: " + calculadora.signoArrayN2.concat(arrayNumber));}

    if(valorIngresado !== "0")
    {
      calculadora.ImprimirEnDisplay(arrayNumber);
    }
  },
  DisplayVacio: function(){
    document.getElementById('display').innerHTML = "";
  },
  InsertaPunto: function(arrayNumber){
    stringDisplay = "";
    for( i=0 ; i < arrayNumber.length ; i++ ){
      calculadora.stringDisplay = calculadora.stringDisplay + arrayNumber[i];
    }
    var existePunto = calculadora.stringDisplay.indexOf(".");

    if(existePunto == -1){
      if(document.getElementById("display").innerHTML !== "0"){arrayNumber.push(".");}
      else if (document.getElementById("display").innerHTML === "0" && calculadora.operacion[0]){arrayNumber.push(".");}
      else {arrayNumber.push("0");arrayNumber.push(".");}
    }

    calculadora.ImprimirEnDisplay(arrayNumber);
  },
  OperacionMatematica: function(){
    var operacion = calculadora.operacion[0];
    calculadora.banderaIgual = true;
    console.log("se ha ingresado un boton igual? " + calculadora.banderaIgual);
    switch (operacion) {
      case "+":
        var operador1 = calculadora.LeerNumero(calculadora.arrayNumber1);
        var operador2 = calculadora.LeerNumero(calculadora.arrayNumber2);
        if (!operador1){operador1=0;}
        if (!operador2){operador2=0;}
        calculadora.resultado = (parseFloat(calculadora.signoArrayN1[0] + operador1) + parseFloat(calculadora.signoArrayN2[0] + operador2));
        calculadora.resultado = parseFloat(calculadora.resultado.toFixed(9)); // Para solucionar problema con resultados decimales inexactos
        // Solamente se muestra en el display los primeros 8 digitos de la respuesta de la operacion
        document.getElementById('display').innerHTML = calculadora.resultado.toString().substr(0,8);
        break;
      case "-":
        var operador1 = calculadora.LeerNumero(calculadora.arrayNumber1);
        var operador2 = calculadora.LeerNumero(calculadora.arrayNumber2);
        if (!operador1){operador1=0;}
        if (!operador2){operador2=0;}
        calculadora.resultado = (parseFloat(calculadora.signoArrayN1[0] + operador1) - parseFloat(calculadora.signoArrayN2[0] + operador2));
        calculadora.resultado = parseFloat(calculadora.resultado.toFixed(9)); // Para solucionar problema con resultados decimales inexactos
        // Solamente se muestra en el display los primeros 8 digitos de la respuesta de la operacion
        document.getElementById('display').innerHTML = calculadora.resultado.toString().substr(0,8);
        break;
      case "*":
        var operador1 = calculadora.LeerNumero(calculadora.arrayNumber1);
        var operador2 = calculadora.LeerNumero(calculadora.arrayNumber2);
        if (!operador1){operador1=0;}
        if (!operador2){operador2=1;}
        calculadora.resultado = (parseFloat(calculadora.signoArrayN1[0] + operador1) * parseFloat(calculadora.signoArrayN2[0] + operador2));
        calculadora.resultado = parseFloat(calculadora.resultado.toFixed(9)); // Para solucionar problema con resultados decimales inexactos
        // Solamente se muestra en el display los primeros 8 digitos de la respuesta de la operacion
        document.getElementById('display').innerHTML = calculadora.resultado.toString().substr(0,8);
        break;
      case "/":
        var operador1 = calculadora.LeerNumero(calculadora.arrayNumber1);
        var operador2 = calculadora.LeerNumero(calculadora.arrayNumber2);
        if (!operador2){operador2=1;}
        calculadora.resultado = (parseFloat(calculadora.signoArrayN1[0] + operador1) / parseFloat(calculadora.signoArrayN2[0] + operador2));
        calculadora.resultado = parseFloat(calculadora.resultado.toFixed(9)); // Para solucionar problema con resultados decimales inexactos
        // Solamente se muestra en el display los primeros 8 digitos de la respuesta de la operacion
        if(calculadora.arrayNumber1.length == 0){document.getElementById('display').innerHTML = "Indef"}
        else{document.getElementById('display').innerHTML = calculadora.resultado.toString().substr(0,8);}
        break;
      default:
    }
    calculadora.operacion = [];

    console.log("Resultado con signo: " + calculadora.resultado);
    // Se preserva el signo negativo en caso del resultado ser menor a 0
    if(calculadora.resultado < 0){
      calculadora.signoArrayN1 = ["-"];
    }
    else{
      calculadora.signoArrayN1 = ["+"];
    }
    // Se elimina signos negativos ya que los signos se encuentran almacenados en calculador.signoArrayN1 y calculadora.signoArrayN2
    calculadora.resultado = Math.abs(calculadora.resultado);

    console.log("Operacion: " + calculadora.signoArrayN1[0] + operador1 + operacion + calculadora.signoArrayN2[0] + operador2);
    console.log("Resultado Absoluto: " + calculadora.resultado.toString().substr(0,8));
    string = calculadora.resultado.toString().substr(0,8);
    console.log("Resultado Length: " + string.length);
    // Se lee el resultado y se almacena como el nuevo arrayNumber1 para futuras operaciones
    calculadora.LeerResultadoString(string.length,calculadora.resultado.toString().substr(0,8));
    console.log("Nuevo arrayNumber1: " + calculadora.arrayNumber1);
  },
  ImprimirEnDisplay: function(arrayNumber){
    calculadora.stringDisplay = "";
    for( i=0 ; i < arrayNumber.length ; i++ ){
      calculadora.stringDisplay = calculadora.stringDisplay + arrayNumber[i];
    }
    if(calculadora.signoArrayN1[0] === "-" && !calculadora.operacion[0]){
      calculadora.stringDisplay = calculadora.signoArrayN1[0] + calculadora.stringDisplay;
    }
    if(calculadora.signoArrayN2[0] === "-" && calculadora.operacion[0]){
      calculadora.stringDisplay = calculadora.signoArrayN2[0] + calculadora.stringDisplay;
    }
    console.log("Numero: " + calculadora.stringDisplay);
    document.getElementById('display').innerHTML = calculadora.stringDisplay;
  },
  LeerNumero: function(arrayNumber){
    calculadora.stringDisplay = "";
    for( i=0 ; i < arrayNumber.length ; i++ ){
      calculadora.stringDisplay = calculadora.stringDisplay + arrayNumber[i];
    }
    return calculadora.stringDisplay;
  },
  LeerResultadoString: function(limite,resultadoString){
    // Borro los valores de arrayNumber1
    calculadora.arrayNumber1=[];
    // Hsgo una copia del arrayNumber2 en caso de que se presione consecutivamente el boton Igual
    calculadora.arrayNumber2Copia = calculadora.arrayNumber2;
    calculadora.arrayNumber2=[];
    // Ciclo para cargar el nuevo arrayNumber1 con el valor del resultado en caso de que se requieran futuras operaciones
    for( i = 0 ; i < limite; i++ ){
      //resultadoString.charAt(i);
      calculadora.arrayNumber1.push(resultadoString.charAt(i));
      //console.log("Valor Digito " + (i+1) + " " + resultadoString.charAt(i));
    }
  }

}

calculadora.init();
