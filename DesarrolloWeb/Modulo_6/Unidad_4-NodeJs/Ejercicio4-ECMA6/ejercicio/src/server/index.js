/*
* Dependencias
*/

// Ejercicio
// 1. Abre el archivo index.js en el directorio server el cual contiene todo el código que has desarrollado para el
// funcionamiento de la aplicación.
// 2. Identifica en cada una de las líneas de este archivo, las estructuras que se pueden actualizar a una sintaxis
// de ECMAScript 6.
// 3. Reescribe las líneas de código identificadas en el paso anterior usando los operadores y estructuras de
// ECMAScript 6.

// Se pueden cambiar por const es decir constantes ya que no varían en el código
const http = require('http')
const express = require('express')
const socketio = require('socket.io')

const port = 8082
const app = express()

app.use(express.static('public'))
const Server = http.createServer(app)

const io = socketio(Server)

// Se pueden cambiar a variables locales ya que solo se utilizaran en este JS
let currentUsers = []
let currentRoom = ''
let firstSocket = ''

// Se pueden cambiar a funcion con formato fat arrow
io.on('connection', function (socket) {
    console.log('New user connected to the game, id: '+socket.id)
    socket.on('newUser', user => {
        switch (currentUsers.length) {
            case 0:
                currentUsers.push(user.user)
                currentRoom = user.user
                firstSocket = socket
                break;
            case 1:
                currentUsers.push(user.user)
                currentRoom = currentRoom + user.user
                // Se pueden cambiar a variables locales ya que solo se utilizaran en esta funcion
                let random = Math.floor(Math.random() * currentUsers.length + 1)
                socket.join(currentRoom)
                firstSocket.join(currentRoom)
                io.to(currentRoom).emit('newGame', { users: currentUsers, turn: random })
                currentUsers = []
                break;
            default:
                break;
        }
    })

    socket.on('restartGame', data => {
        let usuarios = data.users,
            random = Math.floor(Math.random() * usuarios.length + 1)
        io.to(currentRoom).emit('newGame', { users: usuarios, turn: random })
    })

    socket.on('movement', data => ) {
        socket.broadcast.to(currentRoom).emit('movement', data)
    })

    socket.on('message', message => {
        socket.broadcast.to(currentRoom).emit('message', message)
    })
    socket.on('finTurno', () => {
      socket.emit('finTurno')
      socket.broadcast.to(currentRoom).emit('miTurno')
    })
})

// Se pueden eliminar los corchetes {} ya que solo es una línea de código
Server.listen(port, () => console.log('TitTacToe is ready for play on port: '+port))
