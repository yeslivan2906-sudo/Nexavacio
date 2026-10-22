-- ======================================================================
-- NEXAVACÍO · servidor (Supabase / PostgreSQL)
-- Cuentas, partidas guardadas por cuenta, compras y logros validados en el
-- servidor, y rol de administrador que SOLO se asigna desde el panel.
--
-- Cómo usarlo: Supabase → SQL Editor → New query → pega TODO este archivo → Run.
-- Se puede volver a ejecutar sin borrar datos (crea lo que falta y
-- reemplaza las funciones).
--
-- Seguridad:
--   · Los jugadores NO pueden escribir en las tablas directamente (RLS sin
--     políticas de escritura). Todo pasa por funciones que revisan precios,
--     saldo, compras repetidas y rol.
--   · El rol 'admin' solo se cambia con SQL desde el panel de Supabase
--     (ver ADMIN al final). No hay contraseñas de administrador en el juego.
--   · La partida de PRUEBAS (slot 'test') solo la puede usar un admin y está
--     separada de su partida normal y de las de los demás.
-- ======================================================================

-- ---------------------------------------------------------------- tablas
create table if not exists public.nx_profiles (
    id          uuid primary key references auth.users (id) on delete cascade,
    username    text not null,
    role        text not null default 'player' check (role in ('player', 'admin')),
    created_at  timestamptz not null default now()
);
create unique index if not exists nx_profiles_username_key on public.nx_profiles (lower(username));

create table if not exists public.nx_saves (
    user_id     uuid not null references auth.users (id) on delete cascade,
    slot        text not null check (slot in ('main', 'test')),
    data        jsonb not null,
    version     integer not null default 1,
    updated_at  timestamptz not null default now(),
    gem_bonus   integer not null default 0,             -- diamantes traídos al pasar la partida de invitado
    primary key (user_id, slot)
);
alter table public.nx_saves add column if not exists gem_bonus integer not null default 0;

-- Precios de la tienda. server_only = solo se consigue comprándolo (no sale en cofres).
create table if not exists public.nx_shop (
    id text primary key, coins integer not null default 0, gems integer not null default 0, server_only boolean not null default true
);
-- Personajes que se compran (monedas en el vestuario · diamantes en la tienda).
create table if not exists public.nx_chars (
    id text primary key, coins integer not null default 0, gems integer not null default 0
);
-- Logros con premio: estadística, meta y premio.
create table if not exists public.nx_achievements (
    id text primary key, stat text not null, goal integer not null, coins integer not null default 0, gems integer not null default 0
);
-- Correos de administrador: quien entre con uno de estos correos es ADMIN (lo decide el servidor).
-- Se llena SOLO desde el panel de Supabase (ver ADMIN al final). Los jugadores no pueden leerla ni cambiarla.
create table if not exists public.nx_admin_emails (email text primary key);

-- Registro de compras y premios (las de la partida de pruebas quedan marcadas).
create table if not exists public.nx_purchases (
    id bigserial primary key, user_id uuid not null references auth.users (id) on delete cascade, slot text not null,
    kind text not null, item text not null, coins integer not null default 0, gems integer not null default 0,
    is_test boolean not null default false, created_at timestamptz not null default now()
);

insert into public.nx_shop (id, coins, gems, server_only) values
  ('sword_steel', 45, 0, true), ('axe_war', 65, 0, true), ('sword_runic', 0, 50, true), ('sword_dragon', 0, 90, true),
  ('armor_scale', 55, 0, true), ('armor_shadow', 0, 60, true), ('ring_power', 40, 0, true), ('amulet_dragon', 0, 80, true),
  ('sword_bronze', 25, 0, false), ('bow_hunter', 35, 0, false), ('bow_long', 75, 0, false), ('armor_bronze', 60, 0, false),
  ('sword_dawn', 0, 60, true), ('bow_solar', 0, 55, true), ('bow_void', 0, 95, true), ('armor_solar', 0, 100, true),
  ('outfit_light', 400, 0, true), ('outfit_explorer', 600, 0, true), ('outfit_heavy', 900, 0, true),
  ('outfit_arcane', 0, 40, true), ('outfit_ancient', 0, 80, true)
on conflict (id) do update set coins = excluded.coins, gems = excluded.gems, server_only = excluded.server_only;

