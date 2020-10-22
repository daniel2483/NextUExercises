var mongoose = require('mongoose');
var Schema = mongoose.Schema;


var userSchema = new Schema({
    nombreEstudiante: { type: String, required: true },
    edad: { type: Number, required: true },
    genero: { type: String, required: true },
    estatura: { type: String, required: true },
})


var User = mongoose.model('Estudiantes', userSchema);

module.exports = User;
