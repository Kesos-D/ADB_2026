/* ============================================================
   full_data_csv.sql
   ------------------------------------------------------------
   Genera los datos de las tablas hijas de la base Proyecto
   a partir de las tablas madre cargadas desde la carpeta data_2.

   Orden de ejecución:
     1) 00_cargar_tablas_madres.sql   (solo si las tablas madre están vacías)
     2) full_data_csv.sql             (este archivo)
     3) 99_validacion.sql             (opcional, solo consultas)

   Requisitos:
     - Base Proyecto creada con Proyecto.sql.
     - Tablas madre con datos: empleado, socio, libro, ejemplar,
       autor, editorial y genero.
     - La tabla prestamo debe estar vacía para evitar duplicados.

   Resultado esperado:
     - ejemplar            : 8,000 filas (4 copias por libro)
     - libro_editorial     : 2,000 filas
     - libro_genero        : 2,000 filas
     - libro_autor         : 2,000 filas
     - prestamo            : 30,000 filas
     - prestamo_ejemplar   : 30,000 filas
     - multa               : ~6,000 filas
   ============================================================ */

USE Proyecto;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================
-- Validaciones previas
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM dbo.empleado)
BEGIN;
    THROW 51001, 'La tabla empleado esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.socio)
BEGIN;
    THROW 51002, 'La tabla socio esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.libro)
BEGIN;
    THROW 51003, 'La tabla libro esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.ejemplar)
BEGIN;
    THROW 51004, 'La tabla ejemplar esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.autor)
BEGIN;
    THROW 51005, 'La tabla autor esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.editorial)
BEGIN;
    THROW 51006, 'La tabla editorial esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.genero)
BEGIN;
    THROW 51007, 'La tabla genero esta vacia. Ejecuta primero 00_cargar_tablas_madres.sql.', 1;
END;

-- Evita duplicar 30,000 prestamos si el script se vuelve a ejecutar.
IF EXISTS (SELECT 1 FROM dbo.prestamo)
BEGIN;
    THROW 51010, 'La tabla prestamo ya tiene datos. Limpiala antes de volver a ejecutar este script.', 1;
END;

