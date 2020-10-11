class Persona {
  constructor(nombre,apellido,peso,edad){
    this._nombre = nombre
    this._appellido = apellido
    this._peso = peso
    this._edad = edad
  }

  mostrarNombre (){
    alert('Mi nombre completo es: ' + this._nombre + ' ' + this._appellido)
  }
}

let nuevaPersona = new Persona('Daniel', 'Rodríguez', '74kg', '37')

nuevaPersona.mostrarNombre()
