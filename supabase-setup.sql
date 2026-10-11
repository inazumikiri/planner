-- «Мой день»: облако для синхронизации.
-- Вставь весь этот текст в Supabase → SQL Editor → New query и нажми Run.

-- 1. Таблица для всех записей приложения: задачи, рутина, календарь, дневник, покупки
create table if not exists public.items (
  id         text not null,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind       text not null,
  data       jsonb not null default '{}'::jsonb,
  updated    bigint not null default 0,
  deleted    boolean not null default false,
  server_ts  timestamptz not null default now(),
  primary key (user_id, id)
);
-- если таблица уже была создана прошлой версией скрипта, ключ обновится здесь
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.items'::regclass and contype = 'p' and array_length(conkey, 1) = 1
  ) then
    execute 'alter table public.items drop constraint ' || (
      select conname from pg_constraint where conrelid = 'public.items'::regclass and contype = 'p');
    alter table public.items add primary key (user_id, id);
  end if;
end $$;
create index if not exists items_user_ts on public.items (user_id, server_ts, id);

-- 2. Каждая видит только свои записи
alter table public.items enable row level security;
drop policy if exists "own items" on public.items;
create policy "own items" on public.items
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
grant select, insert, update, delete on public.items to authenticated;

-- 3. Более новая правка всегда побеждает более старую
create or replace function public.items_before_write() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated < old.updated then
    return null;
  end if;
  new.server_ts := clock_timestamp();
  return new;
end $$;
drop trigger if exists items_before_write on public.items;
create trigger items_before_write
  before insert or update on public.items
  for each row execute function public.items_before_write();

-- 4. Закрытое хранилище для фото: у каждой своя папка
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

drop policy if exists "own photos read"   on storage.objects;
drop policy if exists "own photos add"    on storage.objects;
drop policy if exists "own photos change" on storage.objects;
drop policy if exists "own photos delete" on storage.objects;
create policy "own photos read" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own photos add" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own photos change" on storage.objects for update to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own photos delete" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
