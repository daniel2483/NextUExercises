CREATE DATABASE golf_db
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    CONNECTION LIMIT = -1;

    CREATE TABLE public.paises
    (
        id integer NOT NULL,
        nombre character varying(45) NOT NULL,
        PRIMARY KEY (id)
    );
    CREATE TABLE public.ciudades
    (
        id integer NOT NULL,
        nombre character varying(45) NOT NULL,
        latitud character varying(60) NOT NULL,
        fk_pais integer NOT NULL,
        PRIMARY KEY (id)
    );
    CREATE TABLE public.jugadores
    (
        id integer NOT NULL,
        nombre character varying(45) NOT NULL,
        apellido character varying(45) NOT NULL,
        fecha_nacimiento date NOT NULL,
        categoria character varying(45) NOT NULL,
        fk_ciudad_origen integer NOT NULL,
        PRIMARY KEY (id)
    );
    CREATE TABLE public.posiciones_torneo
    (
        fk_jugador integer NOT NULL,
        fk_torneo integer NOT NULL,
        puntuacion_general integer NOT NULL,
        golpes_totales integer NOT NULL,
        PRIMARY KEY (fk_jugador, fk_torneo)
    );
    CREATE TABLE public.campos
    (
        id integer NOT NULL,
        nombre character varying(45) NOT NULL,
        direccion character varying(45) NOT NULL,
        fk_ciudad integer NOT NULL,
        PRIMARY KEY (id)
    );
    CREATE TABLE public.tarjetas_torneo
    (
        fk_torneo integer NOT NULL,
        fk_jugador integer NOT NULL,
        fk_numero_hoyo integer NOT NULL,
        fk_campo integer NOT NULL,
        numero_golpes integer NOT NULL,
        puntuacion integer NOT NULL,
        PRIMARY KEY (fk_torneo, fk_jugador, fk_numero_hoyo, fk_campo)
    );
    CREATE TABLE public.torneos
    (
        id integer NOT NULL,
        nombre character varying(45) NOT NULL,
        fecha date NOT NULL,
        premio double precision NOT NULL,
        categoria character varying(45) NOT NULL,
        PRIMARY KEY (id)
    );
    CREATE TABLE public.hoyos
    (
        numero integer NOT NULL,
        fk_campo integer NOT NULL,
        par integer NOT NULL,
        dificultad character varying(45) NOT NULL,
        PRIMARY KEY (numero, fk_campo)
    );
    ALTER TABLE public.ciudades
        ADD CONSTRAINT fk_ciudades_paises FOREIGN KEY (fk_pais)
        REFERENCES public.paises (id);
    ALTER TABLE public.jugadores
        ADD CONSTRAINT fk_jugadores_ciudad FOREIGN KEY (fk_ciudad_origen)
        REFERENCES public.ciudades (id);
    ALTER TABLE public.posiciones_torneo
        ADD CONSTRAINT fk_posiciones_jugador FOREIGN KEY (fk_jugador)
        REFERENCES public.jugadores (id);
    ALTER TABLE public.posiciones_torneo
        ADD CONSTRAINT fk_posiciones_torneo FOREIGN KEY (fk_torneo)
        REFERENCES public.torneos (id);
    ALTER TABLE public.tarjetas_torneo
        ADD CONSTRAINT fk_tarjetas_torneos FOREIGN KEY (fk_torneo)
        REFERENCES public.torneos (id);
    ALTER TABLE public.tarjetas_torneo
        ADD CONSTRAINT fk_tarjetas_jugador FOREIGN KEY (fk_jugador)
        REFERENCES public.jugadores (id);
    ALTER TABLE public.tarjetas_torneo
        ADD CONSTRAINT fk_tarjetas_hoyo FOREIGN KEY (fk_numero_hoyo, fk_campo)
        REFERENCES public.hoyos (numero, fk_campo);
    ALTER TABLE public.campos
        ADD CONSTRAINT fk_campos_ciudad FOREIGN KEY (fk_ciudad)
        REFERENCES public.ciudades (id);
    ALTER TABLE public.hoyos
        ADD CONSTRAINT fk_hoyos_campos FOREIGN KEY (fk_campo)
        REFERENCES public.campos (id);



        INSERT INTO paises VALUES (1, 'Francia'), (2, 'España'), (3, 'Portugal');

        INSERT INTO ciudades VALUES (1, 'Paris', '48.856684', '2.351826', 1),
                                    (2, 'Marsella', '43.296979', '5.369415', 1),
                                    (3, 'Madrid', '40.416733', '-3.703820', 2),
                                    (4, 'Barcelona', '41.385069', '2.173793', 2),
                                    (5, 'Lisboa', '38.722262', '-9.139397', 3),
                                    (6, 'Oporto', '41.158089', '-8.629861', 3);

        INSERT INTO campos VALUES   (1, 'Le Champ', 'Av4 87-21', 1),
                                    (2, 'Petites', 'Av1 11-40', 2),
                                    (3, 'Los Robles', 'Av7 22-11', 3),
                                    (4, 'Antienes', 'Av2 25-25', 4),
                                    (5, 'Ouro Preto', 'Av9 10-05', 5),
                                    (6, 'Pedras Brancas', 'Av23 12-51', 6);

        INSERT INTO hoyos VALUES    (1, 1, 3, 'baja'),(2, 1, 4, 'baja'),(3, 1, 3, 'baja'),(4, 1, 2, 'media'), (5, 1, 3, 'baja'),
                                    (6, 1, 3, 'baja'),(7, 1, 4, 'alta'), (8, 1, 3, 'media'), (9, 1, 4, 'baja'),(10, 1, 3, 'baja');
        INSERT INTO hoyos VALUES    (11, 1, 3, 'media'), (12, 1, 4, 'baja'),(13, 1, 2, 'baja'), (14, 1, 3, 'alta'), (15, 1, 2, 'baja'),
                                    (16, 1, 4, 'alta'),(17, 1, 4, 'media'),(18, 1, 2, 'alta'),(1, 3, 3, 'alta'), (2, 3, 4, 'alta');
        INSERT INTO hoyos VALUES    (3, 3, 3, 'media'),(4, 3, 2, 'media'),(5, 3, 3, 'alta'), (6, 3, 3, 'media'),(7, 3, 4, 'alta'),
                                    (8, 3, 3, 'media'), (9, 3, 4, 'media');

        INSERT INTO jugadores VALUES (1,'Quin','York','03/17/1977','Semi-profesional',6),
                                    (2,'Alika','Browning','07/12/1978','Semi-profesional',6),
                                    (3,'Zena','Bryan','01/02/1962','Amateur',3),
                                    (4,'Dominique','Mcneil','01/19/1978','Amateur',6),
                                    (5,'Shaeleigh','Brock','08/13/1989','Profesional',2),
                                    (6,'Reed','Skinner','12/24/1968','Profesional',5),
                                    (7,'Deborah','Francis','08/15/1960','Profesional',6),
                                    (8,'Aretha','Gonzales','07/05/1988','Semi-profesional',3),
                                    (9,'Madeline','Chambers','06/07/1992','Profesional',3),
                                    (10,'Kiona','Valdez','10/11/1968','Profesional',5);

        INSERT INTO torneos VALUES  (1, 'Masters de Paris', '2016-04-12', 400000, 'Semi-profesional'),
                                    (2, 'Abierto de Madrid', '2016-08-30', 800000, 'Profesional');

        INSERT INTO tarjetas_torneo VALUES (1, 1, 1, 1, 3, 0),(1, 1, 2, 1, 3, 0),(1, 1, 3, 1, 6, 0),(1, 1, 4, 1, 2, 0),(1, 1, 5, 1, 4, 0),
                                          (1, 1, 6, 1, 1, 0),(1, 1, 7, 1, 3, 0),(1, 1, 8, 1, 5, 0),(1, 1, 9, 1, 4, 0),(1, 1, 10, 1, 2, 0);
        INSERT INTO tarjetas_torneo VALUES (1, 1, 11, 1, 3, 0),(1, 1, 12, 1, 2, 0),(1, 1, 13, 1, 5, 0),(1, 1, 14, 1, 3, 0),(1, 1, 15, 1, 7, 0),
                                          (1, 1, 16, 1, 3, 0),(1, 1, 17, 1, 4, 0),(1, 1, 18, 1, 2, 0),(1, 2, 1, 1, 4, 0),(1, 2, 2, 1, 3, 0);
        INSERT INTO tarjetas_torneo VALUES (1, 2, 3, 1, 3, 0),(1, 2, 4, 1, 3, 0),(1, 2, 5, 1, 6, 0),(1, 2, 6, 1, 2, 0),(1, 2, 7, 1, 4, 0),
                                          (1, 2, 8, 1, 1, 0),(1, 2, 9, 1, 3, 0),(1, 2, 10, 1, 5, 0),(1, 2, 11, 1, 4, 0),(1, 2, 12, 1, 2, 0);
        INSERT INTO tarjetas_torneo VALUES (1, 2, 13, 1, 3, 0),(1, 2, 14, 1, 3, 0),(1, 2, 15, 1, 6, 0),(1, 2, 16, 1, 2, 0),(1, 2, 17, 1, 4, 0),
                                          (1, 2, 18, 1, 1, 0),(1, 4, 1, 1, 3, 0),(1, 4, 2, 1, 5, 0),(1, 4, 3, 1, 4, 0),(1, 4, 4, 1, 2, 0);
        INSERT INTO tarjetas_torneo VALUES (1, 4, 5, 1, 3, 0),(1, 4, 6, 1, 3, 0),(1, 4, 7, 1, 6, 0),(1, 4, 8, 1, 2, 0),(1, 4, 9, 1, 4, 0),
                                          (1, 4, 10, 1, 1, 0),(1, 4, 11, 1, 3, 0),(1, 4, 12, 1, 5, 0),(1, 4, 13, 1, 4, 0),(1, 4, 14, 1, 2, 0);
        INSERT INTO tarjetas_torneo VALUES (1, 4, 15, 1, 3, 0),(1, 4, 16, 1, 3, 0),(1, 4, 17, 1, 6, 0),(1, 4, 18, 1, 2, 0);
