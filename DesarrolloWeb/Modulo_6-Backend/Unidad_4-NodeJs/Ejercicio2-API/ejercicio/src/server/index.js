/*
* Dependencias
*/

var http = require('http')
var express = require('express')
var socketio = require('socket.io')

// 3. Ejecuta el servidor para que escuche por el puerto definido en la variable creada en el ejercicio de la lección anterior.
var port = 8082
var app = express()

app.use(express.static('public'))

// 1. Crea un servidor http basado en una aplicación express en el archivo index.js ubicado en la carpeta server.
var Server = http.createServer(app)

// 2. Instancia un objeto de la librería Socket.io para que corra sobre el servidor creado en el paso anterior.
var io = socketio(Server)



Server.listen(port, function () {
    // 4. Imprime en consola, al lanzar el servidor, un mensaje que indique que éste se ha inicializado y que está escuchando por el puerto correspondiente.
    console.log('TitTacToe esta listo para funcionar en el puerto: '+port)
})

// 5. Ejecuta el comando npm start sobre el directorio del proyecto y verificar que el servidor haya sido iniciado correctamente.

// 6. Verifica el funcionamiento correcto del servidor accediendo desde el navegador a localhost y el puerto definido
//        Visitar: http://localhost:8082/
