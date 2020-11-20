module.exports = function(grunt){

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    author: 'Jose Daniel Rodriguez Sanchez',
    uglify:{
      dist:{
        files:{
          'build/<%= pkg.name %>.min.js':[
            'src/js/main.js'
          ]
        }
      }
    }
  })

  grunt.registerTask('hola','Mi primer tarea registrada con grunt', function(){
    grunt.log.writeln("Hola esta es mi primera tarea Grunt por "+grunt.config('author'));
  })


  grunt.task.loadNpmTasks('grunt-contrib-uglify');

  grunt.registerTask('default',['uglify']);
}
