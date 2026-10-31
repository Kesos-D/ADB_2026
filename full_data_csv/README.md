# Biblioteca `Proyecto` — Datos, reglas y automatizaciones

Documentación de los scripts de carga de `full_data_csv` y de los objetos
programables de la base `Proyecto`.

El proyecto puede poblarse por dos caminos equivalentes:

1. **Desde los CSV de `data_2`** con `00_cargar_tablas_madres.sql` y
   `01_cargar_prestamos_csv.sql`.
2. **Generando los datos** con `full_data_csv.sql` a partir de las tablas
   madre.

En ambos casos se instalan después los mismos 4 triggers y 4 procedimientos.

## Semántica de los estados

| Estado | Significado | `fecha_devolucion` | Multa |
|---|---|---|---|
| `ACTIVO` | El socio **aún conserva** el ejemplar. | `NULL` | No |
| `ATRASADO` | El socio **ya lo devolvió, pero fuera del plazo**. | `NOT NULL` y mayor que `fecha_limite` | Sí |
| `DEVUELTO` | El socio **ya lo devolvió dentro del plazo**. | `NOT NULL` y menor o igual que `fecha_limite` | No |

Un préstamo `ACTIVO` puede tener la `fecha_limite` vencida y **sigue siendo
`ACTIVO`**: el estado no cambia hasta que se registra la devolución.

## Contenido de la carpeta

| Archivo | Uso |
|---|---|
| `00_cargar_tablas_madres.sql` | Carga `empleado`, `socio`, `autor`, `editorial`, `genero`, `libro`, `ejemplar` y `libro_autor` desde los CSV de `data_2`. Solo inserta si la tabla está vacía. |
| `01_cargar_prestamos_csv.sql` | Carga `prestamo`, `prestamo_ejemplar` y `multa` desde los CSV de `data_2`, conservando los identificadores. Desactiva los triggers durante la carga. |
| `full_data_csv.sql` | Genera ejemplares, relaciones libro–editorial/género/autor, 30,000 préstamos, `prestamo_ejemplar` y 6,000 multas. Es la alternativa a `01_cargar_prestamos_csv.sql`. |
| `triggers_procedimientos.sql` | Crea **4 triggers** y **4 procedimientos almacenados**. Sin auditorías, sin jobs y sin índices adicionales. |
| `99_validacion.sql` | Consultas de validación. No modifica datos. |

### Orden de ejecución

**Opción A: cargar los CSV de `data_2`**

```text
1) Proyecto.sql                  (crea la base y el esquema base)
2) 00_cargar_tablas_madres.sql   (tablas madre)
3) 01_cargar_prestamos_csv.sql   (préstamos, relaciones y multas)
4) triggers_procedimientos.sql   (4 triggers y 4 SPs)
5) 99_validacion.sql             (verificación)
```

**Opción B: generar los datos**

```text
1) Proyecto.sql                  (crea la base y el esquema base)
2) 00_cargar_tablas_madres.sql   (tablas madre)
3) full_data_csv.sql             (datos de tablas hijas)
4) triggers_procedimientos.sql   (4 triggers y 4 SPs)
5) 99_validacion.sql             (verificación)
```

> No ejecutar `01_cargar_prestamos_csv.sql` y `full_data_csv.sql` juntos: ambos
> llenan las mismas tablas. `01` requiere que `prestamo`, `prestamo_ejemplar` y
> `multa` estén vacías; `full_data_csv.sql` también.

> `full_data_csv.sql` borra los triggers de negocio antes de sembrar los datos.
> Si se ejecuta solo, la base queda sin triggers hasta correr
> `triggers_procedimientos.sql`.

---

## 1. Reglas de negocio

### 1.1 Fechas y estados del préstamo

1. `ACTIVO` no tiene `fecha_devolucion`.
2. `ATRASADO` tiene `fecha_devolucion` y es **posterior** a `fecha_limite`.
3. `DEVUELTO` tiene `fecha_devolucion` y es **anterior o igual** a
   `fecha_limite`.
