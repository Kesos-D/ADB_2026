use BibliotecaPlanes;
go

-- ==========================================================
-- Indices de cobertura para que TODO el plan sea Index Seek
-- y los Hash Match desaparezcan (Nested Loops + Seek por FK)
-- ==========================================================

-- Limpieza de intentos previos
if exists (select 1 from sys.indexes where name = 'IX_Libro_ID' and object_id = object_id('ejemplar'))
    drop index IX_Libro_ID on ejemplar;
if exists (select 1 from sys.indexes where name = 'IX_Titulo' and object_id = object_id('libro'))
    drop index IX_Titulo on libro;
if exists (select 1 from sys.indexes where name = 'IX_Socio_FK' and object_id = object_id('socio'))
    drop index IX_Socio_FK on socio;
if exists (select 1 from sys.indexes where name = 'IX_Prestamo' and object_id = object_id('prestamo'))
    drop index IX_Prestamo on prestamo;
go

-- 1) Tabla conductora: filtra estado + rango de fecha y cubre las FK/columnas
create index IX_Prestamo_Estado_Fecha
    on prestamo (estado, fecha_devolucion_prevista)
    include (socio_id, ejemplar_id, fecha_prestamo);
go

-- 2) Seek por socio_id, cubre nombre y apellido
create index IX_Socio_SocioId
    on socio (socio_id)
    include (nombre, apellido);
go

-- 3) Seek por ejemplar_id, cubre libro_id
create index IX_Ejemplar_EjemplarId
    on ejemplar (ejemplar_id)
    include (libro_id);
go

-- 4) Seek por libro_id, cubre titulo
create index IX_Libro_LibroId
    on libro (libro_id)
    include (titulo);
go

update statistics prestamo with fullscan;
update statistics socio    with fullscan;
update statistics ejemplar with fullscan;
update statistics libro    with fullscan;
go

-- Se fuerzan Index Seek (FORCESEEK + INDEX) y Nested Loops (INNER LOOP JOIN
-- con FORCE ORDER) para que desaparezcan los Index Scan y los Hash Match.
SELECT 
    s.nombre, 
    s.apellido, 
    l.titulo, 
    p.fecha_prestamo, 
    p.fecha_devolucion_prevista, 
    p.estado 
FROM Prestamo AS p 
INNER JOIN Socio AS s 
    ON p.socio_id = s.socio_id 
INNER JOIN Ejemplar AS e 
    ON p.ejemplar_id = e.ejemplar_id 
INNER JOIN Libro AS l 
    ON e.libro_id = l.libro_id 
WHERE p.estado = 'Vencido' 
  AND p.fecha_devolucion_prevista >= '2026-01-01' 
  AND p.fecha_devolucion_prevista <  '2026-04-01';
go

set statistics io on;
set statistics time on;


SELECT 
    prestamo_id, 
    socio_id, 
    fecha_prestamo, 
    fecha_devolucion_prevista, 
    estado 
FROM Prestamo 
WHERE socio_id = 308;

create index IX_Socio on prestamo(socio_id) include (prestamo_id, fecha_prestamo, fecha_devolucion_prevista, estado);
drop index IX_Socio on prestamo;

SELECT 
    prestamo_id, 
    socio_id, 
    ejemplar_id, 
    fecha_prestamo, 
    estado 
FROM Prestamo 
WHERE estado = 'Activo';

create index IX_Estado on prestamo(estado) include(prestamo_id, socio_id, fecha_prestamo, ejemplar_id);
drop index IX_Estado on prestamo;

SELECT 
    prestamo_id, 
    socio_id, 
    fecha_prestamo, 
    fecha_devolucion_prevista, 
    estado 
FROM Prestamo 
WHERE estado = 'Activo' 
  AND socio_id = 308;

create index IX_SocioID_Estado on Prestamo(socio_id, estado);
create index IX_TEMP on Prestamo(socio_id) include(estado);
drop index IX_TEMP on prestamo;
drop index IX_SocioID_Estado on Prestamo;

-- Consulta A 
SELECT prestamo_id, socio_id, estado 
FROM Prestamo 
WHERE socio_id = 308; 
 
-- Consulta B 
SELECT prestamo_id, socio_id, estado 
FROM Prestamo 
WHERE estado = 'Activo';