/* ============================================================
   99_validacion.sql
   ------------------------------------------------------------
   Consultas de validacion para los datos cargados o generados.
   No modifica datos.

   Semantica:
     ACTIVO    = prestamo abierto. fecha_devolucion IS NULL.
                 Puede estar vencido y sigue siendo ACTIVO.
     ATRASADO  = devuelto fuera de plazo.
                 fecha_devolucion > fecha_limite. Tiene multa.
     DEVUELTO  = devuelto dentro de plazo.
                 fecha_devolucion <= fecha_limite. Sin multa.
   ============================================================ */

USE Proyecto;
GO

SET NOCOUNT ON;
GO

-- ============================================================
-- 1. Conteos por tabla
-- ============================================================
SELECT 'ejemplar' AS tabla, COUNT(*) AS filas FROM dbo.ejemplar
UNION ALL
SELECT 'libro_editorial', COUNT(*) FROM dbo.libro_editorial
UNION ALL
SELECT 'libro_genero', COUNT(*) FROM dbo.libro_genero
UNION ALL
SELECT 'libro_autor', COUNT(*) FROM dbo.libro_autor
UNION ALL
SELECT 'prestamo', COUNT(*) FROM dbo.prestamo
UNION ALL
SELECT 'prestamo_ejemplar', COUNT(*) FROM dbo.prestamo_ejemplar
UNION ALL
SELECT 'multa', COUNT(*) FROM dbo.multa
ORDER BY tabla;
GO

-- ============================================================
-- 2. Distribucion de estados
-- ============================================================
SELECT 'prestamo' AS tabla, estado, COUNT(*) AS cantidad
FROM dbo.prestamo
GROUP BY estado
UNION ALL
SELECT 'ejemplar', estado, COUNT(*)
FROM dbo.ejemplar
GROUP BY estado
ORDER BY tabla, estado;
GO

-- ============================================================
-- 3. Validaciones de integridad
-- ============================================================
CREATE TABLE #validacion
(
    orden       INT IDENTITY(1,1) NOT NULL,
    validacion  VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    errores     INT NOT NULL
);

INSERT INTO #validacion (validacion, descripcion, errores)
VALUES
('Fechas de prestamo', 'fecha_limite o fecha_devolucion invalidas',
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE fecha_limite < CAST(fecha_prestamo AS DATE)
        OR (fecha_devolucion IS NOT NULL AND fecha_devolucion < fecha_prestamo)
        OR (fecha_devolucion IS NOT NULL AND fecha_devolucion > SYSDATETIME()))),

('Activos con devolucion', 'prestamos ACTIVO con fecha_devolucion',
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE estado = 'ACTIVO' AND fecha_devolucion IS NOT NULL)),

('Atrasados sin devolucion', 'prestamos ATRASADO sin fecha_devolucion',
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE estado = 'ATRASADO' AND fecha_devolucion IS NULL)),

('Atrasados a tiempo', 'prestamos ATRASADO con devolucion dentro del plazo',
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE estado = 'ATRASADO'
       AND fecha_devolucion IS NOT NULL
       AND CAST(fecha_devolucion AS DATE) <= fecha_limite)),

('Devueltos sin devolucion', 'prestamos DEVUELTO sin fecha_devolucion',
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE estado = 'DEVUELTO' AND fecha_devolucion IS NULL)),

('Devueltos fuera de plazo', 'prestamos DEVUELTO con devolucion tardia',
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE estado = 'DEVUELTO'
       AND fecha_devolucion IS NOT NULL
       AND CAST(fecha_devolucion AS DATE) > fecha_limite)),

('Prestamos sin ejemplar', 'prestamos sin relacion en prestamo_ejemplar',
    (SELECT COUNT(*) FROM dbo.prestamo p
     WHERE NOT EXISTS (SELECT 1 FROM dbo.prestamo_ejemplar pe WHERE pe.id_prestamo = p.id_prestamo))),

('Prestamos con varios ejemplares', 'prestamos con mas de un ejemplar',
    (SELECT COUNT(*) FROM (
        SELECT id_prestamo
        FROM dbo.prestamo_ejemplar
        GROUP BY id_prestamo
        HAVING COUNT(*) > 1
     ) x)),

('Ejemplares con varios activos', 'ejemplares en mas de un prestamo ACTIVO',
    (SELECT COUNT(*) FROM (
        SELECT pe.id_ejemplar
        FROM dbo.prestamo_ejemplar pe
        INNER JOIN dbo.prestamo p ON p.id_prestamo = pe.id_prestamo
        WHERE p.estado = 'ACTIVO'
        GROUP BY pe.id_ejemplar
        HAVING COUNT(DISTINCT pe.id_prestamo) > 1
     ) x)),

('Socios con mas de 3 activos', 'socios con mas de 3 prestamos ACTIVO',
    (SELECT COUNT(*) FROM (
        SELECT id_socio
        FROM dbo.prestamo
        WHERE estado = 'ACTIVO'
        GROUP BY id_socio
        HAVING COUNT(*) > 3
     ) x)),