4. `fecha_limite` no puede ser anterior a la fecha del préstamo.
5. `fecha_devolucion` no puede ser anterior a `fecha_prestamo` ni futura.
6. No existe un paso automático de `ACTIVO` a `ATRASADO`: un préstamo abierto
   vencido sigue `ACTIVO` hasta que se devuelve.

### 1.2 Préstamos

- Un socio puede tener como máximo **3 préstamos `ACTIVO`**.
- Un ejemplar solo puede estar en **un préstamo `ACTIVO`** a la vez.
- Solo se presta un ejemplar en estado `LIBRE`.
- Un socio con **multas `PENDIENTE`** no puede recibir préstamos.
- Plazo estándar: **14 días**. El SP permite entre 1 y 60 días.
- La relación `prestamo_ejemplar` de un préstamo `ACTIVO` no debe borrarse ni
  moverse; primero debe devolverse el préstamo.

### 1.3 Devoluciones y multas

- Al devolver, el SP calcula:
  `días_retraso = fecha_devolucion - fecha_limite`.
- Si `días_retraso > 0`, el préstamo queda `ATRASADO` y se genera la multa.
- Si `días_retraso = 0`, el préstamo queda `DEVUELTO` y no hay multa.
- Fórmula: `monto = días_retraso * 2.50`.
- Hay **una sola multa por préstamo**.
- Estados de multa: `PENDIENTE`, `PAGADO`, `CANCELADO`.
- Solo se puede pagar o cancelar una multa `PENDIENTE`.
- La multa se crea una sola vez; no se recalcula después.

### 1.4 Ejemplares

Estados: `LIBRE`, `PRESTADO`, `RESERVADO`, `FUERA_SERVICIO`.

| Origen | Destino esperado |
|---|---|
| `LIBRE` | `PRESTADO` (al prestar) |
| `PRESTADO` | `LIBRE` (al devolver) |

- `PRESTADO` ⇔ existe un préstamo `ACTIVO` asociado.
- `LIBRE` ⇔ no existe préstamo `ACTIVO` asociado.
- Los estados `RESERVADO` y `FUERA_SERVICIO` existen en el esquema base, pero
  este diseño no incluye procedimientos de reservas ni de disponibilidad.

### 1.5 Alcance de las automatizaciones

- **4 triggers** de validación y generación de multas.
- **4 procedimientos** para prestar, devolver, pagar y cancelar multas.
- **Sin tablas de auditoría**, **sin jobs** y **sin índices adicionales**.
- Se usan únicamente las llaves primarias, foráneas y restricciones de
  `Proyecto.sql`.

### 1.6 Datos de `data_2`

| Tabla | Filas |
|---|---:|
| `empleado` | 5,000 |
| `socio` | 8,000 |
| `autor` | 1,000 |
| `editorial` | 300 |
| `genero` | 300 |
| `libro` | 2,000 |
| `ejemplar` | 8,000 |
| `libro_autor` | 1,000 |
| `prestamo` | 30,000 (20,932 `DEVUELTO`, 6,015 `ATRASADO`, 3,053 `ACTIVO`) |
| `prestamo_ejemplar` | 30,000 |
| `multa` | 6,015 (una por cada `ATRASADO`) |

### 1.7 Datos que genera `full_data_csv.sql`

| Tabla | Filas esperadas |
|---|---:|
| `ejemplar` | 8,000 (4 copias por libro) |
| `libro_editorial` | 2,000 |
| `libro_genero` | 2,000 |
| `libro_autor` | 2,000 |
| `prestamo` | 30,000 (70% `DEVUELTO`, 20% `ATRASADO`, 10% `ACTIVO`) |
| `prestamo_ejemplar` | 30,000 (uno por préstamo) |
| `multa` | 6,000 (solo `ATRASADO`) |
| `multa` por estado | 60% `PAGADO`, 30% `PENDIENTE`, 10% `CANCELADO` |

---

