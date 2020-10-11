  var bodyParser = require('body-parser'),
      http       = require('http'),
      express    = require('express'),
      chat       = require('./Chat'),
      socketio   = require('socket.io')

  var port        = process.env.PORT || 3000,
      app         = express(),
      Server      = http.createServer(app),
      io = socketio(Server)

  app.use(bodyParser.json())
  app.use(bodyParser.urlencoded({extended: true}))

  app.use('/chat',chat)
  app.use(express.static('public'))

  Server.listen(port, () => console.log("Server is running on port: "+port))

  io.on('Connection',function(socket){
    console.log('new user connected, socket: ' + socket.id);

    socket.on('userJoin', user => {
      // Escuchar el evento user join, para agregar un ususario a los otros sockets
      socket.user = users
      socket.broadcast.emit('userJoin',user) // Para emitir el evento a todos menos a la persona que emite
    })

    socket.on('message', message =>{
      // Escuchar el evento message, para emitirlo a otros sockets
      socket.broadcast.emit('message',message)
    })

    socket.on('disconnect', () => {
      // Escuchar el evento de desconexión para eliminar e l ususario
      if(socket.hasOwnProperty('user')){
        deleteUser(socket.user, (err, confirm) => {
          if(err) throw err
        })
      }
    })


  })
