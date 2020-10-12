-- 1. Realiza una consulta SQL que obtenga el nombre, apellido, fecha de nacimiento y categoría de todos los 
-- jugadores en la base de datos.

select nombre,apellido,fecha_nacimiento,categoria from jugadores

-- 2. Realiza una consulta SQL que obtenga el nombre de todas las ciudades almacenadas, con su latitud y longitud.

select nombre,latitud,longitud from ciudades

-- 3. Realiza una consulta SQL que obtenga el nombre de todos los campos de golf almacenados en la base de datos, 
-- mostrando su nombre, dirección, y el nombre de la ciudad en la que se encuentran.

select campos.nombre,campos.direccion,ci.nombre from campos inner join ciudades ci ON campos.fk_ciudad = ci.id

-- 4. Realiza una consulta SQL que obtenga como resultado la ciudad en la que se juega el torneo “Masters de París”.

select ci.nombre from tarjetas_torneo 
inner join campos ca ON tarjetas_torneo.fk_campo = ca.id 
inner join ciudades ci ON ca.fk_ciudad = ci.id
where fk_torneo = (select id from torneos where nombre like 'Masters de Paris') AND fk_jugador = 1 AND fk_numero_hoyo = 1

-- 5. Realiza una consulta SQL que obtenga como resultado el número de golpes que cada participante del torneo 
-- “Masters de París”, realizó en el primer hoyo del campo.

select jugadores.nombre,jugadores.apellido,sum(numero_golpes) total_golpes from tarjetas_torneo
inner join jugadores ON tarjetas_torneo.fk_jugador = jugadores.id
where fk_torneo = (select id from torneos where nombre like 'Masters de Paris')
AND tarjetas_torneo.fk_numero_hoyo = 1
group by jugadores.nombre,jugadores.apellido

-- 6. Realiza una consulta SQL para obtener el número de golpes de cada jugador por cada hoyo del campo en el que 
-- se jugó el torneo “Masters de París”. Los resultados deben estar ordenados por el número del hoyo.

select jugadores.nombre,jugadores.apellido,fk_numero_hoyo,numero_golpes from tarjetas_torneo
inner join jugadores ON tarjetas_torneo.fk_jugador = jugadores.id
where fk_torneo = (select id from torneos where nombre like 'Masters de Paris')
order by fk_numero_hoyo

-- 7. Realiza una consulta SQL que muestre el nombre, el apellido y la ciudad natal de todos los jugadores inscritos 
-- en los torneos almacenados en la base de datos.

select jugadores.id,jugadores.nombre,jugadores.apellido,ciudades.nombre from tarjetas_torneo
inner join jugadores ON tarjetas_torneo.fk_jugador = jugadores.id
inner join ciudades ON jugadores.fk_ciudad_origen = ciudades.id
group by jugadores.id,jugadores.nombre,jugadores.apellido,ciudades.nombre

-- 8. Realiza una consulta SQL que obtenga el número de campos de golf en cada país almacenado en la base de datos.

select paises.nombre, count(campos.nombre) from campos 
inner join ciudades ON campos.fk_ciudad = ciudades.id
inner join paises ON ciudades.fk_pais = paises.id
group by paises.nombre