insert into public.nx_chars (id, coins, gems) values
  ('nyx', 1800, 0), ('fenrir', 2000, 0), ('selyth', 0, 120), ('kael', 0, 120), ('r7', 0, 150)
on conflict (id) do update set coins = excluded.coins, gems = excluded.gems;

insert into public.nx_achievements (id, stat, goal, coins, gems) values
  ('lab1', 'done', 1, 150, 0), ('lab2', 'done', 2, 150, 0), ('lab3', 'done', 3, 150, 0), ('lab4', 'done', 4, 200, 0), ('lab5', 'done', 5, 250, 0),
  ('boss1', 'bosses', 1, 100, 0), ('boss4', 'bosses', 4, 300, 0), ('best15', 'known', 15, 100, 0), ('bestAll', 'known', 28, 300, 0),
  ('kill100', 'kills', 100, 200, 0), ('kill500', 'kills', 500, 200, 0), ('sec10', 'secrets', 10, 300, 0), ('sec30', 'secrets', 30, 250, 0),
  ('item10', 'items', 10, 200, 0), ('item30', 'items', 30, 200, 0), ('team3', 'chars', 3, 200, 0), ('team6', 'chars', 6, 400, 0),
  ('rich', 'coins', 5000, 200, 0)
on conflict (id) do update set stat = excluded.stat, goal = excluded.goal, coins = excluded.coins, gems = excluded.gems;

-- ---------------------------------------------------------------- permisos (RLS)
alter table public.nx_profiles     enable row level security;
alter table public.nx_saves        enable row level security;
alter table public.nx_shop         enable row level security;
alter table public.nx_chars        enable row level security;
alter table public.nx_achievements enable row level security;
alter table public.nx_purchases    enable row level security;
alter table public.nx_admin_emails enable row level security;
revoke all on public.nx_admin_emails from anon, authenticated;

revoke all on public.nx_profiles, public.nx_saves, public.nx_shop, public.nx_chars, public.nx_achievements, public.nx_purchases from anon, authenticated;
grant select on public.nx_profiles, public.nx_saves, public.nx_purchases to authenticated;
grant select on public.nx_shop, public.nx_chars, public.nx_achievements to anon, authenticated;

drop policy if exists nx_profiles_own on public.nx_profiles;
create policy nx_profiles_own on public.nx_profiles for select to authenticated using (id = auth.uid());
drop policy if exists nx_saves_own on public.nx_saves;
create policy nx_saves_own on public.nx_saves for select to authenticated using (user_id = auth.uid());
drop policy if exists nx_purchases_own on public.nx_purchases;
create policy nx_purchases_own on public.nx_purchases for select to authenticated using (user_id = auth.uid());
drop policy if exists nx_shop_read on public.nx_shop;
create policy nx_shop_read on public.nx_shop for select using (true);
drop policy if exists nx_chars_read on public.nx_chars;
create policy nx_chars_read on public.nx_chars for select using (true);
drop policy if exists nx_ach_read on public.nx_achievements;
create policy nx_ach_read on public.nx_achievements for select using (true);
-- (sin políticas de insert/update/delete: los jugadores no pueden escribir directamente)

-- ---------------------------------------------------------------- perfil al registrarse
create or replace function public.nx_handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare u text := trim(coalesce(new.raw_user_meta_data ->> 'username', ''));
begin
    if u !~ '^[A-Za-z0-9_]{3,16}$' then raise exception 'NX:usuario_invalido'; end if;
    if exists (select 1 from public.nx_profiles where lower(username) = lower(u)) then raise exception 'NX:usuario_ocupado'; end if;
    insert into public.nx_profiles (id, username) values (new.id, u);       -- el rol siempre empieza como 'player'
    return new;
end $$;
drop trigger if exists nx_on_auth_user_created on auth.users;
create trigger nx_on_auth_user_created after insert on auth.users for each row execute function public.nx_handle_new_user();

-- ---------------------------------------------------------------- ayudas internas
create or replace function public.nx_uid() returns uuid language plpgsql stable as $$
begin
    if auth.uid() is null then raise exception 'NX:sin_sesion'; end if;
    return auth.uid();
end $$;

