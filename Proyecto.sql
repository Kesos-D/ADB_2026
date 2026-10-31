-- ==========================================================
-- PARTE ADMINISTRATIVA DE LA BIBLIOTECA
-- ==========================================================
create database Proyecto_2;
use Proyecto_2;

use master;
create database Proyecto;

use Proyecto;

SELECT DB_NAME() AS base_actual;

--! Tabla Empleado
CREATE TABLE empleado
(
    id_empleado INT IDENTITY(1,1),
    dui VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    sexo CHAR(1) NOT NULL,

    CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),
    CONSTRAINT uq_dui_empleado UNIQUE (dui),
    CONSTRAINT ck_sexo_empleado CHECK (sexo IN ('M', 'F'))
);
GO


--! Tabla Socio
CREATE TABLE socio
(
    id_socio INT IDENTITY(1,1),
    dui VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    sexo CHAR(1) NOT NULL,

    CONSTRAINT pk_socio PRIMARY KEY (id_socio),
    CONSTRAINT uq_dui_socio UNIQUE (dui),
    CONSTRAINT ck_sexo_socio CHECK (sexo IN ('M', 'F'))
);
GO


--! Tabla Libro
CREATE TABLE libro
(
    id_libro INT IDENTITY(1,1),
    nombre VARCHAR(150) NOT NULL,
    fecha_publicacion DATE NOT NULL,

    CONSTRAINT pk_libro PRIMARY KEY (id_libro)
);
GO


