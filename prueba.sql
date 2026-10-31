--! Codigo para crear las filas de libro_autor
use master;
use Proyecto;
with data_autor as (
    select
        id_autor,
        row_number() over(order by newid()) rda
    from autor
), data_libro as (
    select
        id_libro,
        row_number() over(order by newid()) rdl
    from libro
)
insert into dbo.libro_autor (id_autor, id_libro)
select
    id_autor,
    id_libro
from data_autor a join data_libro l
    on a.rda = l.rdl
order by id_autor, id_libro;

SELECT
    id_prestamo,
    FLOOR(RAND(CHECKSUM(NEWID())) * 100) + 1 AS aleatorio
FROM prestamo;


-- Si es un numero entre 1-4 -> Libre
-- Si es un numero entre 5-7 -> Prestado
-- Si es un numero entre 8-9 -> Reservado
-- Si es 10 -> Fuera de servicion
with data_libro as (
    select
        id_libro
    from libro
)
insert into dbo.ejemplar (id_libro, estado)
select
    id_libro,
    case 
        when FLOOR(RAND(CHECKSUM(NEWID())) * 10) + 1 <= 4 
            then 'LIBRE'
        when FLOOR(RAND(CHECKSUM(NEWID())) * 10) + 1 <= 7 
            then 'PRESTADO'
        when FLOOR(RAND(CHECKSUM(NEWID())) * 10) + 1 <= 9 
            then 'RESERVADO'
        when FLOOR(RAND(CHECKSUM(NEWID())) * 10) + 1 <= 10 then 'FUERA_SERVICIO'
    end as estado
from data_libro;

select * from ejemplar;

-- Si esta activo el prestamo significa que el ejemplar debe ser -> PRESTADO, RESERVADO
select * from prestamo;
select * from ejemplar;

with data_prestamo as (
    select
        id_prestamo,
        estado,
        row_number() over(order by newid()) dp_unique
    from prestamo
    where estado = 'ACTIVO'
), data_ejemplar as (
    select
        id_ejemplar,
        estado,
        row_number() over(order by newid()) de_unique
    from ejemplar
    where estado in ('PRESTADO', 'RESERVADO')
)
insert into dbo.prestamo_ejemplar (id_prestamo, id_ejemplar)
select
    dp.id_prestamo,
    de.id_ejemplar
from data_prestamo dp
join data_ejemplar de
    on de.de_unique = dp.dp_unique;

begin transaction;

update e
set estado = 'FUERA_SERVICIO'
from ejemplar e
where estado in ('PRESTADO', 'RESERVADO')
and not exists(
    select * from 
    prestamo_ejemplar pe
    where e.id_ejemplar = pe.id_ejemplar
);

select * from ejemplar where estado in ('PRESTADO', 'RESERVADO');
rollback transaction;
commit transaction;

select * from prestamo_ejemplar;

select id_socio, count(estado) libros_prestado
from prestamo
where estado = 'ACTIVO'
group by id_socio 
having count(estado) >= 2
order by libros_prestado desc;


select
    p.id_socio
from prestamo p
where estado = 'ACTIVO' and (
    select count(*)
    from prestamo_ejemplar pe
    where pe.id_prestamo = p.id_prestamo
) > 1

-- estado = 'ACTIVO' > 2 then debe tener 2 libros asociados
-- si es 3 al menos 3 libros
-- podemos usar libros que estan fuera de servicio o activo

create table #asignaciones (
    id_prestamo INT,
    id_ejemplar INT
)
go


with prestamos_activos as (
    select
        id_prestamo,
        id_socio,
        count(estado) over(partition by id_socio) libros_registrados,
        row_number() over(order by newid()) id_pa
    from prestamo p
    where estado = 'ACTIVO' and (
        select
            count(*)
        from prestamo pe
        where p.id_socio = pe.id_socio
        and estado = 'ACTIVO'
    ) > 1
), libros_posibles as (
    select
        id_ejemplar,
        row_number() over(order by newid()) id_lp
    from ejemplar
    where estado = 'LIBRE' or estado = 'FUERA_SERVICIO'
)
insert into #asignaciones (id_prestamo, id_ejemplar)
select
    pa.id_prestamo,
    lp.id_ejemplar
from prestamos_activos pa
join libros_posibles lp
    on pa.id_pa = lp.id_lp
where pa.libros_registrados > 1;

select * from #asignaciones;

select * from libro_genero;

--! Actualizar registros de LIBRE o FUERA DE SERVICIO -> Prestado

update e
set estado = 'PRESTADO'
from ejemplar e
join #asignaciones a
    on a.id_ejemplar = e.id_ejemplar;

select * 
from ejemplar
where id_ejemplar in (
    select
        id_ejemplar
    from #asignaciones
)

BEGIN TRANSACTION;

-- Asegúrate de que la tabla esté vacía o que los IDs de libros y géneros existan (del 1 al 300 y del 1 al 30)
WITH NumerosLibros AS (
    SELECT 1 AS id_libro
    UNION ALL
    SELECT id_libro + 1
    FROM NumerosLibros
    WHERE id_libro < 300
)
INSERT INTO libro_genero (id_genero, id_libro)
SELECT 
    ((id_libro - 1) % 30) + 1 AS id_genero, -- Distribuye cíclicamente del 1 al 30 los géneros
    id_libro
FROM NumerosLibros
OPTION (MAXRECURSION 350);

