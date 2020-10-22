// Realizar conexión

var MongoClient = require('mongodb').MongoClient

var url = "mongodb://localhost/"

var Operaciones = require('./CRUD.js')

MongoClient.connect(url, { useNewUrlParser: true, useUnifiedTopology: true } , function(err,client){
  const db = client.db('nodeDriver');
  // Conexión
    if(err) console.log(err);
    console.log("Conexión establecida con la base de datos");

    Operaciones.consultarYActualizar(db, (error, result) =>{
      if(error) console.log("Error actualizando los registros: "+error);
    })
})