create or replace function public.nx_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
    select exists (select 1 from public.nx_profiles where id = auth.uid() and role = 'admin')
        or exists (select 1 from auth.users u join public.nx_admin_emails a on lower(a.email) = lower(u.email) where u.id = auth.uid());
$$;

create or replace function public.nx_default_save() returns jsonb language sql immutable as $$
    select '{"v":1,"level":1,"coins":0,"gems":0,"char":"zarek","unlocked":["zarek"],"inventory":[],
             "equipped":{"weapon":"sword_energy","armor":"armor_travel","amulet":null,"ring":null,"charm":null},
             "equipBy":{},"progress":{"bosses":[],"secrets":0,"items":[],"time":0,"levelsDone":0,"kills":{},"claimed":[]}}'::jsonb;
$$;

-- Objetos que tiene la partida (bolsa + lo que lleva cada personaje).
create or replace function public.nx_owned(d jsonb) returns text[] language sql immutable as $$
    select coalesce(array_agg(distinct x), '{}') from (
        select e ->> 'id' as x from jsonb_array_elements(case when jsonb_typeof(d -> 'inventory') = 'array' then d -> 'inventory' else '[]' end) e
        union all select value #>> '{}' from jsonb_each(case when jsonb_typeof(d -> 'equipped') = 'object' then d -> 'equipped' else '{}' end)
        union all select v.value #>> '{}' from jsonb_each(case when jsonb_typeof(d -> 'equipBy') = 'object' then d -> 'equipBy' else '{}' end) c,
                  jsonb_each(case when jsonb_typeof(c.value) = 'object' then c.value else '{}' end) v
    ) s where x is not null;
$$;

-- Quita de la partida los objetos indicados (bolsa, equipo y equipo de cada personaje).
create or replace function public.nx_strip(d jsonb, bad text[]) returns jsonb language plpgsql immutable as $$
declare eq jsonb; k text; v text; ch text; basic jsonb := '{"weapon":"sword_energy","armor":"armor_travel"}';
begin
    if bad is null or cardinality(bad) = 0 then return d; end if;
    d := jsonb_set(d, '{inventory}', coalesce((select jsonb_agg(e) from jsonb_array_elements(coalesce(d -> 'inventory', '[]')) e where not ((e ->> 'id') = any (bad))), '[]'));
    if jsonb_typeof(d -> 'equipped') = 'object' then
        eq := d -> 'equipped';
        for k, v in select key, value #>> '{}' from jsonb_each(d -> 'equipped') loop
            if v = any (bad) then eq := jsonb_set(eq, array[k], coalesce(basic -> k, 'null'::jsonb)); end if;
        end loop;
        d := jsonb_set(d, '{equipped}', eq);
    end if;
    if jsonb_typeof(d -> 'equipBy') = 'object' then
        for ch in select key from jsonb_each(d -> 'equipBy') loop
            if jsonb_typeof(d -> 'equipBy' -> ch) = 'object' then
                eq := d -> 'equipBy' -> ch;
                for k, v in select key, value #>> '{}' from jsonb_each(d -> 'equipBy' -> ch) loop
                    if v = any (bad) then eq := jsonb_set(eq, array[k], coalesce(basic -> k, 'null'::jsonb)); end if;
                end loop;
                d := jsonb_set(d, array['equipBy', ch], eq);
            end if;
        end loop;
    end if;
    return d;
end $$;

