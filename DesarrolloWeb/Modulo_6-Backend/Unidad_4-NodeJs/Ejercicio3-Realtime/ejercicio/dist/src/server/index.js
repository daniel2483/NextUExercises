'use strict';

/*
* Dependencias
*/

var http = require('http');
var express = require('express');
var socketio = require('socket.io');

var port = 8082;
var app = express();

app.use(express.static('public'));

// 1. Disponer el objeto socket del servidor que se instanció en el ejercicio anterior,
// para que escuche las conexiones entre los posibles clientes y el servidor.
var Server = http.createServer(app);
var io = socketio(Server);

var currentUsers = [];
var currentRoom = '';
var firstSocket = '';

io.on('Connection', function (socket) {
  // 2. Mostrar un mensaje en consola, cuando se establezca una conexión, indicando que existe una nueva conexión al juego,
  // junto con la propiedad id del objeto socket para mostrar el id del cliente que está enlazado.
  console.log('New user connected to the game, socket: ' + socket.id);

  // 3. Escuchar el evento ‘newUser’ que recibe un objeto como parámetro con el nombre del usuario que se ha conectado.
  socket.on('newUser', function (user) {
    // 4. Verificar si este usuario es el primero que se conecta al servidor

    if (currentUsers.length == 0) {
      // implica que es el primer user en conectarse
      // almacenar el socket por el que se ha conectado y el nombre del usuario en variables
      currentUsers.push(user.user);

      // esta variable será el identificador de la sala entre los dos usuarios.
      currentRoom = user.user;
      firstSocket = socket;
    }
    // Si el usuario que emite este evento, es el segundo en conectarse, se debe crear una variable llamada currentRoom
    // que concatene los nombres de los dos usuarios conectados
    if (currentUsers.length == 1) {
      // implica que es el segundo en conectarse
      currentUsers.push(user.user);

      // esta variable será el identificador de la sala entre los dos usuarios.
      currentRoom = user.user + currentRoom;

      // Se deben unir los sockets de ambos usuarios a la sala
      socket.join(currentRoom);
      firstSocket.join(currentRoom);

      // Numero aleatorio para ver quien inicia la partida
      random = Math.floor(Math.random() * 2 + 1);

      // Se deben unir los sockets de ambos usuarios a la sala y por último emitir un evento ‘newGame’ enviando un arreglo
      // con los nombres de los dos usarios en la propiedad users, y un número aleatorio entre 1 y 2 en la propiedad turn.
      io.to(currentRoom).emit('newGame', { users: currentUsers, turn: random });
    }
  });

  // 5. Escuchar el evento ‘restartGame’ que recibe un objeto que contiene la propiedad ‘users’ que corresponde a un vector
  // con los nombres de los jugadores en la sala
  socket.on('restartGame', function (data) {
    usuarios = data.users;

    // Numero aleatorio para ver quien inicia la partida
    random = Math.floor(Math.random() * 2 + 1);

    // y emitir a ambos miembros el evento ‘newGame’ enviando un objeto con un arreglo que contenga los nombres de los dos
    // usuarios en la sala en una propiedad llamada users, y un número aleatorio entre 1 y 2 en una propiedad llamada turn.
    io.to(currentRoom).emit('newGame', { users: usuarios, turn: random });
  });

  // 6. Escuchar el evento ‘movement’ que recibe un objeto como parámetro y emitir el evento ‘movement’, junto el objeto
  // data recibido, sólo al otro miembro de la sala que no originó dicho evento en principio.
  socket.on('movement', function (data) {
    socket.broadcast.to(currentRoom).emit('movement', data);
  });

  // 7. Escuchar el evento ‘message’ que recibe una cadena de caracteres con un mensaje y emitir el evento ‘message’ junto
  // con la cadena recibida al otro usuario que no envió el evento.
  socket.on('message', function (message) {
    socket.broadcast.to(currentRoom).emit('message', message);
  });

  // 8. Escuchar el evento ‘finTurno’ el cual no recibe ningún parámetro. Emitir el evento ‘finTurno’ al mismo socket que
  // envió del que se envió el evento en principio; y emitir el evento ‘miTurno’ al otro usuario.
  socket.on('finTurno', function () {
    socket.emit('finTurno');
    socket.broadcast.to(currentRoom).emit('miTurno');
  });
});

// Verifica el funcionamiento correcto del videojuego iniciando el servidor con el comando npm start y luego
// conectándose desde el navegador al loclahost por el puerto que especificaste en el código. Dile a un amigo
// que se encuentre en tu misma red wi-fi que ingrese desde su computadora al navegador y digite la dirección
// IP de tu computador seguida del puerto que especificaste para correr el servidor.

Server.listen(port, function () {
  console.log('TitTacToe is ready for play on port: ' + port);
});