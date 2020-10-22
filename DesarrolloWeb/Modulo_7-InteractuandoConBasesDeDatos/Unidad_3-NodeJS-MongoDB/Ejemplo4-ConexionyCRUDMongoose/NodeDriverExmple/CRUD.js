var User = require('./models.js')

// Con el fin de poder exportarla y usarla sin problemas en el archivo index
module.exports.insertarRegistro = function(callback){
  let Mateo = new User({nombre: "Mateo", edad: 28, peso: 90})

  Mateo.save(error => {
    if(error)callback(error)
    callback(null, "Registro Guardado")
  })

}

module.exports.eliminarRegistro = function(callback){
  User.remove({edad:35}, (error) => {
    if(error)callback(error)
    callback(null, "Se eliminó correctamente el registro")
  })
}

module.exports.consultarYActualizar = function(callback){
  User.find({}).exec((error, result) => {
    if(error)callback(error)
    console.log(result);
    User.update({nombre: "Mateo"}, {peso:40}, (error, result) => {
      if(error)callback(error)
      callback(null, result)
    })
  })

}
