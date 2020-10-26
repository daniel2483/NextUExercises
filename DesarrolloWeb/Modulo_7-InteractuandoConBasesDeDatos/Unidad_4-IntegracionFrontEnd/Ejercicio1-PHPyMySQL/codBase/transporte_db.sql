-- phpMyAdmin SQL Dump
-- version 4.5.2
-- http://www.phpmyadmin.net
--
-- Servidor: localhost
-- Tiempo de generación: 28-11-2016 a las 14:39:06
-- Versión del servidor: 10.1.13-MariaDB
-- Versión de PHP: 5.6.23

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `transporte_db`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ciudades`
--

CREATE TABLE `ciudades` (
  `id` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `fk_estado` int(2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `ciudades`
--

INSERT INTO `ciudades` (`id`, `nombre`, `fk_estado`) VALUES
(1, 'Sacramento', 1),
(2, 'Los Angeles', 1),
(3, 'Denver', 2),
(4, 'Tallahassee', 3),
(5, 'Miami', 3),
(6, 'Atlanta', 4),
(7, 'Albany', 5),
(8, 'New York City', 5),
(9, 'Houston', 6),
(10, 'Austin', 6);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estados`
--

CREATE TABLE `estados` (
  `id` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `estados`
--

INSERT INTO `estados` (`id`, `nombre`) VALUES
(1, 'California'),
(2, 'Colorado'),
(3, 'Florida'),
(4, 'Georgia'),
(5, 'New York'),
(6, 'Texas');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id` int(11) NOT NULL,
  `nombre` varchar(30) CHARACTER SET utf8 COLLATE utf8_spanish_ci NOT NULL,
  `psw` varchar(255) NOT NULL,
  `email` varchar(45) NOT NULL,
  `experiencia` varchar(100) NOT NULL,
  `fecha_nacimiento` date NOT NULL,
  `sexo` enum('Masculino','Femenino','','') NOT NULL,
  `tipo_vehiculo` enum('automovil','bus','automovil y bus','') NOT NULL,
  `fuera_ciudad` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id`, `nombre`, `psw`, `email`, `experiencia`, `fecha_nacimiento`, `sexo`, `tipo_vehiculo`, `fuera_ciudad`) VALUES
(1, 'Juan Pablo Morales', '$2y$10$XGpCDWz4hofRbQoAtlaPI.ECG97qqgEEOHlZAXMHroLVHkEahCAra', 'jp@mail.com', 'Entre 5 y 10 anios', '1991-01-08', 'Masculino', 'automovil y bus', 1),
(3, 'Pedro Gonzales', '$2y$10$DxFHrkNzgldPpQPx0a.G0u4ylHSBMNleL4i2PebvC11rspLeqJmQC', 'pedro.g@mail.com', 'Mas de 10 anios', '1967-10-26', 'Masculino', 'automovil y bus', 1),
(4, 'MarÃ­a Jimenez', '$2y$10$ZEFHsMsm8DJsGbPpfhKrT.QhiVIqp6XBHl9hy.2axfOfq9I79TWkC', 'mj@mail.com', 'Menos de 1 anio', '1997-11-06', 'Masculino', 'automovil y bus', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `vehiculos`
--

CREATE TABLE `vehiculos` (
  `placa` varchar(7) NOT NULL,
  `fabricante` varchar(20) NOT NULL,
  `modelo` year(4) NOT NULL,
  `referencia` varchar(20) NOT NULL,
  `capacidad` int(11) NOT NULL,
  `tipo` enum('automovil','bus','','') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `vehiculos`
--

INSERT INTO `vehiculos` (`placa`, `fabricante`, `modelo`, `referencia`, `capacidad`, `tipo`) VALUES
('FRW-875', 'KIA', 2014, 'G4', 10, 'automovil'),
('KDM-324', 'KIA', 2013, 'G4', 10, 'automovil'),
('QSZ-749', 'KIA', 2016, 'G7', 12, 'automovil'),
('RSL-007', 'RENAULT', 2015, 'R9', 20, 'bus'),
('YUL-210', 'RENAULT', 2015, 'R9', 20, 'bus');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `viajes`
--

CREATE TABLE `viajes` (
  `id` int(11) NOT NULL,
  `fk_ciudad_origen` int(2) NOT NULL,
  `fk_ciudad_destino` int(2) NOT NULL,
  `fk_vehiculo` varchar(7) NOT NULL,
  `fk_conductor` int(11) NOT NULL,
  `fecha_salida` date NOT NULL,
  `fecha_llegada` date DEFAULT NULL,
  `hora_salida` time NOT NULL,
  `hora_llegada` time DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `viajes`
--

INSERT INTO `viajes` (`id`, `fk_ciudad_origen`, `fk_ciudad_destino`, `fk_vehiculo`, `fk_conductor`, `fecha_salida`, `fecha_llegada`, `hora_salida`, `hora_llegada`) VALUES
(1, 1, 3, 'FRW-875', 3, '2016-11-01', '2016-11-03', '08:00:00', '17:00:00'),
(5, 7, 9, 'KDM-324', 1, '2016-11-16', '2016-11-26', '14:00:00', '02:00:00'),
(6, 4, 7, 'QSZ-749', 1, '2016-11-27', '2016-11-30', '06:00:00', '14:00:00'),
(7, 9, 7, 'YUL-210', 1, '2016-11-23', '2016-11-25', '21:00:00', '04:00:00'),
(8, 3, 4, 'FRW-875', 3, '2016-11-30', NULL, '11:00:00', NULL),
(9, 3, 4, 'FRW-875', 3, '2016-11-30', NULL, '11:00:00', NULL),
(10, 1, 2, 'YUL-210', 1, '2017-01-11', NULL, '08:00:00', NULL),
(11, 5, 6, 'QSZ-749', 1, '2017-02-08', NULL, '06:00:00', NULL),
(12, 6, 4, 'KDM-324', 4, '2017-02-08', NULL, '11:00:00', NULL);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `ciudades`
--
ALTER TABLE `ciudades`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `estados`
--
ALTER TABLE `estados`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email-user` (`email`);

--
-- Indices de la tabla `vehiculos`
--
ALTER TABLE `vehiculos`
  ADD PRIMARY KEY (`placa`);

--
-- Indices de la tabla `viajes`
--
ALTER TABLE `viajes`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `ciudades`
--
ALTER TABLE `ciudades`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;
--
-- AUTO_INCREMENT de la tabla `estados`
--
ALTER TABLE `estados`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;
--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;
--
-- AUTO_INCREMENT de la tabla `viajes`
--
ALTER TABLE `viajes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
