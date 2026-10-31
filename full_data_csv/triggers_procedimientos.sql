/* ============================================================
   triggers_procedimientos.sql
   ------------------------------------------------------------
   Triggers y procedimientos almacenados de la biblioteca.

   Semantica Opcion A:
     ACTIVO    = prestamo abierto, dentro de plazo.
                 fecha_devolucion IS NULL y fecha_limite >= hoy.
     ATRASADO  = prestamo abierto, fuera de plazo.
                 fecha_devolucion IS NULL y fecha_limite < hoy.
     DEVUELTO  = prestamo devuelto.
                 Si la devolucion es posterior a fecha_limite se
                 genera una multa de dias_retraso * 2.50.

   Alcance:
     - 4 triggers.
     - 4 procedimientos almacenados.
     - Sin tablas de auditoria.
     - Sin jobs.
     - Sin indices adicionales.

   Orden recomendado:
     1) 00_cargar_tablas_madres.sql
     2) full_data_csv.sql
     3) triggers_procedimientos.sql   (este archivo)
     4) 99_validacion.sql

   Importante:
     - Ejecutar este archivo DESPUES de generar los datos.
     - El generador inserta 30,000 prestamos en bloque y los
       triggers rechazarian estados intermedios.
     - Este archivo elimina los objetos anteriores que ya no
       forman parte del diseno.
   ============================================================ */

USE Proyecto;
GO

/* ============================================================
   2. TRIGGERS
   ============================================================ */

/* 2.1 Valida que las fechas y el estado sean coherentes. */
CREATE OR ALTER TRIGGER dbo.trg_prestamo_estado_fechas
ON dbo.prestamo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.fecha_limite < CAST(i.fecha_prestamo AS DATE)
           OR (i.fecha_devolucion IS NOT NULL AND i.fecha_devolucion < i.fecha_prestamo)
           OR (i.fecha_devolucion IS NOT NULL AND i.fecha_devolucion > SYSDATETIME())
           OR (i.estado IN ('ACTIVO', 'ATRASADO') AND i.fecha_devolucion IS NOT NULL)
           OR (i.estado = 'DEVUELTO' AND i.fecha_devolucion IS NULL)
    )
    BEGIN;
        THROW 50201, 'Prestamo inconsistente: revise fecha_limite, fecha_devolucion y estado.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE (i.estado = 'ACTIVO' AND i.fecha_limite < CAST(GETDATE() AS DATE))
           OR (i.estado = 'ATRASADO' AND i.fecha_limite >= CAST(GETDATE() AS DATE))
    )
    BEGIN;
        THROW 50202, 'Estado incompatible con la fecha_limite: ACTIVO debe estar vigente y ATRASADO debe estar vencido.', 1;
    END;
END;
GO

/* 2.2 Genera la multa cuando se registra una devolucion tardia. */
CREATE OR ALTER TRIGGER dbo.trg_prestamo_multa
ON dbo.prestamo
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.multa (fecha_multa, estado, monto, id_prestamo)
    SELECT
        CAST(i.fecha_devolucion AS DATE),
        'PENDIENTE',
        CAST(DATEDIFF(DAY, i.fecha_limite, CAST(i.fecha_devolucion AS DATE)) * 2.50 AS DECIMAL(10,2)),
        i.id_prestamo
    FROM inserted i
    LEFT JOIN deleted d
        ON d.id_prestamo = i.id_prestamo
    WHERE i.estado = 'DEVUELTO'
      AND i.fecha_devolucion IS NOT NULL
      AND CAST(i.fecha_devolucion AS DATE) > i.fecha_limite
      AND (d.id_prestamo IS NULL OR d.fecha_devolucion IS NULL)
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.multa m
            WHERE m.id_prestamo = i.id_prestamo
      );
END;
GO

/* 2.3 Impide mas de 3 prestamos abiertos por socio. */
CREATE OR ALTER TRIGGER dbo.trg_prestamo_max_activos
ON dbo.prestamo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.prestamo p
            ON p.id_socio = i.id_socio
        WHERE i.estado IN ('ACTIVO', 'ATRASADO')
          AND p.estado IN ('ACTIVO', 'ATRASADO')
        GROUP BY i.id_socio
        HAVING COUNT(*) > 3
    )
    BEGIN;
        THROW 50203, 'El socio no puede tener mas de 3 prestamos abiertos (ACTIVO o ATRASADO).', 1;
    END;
