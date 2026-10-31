/*
    #1 empleado : Listo
    #2 Socio : Listo
    #3 Editorial : Listo
    #4 autor : Listo
    #5 Libros : Listo
    #6 Genero : Listo
    #7 Ejemplar : Listo
    #8 Libro_Editorial : Listo
    #9 Libro_genero : Listo
    #10 Libro autor : Listo
    #11 Prestamo : Ejemplar
*/

use Proyecto;
-- 1 Inserta empleados
BULK INSERT dbo.Empleado
FROM '\data\Empleado.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
go

-- 2 Inserta Socios
BULK INSERT dbo.Socio
FROM '\data\socio.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
go

-- 3 Insertar Editorial
BULK INSERT dbo.Editorial
FROM '\data\Editorial.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
go

-- 4 Insertar autor
BULK INSERT dbo.autor
FROM '\data\autor.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
go

-- 5 Insertar libros
BULK INSERT dbo.Libro
FROM '\data\Libros.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
go

-- 6 Insertar genero
BULK INSERT dbo.Genero
FROM '\data\Genero.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
go

-- 7 Insertar prestamos
BULK INSERT dbo.prestamo
FROM '\data\prestamo.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    KEEPIDENTITY,
    TABLOCK
);
go

--! 8 Libro_genero
BULK INSERT dbo.libro_genero
FROM '\data\libro_genero.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 1,
    KEEPIDENTITY,
    TABLOCK
);
go

--! 9 Libro_autor
BULK INSERT dbo.libro_autor
FROM '\data\libro_autor.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 1,
    KEEPIDENTITY,
    TABLOCK
);
go

--! 10 Libro_editorial

BULK INSERT dbo.libro_editorial
FROM '\data\libro_editorial.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 1,
    KEEPIDENTITY,
    TABLOCK
);

--! 11 Prestamo_ejemplar
BULK INSERT dbo.prestamo_ejemplar
FROM '\data\prestamo_ejemplar.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 1,
    KEEPIDENTITY,
    TABLOCK
);
go