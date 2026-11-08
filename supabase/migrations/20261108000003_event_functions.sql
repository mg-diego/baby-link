-- Funciones que evitan descargar a la API miles de filas para calcular algo pequeño.
-- SECURITY INVOKER (por defecto): con la anon key aplican las políticas RLS del usuario.

-- Días (en la zona horaria indicada) con al menos un evento, para el calendario.
create or replace function public.event_dates(p_baby_id uuid, p_tz text)
returns table (day date)
language sql
stable
set search_path = public
as $$
    select distinct (e.start_time at time zone p_tz)::date as day
    from public.baby_events e
    where e.baby_id = p_baby_id
    order by day;
$$;

-- Último evento de cada "clave" para la pantalla de registro:
--   categoría, subtipo de toma (solids/bottle/nursing, 'feed' si no tiene tipo)
--   y pañal mojado/sucio (un pañal 'mixed' cuenta como ambos).
create or replace function public.last_event_times(p_baby_id uuid)
returns table (key text, start_time timestamptz)
language sql
stable
set search_path = public
as $$
    select distinct on (k.key) k.key, e.start_time
    from public.baby_events e
    cross join lateral (
        select case
                   when e.category = 'feed' then
                       case when e.metadata->>'type' in ('solids', 'bottle', 'nursing')
                            then e.metadata->>'type' else 'feed' end
                   else e.category
               end as key
        union all
        select 'diaper_wet' where e.category = 'diaper' and e.metadata->>'condition' in ('wet', 'mixed')
        union all
        select 'diaper_dirty' where e.category = 'diaper' and e.metadata->>'condition' in ('dirty', 'mixed')
    ) k
    where e.baby_id = p_baby_id
    order by k.key, e.start_time desc;
$$;

grant execute on function public.event_dates(uuid, text) to authenticated, service_role;
grant execute on function public.last_event_times(uuid) to authenticated, service_role;
revoke execute on function public.event_dates(uuid, text) from anon, public;
revoke execute on function public.last_event_times(uuid) from anon, public;