END;
GO

/* 2.4 Un ejemplar no puede estar en dos prestamos abiertos. */
CREATE OR ALTER TRIGGER dbo.trg_prestamo_ejemplar_unico_abierto
ON dbo.prestamo_ejemplar
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.prestamo p
            ON p.id_prestamo = i.id_prestamo
        INNER JOIN dbo.prestamo_ejemplar pe
            ON pe.id_ejemplar = i.id_ejemplar
        INNER JOIN dbo.prestamo p2
            ON p2.id_prestamo = pe.id_prestamo
        WHERE p.estado IN ('ACTIVO', 'ATRASADO')
          AND p2.estado IN ('ACTIVO', 'ATRASADO')
        GROUP BY i.id_ejemplar
        HAVING COUNT(DISTINCT pe.id_prestamo) > 1
    )
    BEGIN;
        THROW 50204, 'El ejemplar ya esta asociado a otro prestamo abierto (ACTIVO o ATRASADO).', 1;
    END;
END;
GO

/* ============================================================
   3. PROCEDIMIENTOS ALMACENADOS
   ============================================================ */

/* 3.1 Registra un prestamo. */
CREATE OR ALTER PROCEDURE dbo.usp_prestar_ejemplar
    @id_socio       INT,
    @id_empleado    INT,
    @id_ejemplar    INT,
    @fecha_limite   DATE = NULL,
    @id_prestamo    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
    DECLARE @estado_ejemplar VARCHAR(20);
    DECLARE @multas_pendientes INT;
    DECLARE @abiertos INT;

    SET @id_prestamo = NULL;

    IF @fecha_limite IS NULL
        SET @fecha_limite = DATEADD(DAY, 14, @hoy);

    IF @fecha_limite < @hoy
        THROW 50301, 'La fecha_limite no puede ser anterior a hoy.', 1;

    IF @fecha_limite > DATEADD(DAY, 60, @hoy)
        THROW 50302, 'La fecha_limite no puede superar 60 dias desde hoy.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.socio WHERE id_socio = @id_socio)
            THROW 50303, 'El socio no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.empleado WHERE id_empleado = @id_empleado)
            THROW 50304, 'El empleado no existe.', 1;

        SELECT @estado_ejemplar = estado
        FROM dbo.ejemplar
        WHERE id_ejemplar = @id_ejemplar;

        IF @estado_ejemplar IS NULL
            THROW 50305, 'El ejemplar no existe.', 1;

        IF @estado_ejemplar <> 'LIBRE'
            THROW 50306, 'El ejemplar no esta disponible para prestamo.', 1;

        SELECT @multas_pendientes = COUNT(*)
        FROM dbo.multa m
        INNER JOIN dbo.prestamo p
            ON p.id_prestamo = m.id_prestamo
        WHERE p.id_socio = @id_socio
          AND m.estado = 'PENDIENTE';

        IF @multas_pendientes > 0
            THROW 50307, 'El socio tiene multas pendientes. No se puede prestar.', 1;

        SELECT @abiertos = COUNT(*)
        FROM dbo.prestamo
        WHERE id_socio = @id_socio
          AND estado IN ('ACTIVO', 'ATRASADO');

        IF @abiertos >= 3
            THROW 50308, 'El socio ya tiene 3 prestamos abiertos.', 1;

        INSERT INTO dbo.prestamo
            (fecha_prestamo, fecha_limite, fecha_devolucion, estado, id_empleado, id_socio)
        VALUES
            (SYSDATETIME(), @fecha_limite, NULL, 'ACTIVO', @id_empleado, @id_socio);

        SET @id_prestamo = SCOPE_IDENTITY();

        INSERT INTO dbo.prestamo_ejemplar (id_prestamo, id_ejemplar)
        VALUES (@id_prestamo, @id_ejemplar);

        UPDATE dbo.ejemplar
        SET estado = 'PRESTADO'
        WHERE id_ejemplar = @id_ejemplar;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

/* 3.2 Registra la devolucion, calcula el retraso, recupera la
       multa generada por el trigger y libera el ejemplar. */
