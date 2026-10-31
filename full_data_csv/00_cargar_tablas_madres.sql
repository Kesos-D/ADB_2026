/* ============================================================
   00_cargar_tablas_madres.sql
   ------------------------------------------------------------
   Carga las tablas madre desde los CSV de data_2.

   Este script esta pensado para ejecutarse dentro del contenedor
   SQL Server del proyecto, donde data_2 se copio a /data/data_2.

   Pasos previos (fuera de SQL):
     docker cp .\data_2\ sqlserver-2025:/data/

   Cada BULK INSERT solo se ejecuta si la tabla esta vacia, para
   no duplicar datos. Si una tabla ya tiene filas, se omite.
   ============================================================ */

create database Proyecto;
go

USE Proyecto;
GO

SET NOCOUNT OFF;
GO

PRINT 'Cargando tablas madre desde /data/data_2 ...';

-- 1. empleado
IF NOT EXISTS (SELECT 1 FROM dbo.empleado)
BEGIN
    PRINT '  -> empleado';
    BULK INSERT dbo.empleado
    FROM '/data/data_2/empleado/empleado.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 2. socio
IF NOT EXISTS (SELECT 1 FROM dbo.socio)
BEGIN
    PRINT '  -> socio';
    BULK INSERT dbo.socio
    FROM '/data/data_2/socio/socio.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 3. autor
IF NOT EXISTS (SELECT 1 FROM dbo.autor)
BEGIN
    PRINT '  -> autor';
    BULK INSERT dbo.autor
    FROM '/data/data_2/autor/autor.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 4. editorial
IF NOT EXISTS (SELECT 1 FROM dbo.editorial)
BEGIN
    PRINT '  -> editorial';
    BULK INSERT dbo.editorial
    FROM '/data/data_2/editorial/editorial.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 5. genero
IF NOT EXISTS (SELECT 1 FROM dbo.genero)
BEGIN
    PRINT '  -> genero';
    BULK INSERT dbo.genero
    FROM '/data/data_2/genero/genero.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 6. libro
IF NOT EXISTS (SELECT 1 FROM dbo.libro)
BEGIN
    PRINT '  -> libro';
    BULK INSERT dbo.libro
    FROM '/data/data_2/libro/libro.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 7. ejemplar
IF NOT EXISTS (SELECT 1 FROM dbo.ejemplar)
BEGIN
    PRINT '  -> ejemplar';
    BULK INSERT dbo.ejemplar
    FROM '/data/data_2/ejemplar/ejemplar.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        KEEPIDENTITY,
        TABLOCK
    );
END;

-- 8. libro_autor (sin columna identity)
IF NOT EXISTS (SELECT 1 FROM dbo.libro_autor)
BEGIN
    PRINT '  -> libro_autor';
    BULK INSERT dbo.libro_autor
    FROM '/data/data_2/libro_autor/libro_autor.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        TABLOCK
    );
END;

-- 9. libro_editorial: una editorial por libro
IF EXISTS (
    SELECT 1
    FROM dbo.libro l
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.libro_editorial le
        WHERE le.id_libro = l.id_libro
    )
)
BEGIN
    PRINT '  -> libro_editorial (completar)';

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
END;

-- 10. libro_genero: un genero por libro
IF EXISTS (
    SELECT 1
    FROM dbo.libro l
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.libro_genero lg
        WHERE lg.id_libro = l.id_libro
    )
)
BEGIN
    PRINT '  -> libro_genero (completar)';

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
END;

-- 11. libro_autor: completar libros sin autor
IF EXISTS (
    SELECT 1
    FROM dbo.libro l
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.libro_autor la
        WHERE la.id_libro = l.id_libro
    )
)
BEGIN
    PRINT '  -> libro_autor (completar)';

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
END;

PRINT 'Carga de tablas madre finalizada.';
GO

SELECT 'empleado' AS tabla, COUNT(*) AS filas FROM dbo.empleado
UNION ALL
SELECT 'socio', COUNT(*) FROM dbo.socio
UNION ALL
SELECT 'autor', COUNT(*) FROM dbo.autor
UNION ALL
SELECT 'editorial', COUNT(*) FROM dbo.editorial
UNION ALL
SELECT 'genero', COUNT(*) FROM dbo.genero
UNION ALL
SELECT 'libro', COUNT(*) FROM dbo.libro
UNION ALL
SELECT 'ejemplar', COUNT(*) FROM dbo.ejemplar
UNION ALL
SELECT 'libro_autor', COUNT(*) FROM dbo.libro_autor
UNION ALL
SELECT 'libro_editorial', COUNT(*) FROM dbo.libro_editorial
UNION ALL
SELECT 'libro_genero', COUNT(*) FROM dbo.libro_genero
ORDER BY tabla;
GO