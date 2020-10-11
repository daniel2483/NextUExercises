
var Persona = {

  nombre : "Gabriel Santos",
  ciudad : "New York",
  entidad_salud : "Salud Para Ti",
  peso : 68,
  estatura : 1.76,
  fecha_nacimiento : new Date (79,3,2),

  propiedad : {
      anotaciones : ["El paciente no presenta signos de dolor en las cicatrices de la cirugia",
                        "Presion arterial media normal",
                        "Se mencionan dolores en la zona abdominal"],
      fecha_consulta : new Date(2016,6,23)
  },

  historia_clinica : [["Fractura de femur", new Date(2015,11,3)],
                      ["Apendicitis", new Date(2015,8,22)],
                      ["Insuficiencia Renal", new Date(2013,3,1)]],

  GetEdad : function (fecha_actual){

    var edad = Math.abs(fecha_actual - this.fecha_nacimiento); // Milisegundos
    edad = edad/(1000*60*60*24*365),0
    return edad.toFixed(0)
  },

  GetIMC : function(){
    var imc = this.peso/(this.estatura*this.estatura);
    return imc.toFixed(2)
  }

}


function PrintConsole (){
  console.log("Nombre: " + Persona.nombre)
  console.log("Ciudad: " + Persona.ciudad)
  console.log("Entidad de Salud: " + Persona.entidad_salud)
  console.log("Peso: " + Persona.peso)
  console.log("Estatura: " + Persona.estatura)
  console.log("Fecha de Nacimiento: " + Persona.fecha_nacimiento)
  console.log("Ultima Consulta:")
  console.log("Anotaciones: " + Persona.propiedad.anotaciones + " Fecha: " + Persona.propiedad.fecha_consulta)
  console.log("Historia Clinica:")
  console.log(Persona.historia_clinica[0][0] + ", Fecha: " + Persona.historia_clinica[0][1])
  console.log(Persona.historia_clinica[1][0] + ", Fecha: " + Persona.historia_clinica[1][1])
  console.log(Persona.historia_clinica[2][0] + ", Fecha: " + Persona.historia_clinica[2][1])
  var fecha_actual= Date.now()
  console.log("Fecha Actual: " + fecha_actual)
  console.log("Edad: " + Persona.GetEdad(fecha_actual))
  console.log("Indice de Masa Corporal (IMC): " + String(Persona.GetIMC()))
}

document.getElementById('boton-perfil').addEventListener("click", function(){
  PrintConsole();
})