CREATE OR ALTER PROCEDURE dbo.usp_devolver_prestamo
    @id_prestamo        INT,
    @fecha_devolucion   DATETIME2(7) = NULL,
    @estado             VARCHAR(15) OUTPUT,
    @dias_retraso       INT OUTPUT,
    @monto_multa        DECIMAL(10,2) OUTPUT,
    @id_multa           INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @fecha_limite DATE;
    DECLARE @fecha_prestamo DATETIME2(7);
    DECLARE @estado_actual VARCHAR(15);
    DECLARE @fecha_dev_actual DATETIME2(7);

    SET @fecha_devolucion = ISNULL(@fecha_devolucion, SYSDATETIME());
    SET @estado = NULL;
    SET @dias_retraso = 0;
    SET @monto_multa = 0.00;
    SET @id_multa = NULL;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @fecha_limite = fecha_limite,
            @fecha_prestamo = fecha_prestamo,
            @estado_actual = estado,
            @fecha_dev_actual = fecha_devolucion
        FROM dbo.prestamo
        WHERE id_prestamo = @id_prestamo;

        IF @fecha_limite IS NULL
            THROW 50401, 'El prestamo no existe.', 1;

        IF @fecha_dev_actual IS NOT NULL OR @estado_actual = 'DEVUELTO'
            THROW 50402, 'El prestamo ya fue devuelto.', 1;

        IF @fecha_devolucion < @fecha_prestamo
            THROW 50403, 'La fecha de devolucion no puede ser anterior a la fecha del prestamo.', 1;

        IF @fecha_devolucion > SYSDATETIME()
            THROW 50404, 'La fecha de devolucion no puede estar en el futuro.', 1;

        SET @dias_retraso = CASE
            WHEN CAST(@fecha_devolucion AS DATE) > @fecha_limite
                THEN DATEDIFF(DAY, @fecha_limite, CAST(@fecha_devolucion AS DATE))
            ELSE 0
        END;

        UPDATE dbo.prestamo
        SET fecha_devolucion = @fecha_devolucion,
            estado = 'DEVUELTO'
        WHERE id_prestamo = @id_prestamo;

        SET @estado = 'DEVUELTO';

        /* El trigger trg_prestamo_multa crea la multa si la
           devolucion fue tardia. */
        IF @dias_retraso > 0
        BEGIN
            SELECT
                @id_multa = id_multa,
                @monto_multa = monto
            FROM dbo.multa
            WHERE id_prestamo = @id_prestamo;
        END;

        UPDATE e
        SET e.estado = 'LIBRE'
        FROM dbo.ejemplar e
        INNER JOIN dbo.prestamo_ejemplar pe
            ON pe.id_ejemplar = e.id_ejemplar
        WHERE pe.id_prestamo = @id_prestamo
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.prestamo_ejemplar pe2
                INNER JOIN dbo.prestamo p2
                    ON p2.id_prestamo = pe2.id_prestamo
                WHERE pe2.id_ejemplar = e.id_ejemplar
                  AND p2.estado IN ('ACTIVO', 'ATRASADO')
              );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

/* 3.3 Marca una multa PENDIENTE como PAGADO. */
CREATE OR ALTER PROCEDURE dbo.usp_pagar_multa
    @id_multa   INT,
    @estado     VARCHAR(15) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @estado_actual VARCHAR(15);

    SET @estado = NULL;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @estado_actual = estado
        FROM dbo.multa
        WHERE id_multa = @id_multa;

        IF @estado_actual IS NULL
            THROW 50501, 'La multa no existe.', 1;

        IF @estado_actual <> 'PENDIENTE'
            THROW 50502, 'Solo se puede pagar una multa PENDIENTE.', 1;

        UPDATE dbo.multa
        SET estado = 'PAGADO'
        WHERE id_multa = @id_multa;

        SET @estado = 'PAGADO';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

/* 3.4 Marca como ATRASADO los prestamos ACTIVO vencidos. */
CREATE OR ALTER PROCEDURE dbo.usp_marcar_prestamos_atrasados
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.prestamo
    SET estado = 'ATRASADO'
    WHERE estado = 'ACTIVO'
      AND fecha_devolucion IS NULL
      AND fecha_limite < CAST(GETDATE() AS DATE);

    SELECT @@ROWCOUNT AS prestamos_actualizados;
END;
GO

/* ============================================================
   4. VERIFICACION
   ============================================================ */

PRINT 'Triggers y procedimientos creados correctamente.';
GO

SELECT
    o.type_desc AS tipo,
    o.name AS nombre,
    o.create_date AS fecha_creacion
FROM sys.objects o
WHERE o.type IN ('TR', 'P')
  AND o.is_ms_shipped = 0
ORDER BY o.type_desc, o.name;
GO
