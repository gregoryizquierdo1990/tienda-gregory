-- Traslados de clientes entre cuentas + generador de perfiles
-- (Ya incluido al final de schema.sql. Ejecuta este archivo SOLO si ya habías corrido el esquema anterior.)
create table if not exists transfers (
  id uuid primary key default gen_random_uuid(), order_id uuid references orders, customer_id uuid references customers,
  from_profile uuid references profiles_inventory on delete set null, to_profile uuid references profiles_inventory on delete set null,
  motivo text, created_at timestamptz default now());
alter table transfers enable row level security;
create policy tr_admin on transfers for select to authenticated using (is_admin());

-- Traslada al cliente a otro perfil libre de la MISMA plataforma, conservando sus dias contratados
create or replace function transfer_order(p_order uuid, p_new_profile uuid, p_motivo text, p_liberar_anterior boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; st text; pa text; pb text;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into o from orders where id = p_order for update;
  if not found or o.estado <> 'entregado' or o.profile_id is null then raise exception 'Solo se trasladan pedidos entregados con perfil asignado'; end if;
  if p_new_profile = o.profile_id then raise exception 'Es el mismo perfil'; end if;
  select m.plataforma into pa from profiles_inventory pi join mother_accounts m on m.id = pi.mother_id where pi.id = o.profile_id;
  select pi.estado, m.plataforma into st, pb from profiles_inventory pi join mother_accounts m on m.id = pi.mother_id where pi.id = p_new_profile for update of pi;
  if st is distinct from 'disponible' then raise exception 'El perfil destino no esta disponible'; end if;
  if pa is distinct from pb then raise exception 'El traslado debe ser dentro de la misma plataforma (% / %)', pa, pb; end if;
  update profiles_inventory set estado = 'vendido', inicia = o.inicia, vence = o.vence where id = p_new_profile;
  update profiles_inventory set estado = case when p_liberar_anterior then 'disponible' else 'suspendido' end, inicia = null, vence = null where id = o.profile_id;
  update orders set profile_id = p_new_profile where id = p_order;
  insert into transfers(order_id, customer_id, from_profile, to_profile, motivo) values (p_order, o.customer_id, o.profile_id, p_new_profile, p_motivo);
end $$;

-- Crea N perfiles disponibles para una cuenta madre (respeta max_perfiles)
create or replace function generate_profiles(p_mother uuid, p_product uuid, p_cantidad int, p_prefijo text default 'Perfil') returns int
language plpgsql security definer set search_path = public as $$
declare m mother_accounts; ya int; i int;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into m from mother_accounts where id = p_mother; if not found then raise exception 'Cuenta no existe'; end if;
  select count(*) into ya from profiles_inventory where mother_id = p_mother;
  if p_cantidad < 1 or ya + p_cantidad > coalesce(m.max_perfiles, 5) then raise exception 'Excede el maximo de perfiles de la cuenta (% de %)', ya, m.max_perfiles; end if;
  for i in 1..p_cantidad loop
    insert into profiles_inventory(mother_id, product_id, nombre_perfil, estado) values (p_mother, p_product, p_prefijo || ' ' || (ya + i), 'disponible');
  end loop;
  return p_cantidad;
end $$;

do $$ begin alter publication supabase_realtime add table transfers; exception when duplicate_object then null; end $$;