--! Tabla Prestamo
CREATE TABLE prestamo
(
    id_prestamo INT IDENTITY(1,1),
    fecha_prestamo DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    fecha_limite DATE NOT NULL,
    fecha_devolucion DATETIME2,
    estado VARCHAR(15) NOT NULL DEFAULT 'ACTIVO',
    id_empleado INT NOT NULL,
    id_socio INT NOT NULL,

    CONSTRAINT pk_prestamo PRIMARY KEY (id_prestamo),

    CONSTRAINT ck_estado_prestamo
        CHECK (estado IN ('ACTIVO', 'DEVUELTO', 'ATRASADO')),

    CONSTRAINT fk_id_empleado_prestamo
        FOREIGN KEY (id_empleado)
        REFERENCES empleado(id_empleado)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT fk_id_socio_prestamo
        FOREIGN KEY (id_socio)
        REFERENCES socio(id_socio)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO


--! Tabla Multa
CREATE TABLE multa
(
    id_multa INT IDENTITY(1,1),
    fecha_multa DATE NOT NULL,
    estado VARCHAR(15) NOT NULL DEFAULT 'PENDIENTE',
    monto DECIMAL(10,2) NOT NULL,
    id_prestamo INT NOT NULL,

    CONSTRAINT pk_multa PRIMARY KEY (id_multa),

    CONSTRAINT ck_estado_multa
        CHECK (estado IN ('PENDIENTE', 'PAGADO', 'CANCELADO')),

    CONSTRAINT ck_monto_multa
        CHECK (monto > 0),

    CONSTRAINT fk_id_prestamo_multa
        FOREIGN KEY (id_prestamo)
        REFERENCES prestamo(id_prestamo)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO


--! Tabla Ejemplar
CREATE TABLE ejemplar
(
    id_ejemplar INT IDENTITY(1,1),
    estado VARCHAR(20) NOT NULL DEFAULT 'LIBRE',
    id_libro INT NOT NULL,

    CONSTRAINT pk_ejemplar PRIMARY KEY (id_ejemplar),

    CONSTRAINT ck_estado_ejemplar
        CHECK (estado IN ('LIBRE', 'PRESTADO', 'RESERVADO', 'FUERA_SERVICIO')),

    CONSTRAINT fk_id_libro_ejemplar
        FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO


--! Tabla Prestamo Ejemplar
CREATE TABLE prestamo_ejemplar
(
    id_prestamo INT NOT NULL,
    id_ejemplar INT NOT NULL,

    CONSTRAINT pk_prestamo_ejemplar
        PRIMARY KEY (id_prestamo, id_ejemplar),

    CONSTRAINT fk_id_prestamo_prestamo_ejemplar
        FOREIGN KEY (id_prestamo)
        REFERENCES prestamo(id_prestamo)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT fk_id_ejemplar_prestamo_ejemplar
        FOREIGN KEY (id_ejemplar)
        REFERENCES ejemplar(id_ejemplar)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO


-- ==========================================================
-- PARTE DE LIBROS DE LA BIBLIOTECA
-- ==========================================================

--! Tabla Editorial
CREATE TABLE editorial
(
    id_editorial INT IDENTITY(1,1),
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    direccion VARCHAR(250) NOT NULL,

    CONSTRAINT pk_editorial PRIMARY KEY (id_editorial),

    CONSTRAINT uq_nombre_editorial UNIQUE (nombre),
    CONSTRAINT uq_correo_editorial UNIQUE (correo),

    CONSTRAINT ck_correo_editorial
        CHECK (correo LIKE '%@%'),

    CONSTRAINT ck_telefono_editorial
        CHECK (telefono NOT LIKE '%[^0-9+ -]%')
);
GO


--! Tabla Libro Editorial
CREATE TABLE libro_editorial
(
    id_libro INT NOT NULL,
    id_editorial INT NOT NULL,

    CONSTRAINT pk_libro_editorial
        PRIMARY KEY (id_libro, id_editorial),

    CONSTRAINT fk_id_libro_libro_editorial
        FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT fk_id_editorial_libro_editorial
        FOREIGN KEY (id_editorial)
        REFERENCES editorial(id_editorial)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO


--! Tabla Autor
CREATE TABLE autor
(
    id_autor INT IDENTITY(1,1),
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    sexo CHAR(1) NOT NULL,

    CONSTRAINT pk_autor PRIMARY KEY (id_autor),

    CONSTRAINT ck_sexo_autor
        CHECK (sexo IN ('M', 'F'))
);
GO


--! Tabla Genero
CREATE TABLE genero
(
    id_genero INT IDENTITY(1,1),
    nombre VARCHAR(150) NOT NULL,

    CONSTRAINT pk_genero PRIMARY KEY (id_genero),

    CONSTRAINT uq_nombre_genero UNIQUE (nombre)
);
GO


--! Tabla Libro Genero
CREATE TABLE libro_genero
(
    id_genero INT NOT NULL,
    id_libro INT NOT NULL,

    CONSTRAINT pk_libro_genero
        PRIMARY KEY (id_genero, id_libro),

    CONSTRAINT fk_id_genero_libro_genero
        FOREIGN KEY (id_genero)
        REFERENCES genero(id_genero)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT fk_id_libro_libro_genero
        FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO


--! Tabla Libro Autor
CREATE TABLE libro_autor
(
    id_libro INT NOT NULL,
    id_autor INT NOT NULL,

    CONSTRAINT pk_libro_autor
        PRIMARY KEY (id_libro, id_autor),

    CONSTRAINT fk_id_libro_libro_autor
        FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT fk_id_autor_libro_autor
        FOREIGN KEY (id_autor)
        REFERENCES autor(id_autor)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO

-- ==========================================================
-- TRIGGERS DE LA BIBLIOTECA
-- ==========================================================

CREATE TRIGGER tg_generar_multa_por_retraso
ON prestamo
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO multa
    (
        fecha_multa,
        estado,
        monto,
        id_prestamo
    )
    SELECT
        CAST('2025-01-01' AS DATE),
        'PENDIENTE',
        DATEDIFF(DAY, d.fecha_limite, i.fecha_devolucion) * 2.50,
        i.id_prestamo
    FROM inserted i
    INNER JOIN deleted d
        ON i.id_prestamo = d.id_prestamo
    WHERE i.fecha_devolucion IS NOT NULL
        AND CAST(i.fecha_devolucion AS DATE) > d.fecha_limite
        AND d.fecha_devolucion IS NULL;
END;
GO

-- ==========================================================
-- PROCEDIMIENTOS DE LA BIBLIOTECA
-- ==========================================================

CREATE OR ALTER PROCEDURE sp_procesar_prestamo
    @p_id_socio INT,
    @p_id_empleado INT,
    @p_id_ejemplar INT,
    @p_fecha_limite DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_estado_ejemplar VARCHAR(20);
    DECLARE @v_multas_pendientes INT;
    DECLARE @v_prestamos_activos INT;
    DECLARE @v_id_prestamo INT;

    -- 1. Verificar estado del ejemplar
    SELECT @v_estado_ejemplar = estado
    FROM ejemplar
    WHERE id_ejemplar = @p_id_ejemplar;

    IF @v_estado_ejemplar IS NULL
    BEGIN;
        THROW 50001, 'El ejemplar no existe', 1;
    END;

    IF @v_estado_ejemplar <> 'LIBRE'
    BEGIN;
        THROW 50002, 'El ejemplar no esta disponible', 1;
    END;

    -- 2. Verificar multas pendientes
    SELECT @v_multas_pendientes = COUNT(*)
    FROM multa m
    INNER JOIN prestamo p
        ON m.id_prestamo = p.id_prestamo
    WHERE p.id_socio = @p_id_socio
        AND m.estado = 'PENDIENTE';

    IF @v_multas_pendientes > 0
    BEGIN;
        THROW 50003, 'El socio tiene multas pendientes, prestamo negado', 1;
    END;

    -- 3. Verificar prestamos activos
    SELECT @v_prestamos_activos = COUNT(*)
    FROM prestamo
    WHERE id_socio = @p_id_socio
      AND estado = 'ACTIVO';

    IF @v_prestamos_activos >= 3
    BEGIN;
        THROW 50004, 'El socio tiene 3 prestamos activos', 1;
    END;

    -- 4. Registrar prestamo
    INSERT INTO prestamo
    (
        fecha_limite,
        estado,
        id_empleado,
        id_socio
    )
    VALUES
    (
        @p_fecha_limite,
        'ACTIVO',
        @p_id_empleado,
        @p_id_socio
    );

    SET @v_id_prestamo = SCOPE_IDENTITY();

    -- 5. Relacionar prestamo con ejemplar
    INSERT INTO prestamo_ejemplar
    (
        id_prestamo,
        id_ejemplar
    )
    VALUES
    (
        @v_id_prestamo,
        @p_id_ejemplar
    );

    -- 6. Cambiar estado del ejemplar
    UPDATE ejemplar
    SET estado = 'PRESTADO'
    WHERE id_ejemplar = @p_id_ejemplar;

END;
GO

SELECT
    name AS procedimiento,
    create_date AS fecha_creacion,
    modify_date AS ultima_modificacion,
    is_disabled
FROM sys.TRIGGERs
ORDER BY name;