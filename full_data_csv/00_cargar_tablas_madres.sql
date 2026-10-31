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
ORDER BY tabla;
GO

select * from multa;