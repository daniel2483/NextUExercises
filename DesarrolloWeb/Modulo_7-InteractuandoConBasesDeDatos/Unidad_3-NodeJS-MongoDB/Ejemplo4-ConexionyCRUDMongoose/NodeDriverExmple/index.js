// Realizar conexión

var MongoClient = require('mongodb').MongoClient

var url = "mongodb://localhost/nodeDriver"

var mongoose = require('mongoose')

var Operaciones = require('./CRUD.js')

mongoose.connect(url, { useNewUrlParser: true, useUnifiedTopology: true } )

// Correr metodo para insertar registro
//Operaciones.insertarRegistro((error, result) => {
//  if(error)console.log(error);
//  console.log(result);
//})

//Correr metodo para eliminar registro
//Operaciones.eliminarRegistro((error, result) => {
//  if(error)console.log(error);
//  console.log(result);
//})

// Correr método para consular y actualizar
Operaciones.consultarYActualizar((error, result) => {
  if(error)console.log(error);
  console.log(result);
})