('Activos con ejemplar no prestado', 'prestamos ACTIVO cuyo ejemplar no esta PRESTADO',
    (SELECT COUNT(*) FROM dbo.prestamo p
     WHERE p.estado = 'ACTIVO'
       AND EXISTS (
            SELECT 1
            FROM dbo.prestamo_ejemplar pe
            INNER JOIN dbo.ejemplar e ON e.id_ejemplar = pe.id_ejemplar
            WHERE pe.id_prestamo = p.id_prestamo
              AND e.estado <> 'PRESTADO'
       ))),

('Ejemplares prestados sin activo', 'ejemplares PRESTADO sin prestamo ACTIVO',
    (SELECT COUNT(*) FROM dbo.ejemplar e
     WHERE e.estado = 'PRESTADO'
       AND NOT EXISTS (
            SELECT 1
            FROM dbo.prestamo_ejemplar pe
            INNER JOIN dbo.prestamo p ON p.id_prestamo = pe.id_prestamo
            WHERE pe.id_ejemplar = e.id_ejemplar
              AND p.estado = 'ACTIVO'
       ))),

('Reservados con prestamo activo', 'ejemplares RESERVADO con prestamo ACTIVO',
    (SELECT COUNT(DISTINCT e.id_ejemplar)
     FROM dbo.ejemplar e
     INNER JOIN dbo.prestamo_ejemplar pe ON pe.id_ejemplar = e.id_ejemplar
     INNER JOIN dbo.prestamo p ON p.id_prestamo = pe.id_prestamo
     WHERE e.estado = 'RESERVADO'
       AND p.estado = 'ACTIVO')),

('Fuera de servicio con activo', 'ejemplares FUERA_SERVICIO con prestamo ACTIVO',
    (SELECT COUNT(DISTINCT e.id_ejemplar)
     FROM dbo.ejemplar e
     INNER JOIN dbo.prestamo_ejemplar pe ON pe.id_ejemplar = e.id_ejemplar
     INNER JOIN dbo.prestamo p ON p.id_prestamo = pe.id_prestamo
     WHERE e.estado = 'FUERA_SERVICIO'
       AND p.estado = 'ACTIVO')),

('Multas duplicadas', 'mas de una multa para el mismo prestamo',
    (SELECT COUNT(*) FROM (
        SELECT id_prestamo
        FROM dbo.multa
        GROUP BY id_prestamo
        HAVING COUNT(*) > 1
     ) x)),

('Multas sin prestamo atrasado', 'multas asociadas a un prestamo que no esta ATRASADO',
    (SELECT COUNT(*) FROM dbo.multa m
     INNER JOIN dbo.prestamo p ON p.id_prestamo = m.id_prestamo
     WHERE p.estado <> 'ATRASADO')),

('Multas con monto incorrecto', 'monto distinto de dias_retraso * 2.50',
    (SELECT COUNT(*) FROM dbo.multa m
     INNER JOIN dbo.prestamo p ON p.id_prestamo = m.id_prestamo
     WHERE p.estado = 'ATRASADO'
       AND p.fecha_devolucion IS NOT NULL
       AND CAST(p.fecha_devolucion AS DATE) > p.fecha_limite
       AND (m.monto <> CAST(DATEDIFF(DAY, p.fecha_limite, CAST(p.fecha_devolucion AS DATE)) * 2.50 AS DECIMAL(10,2))
            OR m.fecha_multa <> CAST(p.fecha_devolucion AS DATE)))),

('Atrasados sin multa', 'prestamos ATRASADO sin multa',
    (SELECT COUNT(*) FROM dbo.prestamo p
     WHERE p.estado = 'ATRASADO'
       AND NOT EXISTS (SELECT 1 FROM dbo.multa m WHERE m.id_prestamo = p.id_prestamo))),

('Libros sin editorial', 'libros sin relacion en libro_editorial',
    (SELECT COUNT(*) FROM dbo.libro l
     WHERE NOT EXISTS (SELECT 1 FROM dbo.libro_editorial le WHERE le.id_libro = l.id_libro))),

('Libros sin genero', 'libros sin relacion en libro_genero',
    (SELECT COUNT(*) FROM dbo.libro l
     WHERE NOT EXISTS (SELECT 1 FROM dbo.libro_genero lg WHERE lg.id_libro = l.id_libro))),

('Libros sin autor', 'libros sin relacion en libro_autor',
    (SELECT COUNT(*) FROM dbo.libro l
     WHERE NOT EXISTS (SELECT 1 FROM dbo.libro_autor la WHERE la.id_libro = l.id_libro)));

SELECT
    validacion,
    descripcion,
    errores,
    CASE WHEN errores = 0 THEN 'OK' ELSE 'ERROR' END AS estado
FROM #validacion
ORDER BY orden;
GO

-- ============================================================
-- 4. Resumen
-- ============================================================
SELECT
    SUM(errores) AS total_errores,
    COUNT(*) AS validaciones,
    SUM(CASE WHEN errores = 0 THEN 1 ELSE 0 END) AS validaciones_ok
FROM #validacion;
GO

DROP TABLE #validacion;
GO
