-- RLS: cada usuario solo ve y modifica sus bebés, sus eventos, sus hitos y sus ficheros.
--
-- La API usa la service_role key (se salta RLS y hace su propia comprobación), pero la app
-- accede directamente con la anon key + sesión a `milestones` y a Storage, así que esa vía
-- depende solo de estas políticas.
--
-- Antes de aplicarla puedes revisar lo que hay:
--   select tablename, policyname, cmd, roles, qual, with_check
--   from pg_policies where schemaname in ('public', 'storage');
--
-- Las políticas permisivas se combinan con OR: si quedase una antigua tipo "using (true)",
-- las nuevas no restringirían nada. Por eso se borran TODAS las de estas tres tablas.

do $$
declare p record;
begin
    for p in
        select policyname, tablename from pg_policies
        where schemaname = 'public' and tablename in ('babies', 'baby_events', 'milestones')
    loop
        execute format('drop policy %I on public.%I', p.policyname, p.tablename);
    end loop;
end $$;

alter table public.babies      enable row level security;
alter table public.baby_events enable row level security;
alter table public.milestones  enable row level security;

-- ─── babies ───────────────────────────────────────────────────────────────────
create policy babies_owner_all on public.babies
    for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

-- ─── baby_events / milestones: a través del dueño del bebé ────────────────────
create policy baby_events_owner_all on public.baby_events
    for all to authenticated
    using (baby_id in (select id from public.babies where user_id = (select auth.uid())))
    with check (baby_id in (select id from public.babies where user_id = (select auth.uid())));

create policy milestones_owner_all on public.milestones
    for all to authenticated
    using (baby_id in (select id from public.babies where user_id = (select auth.uid())))
    with check (baby_id in (select id from public.babies where user_id = (select auth.uid())));

-- ─── Storage: bucket "milestones", rutas "<baby_id>/..." ──────────────────────
-- (Las de otros buckets no se tocan; solo se recrean las de este script.)
drop policy if exists babylink_milestones_select on storage.objects;
drop policy if exists babylink_milestones_insert on storage.objects;
drop policy if exists babylink_milestones_update on storage.objects;
drop policy if exists babylink_milestones_delete on storage.objects;

create policy babylink_milestones_select on storage.objects
    for select to authenticated
    using (bucket_id = 'milestones' and (storage.foldername(name))[1] in
           (select id::text from public.babies where user_id = (select auth.uid())));

create policy babylink_milestones_insert on storage.objects
    for insert to authenticated
    with check (bucket_id = 'milestones' and (storage.foldername(name))[1] in
                (select id::text from public.babies where user_id = (select auth.uid())));

create policy babylink_milestones_update on storage.objects
    for update to authenticated
    using (bucket_id = 'milestones' and (storage.foldername(name))[1] in
           (select id::text from public.babies where user_id = (select auth.uid())));

create policy babylink_milestones_delete on storage.objects
    for delete to authenticated
    using (bucket_id = 'milestones' and (storage.foldername(name))[1] in
           (select id::text from public.babies where user_id = (select auth.uid())));

-- Nota: el bucket es público (la app usa getPublicUrl), así que cualquiera con la URL de
-- una foto puede verla. Para cerrarlo del todo habría que hacerlo privado y usar URLs firmadas.
