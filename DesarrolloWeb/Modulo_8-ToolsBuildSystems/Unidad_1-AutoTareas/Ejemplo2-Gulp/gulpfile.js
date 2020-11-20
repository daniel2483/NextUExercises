var gulp = require('gulp');
var minjs = require('gulp-uglify'); // Hace que nuestro archivo Javascript sea mas corto y liviano

gulp.task('default',function(done){
  console.log("Hola mundo con Gulp Default");
  done();
});

gulp.task('test',function(done){
  console.log("Hola mundo con Gulp");
  done();
});

gulp.task('mainminjs',function(done){
  gulp.src('./src/js/main.js')
    .pipe(minjs())
    .pipe(gulp.dest('./build/js/'))
    done();
})


gulp.task('varmainjs',function(){
  gulp.watch('./src/js/*.js', gulp.series('mainminjs'));
})