## 2. Tablas

### 2.1 Resumen

| Nombre | Descripción | Datos que contiene | Tipo / ejemplo |
|---|---|---|---|
| `empleado` | Personal que registra préstamos. | Datos personales y DUI. | `dui = '01234567-8'` |
| `socio` | Personas que piden prestado. | Datos personales y DUI. | `sexo = 'F'` |
| `autor` | Autores de libros. | Nombre, apellido, nacimiento, sexo. | `fecha_nacimiento = 1980-05-14` |
| `editorial` | Editoriales. | Nombre, correo, teléfono, dirección. | `correo = 'ventas@editorial.com'` |
| `genero` | Géneros literarios. | Nombre único. | `nombre = 'Novela'` |
| `libro` | Catálogo de libros. | Nombre y fecha de publicación. | `fecha_publicacion = 2015-03-01` |
| `ejemplar` | Copia física de un libro. | Estado y libro al que pertenece. | `estado = 'LIBRE'` |
| `libro_autor` | Relación N:M libro–autor. | PK compuesta. | `(id_libro, id_autor)` |
| `libro_editorial` | Relación N:M libro–editorial. | PK compuesta. | `(id_libro, id_editorial)` |
| `libro_genero` | Relación N:M libro–género. | PK compuesta. | `(id_genero, id_libro)` |
| `prestamo` | Cabecera del préstamo. | Fechas, estado, socio y empleado. | `estado = 'ATRASADO'` |
| `prestamo_ejemplar` | Detalle: qué ejemplar se prestó. | PK compuesta. | `(id_prestamo, id_ejemplar)` |
| `multa` | Multa por devolución tardía. | Fecha, estado, monto, préstamo. | `monto = 15.00` |

### 2.2 Detalle de columnas

#### `empleado`

| Columna | Tipo | Ejemplo / regla |
|---|---|---|
| `id_empleado` | `INT IDENTITY` | PK, `1` |
| `dui` | `VARCHAR(10)` | Único, `'01234567-8'` |
| `nombre` | `VARCHAR(100)` | `'Ana'` |
| `apellido` | `VARCHAR(100)` | `'López'` |
| `fecha_nacimiento` | `DATE` | `1990-04-12` |
| `sexo` | `CHAR(1)` | `'M'` o `'F'` |

#### `socio`

Mismas columnas y reglas que `empleado`, con PK `id_socio`.

#### `autor`

| Columna | Tipo | Ejemplo |
|---|---|---|
| `id_autor` | `INT IDENTITY` | PK |
| `nombre` | `VARCHAR(100)` | `'Gabriel'` |
| `apellido` | `VARCHAR(100)` | `'García Márquez'` |
| `fecha_nacimiento` | `DATE` | `1927-03-06` |
| `sexo` | `CHAR(1)` | `'M'` / `'F'` |

#### `editorial`

| Columna | Tipo | Ejemplo / regla |
|---|---|---|
| `id_editorial` | `INT IDENTITY` | PK |
| `nombre` | `VARCHAR(150)` | Único |
| `correo` | `VARCHAR(150)` | Único, debe contener `@` |
| `telefono` | `VARCHAR(20)` | Solo dígitos, `+`, espacio y `-` |
| `direccion` | `VARCHAR(250)` | `'Calle 1 #2-3'` |

#### `genero`

| Columna | Tipo | Ejemplo |
|---|---|---|
| `id_genero` | `INT IDENTITY` | PK |
| `nombre` | `VARCHAR(150)` | Único, `'Ciencia ficción'` |

#### `libro`

| Columna | Tipo | Ejemplo |
|---|---|---|
| `id_libro` | `INT IDENTITY` | PK |
| `nombre` | `VARCHAR(150)` | `'Cien años de soledad'` |
| `fecha_publicacion` | `DATE` | `1967-05-30` |

#### `ejemplar`

