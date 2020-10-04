  var bodyParser = require('body-parser'),
      http       = require('http'),
      express    = require('express'),

      chat = require('./Chat')

  var port        = process.env.PORT || 3000,
      app         = express(),
      Server      = http.createServer(app)

  app.use(bodyParser.json())
  app.use(bodyParser.urlencoded({extended: true}))

  app.use('/chat',chat)
  app.use(express.static('public'))

  Server.listen(port, function(){
    console.log("Server is running on port: "+port);
  })
