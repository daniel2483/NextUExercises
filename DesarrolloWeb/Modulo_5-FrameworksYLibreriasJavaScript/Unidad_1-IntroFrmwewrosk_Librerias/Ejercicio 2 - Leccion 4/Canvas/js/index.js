var starArray = [];

var stage = new Konva.Stage({
  container: 'dibujo',
  width: window.innerWidth,
  height: window.innerHeight
});

var layer = new Konva.Layer();

function AddingStar(positionX,positionY,starNumber){
stage.width(556);
stage.height(316);
var star = new Konva.Star({
  x: positionX,
  y: positionY,
  width: 100,
  height: 50,
  numPoints: 5,
  innerRadius: 40,
  outerRadius: 70,
  fill: 'rgba(255,255,0,0.8)',
  stroke: 'black',
  draggable:true,
  strokeWidth: 4,
  offset: {
          x: 0,
          y: 0
        }
});
// add the shape to the layer
layer.add(star);
AnimationRotation(90,star);
AnimationScalableXY(5000,star);
// add the layer to the stage
stage.add(layer);

}

function AnimationRotation(angularSpeed,star){
  var anim = new Konva.Animation(function(frame) {
    var angleDiff = (frame.timeDiff * angularSpeed) / 1000;
    star.rotate(angleDiff);
  }, layer);
  anim.start();
}

function AnimationScalableXY(periodTime,star){
  var period = periodTime;
  var anim2 = new Konva.Animation(function(frame) {
    var scale = Math.sin((frame.time * 2 * Math.PI) / period) + 0.001;
    star.scale({ x: scale, y: scale });
  }, layer);

  anim2.start();
}


for( i = 0 ; i < 10 ; i++){
  var RandomX=Math.floor((Math.random() * 556) + 1);
  var RandomY=Math.floor((Math.random() * 316) + 1);

  console.log("X= " + RandomX);
  console.log("Y= " + RandomY);

  AddingStar(RandomX,RandomY,i);
}
