-- =====================================================================
-- Franchessca's · Agenda sin login (acceso con enlace privado)
-- Pegar entero en Supabase → SQL Editor → New query → Run
--
-- El panel ya no pide email ni contraseña: se abre con un enlace secreto.
-- Aquí solo se guarda la huella (SHA-256) de la clave del enlace, nunca la clave.
-- Las citas siguen sin poder leerse desde la web pública.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- Huellas de las claves válidas (sin políticas RLS: no se puede leer desde la API)
create table if not exists public.agenda_keys (
  key_hash   text primary key,
  label      text,
  created_at timestamptz not null default now()
);
alter table public.agenda_keys enable row level security;

insert into public.agenda_keys (key_hash, label)
values ('73f851b13490987ffb59b33f7dc9b40c33cb299b0439045ee3206bc1117a8e9c', 'Enlace de Franchessca')
on conflict (key_hash) do nothing;

-- Comprueba la clave (solo la usan las funciones de abajo)
create or replace function public.agenda_key_ok(p_key text)
returns boolean
language sql stable security definer set search_path = public, extensions
as $$
  select exists (
    select 1 from public.agenda_keys
     where key_hash = encode(extensions.digest(coalesce(p_key, ''), 'sha256'), 'hex')
  );
$$;
revoke all on function public.agenda_key_ok(text) from public, anon, authenticated;

create or replace function public.agenda_check(p_key text)
returns void
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.agenda_key_ok(p_key) then
    raise exception 'Enlace no válido' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.agenda_check(text) from public, anon, authenticated;

-- ---------- Funciones de la agenda ----------

create or replace function public.agenda_list(p_key text, p_from date)
returns json
language plpgsql stable security definer set search_path = public
as $$
begin
  perform public.agenda_check(p_key);
  return json_build_object(
    'appointments', coalesce((select json_agg(a order by a.date, a.time) from public.appointments a where a.date >= p_from), '[]'::json),
    'blocks', coalesce((select json_agg(b order by b.date, b.time nulls first) from public.blocked_slots b where b.date >= p_from), '[]'::json)
  );
end;
$$;

create or replace function public.agenda_set_status(p_key text, p_id uuid, p_status text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  perform public.agenda_check(p_key);
  update public.appointments set status = p_status where id = p_id;
end;
$$;

create or replace function public.agenda_move(p_key text, p_id uuid, p_date date, p_time time)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  perform public.agenda_check(p_key);
  update public.appointments set date = p_date, time = p_time, status = 'confirmada' where id = p_id;
end;
$$;

create or replace function public.agenda_add(p_key text, p_service text, p_date date, p_time time, p_name text, p_phone text, p_notes text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  perform public.agenda_check(p_key);
  insert into public.appointments (service, date, time, name, phone, notes, status)
  values (p_service, p_date, p_time, p_name, coalesce(nullif(p_phone, ''), '-'), nullif(p_notes, ''), 'confirmada');
end;
$$;

create or replace function public.agenda_block(p_key text, p_date date, p_time time, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  perform public.agenda_check(p_key);
  insert into public.blocked_slots (date, time, reason) values (p_date, p_time, nullif(p_reason, ''));
end;
$$;

create or replace function public.agenda_unblock(p_key text, p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  perform public.agenda_check(p_key);
  delete from public.blocked_slots where id = p_id;
end;
$$;

grant execute on function public.agenda_list(text, date) to anon, authenticated;
grant execute on function public.agenda_set_status(text, uuid, text) to anon, authenticated;
grant execute on function public.agenda_move(text, uuid, date, time) to anon, authenticated;
grant execute on function public.agenda_add(text, text, date, time, text, text, text) to anon, authenticated;
grant execute on function public.agenda_block(text, date, time, text) to anon, authenticated;
grant execute on function public.agenda_unblock(text, uuid) to anon, authenticated;