| Columna | Tipo | Ejemplo / regla |
|---|---|---|
| `id_ejemplar` | `INT IDENTITY` | PK |
| `estado` | `VARCHAR(20)` | `LIBRE`, `PRESTADO`, `RESERVADO`, `FUERA_SERVICIO` |
| `id_libro` | `INT` | FK → `libro` |

#### Relaciones N:M

| Tabla | Columnas | PK |
|---|---|---|
| `libro_autor` | `id_libro`, `id_autor` | `(id_libro, id_autor)` |
| `libro_editorial` | `id_libro`, `id_editorial` | `(id_libro, id_editorial)` |
| `libro_genero` | `id_genero`, `id_libro` | `(id_genero, id_libro)` |

#### `prestamo`

| Columna | Tipo | Ejemplo / regla |
|---|---|---|
| `id_prestamo` | `INT IDENTITY` | PK |
| `fecha_prestamo` | `DATETIME2` | `2026-10-31 16:24:58` |
| `fecha_limite` | `DATE` | `2026-11-14` |
| `fecha_devolucion` | `DATETIME2 NULL` | `NULL` solo si está `ACTIVO` |
| `estado` | `VARCHAR(15)` | `ACTIVO`, `ATRASADO`, `DEVUELTO` |
| `id_empleado` | `INT` | FK → `empleado` |
| `id_socio` | `INT` | FK → `socio` |

#### `prestamo_ejemplar`

| Columna | Tipo | Regla |
|---|---|---|
| `id_prestamo` | `INT` | FK → `prestamo` |
| `id_ejemplar` | `INT` | FK → `ejemplar` |

PK compuesta `(id_prestamo, id_ejemplar)`. En la práctica, un préstamo tiene un solo ejemplar.

#### `multa`

| Columna | Tipo | Ejemplo / regla |
|---|---|---|
| `id_multa` | `INT IDENTITY` | PK |
| `fecha_multa` | `DATE` | Fecha de la devolución tardía |
| `estado` | `VARCHAR(15)` | `PENDIENTE`, `PAGADO`, `CANCELADO` |
| `monto` | `DECIMAL(10,2)` | `> 0`, `días * 2.50` |
| `id_prestamo` | `INT` | FK → `prestamo`, una multa por préstamo |

---

## 3. Triggers y procedimientos almacenados

### 3.1 Triggers

Todos son `AFTER` y trabajan con las tablas virtuales `inserted` y `deleted`.
No reciben parámetros: su entrada son las filas afectadas por la sentencia y su
salida es el propio cambio o un error `THROW`.

#### `trg_prestamo_estado_fechas`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo` |
| Evento | `AFTER INSERT, UPDATE` |
| Entrada | Filas de `inserted`. |
| Salida | Ninguna si todo es válido; `THROW` 50201 si no. |
| Objetivo | Hacer cumplir la semántica de estados y la coherencia de fechas. |

Descripción: `ACTIVO` debe tener `fecha_devolucion = NULL`; `ATRASADO` debe
tener devolución posterior a `fecha_limite`; `DEVUELTO` debe tener devolución
anterior o igual a `fecha_limite`. También rechaza fechas incoherentes y
devoluciones futuras.

#### `trg_prestamo_multa`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo` |
| Evento | `AFTER INSERT, UPDATE` |
| Entrada | Filas de `inserted`. |
| Salida | Inserta una fila en `multa` cuando corresponde. |
| Objetivo | Generar la multa al quedar un préstamo en `ATRASADO`. |

Descripción: crea una multa `PENDIENTE` con
`monto = días_retraso * 2.50` y `fecha_multa = fecha_devolucion`. Si el
préstamo ya tiene multa, no inserta otra.

#### `trg_prestamo_max_activos`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo` |
| Evento | `AFTER INSERT, UPDATE` |
| Entrada | Filas de `inserted`. |
| Salida | Ninguna si cumple; `THROW` 50203 si excede. |
| Objetivo | Impedir que un socio tenga más de 3 préstamos `ACTIVO`. |

