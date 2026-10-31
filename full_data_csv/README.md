# Biblioteca `Proyecto` — Datos, reglas y automatizaciones

Documentación de los scripts de carga de `full_data_csv` y de los objetos
programables de la base `Proyecto`.

El diseño usa la **Opción A**: un préstamo está `ACTIVO` mientras siga dentro
del plazo, pasa a `ATRASADO` cuando vence sin devolución y termina en
`DEVUELTO` al registrarse la devolución. La multa se genera únicamente cuando
la devolución ocurre después de `fecha_limite`.

## Contenido de la carpeta

| Archivo | Uso |
|---|---|
| `00_cargar_tablas_madres.sql` | Carga `empleado`, `socio`, `autor`, `editorial`, `genero`, `libro`, `ejemplar` y `libro_autor` desde los CSV de `data_2`. Solo inserta si la tabla está vacía. |
| `full_data_csv.sql` | Genera ejemplares, relaciones libro-editorial/género/autor, 30,000 préstamos, `prestamo_ejemplar` y multas. Elimina los triggers de negocio al inicio para permitir la carga masiva. |
| `triggers_procedimientos.sql` | Crea **4 triggers** y **4 procedimientos almacenados**. Sin auditorías, sin jobs y sin índices adicionales. |
| `99_validacion.sql` | Consultas de validación. No modifica datos. |

### Orden de ejecución

```text
1) Proyecto.sql                  (crea la base y el esquema base)
2) 00_cargar_tablas_madres.sql   (tablas madre desde data_2)
3) full_data_csv.sql             (datos de tablas hijas)
4) triggers_procedimientos.sql   (4 triggers y 4 SPs)
5) 99_validacion.sql             (verificación, opcional)
```

> `full_data_csv.sql` borra los triggers de negocio antes de sembrar los datos.
> Si se ejecuta solo, la base queda sin triggers hasta correr
> `triggers_procedimientos.sql`.

---

## 1. Reglas de negocio

### 1.1 Semántica de estados del préstamo (Opción A)

| Estado | Significado | `fecha_devolucion` | `fecha_limite` |
|---|---|---|---|
| `ACTIVO` | Préstamo abierto, dentro de plazo. | `NULL` | `>= hoy` |
| `ATRASADO` | Préstamo abierto, fuera de plazo. | `NULL` | `< hoy` |
| `DEVUELTO` | Préstamo devuelto (a tiempo o tarde). | `NOT NULL` | cualquiera |

Reglas derivadas:

1. Un préstamo abierto nunca tiene `fecha_devolucion`.
2. Un préstamo `DEVUELTO` siempre tiene `fecha_devolucion`.
3. `ACTIVO` no puede tener `fecha_limite` vencida; `ATRASADO` no puede tenerla vigente.
4. `fecha_limite` no puede ser anterior a la fecha del préstamo.
5. `fecha_devolucion` no puede ser anterior a `fecha_prestamo` ni futura.
6. El paso de `ACTIVO` a `ATRASADO` se hace con `usp_marcar_prestamos_atrasados`.

### 1.2 Préstamos

- Un socio puede tener como máximo **3 préstamos abiertos** (`ACTIVO` + `ATRASADO`).
- Un ejemplar solo puede estar en **un préstamo abierto** a la vez.
- Solo se presta un ejemplar en estado `LIBRE`.
- Un socio con **multas `PENDIENTE`** no puede recibir préstamos.
- Plazo estándar: **14 días**. El SP permite entre 1 y 60 días.
- La relación `prestamo_ejemplar` de un préstamo abierto no debe borrarse ni
  moverse; primero debe devolverse el préstamo.

### 1.3 Devoluciones y multas

- La multa se genera **solo al devolver tarde**.
- Fórmula: `monto = días_de_retraso * 2.50`, donde
  `días_de_retraso = fecha_devolucion - fecha_limite`.
- Si la devolución es el mismo día de `fecha_limite` o antes, **no hay multa**.
- Una multa solo aplica a un préstamo `DEVUELTO` con devolución tardía.
- Hay **una sola multa por préstamo**.
- Estados de multa: `PENDIENTE` → `PAGADO`. Solo se paga una multa `PENDIENTE`.
- La multa se crea una sola vez al registrar la devolución tardía; no se
  recalcula automáticamente después.

### 1.4 Ejemplares

Estados: `LIBRE`, `PRESTADO`, `RESERVADO`, `FUERA_SERVICIO`.

| Origen | Destino esperado |
|---|---|
| `LIBRE` | `PRESTADO` (al prestar) |
| `PRESTADO` | `LIBRE` (al devolver) |

- `PRESTADO` ⇔ existe un préstamo `ACTIVO`/`ATRASADO` asociado.
- `LIBRE` ⇔ no existe préstamo abierto asociado.
- Los estados `RESERVADO` y `FUERA_SERVICIO` existen en el esquema base, pero
  este diseño no incluye procedimientos de reservas ni de disponibilidad.

### 1.5 Datos generados

| Tabla | Filas esperadas |
|---|---|
| `ejemplar` | 8,000 (4 copias por libro) |
| `libro_editorial` | 2,000 |
| `libro_genero` | 2,000 |
| `libro_autor` | 2,000 |
| `prestamo` | 30,000 (80% `DEVUELTO`, 12% `ATRASADO`, 8% `ACTIVO`) |
| `prestamo_ejemplar` | 30,000 (uno por préstamo) |
| `multa` | ~7,200 (solo devoluciones tardías) |
| `multa` por estado | 60% `PAGADO`, 30% `PENDIENTE`, 10% `CANCELADO` |

### 1.6 Alcance de las automatizaciones