WITH NumerosLibros AS (
    SELECT 1 AS id_libro
    UNION ALL
    SELECT id_libro + 1
    FROM NumerosLibros
    WHERE id_libro < 300
)
INSERT INTO libro_editorial (id_libro, id_editorial)
SELECT 
    id_libro,
    ((id_libro - 1) / 3) + 1 AS id_editorial
FROM NumerosLibros
OPTION (MAXRECURSION 350);

select * from libro_editorial;

commit TRANSACTION;


with data_prestamo as (
    select
    id_prestamo,
    id_socio
    from prestamo
    where estado = 'ACTIVO'
), tabla_data as (
    select
        id_prestamo
    from prestamo_ejemplar
)
select
    dp.id_socio, count(dp.id_socio) xd, count(dp.id_prestamo)
from data_prestamo dp
join tabla_data td
    on td.id_prestamo = dp.id_prestamo
group by dp.id_socio
order by xd desc;

WITH data_prestamo AS (
    SELECT
        id_prestamo,
        id_socio
    FROM prestamo
    where estado = 'ACTIVO'
),
tabla_data AS (
    SELECT
        id_prestamo
    FROM prestamo_ejemplar
)
SELECT
    dp.id_socio,
    COUNT(DISTINCT dp.id_prestamo) AS prestamos_activos,
    COUNT(td.id_prestamo) AS registros_relacionados
FROM data_prestamo dp
LEFT JOIN tabla_data td
    ON td.id_prestamo = dp.id_prestamo
GROUP BY dp.id_socio
ORDER BY prestamos_activos DESC;

select * from prestamo where id_socio = 31

select
    id_socio,
    count(id_socio) x
from prestamo p
group by id_socio
order by x desc;

select * from prestamo where id_socio = 231;


select *
from prestamo
where estado in ('DEVUELTO', 'ATRASADO')

select * from libro;

BEGIN TRANSACTION;

create table #tempRegistro(
    id_prestamo INT NOT NULL,
    id_ejemplar INT NOT NULL
)
go

with prestamos_activos as (
    select
        id_prestamo,
        id_socio,
        count(estado) over(partition by id_socio) libros_registrados,
        row_number() over(order by newid()) id_pa
    from prestamo p
    where estado in ('DEVUELTO', 'ATRASADO') and not exists (
        select 
            1 
        from #tempRegistro t
        where t.id_prestamo = p.id_prestamo
    )
), libros_posibles as (
    select
        id_ejemplar,
        estado,
        row_number() over(order by newid()) id_lp
    from ejemplar
    where estado = 'PRESTADO' or estado = 'RESERVADO'
)
insert into #tempRegistro (id_prestamo, id_ejemplar)
select
    pa.id_prestamo,
    lp.id_ejemplar
from prestamos_activos pa
join libros_posibles lp
    on pa.id_pa = lp.id_lp;

select * from #tempRegistro;

insert into prestamo_ejemplar (id_ejemplar, id_prestamo)
select
    a.id_ejemplar,
    a.id_prestamo
from #tempRegistro a;

select * from prestamo where id_socio = 177;

WITH data_x AS (
    SELECT 
        p.id_socio,
        COUNT(DISTINCT p.id_prestamo) AS total_prestamos,
        COUNT(pe.id_prestamo) AS total_prestamo_ejemplar
    FROM prestamo p
    LEFT JOIN prestamo_ejemplar pe ON p.id_prestamo = pe.id_prestamo
    GROUP BY p.id_socio
    HAVING COUNT(DISTINCT p.id_prestamo) <> COUNT(pe.id_prestamo)
)
SELECT 
    p.id_prestamo,
    p.id_socio,
    p.estado -- Agrega aquí las demás columnas de la tabla prestamo que necesites
FROM prestamo p
left JOIN data_x dx ON p.id_socio = dx.id_socio
order by id_socio desc;

SELECT 
    p.id_prestamo, 
    COUNT(pe.id_ejemplar) AS cantidad_ejemplares
FROM prestamo p
LEFT JOIN prestamo_ejemplar pe ON p.id_prestamo = pe.id_prestamo
WHERE p.id_socio = 29
GROUP BY p.id_prestamo;

SELECT 
    p.id_prestamo,
    p.id_socio,
    COUNT(pe.id_ejemplar) AS total_libros
FROM prestamo p
INNER JOIN prestamo_ejemplar pe ON p.id_prestamo = pe.id_prestamo
GROUP BY p.id_prestamo, p.id_socio
HAVING COUNT(pe.id_ejemplar) > 1
order by p.id_socio desc;

select * from prestamo where id_socio = 29;

select * from prestamo_ejemplar where id_prestamo in (877,
945,
977,
12,
90,
282)

select count(*) from prestamo_ejemplar;

WITH SociosInconsistentes AS (
    SELECT p.id_socio
    FROM prestamo p
    LEFT JOIN prestamo_ejemplar pe ON p.id_prestamo = pe.id_prestamo
    GROUP BY p.id_socio
    HAVING COUNT(DISTINCT p.id_prestamo) <> COUNT(pe.id_prestamo)
)
DELETE pe
FROM prestamo_ejemplar pe
INNER JOIN prestamo p ON pe.id_prestamo = p.id_prestamo
INNER JOIN SociosInconsistentes s ON p.id_socio = s.id_socio;

rollback transaction;

select * from prestamo_ejemplar;

SELECT id_prestamo, id_ejemplar, COUNT(*) AS veces_repetido
FROM prestamo_ejemplar
GROUP BY id_prestamo, id_ejemplar
HAVING COUNT(*) > 1;

commit transaction;