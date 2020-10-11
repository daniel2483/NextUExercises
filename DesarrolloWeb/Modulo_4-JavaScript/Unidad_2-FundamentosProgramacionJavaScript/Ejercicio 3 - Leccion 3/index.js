var IVA = 0.16
var Pedido = {
  cliente: "Federico Gutierrez",
  productos: ["Manzanas", "Refrescos", "Azucar", "Sal", "Lechugas frescas"],
  precios: [500, 4000, 2500, 2000, 5000],
  cantidad: [20, 10, 3, 3, 10]
}

var resultado = 0
var premio = ""
var valorTotal = 0

// Algoritmo de calculo
i=0
for ( resultado in Pedido.productos){
  resultado = resultado + (Pedido.precios[i] * Pedido.cantidad[i])
  i++
}

valorTotal = Number(resultado * IVA) + Number(resultado)

if (valorTotal > 100000){
  premio = "Tiene derecho a Premio"
}
else{
  premio = "No tiene derecho a Premio"
}


var button = document.getElementById('calculo')
button.addEventListener('click', function(){

  // Aqui debes poner tu alerta
  alert("Señor(a)" + Pedido.cliente + ", el valor total de su pedido es: " + resultado + " y aplicando el IVA el total es: " +
      valorTotal + " y debido al valor de tu compra: " + premio)

})
