-- Casi todas las consultas filtran por bebé (+ categoría) y ordenan / acotan por fecha.
create index if not exists baby_events_baby_start_idx
    on public.baby_events (baby_id, start_time desc);

create index if not exists baby_events_baby_category_start_idx
    on public.baby_events (baby_id, category, start_time desc);

-- Cronómetros abiertos (/events/active)
create index if not exists baby_events_open_idx
    on public.baby_events (baby_id, category)
    where end_time is null;

create index if not exists milestones_baby_date_idx
    on public.milestones (baby_id, date);
