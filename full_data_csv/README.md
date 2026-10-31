# full_data_csv

Scripts para cargar las tablas madre y generar los datos de las tablas hijas de la base `Proyecto`.

## Contenido

| Archivo | Uso |
|---|---|
| `00_cargar_tablas_madres.sql` | Carga `empleado`, `socio`, `autor`, `editorial`, `genero`, `libro`, `ejemplar` y `libro_autor` desde los CSV de `data_2`. Solo inserta si la tabla está vacía. |
| `full_data_csv.sql` | Script principal. Genera ejemplares adicionales, relaciones libro-editorial/género/autor, 30,000 préstamos, `prestamo_ejemplar` y multas. |
| `99_validacion.sql` | Consultas de validación. No modifica datos. |

## Requisitos

1. Base `Proyecto` creada con `Proyecto.sql`.
2. Carpeta `data_2` copiada dentro del contenedor:

   ```powershell
   docker cp .\data_2\ sqlserver-2025:/data/
   ```

   Los archivos deben quedar en:

   ```text
   /data/data_2/empleado/empleado.csv
   /data/data_2/socio/socio.csv
   /data/data_2/autor/autor.csv
   /data/data_2/editorial/editorial.csv
   /data/data_2/genero/genero.csv
   /data/data_2/libro/libro.csv
   /data/data_2/ejemplar/ejemplar.csv
   /data/data_2/libro_autor/libro_autor.csv
   ```

3. La tabla `prestamo` debe estar vacía. El script principal se detiene si ya existen préstamos para evitar duplicarlos.

## Orden de ejecución

```text
1. 00_cargar_tablas_madres.sql
2. full_data_csv.sql
3. 99_validacion.sql
```

Desde `sqlcmd`:

```powershell
docker exec -i sqlserver-2025 /opt/mssql-tools18/bin/sqlcmd `
  -S localhost -U sa -P "MiPassword123!" -C `
  -i /ruta/full_data_csv/full_data_csv.sql
```

En SSMS o Azure Data Studio: abrir cada archivo y ejecutarlo en orden sobre `Proyecto`.

## Resultado esperado

| Tabla | Filas |
|---|---:|
| `ejemplar` | 8,000 |
| `libro_editorial` | 2,000 |
| `libro_genero` | 2,000 |
| `libro_autor` | 2,000 |
| `prestamo` | 30,000 |
| `prestamo_ejemplar` | 30,000 |
| `multa` | ~6,000 |

Distribución de estados:

- `prestamo`: 70% `DEVUELTO`, 20% `ATRASADO`, 10% `ACTIVO`.
- `ejemplar`: los ejemplares con préstamo activo quedan `PRESTADO`; el resto conserva `LIBRE`, `RESERVADO` o `FUERA_SERVICIO`.

## Reglas aplicadas

- Cada libro tiene al menos una editorial, un género y un autor.
- Cada libro tiene 4 ejemplares.
- Cada préstamo tiene exactamente un ejemplar asociado.
- Un ejemplar no puede tener más de un préstamo `ACTIVO`.
- Un socio no puede tener más de 3 préstamos `ACTIVO`.
- Solo se genera multa cuando la devolución es posterior a `fecha_limite`.
- Monto de multa: `días de retraso * 2.50`.

## Nota sobre transacciones

El script principal usa `SET XACT_ABORT ON` y `TRY/CATCH`. Si ocurre un error, revierte toda la generación.

Antes de ejecutarlo, cierra cualquier ventana de SSMS/Azure Data Studio que tenga transacciones abiertas sobre `Proyecto`, especialmente bloqueos sobre `ejemplar`.
