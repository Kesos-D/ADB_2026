-- # Empleado : Listo
-- # Autor : Listo
-- # Socio : Listo
-- # Editorial : Listo
-- # Libro : Listo

use Proyecto_2;

BEGIN TRANSACTION;

CREATE TABLE #data_temp (
    id_socio int,
    dui VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    sexo CHAR(1) NOT NULL
);
go

select * from empleado;

BULK INSERT #data_temp
FROM '/data_2/socio/socio.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a',
    TABLOCK
);
go

select * from #data_temp;

INSERT INTO dbo.socio (dui, nombre, apellido, fecha_nacimiento, sexo)
SELECT dui, nombre, apellido, fecha_nacimiento, sexo
FROM #data_temp;
go
select * from dbo.libro;
rollback transaction;

drop table #data_temp

select * from dbo.socio;

commit TRANSACTION;