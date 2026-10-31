-- # Empleado : Listo
-- # Autor : Listo
-- # Socio : Listo
-- # Editorial : Listo
-- # Libro : Listo

/*
    1) docker exec -u 0 -it sqlserver-2025 sh
    2) mkdir data
    3) cp docker cp .\data_2\ sqlserver-2025:\data\
*/

use Proyecto;
go

BULK INSERT socio
FROM '/data/data_2/socio/socio.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a',
    TABLOCK
);

select * from socio;

commit TRANSACTION;