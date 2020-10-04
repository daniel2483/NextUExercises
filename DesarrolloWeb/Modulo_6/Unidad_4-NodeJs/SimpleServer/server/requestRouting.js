  var dispatcher = require('httpdispatcher')

  function handleRequest(req, res){

    dispatcher.onGet('/users', function(req, res){
      res.writeHead(200,{'Content-type':'text/plain'})
      res.end('Estas en el modulo de users')
    })

    dispatcher.onGet('/admin', function(req, res){
      res.writeHead(200,{'Content-type':'text/plain'})
      res.end('Estas en el modulo de administradores')
    })

    dispatcher.onGet('/dashboard', function(req, res){
      res.writeHead(200,{'Content-type':'text/plain'})
      res.end('Estas en el modulo de dashboard')
    })

    dispatcher.onError(function(req, res){
      res.writeHead(400,{'Content-type':'text/plain'})
      res.end('No se encontro el recurso solicitado')
    })

    dispatcher.dispatch(req, res)

  }
