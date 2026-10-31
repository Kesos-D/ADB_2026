use Proyecto_2;



begin transaction;
--! Creacion de datos para libro_editorial
create table #temp_libro_editorial(
    id_libro int not null,
    id_editorial int not null
)
go

with libro_id as (
    select
        id_libro,
        row_number() over(order by id_libro) id_L
    from libro
    where id_libro not in (
    select id_libro from #temp_libro_editorial
    )
), editorial_id as (
    select
        id_editorial,
        row_number() over(order by id_editorial) id_E
    from editorial
)
insert into #temp_libro_editorial (id_libro, id_editorial)
select
    ld.id_libro,
    ed.id_editorial   
from libro_id ld
join editorial_id ed
    on ld.id_L = ed.id_E;

--! Creacion de datos para libro_genero

create table #temp_libro_genero(
    id_genero int not null,
    id_libro int not null
)
go

with libro_id as (
    select
        id_libro,
        row_number() over(order by id_libro) id_L
    from libro
    where id_libro not in (
    select id_libro from #temp_libro_genero
    )
), genero_id as (
    select
        id_genero,
        row_number() over(order by id_genero) id_E
    from genero
)
insert into #temp_libro_genero (id_libro, id_genero)
select
    ld.id_libro,
    ed.id_genero   
from libro_id ld
join genero_id ed
    on ld.id_L = ed.id_E;

drop table #temp_libro_genero;

--! Creacion de datos para libro_autor

create table #temp_libro_autor(
    id_libro int not null,
    id_autor int not null
)
go

with libro_id as (
    select
        id_libro,
        row_number() over(order by id_libro) id_L
    from libro
    where id_libro not in (
    select id_libro from #temp_libro_autor
    )
), autor_id as (
    select
        id_autor,
        row_number() over(order by id_autor) id_E
    from autor
)
insert into #temp_libro_autor (id_libro, id_autor)
select
    ld.id_libro,
    ed.id_autor   
from libro_id ld
join autor_id ed
    on ld.id_L = ed.id_E;

--! Creacion de datos para prestamo (une socios y empleados reales)
--! 70% DEVUELTO / 20% ATRASADO / 10% ACTIVO (fecha > 2026-01-01)
create table #nuevos_prestamo (
    id_prestamo      int         not null,
    fecha_prestamo   datetime2   not null,
    fecha_limite     date        not null,
    fecha_devolucion datetime2   null,
    estado           varchar(15) not null
);
go

declare @total int = 30000;
declare @n_socios int = (select count(*) from socio);
declare @n_empleados int = (select count(*) from empleado);

with numeros as (
    select 1 as n
    union all
    select n + 1
    from numeros
    where n < @total
), socios as (
    select
        id_socio,
        row_number() over(order by newid()) as rn
    from socio
), empleados as (
    select
        id_empleado,
        row_number() over(order by newid()) as rn
    from empleado
), generado as (
    select
        n.n,
        abs(checksum(newid())) % 100 as azar
    from numeros n
), prestamo_base as (
    select
        g.n,
        g.azar,
        case
            when g.azar < 10
                then dateadd(day, -(abs(checksum(newid())) % 14), cast(getdate() as date))
            else dateadd(
                    day,
                    abs(checksum(newid())) % (datediff(day, '2020-01-01', '2025-12-17') + 1),
                    cast('2020-01-01' as date)
                 )
        end as fecha_prestamo,
        s.id_socio,
        e.id_empleado
    from generado g
    join socios s
        on s.rn = ((g.n - 1) % @n_socios) + 1
    join empleados e
        on e.rn = ((g.n - 1) % @n_empleados) + 1
)
insert into dbo.prestamo
    (fecha_prestamo, fecha_limite, fecha_devolucion, estado, id_empleado, id_socio)
output
    inserted.id_prestamo,
    inserted.fecha_prestamo,
    inserted.fecha_limite,
    inserted.fecha_devolucion,
    inserted.estado
into #nuevos_prestamo
    (id_prestamo, fecha_prestamo, fecha_limite, fecha_devolucion, estado)
select
    b.fecha_prestamo,
    dateadd(day, 1 + (abs(checksum(newid())) % 15), b.fecha_prestamo) as fecha_limite,
    case
        when b.azar >= 30
            then cast(dateadd(day, 14, b.fecha_prestamo) as datetime2)
        when b.azar >= 10
            then dateadd(day, 1 + (abs(checksum(newid())) % 15),
                         cast(dateadd(day, 14, b.fecha_prestamo) as datetime2))
        else null
    end as fecha_devolucion,
    case
        when b.azar >= 30 then 'DEVUELTO'
        when b.azar >= 10 then 'ATRASADO'
        else 'ACTIVO'
    end as estado,
    b.id_empleado,
    b.id_socio
from prestamo_base b
option (maxrecursion 0);
go

select
    estado,
    count(*) as cantidad,
    min(fecha_limite) as limite_min,
    max(fecha_limite) as limite_max
from #nuevos_prestamo
group by estado
order by cantidad desc;
go

create index IX_socio on prestamo (id_socio);

select
    top 10
    id_socio,
    count(id_socio) x
from prestamo
group by id_socio;

select * from socio;