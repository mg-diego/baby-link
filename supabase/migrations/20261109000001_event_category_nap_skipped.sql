-- Categorías válidas de baby_events, incluida 'nap_skipped' (siesta prevista que se
-- marcó como no hecha; borrar el evento deshace la marca).
--
-- La restricción se creó a mano en Supabase y no estaba en las migraciones: aquí queda
-- versionada. Tiene que coincidir con `EventCategory` (api/models/event_models.py);
-- `tests/test_migrations.py` lo comprueba.
alter table public.baby_events drop constraint if exists baby_events_category_check;

alter table public.baby_events add constraint baby_events_category_check check (
    category in (
        'woke_up',
        'nap',
        'nap_skipped',
        'bed_time',
        'night_waking',
        'feed',
        'diaper',
        'medicine',
        'bath',
        'temperature',
        'growth',
        'pumping',
        'milestone'
    )
);