- **4 triggers** de validación y generación de multas.
- **4 procedimientos** para prestar, devolver, pagar multas y actualizar atrasos.
- **Sin tablas de auditoría**, **sin jobs** y **sin índices adicionales**.
- Se usan únicamente las llaves primarias, foráneas y restricciones de
  `Proyecto.sql`.

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
| `fecha_devolucion` | `DATETIME2 NULL` | `NULL` si está abierto |
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
| `id_prestamo` | `INT` | FK → `prestamo` |

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
| Salida | Ninguna si todo es válido; `THROW` 50201/50202 si no. |
| Objetivo | Evitar fechas incoherentes o estados incompatibles con el plazo. |

Descripción: valida que `fecha_limite` no sea anterior a `fecha_prestamo`, que
`fecha_devolucion` no sea anterior al préstamo ni futura, que los estados
abiertos no tengan devolución, que `DEVUELTO` sí la tenga y que `ACTIVO` esté
vigente y `ATRASADO` vencido.

#### `trg_prestamo_multa`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo` |
| Evento | `AFTER UPDATE` |
| Entrada | Filas de `inserted` y `deleted`. |
| Salida | Inserta una fila en `multa` cuando corresponde. |
| Objetivo | Generar la multa al registrar una devolución tardía. |

Descripción: cuando un préstamo pasa a `DEVUELTO` con fecha posterior a
`fecha_limite`, crea una multa `PENDIENTE` con monto `días * 2.50`. Si el
préstamo ya tiene multa, no inserta otra.

#### `trg_prestamo_max_activos`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo` |
| Evento | `AFTER INSERT, UPDATE` |
| Entrada | Filas de `inserted`. |
| Salida | Ninguna si cumple; `THROW` 50203 si excede. |
| Objetivo | Impedir que un socio tenga más de 3 préstamos abiertos. |

Descripción: cuando se abre un préstamo, cuenta los préstamos `ACTIVO` y
`ATRASADO` del socio. Si el total supera 3, cancela la operación.

#### `trg_prestamo_ejemplar_unico_abierto`

| Aspecto | Detalle |
|---|---|
| Tabla | `prestamo_ejemplar` |
| Evento | `AFTER INSERT, UPDATE` |
| Entrada | Filas de `inserted`. |
| Salida | Ninguna si cumple; `THROW` 50204 si hay duplicado. |
| Objetivo | Evitar que un ejemplar esté en dos préstamos abiertos. |

Descripción: busca el mismo `id_ejemplar` en más de un préstamo
`ACTIVO`/`ATRASADO` y rechaza la operación si encuentra duplicados.

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
menos de 3 préstamos abiertos.

Validaciones: socio, empleado y ejemplar existentes; ejemplar `LIBRE`; sin
multas `PENDIENTE`; menos de 3 abiertos; `fecha_limite` entre hoy y hoy + 60.
Errores: 50301–50308.

#### `usp_devolver_prestamo`

Registra la devolución, calcula el retraso, recupera la multa creada por el
trigger y libera el ejemplar.

| Parámetro | Tipo | E/S | Descripción |
|---|---|---|---|
| `@id_prestamo` | `INT` | Entrada | Préstamo a devolver. |
| `@fecha_devolucion` | `DATETIME2` | Entrada (opcional) | Por defecto `SYSDATETIME()`. |
| `@estado` | `VARCHAR(15)` | Salida | `DEVUELTO`. |
| `@dias_retraso` | `INT` | Salida | Días posteriores a `fecha_limite`. |
| `@monto_multa` | `DECIMAL(10,2)` | Salida | `días * 2.50` (0 si no hay retraso). |
| `@id_multa` | `INT` | Salida | Multa generada (o `NULL`). |

Objetivo: cerrar un préstamo abierto, dejar la multa correspondiente si hubo
retraso y devolver el ejemplar a `LIBRE`.

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

#### `usp_marcar_prestamos_atrasados`

Marca como `ATRASADO` los préstamos `ACTIVO` vencidos.

| Parámetro | Tipo | E/S | Descripción |
|---|---|---|---|
| — | — | — | No recibe parámetros. |

Salida: un result set con la columna `prestamos_actualizados`.

Objetivo: actualizar el estado de los préstamos abiertos cuya `fecha_limite` ya
pasó y que aún no tienen devolución.

### 3.3 Objetos reemplazados

| Objeto anterior | Reemplazo |
|---|---|
| `tg_generar_multa_por_retraso` | `trg_prestamo_multa` |
| `sp_procesar_prestamo` | `usp_prestar_ejemplar` |

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

-- Préstamos abiertos por socio (máximo 3)
SELECT id_socio, COUNT(*) AS abiertos
FROM dbo.prestamo
WHERE estado IN ('ACTIVO', 'ATRASADO')
GROUP BY id_socio
HAVING COUNT(*) > 3;
```

También puede ejecutarse `99_validacion.sql`, que devuelve el detalle de las
validaciones de integridad y el total de errores.

---

## 5. Notas operativas

- Ejecutar `triggers_procedimientos.sql` con `sqlcmd` o SSMS; usa `GO` entre lotes.
- El script es idempotente: se puede volver a ejecutar sin duplicar objetos.
- `ALTER TABLE ... DISABLE TRIGGER` requiere el nombre sin esquema
  (`trg_prestamo_estado_fechas`, no `dbo.trg_...`).
- Para recargar los datos: limpiar `prestamo`, `prestamo_ejemplar` y `multa`,
  volver a ejecutar `full_data_csv.sql` y luego `triggers_procedimientos.sql`.
- El generador asume 8,000 ejemplares y 8,000 socios; si cambian esos volúmenes,
  revisar la distribución 80/12/8 para que los préstamos abiertos quepan en los
  ejemplares disponibles.
