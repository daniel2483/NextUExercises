var IVA = 0.16
var Pedido1 = {
  cliente: "Federico Gutierrez",
  productos: ["Manzanas", "Refrescos", "Azucar", "Sal", "Lechugas frescas"],
  precios: [500, 4000, 2500, 2000, 5000],
  cantidad: [20, 10, 3, 3, 10]
}

var Pedido2 = {
  cliente: "Andres Felipe Liberato",
  productos: ["Naranjas", "Leche", "Queso", "Pan"],
  precios: [1000, 2000, 3000, 1500],
  cantidad: [50, 2, 2, 20]
}

var resultado = 0
var premio = ""
var valorTotal = 0

// Algoritmo de calculo

function CalculoCompra(objPedido,callback){
  for (var indice in objPedido.productos) {
    resultado = resultado + (objPedido.precios[indice] * objPedido.cantidad[indice])
  }

  valorTotal = resultado + (resultado * IVA)

  if (valorTotal > 10000) {
    premio = "Tiene derecho a un premio"
  } else {
    premio = "No tiene derecho a un premio"
  }

  mensaje = "Señor(a)" + objPedido.cliente + ", el valor total de su pedido es: " + resultado + " y aplicando el IVA el total es: " +
      valorTotal + " y debido al valor de tu compra: " + premio

  callback(mensaje);
}

function callback (mensaje){
  alert(mensaje);
};


var button1 = document.getElementById('calculo1')
button1.addEventListener('click', function(){

  // Aqui debes llamar la funcion realizarCalculo y enviarle como argumento el primer pedido y el callback que se definio como funcion
  CalculoCompra(Pedido1,callback);

})

var button2 = document.getElementById('calculo2')
button2.addEventListener('click', function() {

  // Aqui debes llamar la funcion realizarCalculo y enviarle como argumento el segundo pedido y un callback como funcion anonima
  CalculoCompra(Pedido1,function(mensaje){
      alert(mensaje)
  });
})
