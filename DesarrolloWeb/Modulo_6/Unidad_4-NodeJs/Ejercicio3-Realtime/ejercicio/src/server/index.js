/*
* Dependencias
*/

var http = require('http')
var express = require('express')
var socketio = require('socket.io')
var user1 = ""
var user2 = ""
var socketUser = ""

var port = 8082
var app = express()

app.use(express.static('public'))

// 1. Disponer el objeto socket del servidor que se instanció en el ejercicio anterior,
// para que escuche las conexiones entre los posibles clientes y el servidor.
var Server = http.createServer(app)
var io = socketio(Server)

Server.listen(port, function () {
    console.log('TitTacToe is ready for play on port: '+port)
})

io.on('Connection', function(socket){
  // 2. Mostrar un mensaje en consola, cuando se establezca una conexión, indicando que existe una nueva conexión al juego,
  // junto con la propiedad id del objeto socket para mostrar el id del cliente que está enlazado.
  console.log('New user connected to the game, socket: ' + socket.id);

  // 3. Escuchar el evento ‘newUser’ que recibe un objeto como parámetro con el nombre del usuario que se ha conectado.
  socket.on('newUser',function(user){
    // 4. Verificar si este usuario es el primero que se conecta al servidor
    if(user1 === ""){
      // almacenar el socket por el que se ha conectado y el nombre del usuario en variables
      user1 = user
      socketUser = socket.id
    }

    

  })
})
