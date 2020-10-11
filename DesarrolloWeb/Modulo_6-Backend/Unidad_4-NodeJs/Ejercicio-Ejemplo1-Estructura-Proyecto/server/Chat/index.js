  var express = require('express')

  var Storage = require('../Storage')
  var Router = express.Router()

  Router.get('/users',function(req, res){
    //get Usuario
    Storage.getData('users')
            .then(function (users){
              res.json(users)
            }).catch(function(error){
              res.sendStatus(500).json(error)
            })
  })

  Router.get('/messages',function(req, res){
    //get messages
    Storage.getData('messages')
            .then(function (messages){
              res.json(messages)
            }).catch(function(error){
              res.sendStatus(500).json(error)
            })
  })

  Router.post('/users',function(req, res){
    //post Usuario
    var user = req.body.user
    Storage.getData('users')
            .then(function(users){
              return new Promise(function(resolve, reject){
                Storage.saveData('users',user,users)
                        .then(function(message){
                          resolve(message)
                        }).catch(function(err){
                          reject(err)
                        })
              })
            }).then(function(message){
              res.json(message)
            }).catch(function (err){
              res.sendStatus(500).json(err)
            })
  })

  Router.post('/messages',function(req, res){
    //post messages
    var message = req.body.message
    Storage.getData('message')
            .then(function(message){
              return new Promise(function(resolve, reject){
                Storage.saveData('message',message,message)
                        .then(function(message){
                          resolve(message)
                        }).catch(function(err){
                          reject(err)
                        })
              })
            }).then(function(message){
              res.json(message)
            }).catch(function (err){
              res.sendStatus(500).json(err)
            })
  })

  module.exports = Router

  (function(document, window, undefined , $){
    (function (){
      return Chat = {
        //Todo el código requerido
        apiUrl: '/chat',
        $userDataModal: $('#modalCaptura'),
        $btnMessage: $('#btnMessage'),
        $messageText: $('#messageText'),
        userName: '',

        Init: function(){
          var self = this
          this.fetchUserInfo(function(user){
            self.renderUser(user)
          })
        },
        fetchUserInfo: function (callback){
          var self = this
          this.$userDataModal.openModal()
          var $GuardaInfo = $('.guardaInfo')
          $GuardaInfo.on('click', function(){
            var nombre = $('.nombreUsuario').val()
            var user = [{nombre: nombre, img: 'p2.jpg'}]
            callback(user)

            self.joinUser(user[0])


            self.userName = nombre
            self.$userDataModal.closeModal()
          })

          self.getInitialUsers()
        },
        getInitialUsers: function(){
          var self = this
          var endpoint = self.apiUrl + '/users'
          self.ajaxRequest(endpoint, 'GET', {})
              .done(function(data){
                var users = data.current
                self.renderUser(users)
              }).fail(function(err){
                console.log(err);
              })
        },
        ajaxRequest: function(url, type, data){
          return $.ajax({
            url:url,
            type: type,
            data: data
          })
        },
        joinUser: function(user){
          var self = this
          var endpoint = self.apiUrl + '/users'
          var userObj = {user: user}
          self.ajaxRequest(endpoint,'POST',userObj)
              .done(function(confirm){
                console.log(confirm)
              }).fail(function(error{
                alert(error)
              })
        },
        renderUser: function(users){
          var self = this
          var userList = $('.users-list')
          var userTemplate = '<li class="collection-item avatar">' +
                             '<img src="image/:image:" class="circle">' +
                             '<span class="title">:nombre:</span>' +
                             '<p><img src="image/online.png"> En linea </p>'
                             '<li>'
          users.map(function(user){
            var newUser = userTemplate.replace(':image:','p2.jpg')
                                      .replace(':nombre:', user.nombre)
          })
        },
        watchMessages: function(){
          var self = this
          self.$messageText.on('keypress', function(e){
            if(e.which == 13){

              if($(this).val().trim()!= ''){
                var message = {
                  sender: self.userName,
                  text: $(this).val()
                }
                self.renderMessage(message)
                $(this).val('')
              }else{
                e.preventDefault()
              }
            }
          })
          self.$btnMessage.on('click', function(){
            if (self.$messageText.val() != ''){
              var message = {
                sender: self.userName,
                text: $(this).val()
              }
              self.renderMessage(message)
              self.$messageText.val('')
            }else{
              e.preventDefault()
            }
          })
        },
        renderMessage: function(message){
          var self = this
          var tipoMensaje = message.sender == self.userName ? 'recibidos' : 'enviados'
          var messageList = $('.historial-chat')
          var messageTemplate = '<div class=":tipoMensaje:">'+
                                  '<div class="mensaje">'+
                                    '<div class=images>'+
                                      '<img src="image/p2.jpg" alt="Contacto">'+
                                    '</div>'+
                                    '<div class="texto">'+
                                      '<span class="nombre">:nombre:</span><br>'+
                                      '<span>:mensaje:</span>'+
                                    '</div>'+
                                    '<div class="hora">'+
                                      '<span class="numHora">:hora:</span>'+
                                    '</div>'+
                                  '</div>'+
                                '</div>'
          var currentDate = new Date()
          var newMessage = messageTemplate.replace(':tipoMensaje:',tipoMensaje)
                                          .replace(':nombre:',message.sender)
                                          .replace(':mensaje:',message.text)
                                          .replace(':hora:',currentDate.getHours()+ : currentDate.getMinutes())
          messageList.append(newMessage)
          $(".scroller-chat").animate({ scrollTop: $(".scroller-chat").get(0).scrollHeight }, 500)

        }









      }
    })()
    Chat.Init()
  })(document, window, undefined, jQuery)