IF OBJECT_ID('tempdb..#nuevos_prestamo') IS NOT NULL
    DROP TABLE #nuevos_prestamo;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ========================================================
    -- 1. Ejemplares: completar 4 copias por libro
    -- ========================================================
    PRINT '1/8 Generando ejemplares adicionales...';

    INSERT INTO dbo.ejemplar (estado, id_libro)
    SELECT
        'LIBRE',
        l.id_libro
    FROM dbo.libro l
    CROSS APPLY (
        SELECT COUNT(*) AS copias_actuales
        FROM dbo.ejemplar e
        WHERE e.id_libro = l.id_libro
    ) c
    CROSS JOIN (VALUES (1), (2), (3), (4)) n(numero_copia)
    WHERE c.copias_actuales < n.numero_copia;

    -- ========================================================
    -- 2. libro_editorial: una editorial por libro
    -- ========================================================
    PRINT '2/8 Generando libro_editorial...';

    ;WITH libros_faltantes AS (
        SELECT
            l.id_libro,
            ROW_NUMBER() OVER (ORDER BY l.id_libro) AS rn
        FROM dbo.libro l
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.libro_editorial le
            WHERE le.id_libro = l.id_libro
        )
    ), editoriales AS (
        SELECT
            e.id_editorial,
            ROW_NUMBER() OVER (ORDER BY e.id_editorial) AS rn,
            COUNT(*) OVER () AS total
        FROM dbo.editorial e
    )
    INSERT INTO dbo.libro_editorial (id_libro, id_editorial)
    SELECT
        lf.id_libro,
        ed.id_editorial
    FROM libros_faltantes lf
    INNER JOIN editoriales ed
        ON ed.rn = ((lf.rn - 1) % ed.total) + 1;

    -- ========================================================
    -- 3. libro_genero: un genero por libro
    -- ========================================================
    PRINT '3/8 Generando libro_genero...';

    ;WITH libros_faltantes AS (
        SELECT
            l.id_libro,
            ROW_NUMBER() OVER (ORDER BY l.id_libro) AS rn
        FROM dbo.libro l
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.libro_genero lg
            WHERE lg.id_libro = l.id_libro
        )
    ), generos AS (
        SELECT
            g.id_genero,
            ROW_NUMBER() OVER (ORDER BY g.id_genero) AS rn,
            COUNT(*) OVER () AS total
        FROM dbo.genero g
    )
    INSERT INTO dbo.libro_genero (id_genero, id_libro)
    SELECT
        ge.id_genero,
        lf.id_libro
    FROM libros_faltantes lf
    INNER JOIN generos ge
        ON ge.rn = ((lf.rn - 1) % ge.total) + 1;

    -- ========================================================
    -- 4. libro_autor: completar libros sin autor
    -- ========================================================
    PRINT '4/8 Generando libro_autor...';

    ;WITH libros_faltantes AS (
        SELECT
            l.id_libro,
            ROW_NUMBER() OVER (ORDER BY l.id_libro) AS rn
        FROM dbo.libro l
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.libro_autor la
            WHERE la.id_libro = l.id_libro
        )
    ), autores AS (
        SELECT
            a.id_autor,
            ROW_NUMBER() OVER (ORDER BY a.id_autor) AS rn,
            COUNT(*) OVER () AS total
        FROM dbo.autor a
    )
    INSERT INTO dbo.libro_autor (id_libro, id_autor)
    SELECT
        lf.id_libro,
        au.id_autor
    FROM libros_faltantes lf
    INNER JOIN autores au
        ON au.rn = ((lf.rn - 1) % au.total) + 1;

    -- ========================================================
    -- 5. prestamo: 30,000 prestamos
    --    70% DEVUELTO / 20% ATRASADO / 10% ACTIVO
    -- ========================================================
    PRINT '5/8 Generando prestamo...';

    CREATE TABLE #nuevos_prestamo (
        id_prestamo      INT         NOT NULL PRIMARY KEY,
        fecha_prestamo   DATETIME2   NOT NULL,
        fecha_limite     DATE        NOT NULL,
        fecha_devolucion DATETIME2   NULL,
        estado           VARCHAR(15) NOT NULL
    );

    DECLARE @total INT = 30000;
    DECLARE @n_socios INT = (SELECT COUNT(*) FROM dbo.socio);
    DECLARE @n_empleados INT = (SELECT COUNT(*) FROM dbo.empleado);
    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    ;WITH numeros AS (
        SELECT 1 AS n
        UNION ALL
        SELECT n + 1
        FROM numeros
        WHERE n < @total
    ), socios AS (
        SELECT
            id_socio,
            ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
        FROM dbo.socio
    ), empleados AS (
        SELECT
            id_empleado,
            ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
        FROM dbo.empleado
    ), generado AS (
        SELECT
            n.n,
            ABS(CHECKSUM(NEWID()) % 100) AS azar,
            ABS(CHECKSUM(NEWID()) % 1000000) AS azar_fecha
        FROM numeros n
    ), prestamo_base AS (
        SELECT
            g.n,
            g.azar,
            g.azar_fecha,
            s.id_socio,
            e.id_empleado,
            CASE
                WHEN g.azar < 10 THEN 'ACTIVO'
                WHEN g.azar < 30 THEN 'ATRASADO'
                ELSE 'DEVUELTO'
            END AS estado,
            CASE
                WHEN g.azar < 10
                    THEN DATEADD(DAY, -(g.azar_fecha % 14), @hoy)
                ELSE DATEADD(
                        DAY,
                        g.azar_fecha % (DATEDIFF(DAY, '2020-01-01', '2025-12-17') + 1),
                        CAST('2020-01-01' AS DATE)
                     )
            END AS fecha_prestamo
        FROM generado g
        INNER JOIN socios s
            ON s.rn = ((g.n - 1) % @n_socios) + 1
        INNER JOIN empleados e
            ON e.rn = ((g.n - 1) % @n_empleados) + 1
    )
    INSERT INTO dbo.prestamo
        (fecha_prestamo, fecha_limite, fecha_devolucion, estado, id_empleado, id_socio)
    OUTPUT
        inserted.id_prestamo,
        inserted.fecha_prestamo,
        inserted.fecha_limite,
        inserted.fecha_devolucion,
        inserted.estado
    INTO #nuevos_prestamo
        (id_prestamo, fecha_prestamo, fecha_limite, fecha_devolucion, estado)
    SELECT
        b.fecha_prestamo,
        CASE
            WHEN b.estado = 'ACTIVO'
                THEN DATEADD(DAY, 14 + (ABS(CHECKSUM(NEWID()) % 8)), b.fecha_prestamo)
            ELSE DATEADD(DAY, 14, b.fecha_prestamo)
        END AS fecha_limite,
        CASE
            WHEN b.estado = 'ACTIVO'
                THEN NULL
            WHEN b.estado = 'DEVUELTO'
                THEN DATEADD(DAY, 7 + (ABS(CHECKSUM(NEWID()) % 8)), b.fecha_prestamo)
            ELSE DATEADD(DAY, 15 + (ABS(CHECKSUM(NEWID()) % 15)), b.fecha_prestamo)
        END AS fecha_devolucion,
        b.estado,
        b.id_empleado,
        b.id_socio
    FROM prestamo_base b
    OPTION (MAXRECURSION 0);

    -- ========================================================
    -- 6. Regla del procedimiento: maximo 3 prestamos activos
    --    por socio. El exceso se devuelve de forma puntual.
    -- ========================================================
    PRINT '6/8 Ajustando maximo de prestamos activos por socio...';

    ;WITH activos_ordenados AS (
        SELECT
            p.id_prestamo,
            ROW_NUMBER() OVER (
                PARTITION BY p.id_socio
                ORDER BY p.fecha_prestamo, p.id_prestamo
            ) AS rn
        FROM dbo.prestamo p
        WHERE p.estado = 'ACTIVO'
    )
    UPDATE p
    SET
        estado = 'DEVUELTO',
        fecha_devolucion = DATEADD(
            DAY,
            7 + (ABS(CHECKSUM(NEWID()) % 8)),
            p.fecha_prestamo
        )
    FROM dbo.prestamo p
    INNER JOIN activos_ordenados a
        ON a.id_prestamo = p.id_prestamo
    WHERE a.rn > 3;

    -- ========================================================
    -- 7. prestamo_ejemplar
    -- ========================================================
    PRINT '7/8 Generando prestamo_ejemplar...';

    -- Los ejemplares PRESTADO del CSV no representan necesariamente
    -- un prestamo activo. Se liberan y luego se marcan los que si
    -- quedan asociados a un prestamo ACTIVO.
    UPDATE dbo.ejemplar
    SET estado = 'LIBRE'
    WHERE estado = 'PRESTADO';

    -- Prestamos historicos: asignacion ciclica sobre todos los ejemplares.
    ;WITH historicos AS (
        SELECT
            p.id_prestamo,
            ROW_NUMBER() OVER (ORDER BY p.fecha_prestamo, p.id_prestamo) AS rn
        FROM dbo.prestamo p
        WHERE p.estado IN ('DEVUELTO', 'ATRASADO')
    ), copias AS (
        SELECT
            e.id_ejemplar,
            ROW_NUMBER() OVER (ORDER BY e.id_ejemplar) AS rn,
            COUNT(*) OVER () AS total
        FROM dbo.ejemplar e
    )
    INSERT INTO dbo.prestamo_ejemplar (id_prestamo, id_ejemplar)
    SELECT
        h.id_prestamo,
        c.id_ejemplar
    FROM historicos h
    INNER JOIN copias c
        ON c.rn = ((h.rn - 1) % c.total) + 1
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.prestamo_ejemplar pe
        WHERE pe.id_prestamo = h.id_prestamo
    );

    DECLARE @activos INT = (SELECT COUNT(*) FROM dbo.prestamo WHERE estado = 'ACTIVO');
    DECLARE @libres INT = (SELECT COUNT(*) FROM dbo.ejemplar WHERE estado = 'LIBRE');

    IF @activos > @libres
    BEGIN;
        THROW 51020, 'No hay suficientes ejemplares LIBRE para los prestamos ACTIVO.', 1;
    END;

    -- Prestamos activos: un ejemplar distinto por prestamo.
    ;WITH activos AS (
        SELECT
            p.id_prestamo,
            ROW_NUMBER() OVER (ORDER BY p.fecha_prestamo, p.id_prestamo) AS rn
        FROM dbo.prestamo p
        WHERE p.estado = 'ACTIVO'
    ), libres AS (
        SELECT
            e.id_ejemplar,
            ROW_NUMBER() OVER (ORDER BY e.id_ejemplar) AS rn
        FROM dbo.ejemplar e
        WHERE e.estado = 'LIBRE'
    )
    INSERT INTO dbo.prestamo_ejemplar (id_prestamo, id_ejemplar)
    SELECT
        a.id_prestamo,
        l.id_ejemplar
    FROM activos a
    INNER JOIN libres l
        ON l.rn = a.rn
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.prestamo_ejemplar pe
        WHERE pe.id_prestamo = a.id_prestamo
    );

    -- Marcar como PRESTADO unicamente los ejemplares con prestamo activo.
    UPDATE e
    SET estado = 'PRESTADO'
    FROM dbo.ejemplar e
    WHERE EXISTS (
        SELECT 1
        FROM dbo.prestamo p
        INNER JOIN dbo.prestamo_ejemplar pe
            ON pe.id_prestamo = p.id_prestamo
        WHERE p.estado = 'ACTIVO'
          AND pe.id_ejemplar = e.id_ejemplar
    );

    -- ========================================================
    -- 8. multa: devoluciones tardias
    --    60% PAGADO / 30% PENDIENTE / 10% CANCELADO
    -- ========================================================
    PRINT '8/8 Generando multa...';

    ;WITH tardios AS (
        SELECT
            p.id_prestamo,
            CAST(p.fecha_devolucion AS DATE) AS fecha_devolucion,
            DATEDIFF(DAY, p.fecha_limite, CAST(p.fecha_devolucion AS DATE)) AS dias_retraso,
            ABS(CHECKSUM(NEWID()) % 10) AS azar
        FROM dbo.prestamo p
        WHERE p.fecha_devolucion IS NOT NULL
          AND CAST(p.fecha_devolucion AS DATE) > p.fecha_limite
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.multa m
              WHERE m.id_prestamo = p.id_prestamo
          )
    )
    INSERT INTO dbo.multa (fecha_multa, estado, monto, id_prestamo)
    SELECT
        t.fecha_devolucion,
        CASE
            WHEN t.azar < 6 THEN 'PAGADO'
            WHEN t.azar < 9 THEN 'PENDIENTE'
            ELSE 'CANCELADO'
        END,
        CAST(t.dias_retraso * 2.50 AS DECIMAL(10, 2)),
        t.id_prestamo
    FROM tardios t;

    -- ========================================================
    -- Validaciones antes del COMMIT
    -- ========================================================
    IF (SELECT COUNT(*) FROM dbo.prestamo) <> 30000
    BEGIN;
        THROW 51030, 'La tabla prestamo no quedo con 30,000 filas.', 1;
    END;

    IF (SELECT COUNT(*) FROM dbo.prestamo_ejemplar) <> 30000
    BEGIN;
        THROW 51031, 'La tabla prestamo_ejemplar no quedo con 30,000 filas.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.libro l
        WHERE NOT EXISTS (SELECT 1 FROM dbo.libro_editorial le WHERE le.id_libro = l.id_libro)
    )
    BEGIN;
        THROW 51032, 'Hay libros sin editorial.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.libro l
        WHERE NOT EXISTS (SELECT 1 FROM dbo.libro_genero lg WHERE lg.id_libro = l.id_libro)
    )
    BEGIN;
        THROW 51033, 'Hay libros sin genero.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.libro l
        WHERE NOT EXISTS (SELECT 1 FROM dbo.libro_autor la WHERE la.id_libro = l.id_libro)
    )
    BEGIN;
        THROW 51034, 'Hay libros sin autor.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.prestamo_ejemplar pe WHERE pe.id_prestamo = p.id_prestamo)
    )
    BEGIN;
        THROW 51035, 'Hay prestamos sin ejemplar asociado.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT pe.id_ejemplar
            FROM dbo.prestamo_ejemplar pe
            INNER JOIN dbo.prestamo p
                ON p.id_prestamo = pe.id_prestamo
            WHERE p.estado = 'ACTIVO'
            GROUP BY pe.id_ejemplar
            HAVING COUNT(*) > 1
        ) x
    )
    BEGIN;
        THROW 51036, 'Hay ejemplares con mas de un prestamo ACTIVO.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT id_socio
            FROM dbo.prestamo
            WHERE estado = 'ACTIVO'
            GROUP BY id_socio
            HAVING COUNT(*) > 3
        ) x
    )
    BEGIN;
        THROW 51037, 'Hay socios con mas de 3 prestamos ACTIVO.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.multa m
        INNER JOIN dbo.prestamo p
            ON p.id_prestamo = m.id_prestamo
        WHERE m.monto <= 0
           OR p.fecha_devolucion IS NULL
           OR CAST(p.fecha_devolucion AS DATE) <= p.fecha_limite
    )
    BEGIN;
        THROW 51038, 'Hay multas sin una devolucion tardia valida.', 1;
    END;

    COMMIT TRANSACTION;
    PRINT 'Datos generados correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- ============================================================
-- Resumen final
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

SELECT 'prestamo' AS tabla, estado, COUNT(*) AS cantidad
FROM dbo.prestamo
GROUP BY estado
UNION ALL
SELECT 'ejemplar', estado, COUNT(*)
FROM dbo.ejemplar
GROUP BY estado
ORDER BY tabla, estado;
GO
