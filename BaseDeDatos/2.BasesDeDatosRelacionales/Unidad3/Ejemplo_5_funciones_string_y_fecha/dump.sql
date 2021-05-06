--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: registrar_cambio_de_nombre(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION registrar_cambio_de_nombre() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

INSERT INTO cambios_de_nombre (descripcion, fecha) VALUES
(CONCAT('Cambio de nombre de: <', OLD.nombre,'> a <', NEW.nombre, '>'), NOW());

RETURN NEW;

END
$$;


--
-- Name: relacion_ventas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION relacion_ventas() RETURNS real
    LANGUAGE plpgsql
    AS $$
DECLARE total real;
BEGIN
SELECT SUM(costo) INTO total FROM ventas;
RETURN total;
END
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: cambios_de_nombre; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE cambios_de_nombre (
    id smallint DEFAULT 1 NOT NULL,
    descripcion character varying NOT NULL,
    fecha date NOT NULL
);


--
-- Name: cambios_de_nombre_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cambios_de_nombre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cambios_de_nombre_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cambios_de_nombre_id_seq OWNED BY cambios_de_nombre.id;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY cambios_de_nombre ALTER COLUMN id SET DEFAULT nextval('cambios_de_nombre_id_seq'::regclass);



--
-- Name: ciudadanos; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE ciudadanos (
    id smallint NOT NULL,
    ddi character varying NOT NULL,
    nombre character varying NOT NULL
);


--
-- Name: ciudadanos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ciudadanos_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ciudadanos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ciudadanos_id_seq OWNED BY ciudadanos.id;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY ciudadanos ALTER COLUMN id SET DEFAULT nextval('ciudadanos_id_seq'::regclass);



--
-- Name: contenedores; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE contenedores (
    id smallint NOT NULL,
    ancho real,
    largo real,
    alto real
);


--
-- Name: contenedores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE contenedores_id_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contenedores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE contenedores_id_seq OWNED BY contenedores.id;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY contenedores ALTER COLUMN id SET DEFAULT nextval('contenedores_id_seq'::regclass);

--
-- Name: documentos; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE documentos (
    id smallint NOT NULL,
    titulo character varying(255),
    palabras_clave character varying(255),
    contenido text,
    autor character varying(255),
    publicado boolean,
    fecha_publicacion date
);

--
-- Name: documentos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE documentos_id_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documentos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE documentos_id_seq OWNED BY documentos.id;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY documentos ALTER COLUMN id SET DEFAULT nextval('documentos_id_seq'::regclass);


--
-- Name: ventas; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE ventas (
    id smallint NOT NULL,
    descripcion character varying,
    costo real
);

--
-- Name: ventas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ventas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ventas_id_seq OWNED BY ventas.id;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY ventas ALTER COLUMN id SET DEFAULT nextval('ventas_id_seq'::regclass);


--
-- Data for Name: cambios_de_nombre; Type: TABLE DATA; Schema: public; Owner: -
--

COPY cambios_de_nombre (id, descripcion, fecha) FROM stdin;
\.


--
-- Data for Name: ciudadanos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY ciudadanos (id, ddi, nombre) FROM stdin;
1	A1	LUIZ
2	B1	MARCOS
3	C1	ANA
\.


--
-- Data for Name: contenedores; Type: TABLE DATA; Schema: public; Owner: -
--

COPY contenedores (id, ancho, largo, alto) FROM stdin;
1	10.5	5	3.20000005
2	20	30	15
3	3	3.0999999	10.5
4	8	8	8
5	2	8	10
6	5	5.5	5.5
\.


--
-- Data for Name: documentos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY documentos (id, titulo, palabras_clave, contenido, autor, publicado, fecha_publicacion) FROM stdin;
1	moda	camisa negra	Aqui tenemos una descripcion de mode de los 80	Luis Torres	t	2019-01-01
2	esporte	futbol jugadores	Um articulo sobre jugadores de futbol africanos	Manuela Vera	t	2019-02-01
3	comida	arroz azeite negro	Contiene recetas de comidas	Carolina Mata	f	2019-01-10
4	futbol	copa de futbol	El ganador de copas del mundo	Miriam Castro	t	2019-03-10
\.


--
-- Data for Name: ventas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY ventas (id, descripcion, costo) FROM stdin;
\.


--
-- Name: cambios_de_nombre_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY cambios_de_nombre
    ADD CONSTRAINT cambios_de_nombre_pkey PRIMARY KEY (id);

--
-- Name: ciudadanos_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY ciudadanos
    ADD CONSTRAINT ciudadanos_pkey PRIMARY KEY (id);


--
-- Name: contenedores_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY contenedores
    ADD CONSTRAINT contenedores_pkey PRIMARY KEY (id);


--
-- Name: documentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY documentos
    ADD CONSTRAINT documentos_pkey PRIMARY KEY (id);


--
-- Name: ventas_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY ventas
    ADD CONSTRAINT ventas_pkey PRIMARY KEY (id);


--
-- Name: cambiando_el_nombre; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cambiando_el_nombre AFTER UPDATE OF nombre ON ciudadanos FOR EACH ROW EXECUTE PROCEDURE registrar_cambio_de_nombre();


--
-- PostgreSQL database dump complete
--

