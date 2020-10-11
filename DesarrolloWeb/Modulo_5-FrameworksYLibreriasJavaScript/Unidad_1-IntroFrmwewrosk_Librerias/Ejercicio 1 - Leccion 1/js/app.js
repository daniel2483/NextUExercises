var canvas = document.getElementById('miCanvas'),
    context = canvas.getContext('2d');

context.beginPath(); // Vamos a dibujar un nuevo trazo
context.moveTo(100,30); // Punto de inicio
context.lineTo(200,150); // Para dibujar una linea recta con el punto inicial, se utiliza cuantas veces se necesita
context.stroke(); // Para hacer la linea visible, por defecto el color es negro



var canvas = document.getElementById('miCanvas2'),
    context = canvas.getContext('2d');

context.beginPath(); // Vamos a dibujar un nuevo trazo
context.rect(100,50, 50, 100); // Dibujar rectangulo x,y,ancho,alto
context.fillStyle = 'blue';
context.fill();
context.lineWidth=5; // Para mostrar el contorno
context.strokeStyle='black';
context.stroke(); // Para hacer la linea visible, por defecto el color es negro

var canvas = document.getElementById('miCanvas3'),
    context = canvas.getContext('2d');

context.beginPath(); // Vamos a dibujar un nuevo trazo
context.fillStyle = 'blue';
context.strokeStyle='black';
context.lineWidth=5; // Para mostrar el contorno
context.fillRect(100,50, 50, 100); // Dibujar rectangulo x,y,ancho,alto
context.strokeRect(100,50,50,100); // Para hacer la linea visible, por defecto el color es negro

// Para borrar un rectangulo clear.Rect(x,y,ancho,alto)
var canvas = document.getElementById('miCanvas4'),
    context = canvas.getContext('2d');

context.arc(100,100,50,Math.PI,Math.PI*1.5,false); // Es una seccion de circunferencia o arco x,y,radio,angula de inicio,angulo de fin,direccion (false en sentido de las manecillas del reloj)
context.stroke();


var canvas = document.getElementById('miCanvas5'),
    context = canvas.getContext('2d');

context.arc(120,120,70,0,Math.PI*2,false); // Es una seccion de circunferencia o arco x,y,radio,angula de inicio,angulo de fin,direccion (false en sentido de las manecillas del reloj)
context.fillStyle = "#ff8800";
context.fill();

var canvas = document.getElementById('miCanvas6'),
    context = canvas.getContext('2d');

context.font = "bold 30pt Arial, sans-serif"; // Por defecto el estilo de la fuente es normal
context.fillText("Hola!",100,45); // String, x,y


var canvas = document.getElementById('miCanvas6'),
    context = canvas.getContext('2d');

var imageObj = new Image();
imageObj.onload= function(){
  context.drawImage(imageObj,50,50,200,150); // Imagen, x,y ,ancho ,alto // Posicion se refiere a la esquina superior izquierda
};
imageObj.src = '../img/Calculadora.png';
