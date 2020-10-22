var mongoose = require('mongoose')
var Operaciones = require('./CRUD.js')

var url = "mongodb://localhost/estudiantes"

mongoose.connect(url)
Operaciones.ordenarConsulta((error, result) => {
    if (error) console.log(error)
    console.log(result)
})