create or replace function public.nx_int(d jsonb, path text[], dflt integer default 0) returns integer language sql immutable as $$
    select case when jsonb_typeof(d #> path) = 'number' then floor((d #>> path)::numeric)::integer else dflt end;
$$;

-- Revisa una partida normal antes de guardarla, comparándola con la del servidor:
--   · las monedas no pueden subir más rápido de lo que da el juego (según el tiempo
--     desde el último guardado);
--   · los diamantes nunca suben al guardar (solo se compran con dinero real);
--   · personajes de diamantes, objetos de solo tienda y premios de logros solo entran
--     por las funciones de compra / premio (aquí se respetan los del servidor);
--   · límites razonables para mejoras y progreso.
create or replace function public.nx_sanitize(nw jsonb, old jsonb, uid uuid, last_at timestamptz, coin_cap integer default 3000, gem_cap integer default 150, bonus integer default 0)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d jsonb := nw; oc integer := public.nx_int(old, '{coins}'); og integer := public.nx_int(old, '{gems}');
        old_un text[]; new_un text[]; paid text[]; bad text[]; owned_old text[]; secs numeric; coin_allow integer; bosses text[];
begin
    if jsonb_typeof(d) <> 'object' then raise exception 'NX:datos_invalidos'; end if;
    d := jsonb_set(d, '{progress}', coalesce(case when jsonb_typeof(d -> 'progress') = 'object' then d -> 'progress' end, '{}'));
    -- progreso con límites (solo existen 5 laberintos y 6 guardianes)
    bosses := array(select distinct b from jsonb_array_elements_text(case when jsonb_typeof(d #> '{progress,bosses}') = 'array' then d #> '{progress,bosses}' else '[]' end) b
                    where b in ('ruinas', 'llama', 'glaciar', 'espejo', 'solar', 'animas'));
    d := jsonb_set(d, '{progress,bosses}', to_jsonb(bosses));
    d := jsonb_set(d, '{progress,levelsDone}', to_jsonb(greatest(0, least(public.nx_int(d, '{progress,levelsDone}'), 5))));
    d := jsonb_set(d, '{progress,secrets}', to_jsonb(greatest(0, least(public.nx_int(d, '{progress,secrets}'), 80))));
    d := jsonb_set(d, '{level}', to_jsonb(greatest(1, least(public.nx_int(d, '{level}', 1), 5))));
    -- monedas: según el tiempo jugado desde el último guardado
    secs := greatest(0, extract(epoch from (now() - coalesce(last_at, now()))));
    coin_allow := least(coin_cap, 150 + floor(secs * 15)::integer)
        -- + los premios en monedas por lo nuevo que se logró (guardián 300 · laberinto 150 · secreto 20 · tesoro 100)
        + 300 * greatest(0, cardinality(bosses) - coalesce(jsonb_array_length(case when jsonb_typeof(old #> '{progress,bosses}') = 'array' then old #> '{progress,bosses}' end), 0))
        + 150 * greatest(0, public.nx_int(d, '{progress,levelsDone}') - public.nx_int(old, '{progress,levelsDone}'))
        + 20 * greatest(0, public.nx_int(d, '{progress,secrets}') - public.nx_int(old, '{progress,secrets}'))
        + 100 * least(10, greatest(0, coalesce(jsonb_array_length(case when jsonb_typeof(d #> '{progress,items}') = 'array' then d #> '{progress,items}' end), 0)
                                     - coalesce(jsonb_array_length(case when jsonb_typeof(old #> '{progress,items}') = 'array' then old #> '{progress,items}' end), 0)));
    d := jsonb_set(d, '{coins}', to_jsonb(greatest(0, least(public.nx_int(d, '{coins}'), oc + coin_allow))));
    -- diamantes: SOLO se compran con dinero real (todavía no hay pagos). Jugando no se ganan,
    -- así que al guardar nunca pueden subir: solo bajar (al gastarlos en las funciones de compra).
    d := jsonb_set(d, '{gems}', to_jsonb(greatest(0, least(public.nx_int(d, '{gems}'), og))));
    -- personajes de diamantes: solo los que el servidor ya tenía
    select coalesce(array_agg(id), '{}') into paid from public.nx_chars where gems > 0;
    old_un := array(select jsonb_array_elements_text(coalesce(old -> 'unlocked', '["zarek"]')));
    new_un := array(select jsonb_array_elements_text(case when jsonb_typeof(d -> 'unlocked') = 'array' then d -> 'unlocked' else '["zarek"]' end));
    new_un := array(select distinct x from unnest(new_un || array['zarek'] || (select coalesce(array_agg(p), '{}') from unnest(old_un) p where p = any (paid))) x
                    where (not (x = any (paid)) or x = any (old_un)) and x in ('zarek', 'nyx', 'fenrir', 'selyth', 'kael', 'r7'));
    d := jsonb_set(d, '{unlocked}', to_jsonb(new_un));
    if not ((d ->> 'char') = any (new_un)) then d := jsonb_set(d, '{char}', '"zarek"'); end if;
    -- objetos de solo tienda que no estaban en el servidor
    owned_old := public.nx_owned(old);
    select coalesce(array_agg(s.id), '{}') into bad from public.nx_shop s where s.server_only and s.id = any (public.nx_owned(d)) and not (s.id = any (owned_old));
    d := public.nx_strip(d, bad);
    -- premios de logros: solo los del servidor
    d := jsonb_set(d, '{progress,claimed}', coalesce(old #> '{progress,claimed}', '[]'));
    -- mejoras con límites razonables
    if d ? 'speed' then d := jsonb_set(d, '{speed}', to_jsonb(least(public.nx_int(d, '{speed}', 165), 400))); end if;
    if d ? 'damage' then d := jsonb_set(d, '{damage}', to_jsonb(least(public.nx_int(d, '{damage}', 1), 50))); end if;
    if d ? 'baseMaxHealth' then d := jsonb_set(d, '{baseMaxHealth}', to_jsonb(least(public.nx_int(d, '{baseMaxHealth}', 4), 20))); end if;
    if d ? 'playerLevel' then d := jsonb_set(d, '{playerLevel}', to_jsonb(least(public.nx_int(d, '{playerLevel}', 1), 200))); end if;
    return d;
end $$;

-- Valor de una estadística de logros a partir de la partida.
create or replace function public.nx_stat(d jsonb, stat text) returns integer language plpgsql immutable as $$
declare n integer := 0;
begin
    case stat
    when 'done' then n := greatest(public.nx_int(d, '{progress,levelsDone}'), public.nx_int(d, '{level}', 1) - 1);
    when 'bosses' then n := coalesce(jsonb_array_length(case when jsonb_typeof(d #> '{progress,bosses}') = 'array' then d #> '{progress,bosses}' end), 0);
    when 'known' then
        select count(distinct x) into n from (
            select key as x from jsonb_each(case when jsonb_typeof(d #> '{progress,kills}') = 'object' then d #> '{progress,kills}' else '{}' end) where (value #>> '{}')::numeric > 0
            union all
            select case b when 'ruinas' then 'guardian_ruinas' when 'llama' then 'ulmarok' when 'glaciar' then 'devorador' when 'espejo' then 'guardian_espejo' when 'solar' then 'guardian_solar' else b end
            from jsonb_array_elements_text(case when jsonb_typeof(d #> '{progress,bosses}') = 'array' then d #> '{progress,bosses}' else '[]' end) b
        ) s;
    when 'kills' then select coalesce(sum((value #>> '{}')::numeric), 0)::integer into n from jsonb_each(case when jsonb_typeof(d #> '{progress,kills}') = 'object' then d #> '{progress,kills}' else '{}' end);
    when 'secrets' then n := public.nx_int(d, '{progress,secrets}');
    when 'items' then n := coalesce(jsonb_array_length(case when jsonb_typeof(d #> '{progress,items}') = 'array' then d #> '{progress,items}' end), 0);
    when 'chars' then n := coalesce(jsonb_array_length(case when jsonb_typeof(d -> 'unlocked') = 'array' then d -> 'unlocked' end), 1);
    when 'coins' then n := public.nx_int(d, '{coins}');
    else n := 0;
    end case;
    return n;
end $$;

-- Lee (y bloquea) la partida normal; si no existe, la crea con el inicio normal.
create or replace function public.nx_lock_main(uid uuid) returns public.nx_saves
language plpgsql security definer set search_path = public as $$
declare r public.nx_saves;
begin
    select * into r from public.nx_saves where user_id = uid and slot = 'main' for update;
    if not found then
        insert into public.nx_saves (user_id, slot, data) values (uid, 'main', public.nx_default_save()) returning * into r;
    end if;
    return r;
end $$;

-- ---------------------------------------------------------------- funciones que usa el juego
-- ¿Está libre este nombre de usuario? (para el formulario de registro)
create or replace function public.nx_username_available(p_username text) returns boolean
language sql stable security definer set search_path = public as $$
    select p_username ~ '^[A-Za-z0-9_]{3,16}$' and not exists (select 1 from public.nx_profiles where lower(username) = lower(p_username));
$$;

-- Mi perfil: nombre, correo y rol (el rol lo decide el servidor).
create or replace function public.nx_my_profile() returns jsonb
language sql stable security definer set search_path = public as $$
    select jsonb_build_object('id', p.id, 'username', p.username, 'role', case when public.nx_is_admin() then 'admin' else 'player' end, 'email', u.email, 'created_at', p.created_at)
    from public.nx_profiles p join auth.users u on u.id = p.id where p.id = public.nx_uid();
$$;

-- Cargar una partida ('main' o 'test'; 'test' solo para admin).
create or replace function public.nx_load(p_slot text default 'main') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r public.nx_saves; uid uuid := public.nx_uid();
begin
    if p_slot = 'test' and not public.nx_is_admin() then raise exception 'NX:no_admin'; end if;
    if p_slot not in ('main', 'test') then raise exception 'NX:slot_invalido'; end if;
    select * into r from public.nx_saves where user_id = uid and slot = p_slot;
    if not found then return null; end if;
    return jsonb_build_object('data', r.data, 'version', r.version, 'updated_at', r.updated_at);
end $$;

-- Guardar. p_base = la versión que el juego cargó; si otro dispositivo guardó
-- después, responde conflict:true con la partida más reciente (no la pisa).
create or replace function public.nx_save(p_slot text, p_data jsonb, p_base integer default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.nx_uid(); r public.nx_saves; d jsonb;
begin
    if p_slot not in ('main', 'test') then raise exception 'NX:slot_invalido'; end if;
    if p_slot = 'test' and not public.nx_is_admin() then raise exception 'NX:no_admin'; end if;
    if octet_length(p_data::text) > 400000 then raise exception 'NX:demasiado_grande'; end if;
    select * into r from public.nx_saves where user_id = uid and slot = p_slot for update;
    if found and p_base is not null and p_base <> r.version then
        return jsonb_build_object('ok', false, 'conflict', true, 'data', r.data, 'version', r.version, 'updated_at', r.updated_at);
    end if;
    if p_slot = 'main' then d := public.nx_sanitize(p_data, coalesce(r.data, public.nx_default_save()), uid, r.updated_at, 3000, 150, coalesce(r.gem_bonus, 0));
    else d := p_data; end if;                                      -- la partida de pruebas del admin no se limita
    if found then
        update public.nx_saves set data = d, version = version + 1, updated_at = now() where user_id = uid and slot = p_slot returning * into r;
    else
        insert into public.nx_saves (user_id, slot, data) values (uid, p_slot, d) returning * into r;
    end if;
    return jsonb_build_object('ok', true, 'data', r.data, 'version', r.version, 'updated_at', r.updated_at, 'adjusted', d <> p_data);
end $$;

-- Pasar la partida de invitado de este dispositivo a la cuenta (solo si la cuenta aún no tiene partida).
create or replace function public.nx_import_guest(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.nx_uid(); d jsonb; r public.nx_saves;
begin
    if exists (select 1 from public.nx_saves where user_id = uid and slot = 'main') then raise exception 'NX:ya_tiene_partida'; end if;
    if octet_length(p_data::text) > 400000 then raise exception 'NX:demasiado_grande'; end if;
    -- lo que traía el invitado se acepta con límites (los diamantes, los personajes de diamantes
    -- y lo de solo tienda no se traen: eso solo se consigue comprando)
    d := public.nx_sanitize(p_data, public.nx_default_save(), uid, now() - interval '30 days', 20000, 0, 0);
    insert into public.nx_saves (user_id, slot, data) values (uid, 'main', d) returning * into r;
    return jsonb_build_object('ok', true, 'data', r.data, 'version', r.version, 'updated_at', r.updated_at, 'adjusted', d <> p_data);
end $$;

-- Comprar un objeto de la tienda (partida normal). Revisa precio, saldo y si ya lo tienes.
create or replace function public.nx_buy_item(p_item text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.nx_uid(); r public.nx_saves; s public.nx_shop; d jsonb; have integer;
begin
    select * into s from public.nx_shop where id = p_item;
    if not found then raise exception 'NX:no_esta_en_tienda'; end if;
    r := public.nx_lock_main(uid); d := r.data;
    if p_item = any (public.nx_owned(d)) then raise exception 'NX:ya_lo_tienes'; end if;
    if s.gems > 0 then
        have := public.nx_int(d, '{gems}');
        if have < s.gems then raise exception 'NX:faltan:gems:%', s.gems - have; end if;
        d := jsonb_set(d, '{gems}', to_jsonb(have - s.gems));
    else
        have := public.nx_int(d, '{coins}');
        if have < s.coins then raise exception 'NX:faltan:coins:%', s.coins - have; end if;
        d := jsonb_set(d, '{coins}', to_jsonb(have - s.coins));
    end if;
    d := jsonb_set(d, '{inventory}', coalesce(case when jsonb_typeof(d -> 'inventory') = 'array' then d -> 'inventory' end, '[]') || jsonb_build_array(jsonb_build_object('id', p_item, 'qty', 1)));
    d := jsonb_set(d, '{progress}', coalesce(case when jsonb_typeof(d -> 'progress') = 'object' then d -> 'progress' end, '{}'));
    if not coalesce((d #> '{progress,items}') ? p_item, false) then
        d := jsonb_set(d, '{progress,items}', coalesce(case when jsonb_typeof(d #> '{progress,items}') = 'array' then d #> '{progress,items}' end, '[]') || to_jsonb(p_item));
    end if;
    update public.nx_saves set data = d, version = version + 1, updated_at = now() where user_id = uid and slot = 'main' returning * into r;
    insert into public.nx_purchases (user_id, slot, kind, item, coins, gems) values (uid, 'main', 'item', p_item, s.coins, s.gems);
    return jsonb_build_object('ok', true, 'data', r.data, 'version', r.version, 'updated_at', r.updated_at);
end $$;

-- Comprar un personaje (Nyx y Fenrir con monedas · los especiales con diamantes).
create or replace function public.nx_buy_char(p_char text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.nx_uid(); r public.nx_saves; c public.nx_chars; d jsonb; have integer;
begin
    select * into c from public.nx_chars where id = p_char;
    if not found then raise exception 'NX:no_se_vende'; end if;
    r := public.nx_lock_main(uid); d := r.data;
    if coalesce((d -> 'unlocked') ? p_char, false) then raise exception 'NX:ya_lo_tienes'; end if;
    if c.gems > 0 then
        have := public.nx_int(d, '{gems}');
        if have < c.gems then raise exception 'NX:faltan:gems:%', c.gems - have; end if;
        d := jsonb_set(d, '{gems}', to_jsonb(have - c.gems));
    else
        have := public.nx_int(d, '{coins}');
        if have < c.coins then raise exception 'NX:faltan:coins:%', c.coins - have; end if;
        d := jsonb_set(d, '{coins}', to_jsonb(have - c.coins));
    end if;
    d := jsonb_set(d, '{unlocked}', coalesce(case when jsonb_typeof(d -> 'unlocked') = 'array' then d -> 'unlocked' end, '["zarek"]') || to_jsonb(p_char));
    update public.nx_saves set data = d, version = version + 1, updated_at = now() where user_id = uid and slot = 'main' returning * into r;
    insert into public.nx_purchases (user_id, slot, kind, item, coins, gems) values (uid, 'main', 'char', p_char, c.coins, c.gems);
    return jsonb_build_object('ok', true, 'data', r.data, 'version', r.version, 'updated_at', r.updated_at);
end $$;

-- Reclamar el premio de un logro (se comprueba con la partida guardada en el servidor).
create or replace function public.nx_claim(p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.nx_uid(); r public.nx_saves; a public.nx_achievements; d jsonb;
begin
    select * into a from public.nx_achievements where id = p_id;
    if not found then raise exception 'NX:logro_desconocido'; end if;
    r := public.nx_lock_main(uid); d := r.data;
    if coalesce((d #> '{progress,claimed}') ? p_id, false) then raise exception 'NX:ya_reclamado'; end if;
    if public.nx_stat(d, a.stat) < a.goal then raise exception 'NX:logro_incompleto'; end if;
    d := jsonb_set(d, '{coins}', to_jsonb(public.nx_int(d, '{coins}') + a.coins));
    d := jsonb_set(d, '{gems}', to_jsonb(public.nx_int(d, '{gems}') + a.gems));
    d := jsonb_set(d, '{progress}', coalesce(case when jsonb_typeof(d -> 'progress') = 'object' then d -> 'progress' end, '{}'));
    d := jsonb_set(d, '{progress,claimed}', coalesce(case when jsonb_typeof(d #> '{progress,claimed}') = 'array' then d #> '{progress,claimed}' end, '[]') || to_jsonb(p_id));
    update public.nx_saves set data = d, version = version + 1, updated_at = now() where user_id = uid and slot = 'main' returning * into r;
    insert into public.nx_purchases (user_id, slot, kind, item, coins, gems) values (uid, 'main', 'logro', p_id, -a.coins, -a.gems);
    return jsonb_build_object('ok', true, 'data', r.data, 'version', r.version, 'updated_at', r.updated_at);
end $$;

-- ADMIN: registrar una compra de prueba (no cobra nada, queda marcada como prueba).
create or replace function public.nx_log_test_purchase(p_kind text, p_item text, p_coins integer, p_gems integer) returns void
language plpgsql security definer set search_path = public as $$
begin
    if not public.nx_is_admin() then raise exception 'NX:no_admin'; end if;
    insert into public.nx_purchases (user_id, slot, kind, item, coins, gems, is_test) values (public.nx_uid(), 'test', left(p_kind, 20), left(p_item, 60), p_coins, p_gems, true);
end $$;

-- ADMIN: borrar SOLO su propia partida de pruebas.
create or replace function public.nx_reset_test() returns void
language plpgsql security definer set search_path = public as $$
begin
    if not public.nx_is_admin() then raise exception 'NX:no_admin'; end if;
    delete from public.nx_saves where user_id = public.nx_uid() and slot = 'test';
end $$;

-- ADMIN: resumen de su progreso (partida normal y de pruebas) y de sus compras de prueba.
create or replace function public.nx_admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := public.nx_uid();
begin
    if not public.nx_is_admin() then raise exception 'NX:no_admin'; end if;
    return jsonb_build_object(
        'saves', (select coalesce(jsonb_agg(jsonb_build_object('slot', slot, 'version', version, 'updated_at', updated_at,
                    'coins', data -> 'coins', 'gems', data -> 'gems', 'level', data -> 'level', 'unlocked', data -> 'unlocked')), '[]') from public.nx_saves where user_id = uid),
        'test_purchases', (select count(*) from public.nx_purchases where user_id = uid and is_test),
        'players', (select count(*) from public.nx_profiles));
end $$;

-- Solo los usuarios con sesión pueden llamar a las funciones (el registro usa nx_username_available).
revoke execute on function public.nx_uid(), public.nx_is_admin(), public.nx_default_save(), public.nx_owned(jsonb), public.nx_strip(jsonb, text[]),
    public.nx_int(jsonb, text[], integer), public.nx_sanitize(jsonb, jsonb, uuid, timestamptz, integer, integer, integer), public.nx_stat(jsonb, text), public.nx_lock_main(uuid),
    public.nx_handle_new_user(), public.nx_username_available(text), public.nx_my_profile(), public.nx_load(text), public.nx_save(text, jsonb, integer),
    public.nx_import_guest(jsonb), public.nx_buy_item(text), public.nx_buy_char(text), public.nx_claim(text),
    public.nx_log_test_purchase(text, text, integer, integer), public.nx_reset_test(), public.nx_admin_overview() from public, anon;
grant execute on function public.nx_username_available(text) to anon, authenticated;
grant execute on function public.nx_my_profile(), public.nx_load(text), public.nx_save(text, jsonb, integer), public.nx_import_guest(jsonb),
    public.nx_buy_item(text), public.nx_buy_char(text), public.nx_claim(text), public.nx_log_test_purchase(text, text, integer, integer),
    public.nx_reset_test(), public.nx_admin_overview() to authenticated;
-- las ayudas internas no se llaman desde el juego
revoke execute on function public.nx_sanitize(jsonb, jsonb, uuid, timestamptz, integer, integer, integer), public.nx_strip(jsonb, text[]), public.nx_lock_main(uuid),
    public.nx_handle_new_user() from authenticated;

-- ======================================================================
-- ADMIN · tu correo de administradora (una sola vez, desde el panel de Supabase):
--   En SQL Editor ejecuta, con TU correo (el mismo con el que creas la cuenta en el juego):
--        insert into public.nx_admin_emails (email) values ('tu_correo@ejemplo.com') on conflict do nothing;
--   Desde ese momento, al entrar con ese correo eres administradora (no hace falta nada más).
--   Para quitarlo:  delete from public.nx_admin_emails where email = 'tu_correo@ejemplo.com';
-- ======================================================================
