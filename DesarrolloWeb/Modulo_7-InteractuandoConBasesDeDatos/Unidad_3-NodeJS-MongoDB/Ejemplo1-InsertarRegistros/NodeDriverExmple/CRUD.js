
// Con el fin de poder exportarla y usarla sin problemas en el archivo index
module.exports.insertarRegistro = function(db, callback){
  let coleccion = db.collection("users")

  // inserMany recibo un arreglo como parametros de inserción, tambien recibe un callback que notifica el error o resultado
  coleccion.insertMany([
    {nombre: "David", edad: 25, peso: 70},
    {nombre: "Steven", edad: 35, peso: 80},
    {nombre: "Fernando", edad: 40, peso: 68}
  ], (error, result) => {
    console.log("Resultado de insert: " + result.toString());
  })

}
