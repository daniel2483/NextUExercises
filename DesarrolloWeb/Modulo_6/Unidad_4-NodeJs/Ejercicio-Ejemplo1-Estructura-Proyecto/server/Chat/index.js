  var express = require('express')
  var Router = express.Router()

  Router.get('/users',function(req, res){
    //get Usuario
  })

  Router.get('/messages',function(req, res){
    //get messages
  })

  Router.post('/users',function(req, res){
    //post Usuario
  })

  Router.post('/messages',function(req, res){
    //post messages
  })

  module.exports = Router
