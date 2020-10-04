//console.log('Saludos desde NodeJS');

  var http = require('http');
  var Routing = require('./requestRouting.js');

  var PORT = 8083;

  var Server = http.createServer(Routing);
  Server.listen(PORT, function(){
    console.log('Server is listening on port: ' + PORT);
  })



  // Visitar el modulo http://npmjs.com para buscar módulos
