
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

module.exports.eliminarRegistro = function(db, callback){
  let coleccion = db.collection("users")
  try{
    coleccion.deleteOne({edad:40})
    console.log("Se eliminó el registro correctamente");
  }catch(e){
    console.log("Se generó un error: " + e);
  }
}

module.exports.consultarYActualizar = function(db, callback){
  let coleccion = db.collection("users")

  console.log("Registros Originales: ");
  coleccion.find().toArray((error, documents) =>{
    if(error)console.log(error);
    console.log(documents);
    callback();
  })

  try{
    coleccion.updateOne({name: "David"}, {$set: {peso: 65}})
    console.log("Se ha actualizado el registro correctamente");
  }catch(e){
    console.log("Error actualizando el registro: "+e);
  }

  console.log("Registros Modificados: ");
  coleccion.find().toArray((error, documents) =>{
    if(error)console.log(error);
    console.log(documents);
    callback();
  })

}
