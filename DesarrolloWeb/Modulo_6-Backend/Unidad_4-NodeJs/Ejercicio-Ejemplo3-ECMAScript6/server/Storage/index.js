  var fs = require('fs')
      path = require('path')

  module.exports = {

    saveData: function(datatype, newData, data){
      // DataType que informacion es la que se va a actualizar: mensajes o usuarios
      // El segundo es el nuevo dato a ingresar
      // El tercero hace referencia a los datos viejos

      var dataPath = dataType == 'users' ?
                  __dirname + path.join('/data/users.json'):
                  __dirname + path.join('/data/messages.json')
      data.current.push(newData)
      return new promise(function (resolver, reject) {
        fs.writeFile(dataPath, JSON.stringify(data), function(err){
          if(err) reject(err)
          resolve('OK')
        })
      })

    },
    getData: function(dataType){
      var dataPath = dataType == 'users' ?
                    __dirname + path.join('/data/users.json'):
                    __dirname + path.join('/data/messages.json')
      return new promise(function (resolve, reject){
        fs.readFile(dataPath, 'utf8', function(err,readData){
          if (err) reject(err)
          resolve(JSON.parse(readData))
        })
      })
    }
  }
