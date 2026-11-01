-- =====================================================================
-- Franchessca's · Reservas
-- Pegar entero en Supabase → SQL Editor → New query → Run
-- =====================================================================

-- ---------- Tablas ----------

create table if not exists public.appointments (
  id          uuid primary key default gen_random_uuid(),
  service     text not null,
  date        date not null,
  time        time not null,
  name        text not null,
  phone       text not null,
  notes       text,
  status      text not null default 'pendiente'
              check (status in ('pendiente', 'confirmada', 'cancelada')),
  created_at  timestamptz not null default now()
);

-- Una sola cita activa por hueco (las canceladas liberan la hora)
create unique index if not exists appointments_slot_unique
  on public.appointments (date, time)
  where status <> 'cancelada';

-- Huecos bloqueados por el salón (time null = día completo)
create table if not exists public.blocked_slots (
  id          uuid primary key default gen_random_uuid(),
  date        date not null,
  time        time,
  reason      text,
  created_at  timestamptz not null default now()
);

-- Usuarias con acceso al panel
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- La web no puede leer blocked_slots, así que la comprobación va en una función con permisos propios
create or replace function public.is_blocked(p_date date, p_time time)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.blocked_slots
     where date = p_date and (time is null or time = p_time)
  );
$$;

-- ---------- Seguridad (RLS) ----------

alter table public.appointments  enable row level security;
alter table public.blocked_slots enable row level security;
alter table public.admins        enable row level security;

-- La web pública solo puede CREAR solicitudes válidas (nunca leer datos de otras clientas)
drop policy if exists "web crea solicitudes" on public.appointments;
create policy "web crea solicitudes" on public.appointments
  for insert to anon, authenticated
  with check (
    status = 'pendiente'
    and date >= current_date
    and date <= current_date + 90
    and extract(isodow from date) between 1 and 5            -- lunes a viernes
    and time between '08:00' and '13:30'                      -- 08:00–14:00
    and extract(minute from time) in (0, 30)
    and length(trim(name)) between 2 and 80
    and length(regexp_replace(phone, '\D', '', 'g')) between 9 and 15
    and length(service) <= 80
    and coalesce(length(notes), 0) <= 500
    and not public.is_blocked(date, time)
  );

drop policy if exists "admin gestiona citas" on public.appointments;
create policy "admin gestiona citas" on public.appointments
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin gestiona bloqueos" on public.blocked_slots;
create policy "admin gestiona bloqueos" on public.blocked_slots
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin se ve a sí misma" on public.admins;
create policy "admin se ve a sí misma" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- ---------- Horas ocupadas (solo devuelve horas, sin datos personales) ----------

create or replace function public.get_busy_slots(p_date date)
returns setof time
language sql stable security definer set search_path = public
as $$
  select time from public.appointments
   where date = p_date and status <> 'cancelada'
  union
  select time from public.blocked_slots
   where date = p_date and time is not null
  union
  select s::time
    from generate_series(p_date + time '08:00', p_date + time '13:30', interval '30 minutes') s
   where exists (select 1 from public.blocked_slots where date = p_date and time is null);
$$;

revoke all on function public.get_busy_slots(date) from public;
grant execute on function public.get_busy_slots(date) to anon, authenticated;

-- =====================================================================
-- DESPUÉS de ejecutar lo anterior:
-- 1) Authentication → Users → Add user → crea el usuario de Franchessca (email + contraseña)
-- 2) Ejecuta esta línea cambiando el email:
--
--    insert into public.admins (user_id)
--    select id from auth.users where email = 'EMAIL_DE_FRANCHESSCA';
--
-- 3) Authentication → Sign In / Providers → desactiva "Allow new users to sign up"
-- =====================================================================