Descripción: cuenta únicamente los préstamos `ACTIVO` del socio. Los estados
`ATRASADO` y `DEVUELTO` son préstamos cerrados y no cuentan.

#### `trg_prestamo_ejemplar_unico_abierto`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo_ejemplar` |
| Evento | `AFTER INSERT, UPDATE` |
| Entrada | Filas de `inserted`. |
| Salida | Ninguna si cumple; `THROW` 50204 si hay duplicado. |
| Objetivo | Evitar que un ejemplar esté en dos préstamos `ACTIVO`. |

Descripción: busca el mismo `id_ejemplar` en más de un préstamo `ACTIVO` y
rechaza la operación si encuentra duplicados.

### 3.2 Procedimientos almacenados

#### `usp_prestar_ejemplar`

Registra un préstamo completo: cabecera, relación con el ejemplar y estado
`PRESTADO`, dentro de una transacción.

| Parámetro | Tipo | E/S | Descripción |
|---|---|---|---|
| `@id_socio` | `INT` | Entrada | Socio que recibe el préstamo. |
| `@id_empleado` | `INT` | Entrada | Empleado que registra. |
| `@id_ejemplar` | `INT` | Entrada | Ejemplar a prestar. |
| `@fecha_limite` | `DATE` | Entrada (opcional) | Por defecto hoy + 14 días. |
| `@id_prestamo` | `INT` | Salida | ID del préstamo creado. |

Objetivo: prestar un ejemplar `LIBRE` a un socio sin multas pendientes y con
menos de 3 préstamos `ACTIVO`.

Validaciones: socio, empleado y ejemplar existentes; ejemplar `LIBRE`; sin
multas `PENDIENTE`; menos de 3 `ACTIVO`; `fecha_limite` entre hoy y hoy + 60.
Errores: 50301–50308.

#### `usp_devolver_prestamo`

Registra la devolución, calcula el retraso, recupera la multa creada por el
trigger y libera el ejemplar.

| Parámetro | Tipo | E/S | Descripción |
|---|---|---|---|
| `@id_prestamo` | `INT` | Entrada | Préstamo a devolver. |
| `@fecha_devolucion` | `DATETIME2` | Entrada (opcional) | Por defecto `SYSDATETIME()`. |
| `@estado` | `VARCHAR(15)` | Salida | `ATRASADO` o `DEVUELTO`. |
| `@dias_retraso` | `INT` | Salida | Días posteriores a `fecha_limite`. |
| `@monto_multa` | `DECIMAL(10,2)` | Salida | `días * 2.50` (0 si no hay retraso). |
| `@id_multa` | `INT` | Salida | Multa generada (o `NULL`). |

Objetivo: cerrar un préstamo `ACTIVO`, dejarlo `ATRASADO` o `DEVUELTO` según
la fecha, generar la multa si hubo retraso y devolver el ejemplar a `LIBRE`.

Validaciones: préstamo existente y no devuelto; fecha no anterior al préstamo
ni futura. Errores: 50401–50404.

#### `usp_pagar_multa`

Marca una multa `PENDIENTE` como `PAGADO`.

| Parámetro | Tipo | E/S | Descripción |
|---|---|---|---|
| `@id_multa` | `INT` | Entrada | Multa a pagar. |
| `@estado` | `VARCHAR(15)` | Salida | `PAGADO`. |

Objetivo: registrar el pago de una multa, impidiendo pagos duplicados o de
multas inexistentes. Errores: 50501 (no existe), 50502 (no está pendiente).

#### `usp_cancelar_multa`

Marca una multa `PENDIENTE` como `CANCELADO`.

| Parámetro | Tipo | E/S | Descripción |
|---|---|---|---|
| `@id_multa` | `INT` | Entrada | Multa a cancelar. |
| `@estado` | `VARCHAR(15)` | Salida | `CANCELADO`. |

Objetivo: anular una multa pendiente sin registrarla como pagada. Errores:
50601 (no existe), 50602 (no está pendiente).

### 3.3 Objetos reemplazados

