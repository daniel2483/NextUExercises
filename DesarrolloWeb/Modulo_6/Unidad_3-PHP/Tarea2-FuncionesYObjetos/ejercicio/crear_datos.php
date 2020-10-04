<?php
  // Crea un nuevo archivo con el nombre “crear_datos.php”. Allí debes incluir el archivo “clases.php”; si este archivo no se añade,
  // el script no debe funcionar. En este archivo crea:
  //  -5 instancias de la clase Asignatura, especificando todas sus propiedades.
  //  - 3 instancias de la clase Estudiante, añadiendo la cantidad de asignaturas que desees en su propiedad arreglo de asignaturas, y especificando sus demás propiedades.
  //  - 1 instancia de la clase Profesor, añadiendo la cantidad total de estudiantes creados, en su propiedad arreglo de asignaturas, y especificando sus demás propiedades.
  //  - 1 instancia de la clase Padre, añadiendo la cantidad total de estudiantes creados, en su propiedad arreglo de asignaturas, y especificando sus demás propiedades.
  require "clases.php";
  $asig1 = new Asignatura('Matematicas', 5.0, 4.2, 3.4);
  $asig2 = new Asignatura('Ciencias', 2.0, 1.6, 4.2);
  $asig3 = new Asignatura('Biología', 2.4, 3.0, 3.0);
  $asig4 = new Asignatura('Lenguaje', 2.1, 0.0, 3.0);
  $asig5 = new Asignatura('Deporte', 4.9, 4.3, 4.2);

  $est1 = new Estudiante('Santiago Rodriguez', 'Tercero', '2016');
  $est1->NuevoValorAsignatura($asig1);
  $est1->NuevoValorAsignatura($asig2);
  $est1->NuevoValorAsignatura($asig3);
  $est1->NuevoValorAsignatura($asig4);
  $est1->NuevoValorAsignatura($asig5);

  $est2 = new Estudiante('Laura Pérez', 'Sexto', '2016');
  $est2->NuevoValorAsignatura($asig1);
  $est2->NuevoValorAsignatura($asig2);
  $est2->NuevoValorAsignatura($asig4);
  $est2->NuevoValorAsignatura($asig5);

  $est3 = new Estudiante('Maria Rodriguez', 'Octavo', '2016');
  $est3->NuevoValorAsignatura($asig1);
  $est3->NuevoValorAsignatura($asig2);
  $est3->NuevoValorAsignatura($asig3);
  $est3->NuevoValorAsignatura($asig4);

  $prof1 = new Profesor('Juan Carlos Fernandez');
  $prof1->NuevoValorEstudiante($est1);
  $prof1->NuevoValorEstudiante($est2);
  $prof1->NuevoValorEstudiante($est3);

  $padre1 = new Padre('Gonzalo Rodriguez');
  $padre1->NuevoValorHijos($est1);
  $padre1->NuevoValorHijos($est3);

  $padre2 = new Padre('Felipe Castro');
  $padre2->NuevoValorHijos($est2);


 ?>
