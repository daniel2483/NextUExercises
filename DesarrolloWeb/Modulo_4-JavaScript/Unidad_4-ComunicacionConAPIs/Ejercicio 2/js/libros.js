var JSON = {
  "libros" : [
      {
        "titulo" : "Conocimiento es poder",
        "codigo": "KAFAFCFG45",
        "editorial": "Edicion Especial",
        "fecha_publicacion": "2018-05-25",
        "edicion": "tercera",
        "estado": "disponible",
        "numero_paginas": 200,
        "numero_copias": 5,
        "autores" : [
            {
              "autor1":
                {
                "nombre": "Jose F. Allende",
                "fecha_nacimiento": "1980-12-02",
                "nacionalidad": "Peruano"
                }
            },
            {
              "autor2":
                {
                "nombre": "Juan Felipe Baltodano",
                "fecha_nacimiento": "1985-11-22",
                "nacionalidad": "Egipcio"
                }
            }
        ]
      },
      {
        "titulo" : "Enriquece tu mente",
        "codigo": "KAFANNN45",
        "editorial": "Editorial Santillana",
        "fecha_publicacion": "2005-07-12",
        "edicion": "cuarta",
        "estado": "disponible",
        "numero_paginas": 567,
        "numero_copias": 3,
        "autores" : [
            {
              "autor1":
                {
                "nombre": "Juan Felipe Constantino",
                "fecha_nacimiento": "1989-12-02",
                "nacionalidad": "Puertorriqueño"
                }

            },
            {
              "autor2":
                {
                "nombre": "Pedro Somoza",
                "fecha_nacimiento": "1983-05-24",
                "nacionalidad": "Costarricense"
                }
            }
        ]
      },
      {
        "titulo" : "Cultiva tu mente que tu mente llenara tus bolsillos",
        "codigo": "SDFJJ45",
        "editorial": "PubliTec",
        "fecha_publicacion": "2019-01-20",
        "edicion": "Primera",
        "estado": "En uso",
        "numero_paginas": 356,
        "numero_copias": 1,
        "autores" : [
            {
              "autor1":
                {
                "nombre": "Gabriel Rodriguez S",
                "fecha_nacimiento": "1979-09-02",
                "nacionalidad": "Venezolano"
                }
            },
            {
              "autor2":
                {
                "nombre": "Yjab Cantillano Fernández",
                "fecha_nacimiento": "1985-11-22",
                "nacionalidad": "Colombiano"
                }
            }
        ]
      }
    ]
};


var titulo_del_libro = JSON.libros[0].titulo;
var codigo_del_libro = JSON.libros[0].codigo;
var fecha_de_publicación = JSON.libros[0].fecha_publicacion;

alert("El libro '" + titulo_del_libro + "' tiene el código '" + codigo_del_libro + "' y fue publicado el " + fecha_de_publicación);