| Objeto anterior | Reemplazo |
|---|---|
| `tg_generar_multa_por_retraso` | `trg_prestamo_multa` |
| `sp_procesar_prestamo` | `usp_prestar_ejemplar` |
| `usp_marcar_prestamos_atrasados` | `usp_cancelar_multa` |

`triggers_procedimientos.sql` elimina estos objetos y cualquier trigger o
procedimiento anterior que ya no forme parte del diseño, de modo que la base
quede solamente con los 4 triggers y 4 procedimientos documentados aquí.

---

## 4. Verificación rápida

```sql
USE Proyecto;

-- Objetos creados (deben aparecer 4 triggers y 4 procedimientos)
SELECT o.type_desc AS tipo, o.name AS nombre
FROM sys.objects o
WHERE o.type IN ('TR', 'P')
  AND o.is_ms_shipped = 0
ORDER BY o.type_desc, o.name;

-- Conteos principales
SELECT 'prestamo' AS tabla, COUNT(*) AS filas FROM dbo.prestamo
UNION ALL SELECT 'multa', COUNT(*) FROM dbo.multa
UNION ALL SELECT 'prestamo_ejemplar', COUNT(*) FROM dbo.prestamo_ejemplar;

-- Préstamos ACTIVO por socio (máximo 3)
SELECT id_socio, COUNT(*) AS activos
FROM dbo.prestamo
WHERE estado = 'ACTIVO'
GROUP BY id_socio
HAVING COUNT(*) > 3;
```

También puede ejecutarse `99_validacion.sql`, que devuelve el detalle de las
validaciones de integridad y el total de errores.

### 4.1 Pruebas funcionales sugeridas

```sql
-- 1. Prestar un ejemplar LIBRE
DECLARE @id_prestamo INT;
EXEC dbo.usp_prestar_ejemplar
    @id_socio = 1,
    @id_empleado = 1,
    @id_ejemplar = 1,
    @id_prestamo = @id_prestamo OUTPUT;
SELECT @id_prestamo;

-- 2. Devolver a tiempo: debe quedar DEVUELTO y sin multa
DECLARE @estado VARCHAR(15), @dias INT, @monto DECIMAL(10,2), @id_multa INT;
EXEC dbo.usp_devolver_prestamo
    @id_prestamo = @id_prestamo,
    @estado = @estado OUTPUT,
    @dias_retraso = @dias OUTPUT,
    @monto_multa = @monto OUTPUT,
    @id_multa = @id_multa OUTPUT;
SELECT @estado, @dias, @monto, @id_multa;

-- 3. Devolver tarde: debe quedar ATRASADO y con multa
--    (usar una fecha posterior a fecha_limite y no futura)

-- 4. Pagar o cancelar la multa
EXEC dbo.usp_pagar_multa @id_multa = 1, @estado = @estado OUTPUT;
EXEC dbo.usp_cancelar_multa @id_multa = 1, @estado = @estado OUTPUT;
```

---

## 5. Notas operativas

- Ejecutar `triggers_procedimientos.sql` con `sqlcmd` o SSMS; usa `GO` entre lotes.
- El script es idempotente: se puede volver a ejecutar sin duplicar objetos.
- `ALTER TABLE ... DISABLE TRIGGER` requiere el nombre sin esquema
  (`trg_prestamo_estado_fechas`, no `dbo.trg_...`).
- `01_cargar_prestamos_csv.sql` desactiva los triggers durante la carga y los
  vuelve a habilitar al terminar. Así evita multas duplicadas y rechazos de
  filas históricas.
- Para recargar los datos: limpiar `prestamo`, `prestamo_ejemplar` y `multa`,
  volver a ejecutar el cargador o el generador y luego
  `triggers_procedimientos.sql`.
- El generador asume 8,000 ejemplares y 8,000 socios; si cambian esos volúmenes,
  revisar la distribución 70/20/10 para que los 3,000 préstamos `ACTIVO` quepan
  en los ejemplares disponibles.
