
//Document.Ready
$(function(){

  //Inicializador del elemento select de materialize css
  $('select').material_select();

  //Evento para cambiar de color al item seleccionado
  $(".elemento-tabla .collection-item").on("click",function(){
    $(".collection-item").removeClass("selected-item");
    $(this).toggleClass("selected-item");
    var checkAsociadoId= $(this).attr("id")+"Check";
    $("#"+checkAsociadoId).parent().toggleClass("selected-item");
  });


  //1. Eliminar un elemento junto con su respectivo checkbox, después de hacer click en él y presionar en el ícono de la basura.
  var tmpColumna1=0;
  var tmpColumna2=0;
  $("#borrar").on("click",function(){
    tmpColumna1 = $(".selected-item")[0];
    tmpColumna2 = $(".selected-item")[1];
    $(".selected-item").detach();
  })

  //2. Deshacer la última eliminación que se haya realizado al presionar el segundo botón con la flecha.
  $("#deshacer").on("click",function(){
    if(tmpColumna1.length != 0){

      $("ul")[2].append(tmpColumna1);
      $("ul")[3].append(tmpColumna2);
      //console.log($("ul.collection").html());
      $("ul li:last-child").removeClass("selected-item")

    }

  });

  //3. Solo dos checkbox seleccionados
  var count=0;
  var arrayValores=[];
  $(".listaCheck li input").on("click",function(){
    // third last click
    count = count +1;
    arrayValores.push($(this).attr('id'));
    if(count > 2){
      arrayValores[0];
      $("#"+arrayValores[0]).prop('checked', false);
      count = count -1;
      arrayValores.shift();
      console.log("Limite maximo: " + arrayValores[0]);
    }
  })
  //$("[type='checkbox']:not(:checked)")

  //4. Intercambiar las posiciones de los ítems seleccionados en los
  // checkbox al presionar el botón con el ícono de las dos flechas.
  $("#reemplazar").on("click",function(){
    // Funciona solamente si se han seleccionado 2 items
    if( $($("input[type='checkbox']:checked")[0]).length ==1 && $($("input[type='checkbox']:checked")[1]).length == 1)
    {
    // Objeto 1 seleccionado
    var object1Columna1 = "#";
    var object1Columna2 = "#";
    var id1 = $($("input[type='checkbox']:checked")[0]).attr('id');
    id1 = id1.substring(0,id1.length-5);
    object1Columna2 += $($("input[type='checkbox']:checked")[0]).attr('id');
    object1Columna1 = object1Columna2.substring(0,object1Columna2.length-5);

    object1HTML1 = $(object1Columna1).html();
    object1HTML2 = $(object1Columna2).html();

    // Objeto 2 seleccionado
    var object2Columna1 = "#";
    var object2Columna2 = "#";
    var id2 = $($("input[type='checkbox']:checked")[1]).attr('id');
    id2 = id2.substring(0,id2.length-5);
    object2Columna2 += $($("input[type='checkbox']:checked")[1]).attr('id');
    object2Columna1 = object2Columna2.substring(0,object2Columna2.length-5);

    object2HTML1 = $(object2Columna1).html();
    object2HTML2 = $(object2Columna2).html();

    // Reemplazando columnas de items (Columna1)
    $(object1Columna1).html(object2HTML1);
    $(object2Columna1).html(object1HTML1);
    // Reemplazando Id's de columnas 1
    var tmp1 = "1";
    var tmp2 = "2";
    $(object1Columna1).attr("id",tmp2);
    $(object2Columna1).attr("id",tmp1);
    $("#"+tmp2).attr("id",id2);
    $("#"+tmp1).attr("id",id1);

    // Remplazando Check input y label
    var index1= $("input[type='checkbox']").index($(object1Columna2));
    //$("label[for*='Check']").index("#PimenteroCheck");

    var index2= $("input[type='checkbox']").index($(object2Columna2));
    //$("label[for*='Check']").index("#PimenteroCheck");

    $($("input[type='checkbox']")[index1]).attr("id",object2Columna2.substring(1,object2Columna2.length));
    $($("label[for*='Check']")[index1]).attr("for",object2Columna2.substring(1,object2Columna2.length));
    $($("input[type='checkbox']")[index2]).attr("id",object1Columna2.substring(1,object1Columna2.length));
    $($("label[for*='Check']")[index2]).attr("id",object1Columna2.substring(1,object1Columna2.length));
    $($("input[type='checkbox']")[index1]).prop('checked', false);
    $($("input[type='checkbox']")[index2]).prop('checked', false);

    console.log("Objeto 1 Id: " + object1Columna1 + " Objeto 2 Id: " + object2Columna1);
    console.log("Index 1: " + index1 + " Index2: " + index2);
    }
    else{
      console.log("No has seleccionado 2 items")
    }
  })

  // 5. Al modificar el valor del selector con el título “Ordenar por”  nombre, precio, o marca
  var Item = {
    nombre : "",
    image : "",
    brand : "",
    price : "",
    collectionItem : ""
  }

  //$(".opciones").on("change",function(){
    //console.log("cambio");
    //if($("#filtro option:first").prop('selected') == true){
      // Ordenar por nombre
      //console.log("Se ordena por Nombre");
      //var item = $(".collection li span.title");
      //var nombres = new Array(item.length);

      //for(i=0;i<item.length;i++){
        //Item.nombre[i]=$($(".collection li span.title")[i]).text();
        //Item.image[i]=$($(".collection img")[i]).attr("src");
        //Item.brand[i]=$($(".collection p span")[i]).text();
        //Item.price[i]=$($(".collection p b")[i]).text();
        //Item.collectionItem[i]=$($(".collection li span.title")[i]).text();
        //nombres[i]=$($(".collection li span.title")[i]).text();
      //}
      //nombres.sort();
      //console.log("Arreglo ordenado por nombre: " + nombres);
      //for(i=0;i<item.length;i++){
        //$($(".collection li span.title")[i]).text(Item.nombres[i]);
        //$($(".collection img")[i]).attr("src",Item.image[i]);
        //$($(".collection p span")[i]).text(Item.brand[i]);
        //$($(".collection p b")[i]).text(Item.price[i]);
        //$($(".collection li span.title")[i]).text(Item.collectionItem[i]);
        //$($(".collection li span.title")[i]).text(nombres[i]);
      //}

    //}
    //else if($("#filtro option:eq(1)").prop('selected') == true){
      // Ordenar por precio
      //console.log("Se ordena por Precio");
    //}
    //else{
      // Ordenar por marca
      //console.log("Se ordena por Marca");
    //}





  //})

  $("#filtro").on("change", function(){
    var categoria = $(this).val();
    var elementosOrdenar = getStringArray(categoria);
    if (categoria=="precio") {
      elementosOrdenar.sort(sortNumber);
    }else {
      elementosOrdenar.sort();
    }

    organizarItemsOrdenados(elementosOrdenar);

  });


  //Compara un arreglo ordenado de strings o números y los relaciona con los items en las listas, organizandolos para que queden en orden
  function organizarItemsOrdenados(arrayElementos){
    var itemsOriginales = $(".elemento-tabla .collection-item");
    var checkOriginales = $(".elemento-selec .collection-item");
    for (var i = 0; i < arrayElementos.length; i++) {
      for (var j = 0; j < itemsOriginales.length; j++) {
        if (typeof arrayElementos[i] == "number") {
          var precioOriginal = $(itemsOriginales[j]).find("b").text().split("$");
          if (parseFloat(precioOriginal[1])==arrayElementos[i]) {
            if (i==0) {
              $(".elemento-tabla .collection-item").last().before(itemsOriginales[j]);
              $(".elemento-selec .collection-item").last().before(checkOriginales[j]);
            }else{
              $(".elemento-tabla .collection-item").last().after(itemsOriginales[j]);
              $(".elemento-selec .collection-item").last().after(checkOriginales[j]);
            }
          }
        }else {
          if ($(itemsOriginales[j]).text().search(arrayElementos[i])!=-1) {
            if (i==0) {
              $(".elemento-tabla .collection-item").last().before(itemsOriginales[j]);
              $(".elemento-selec .collection-item").last().before(checkOriginales[j]);
            }else{
              $(".elemento-tabla .collection-item").last().after(itemsOriginales[j]);
              $(".elemento-selec .collection-item").last().after(checkOriginales[j]);
            }
          }
        }


      }
    }
  }


  //Obtener los valores de los items a partir de la categoría del filtro para ordenarlos
  function getStringArray(tipo){
    var stringElementos;
    if (tipo=='nombre') {
      var getNombres = $(".elemento-tabla .collection-item .title");
      stringElementos = $(".elemento-tabla .collection-item .title");
      for (var i = 0; i < getNombres.length; i++) {
        stringElementos[i]=$(getNombres[i]).text();
      }
    }
    if (tipo=='precio') {
      var getPrice = $(".elemento-tabla .collection-item p b").text();
      stringElementos = getPrice.split("Precio: $");
      stringElementos.shift();
      for (var i = 0; i < stringElementos.length; i++) {
        stringElementos[i] = parseFloat(stringElementos[i]);
      }

    }
    if (tipo=='marca') {
      var getMarca = $(".elemento-tabla .collection-item p span").text();
      stringElementos = getMarca.split("Marca ");
      stringElementos.shift();
    }
    return stringElementos;
  }

  //Auxiliar para usar el método sort() con números
  function sortNumber(a,b) {
    return a - b;
  }

})
