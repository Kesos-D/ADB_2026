/* ============================================================
   01_cargar_prestamos_csv.sql
   ------------------------------------------------------------
   Carga prestamo, prestamo_ejemplar y multa desde los CSV de
   data_2, conservando los id originales.

   Este script es la alternativa a full_data_csv.sql: usa los
   datos ya validados de data_2 en lugar de generarlos.

   Pasos previos (fuera de SQL):
     docker cp .\data_2\ sqlserver-2025:/data/

   Orden de ejecucion:
     1) Proyecto.sql
     2) 00_cargar_tablas_madres.sql
     3) 01_cargar_prestamos_csv.sql    (este archivo)
     4) triggers_procedimientos.sql
     5) 99_validacion.sql

   Notas:
     - No ejecutar full_data_csv.sql si se usa este cargador.
     - Las tres tablas deben estar vacias.
     - Los triggers se desactivan durante la carga para que no
       generen multas duplicadas ni rechacen filas historicas.
     - Se usan tablas temporales de texto para convertir la fecha
       de devolucion vacia (un espacio en el CSV) a NULL.
   ============================================================ */

USE Proyecto;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF EXISTS (SELECT 1 FROM dbo.prestamo)
   OR EXISTS (SELECT 1 FROM dbo.prestamo_ejemplar)
   OR EXISTS (SELECT 1 FROM dbo.multa)
BEGIN
    ;THROW 52001, 'Las tablas prestamo, prestamo_ejemplar o multa ya tienen datos. Limpialas antes de cargar los CSV.', 1;
END

