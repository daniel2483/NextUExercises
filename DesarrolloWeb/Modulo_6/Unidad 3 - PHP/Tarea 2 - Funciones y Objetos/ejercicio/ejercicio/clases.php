<?php
  // Crea un nuevo archivo con el nombre “clases.php”
  // 1. Crea la clase Asignatura en el archivo creado, con las siguientes propiedades privadas: nombre, nota1, nota2 y nota 3.
  class Asignatura
  {
    private $nombre, $nota1, $nota2, $nota3;

    // 4. La clase debe contar con su constructor correspondiente.
    // Constructor
    function __construct($nombre, $nota1, $nota2, $nota3)
    {
      $this->nombre = $nombre;
      $this->nota1 = $nota1;
      $this->nota2 = $nota2;
      $this->nota3 = $nota3;
    }

    // 3. crear dos métodos públicos por cada propiedad, uno que obtenga el valor de la propiedad y otro que le asigne
    // un nuevo valor
    // Nombre
    public function ValorNombre(){
      return $this->nombre;
    }

    public function NuevoValorNombre($nuevoNombre){
      $this->nombre = $nuevoNombre;
    }
    // Nota 1
    public function ValorNota1(){
      return $this->nota1;
    }

    public function NuevoValorNota1($nuevoNota1){
      $this->nota1 = $nuevoNota1;
    }
    // Nota 2
    public function ValorNota2(){
      return $this->nota2;
    }

    public function NuevoValorNota2($nuevoNota2){
      $this->nota2 = $nuevoNota2;
    }
    // Nota 3
    public function ValorNota3(){
      return $this->nota3;
    }

    public function NuevoValorNota3($nuevoNota3){
      $this->nota3 = $nuevoNota3;
    }

    // 5. Añade a la clase Asignatura un método que calcule el promedio de las 3 propiedades de del objeto que almacenan notas.
    public function promedio(){
      $promedio = ($this->nota1 + $this->nota2 + $this->nota3) / 3;
      return $promedio;
    }

  }

  // 6. Crea la clase Estudiante en el archivo creado, con las siguientes propiedades privadas: nombre, curso y un arreglo
  // de asignaturas.
  // propiedades privadas: nombre, curso y un arreglo de asignaturas
  class Estudiante
  {
    private $nombre;
    private $curso;
    private $asignaturas = array();

    // 7. Para acceder a los valores de dichas propiedades debes crear dos métodos públicos por cada propiedad, uno que
    // obtenga el valor de la propiedad y otro que le asigne un nuevo valor.  Para el arreglo de asignaturas sólo crea
    // el método que retorne su valor. La clase debe contar con su constructor correspondiente.

    // constructor
    function __construct($nombre, $curso)
    {
      $this->nombre = $nombre;
      $this->curso = $curso;
    }


    // Nombre
    public function ValorNombre(){
      return $this->nombre;
    }

    public function NuevoValorNombre($nuevoNombre){
      $this->nombre = $nuevoNombre;
    }
    // Curso
    public function ValorCurso(){
      return $this->curso;
    }

    public function NuevoValorCurso($nuevoCurso){
      $this->curso = $nuevoCurso;
    }
    // Asignatura
    public function ValorAsignatura(){
      return $this->asignaturas;
    }

    // 8. Añade a la clase Estudiante un método para adicionar un objeto de la clase Asignatura a la propiedad arreglo de
    // asignaturas. Para esto debes especificar en los argumentos del método el tipo de dato que debe recibir, en este
    // caso Asignatura y el nombre del parámetro. Para añadir el elemento ingresado como parámetro usa la función
    // “array_push” y en sus argumentos define primero el arreglo al cual será añadido el objeto, y el segundo parámetro
    // indica el elemento a añadir
    public function NuevoValorAsignatura ( Asignatura $a){
      array_push($this->asignaturas, $a);
    }

  }

  // 9. Crea la clase Profesor en el archivo creado, con las siguientes propiedades privadas: nombre y un arreglo de
  // estudiantes.

  class Profesor
  {
    private $nombre;
    private $estudiantes = array();

    // 10. Para acceder a los valores de dichas propiedades debes crear dos métodos públicos por cada propiedad, uno que
    //obtenga el valor de la propiedad y otro que le asigne un nuevo valor. Para el arreglo de estudiantes sólo crea el
    //método que retorne su valor. La clase debe contar con su constructor correspondiente.

    function __construct($nombre){
      $this->nombre = $nombre;
    }

    // Nombre
    public function ValorNombre(){
      return $this->nombre;
    }

    public function NuevoValorNombre($nuevoNombre){
      $this->nombre = $nuevoNombre;
    }
    // estudiantes
    public function ValorEstudiantes(){
      return $this->estudiantes;
    }

    // Añade a la clase Profesor un método para adicionar un objeto de la clase Estudiante a la propiedad arreglo de
    //estudiantes.
    public function NuevoValorEstudiante(Estudiante $a){
      array_push($this->estudiantes, $a);
    }



  }


  // 11. Crea la clase Padre en el archivo creado, con las siguientes propiedades privadas: nombre y un arreglo de hijos.
  class Padre {
    private $nombre;
    private $hijos = array();

    // Para acceder a los valores de dichas propiedades debes crear dos métodos públicos por cada propiedad, uno que obtenga
    // el valor de la propiedad y otro que le asigne un nuevo valor. Para el arreglo de hijos sólo crea el método que retorne
    // su valor. La clase debe contar con su constructor correspondiente.

    // constructor
    function __construct($nombre){
      $this->nombre = $nombre;
    }


    // Nombre
    public function ValorNombre(){
      return $this->nombre;
    }

    public function NuevoValorNombre($nombre){
      $this->nombre = $nombre;
    }
    // estudiantes
    public function ValorHijos(){
      return $this->hijos;
    }
    // 12. Añade a la clase Padre un método para adicionar un objeto de la clase Estudiante a la propiedad arreglo de hijos.
    public function NuevoValorHijos(Estudiante $a){
      array_push($this->hijos, $a);
    }
  }





 ?>
