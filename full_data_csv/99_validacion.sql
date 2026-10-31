/* ============================================================
   99_validacion.sql
   ------------------------------------------------------------
   Consultas de validación para los datos generados.
   No modifica datos.
   ============================================================ */

USE Proyecto;
GO

SET NOCOUNT ON;
GO

-- Conteos por tabla
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

-- Distribución de estados
SELECT 'prestamo' AS tabla, estado, COUNT(*) AS cantidad
FROM dbo.prestamo
GROUP BY estado
UNION ALL
SELECT 'ejemplar', estado, COUNT(*)
FROM dbo.ejemplar
GROUP BY estado
ORDER BY tabla, estado;
GO

-- Libros sin relaciones
SELECT 'libros sin editorial' AS validacion, COUNT(*) AS cantidad
FROM dbo.libro l
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.libro_editorial le WHERE le.id_libro = l.id_libro
)
UNION ALL
SELECT 'libros sin genero', COUNT(*)
FROM dbo.libro l
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.libro_genero lg WHERE lg.id_libro = l.id_libro
)
UNION ALL
SELECT 'libros sin autor', COUNT(*)
FROM dbo.libro l
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.libro_autor la WHERE la.id_libro = l.id_libro
);
GO

-- Préstamos sin ejemplar
SELECT 'prestamos sin ejemplar' AS validacion, COUNT(*) AS cantidad
FROM dbo.prestamo p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.prestamo_ejemplar pe WHERE pe.id_prestamo = p.id_prestamo
);
GO

-- Ejemplares con más de un préstamo activo
SELECT
    pe.id_ejemplar,
    COUNT(*) AS prestamos_activos
FROM dbo.prestamo_ejemplar pe
INNER JOIN dbo.prestamo p
    ON p.id_prestamo = pe.id_prestamo
WHERE p.estado = 'ACTIVO'
GROUP BY pe.id_ejemplar
HAVING COUNT(*) > 1;
GO

-- Socios con más de 3 préstamos activos
SELECT
    id_socio,
    COUNT(*) AS prestamos_activos
FROM dbo.prestamo
WHERE estado = 'ACTIVO'
GROUP BY id_socio
HAVING COUNT(*) > 3;
GO

-- Multas inválidas
SELECT
    m.id_multa,
    m.id_prestamo,
    m.monto,
    p.fecha_limite,
    p.fecha_devolucion
FROM dbo.multa m
INNER JOIN dbo.prestamo p
    ON p.id_prestamo = m.id_prestamo
WHERE m.monto <= 0
   OR p.fecha_devolucion IS NULL
   OR CAST(p.fecha_devolucion AS DATE) <= p.fecha_limite;
GO

-- Diferencia entre devoluciones tardías y multas
SELECT
    (SELECT COUNT(*) FROM dbo.prestamo
     WHERE fecha_devolucion IS NOT NULL
       AND CAST(fecha_devolucion AS DATE) > fecha_limite) AS devoluciones_tardias,
    (SELECT COUNT(*) FROM dbo.multa) AS multas_generadas;
GO

select * from prestamo_ejemplar;