-- Desactiva todos los triggers de las tablas que se van a cargar.
ALTER TABLE dbo.prestamo DISABLE TRIGGER ALL;
ALTER TABLE dbo.prestamo_ejemplar DISABLE TRIGGER ALL;
ALTER TABLE dbo.multa DISABLE TRIGGER ALL;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ========================================================
    -- 1. prestamo
    -- ========================================================
    PRINT '1/3 Cargando prestamo...';

    CREATE TABLE #prestamo_csv
    (
        id_prestamo      INT           NOT NULL,
        fecha_prestamo   VARCHAR(50)   NOT NULL,
        fecha_limite     VARCHAR(20)   NOT NULL,
        fecha_devolucion VARCHAR(50)   NULL,
        estado           VARCHAR(15)   NOT NULL,
        id_empleado      INT           NOT NULL,
        id_socio         INT           NOT NULL
    );

    BULK INSERT #prestamo_csv
    FROM '/data/data_2/prestamo/prestamo.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        TABLOCK
    );

    SET IDENTITY_INSERT dbo.prestamo ON;

    INSERT INTO dbo.prestamo
        (id_prestamo, fecha_prestamo, fecha_limite, fecha_devolucion, estado, id_empleado, id_socio)
    SELECT
        id_prestamo,
        TRY_CONVERT(DATETIME2(7), fecha_prestamo),
        TRY_CONVERT(DATE, fecha_limite),
        TRY_CONVERT(DATETIME2(7), NULLIF(LTRIM(RTRIM(fecha_devolucion)), '')),
        estado,
        id_empleado,
        id_socio
    FROM #prestamo_csv;

    SET IDENTITY_INSERT dbo.prestamo OFF;

    -- ========================================================
    -- 2. prestamo_ejemplar
    -- ========================================================
    PRINT '2/3 Cargando prestamo_ejemplar...';

    BULK INSERT dbo.prestamo_ejemplar
    FROM '/data/data_2/prestamo_ejemplar/prestamo_ejemplar.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        TABLOCK
    );

    -- ========================================================
    -- 3. multa
    -- ========================================================
    PRINT '3/3 Cargando multa...';

    CREATE TABLE #multa_csv
    (
        id_multa    INT           NOT NULL,
        fecha_multa VARCHAR(20)   NOT NULL,
        estado      VARCHAR(15)   NOT NULL,
        monto       VARCHAR(30)   NOT NULL,
        id_prestamo INT           NOT NULL
    );

    BULK INSERT #multa_csv
    FROM '/data/data_2/multa/multa.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0d0a',
        TABLOCK
    );

    SET IDENTITY_INSERT dbo.multa ON;

    INSERT INTO dbo.multa
        (id_multa, fecha_multa, estado, monto, id_prestamo)
    SELECT
        id_multa,
        TRY_CONVERT(DATE, fecha_multa),
        estado,
        TRY_CONVERT(DECIMAL(10,2), monto),
        id_prestamo
    FROM #multa_csv;

    SET IDENTITY_INSERT dbo.multa OFF;

    -- ========================================================
    -- Validaciones de la carga
    -- ========================================================
    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo p
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.prestamo_ejemplar pe
            WHERE pe.id_prestamo = p.id_prestamo
        )
    )
    BEGIN
        ;THROW 52002, 'Hay prestamos cargados sin relacion en prestamo_ejemplar.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo
        WHERE fecha_devolucion IS NOT NULL
          AND fecha_devolucion > SYSDATETIME()
    )
    BEGIN
        ;THROW 52003, 'Hay prestamos con fecha_devolucion futura.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo
        WHERE estado = 'ACTIVO' AND fecha_devolucion IS NOT NULL
    )
    BEGIN
        ;THROW 52004, 'Hay prestamos ACTIVO con fecha_devolucion.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo
        WHERE estado = 'ATRASADO'
          AND (fecha_devolucion IS NULL OR CAST(fecha_devolucion AS DATE) <= fecha_limite)
    )
    BEGIN
        ;THROW 52005, 'Hay prestamos ATRASADO sin una devolucion tardia.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo
        WHERE estado = 'DEVUELTO'
          AND (fecha_devolucion IS NULL OR CAST(fecha_devolucion AS DATE) > fecha_limite)
    )
    BEGIN
        ;THROW 52006, 'Hay prestamos DEVUELTO sin una devolucion dentro de plazo.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.multa m
        INNER JOIN dbo.prestamo p
            ON p.id_prestamo = m.id_prestamo
        WHERE p.estado <> 'ATRASADO'
           OR m.monto <> CAST(DATEDIFF(DAY, p.fecha_limite, CAST(p.fecha_devolucion AS DATE)) * 2.50 AS DECIMAL(10,2))
           OR m.fecha_multa <> CAST(p.fecha_devolucion AS DATE)
    )
    BEGIN
        ;THROW 52007, 'Hay multas que no corresponden a una devolucion tardia valida.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.prestamo p
        WHERE p.estado = 'ATRASADO'
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.multa m
              WHERE m.id_prestamo = p.id_prestamo
          )
    )
    BEGIN
        ;THROW 52008, 'Hay prestamos ATRASADO sin multa.', 1;
    END

    COMMIT TRANSACTION;
    PRINT 'Carga de prestamo, prestamo_ejemplar y multa finalizada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SET IDENTITY_INSERT dbo.prestamo OFF;
    SET IDENTITY_INSERT dbo.multa OFF;

    ALTER TABLE dbo.prestamo ENABLE TRIGGER ALL;
    ALTER TABLE dbo.prestamo_ejemplar ENABLE TRIGGER ALL;
    ALTER TABLE dbo.multa ENABLE TRIGGER ALL;

    THROW;
END CATCH;
GO

ALTER TABLE dbo.prestamo ENABLE TRIGGER ALL;
ALTER TABLE dbo.prestamo_ejemplar ENABLE TRIGGER ALL;
ALTER TABLE dbo.multa ENABLE TRIGGER ALL;
GO

SELECT 'prestamo' AS tabla, COUNT(*) AS filas FROM dbo.prestamo
UNION ALL
SELECT 'prestamo_ejemplar', COUNT(*) FROM dbo.prestamo_ejemplar
UNION ALL
SELECT 'multa', COUNT(*) FROM dbo.multa
ORDER BY tabla;

SELECT 'prestamo' AS tabla, estado, COUNT(*) AS cantidad
FROM dbo.prestamo
GROUP BY estado
ORDER BY estado;
GO
