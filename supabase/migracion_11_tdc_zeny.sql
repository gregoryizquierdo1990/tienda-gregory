-- Migracion 11: Códigos de Identificación Únicos (CLT:001 / RVD:1001), 
-- Tarjetas de Crédito Digitales Zeny (TDC) y Transición de Roles

-- 1. Añadir código de identificación único a la tabla customers
alter table customers add column if not exists codigo_identificacion text unique;

-- 2. Función para obtener el siguiente número disponible (rellena huecos o incrementa)
create or replace function get_next_customer_code(p_es_revendedor boolean)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  prefix text;
  start_num int;
  candidate int;
  code_candidate text;
  exists_code boolean;
begin
  if p_es_revendedor then
    prefix := 'RVD';
    start_num := 1001;
  else
    prefix := 'CLT';
    start_num := 1;
  end if;

  candidate := start_num;
  loop
    if p_es_revendedor then
      code_candidate := prefix || ':' || candidate::text;
    else
      code_candidate := prefix || ':' || lpad(candidate::text, 3, '0');
    end if;

    select exists(select 1 from customers where codigo_identificacion = code_candidate) into exists_code;
    if not exists_code then
      return code_candidate;
    end if;
    candidate := candidate + 1;
  end loop;
end;
$fn$;

-- 3. Actualizar trigger handle_new_user para asignar código automático al registrarse
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  assigned_code text;
begin
  assigned_code := get_next_customer_code(false); -- Por defecto cliente CLT:001
  insert into customers(id, nombre, email, telefono, codigo_identificacion, es_revendedor)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'nombre'),
    new.email,
    coalesce(new.phone, new.raw_user_meta_data->>'telefono'),
    assigned_code,
    false
  ) on conflict (id) do update set
    codigo_identificacion = coalesce(customers.codigo_identificacion, assigned_code);
  return new;
end;
$fn$;

-- 4. Asignar códigos a clientes existentes que aún no tengan uno
do $do$
declare
  r record;
  new_code text;
begin
  for r in select id, coalesce(es_revendedor, false) as es_revendedor from customers where codigo_identificacion is null order by creado asc loop
    new_code := get_next_customer_code(r.es_revendedor);
    update customers set codigo_identificacion = new_code where id = r.id;
  end loop;
end;
$do$;

-- 5. Función para cambiar el rol de usuario (Cliente <-> Revendedor) reasignando el código del otro tipo
create or replace function switch_customer_role(p_customer_id uuid, p_make_reseller boolean)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  new_code text;
begin
  if not is_admin() then
    raise exception 'No autorizado';
  end if;
  new_code := get_next_customer_code(p_make_reseller);
  update customers set 
    es_revendedor = p_make_reseller,
    codigo_identificacion = new_code
  where id = p_customer_id;
  return new_code;
end;
$fn$;
grant execute on function switch_customer_role(uuid, boolean) to authenticated;

-- 6. Tabla de Tarjetas de Crédito Digitales Zeny (TDC)
create table if not exists zeny_cards (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade unique,
  numero_tarjeta text not null unique, -- Ej: 1234 5678 9012 3456
  nombre_titular text not null,        -- Nombre y Apellido grabado en la tarjeta
  codigo_activacion text not null,     -- CVV / Código al reverso (ej: 849)
  fecha_vencimiento text not null default '12/31', -- MM/YY
  estado text not null default 'activa' check (estado in ('activa', 'por_activar', 'bloqueada', 'vencida')),
  descuento_porcentaje numeric(5,2) not null default 5.00, -- 5% de descuento adicional al pagar con la tarjeta
  activada_at timestamptz,
  created_at timestamptz not null default now()
);

-- Indices y RLS para zeny_cards
create index if not exists idx_zeny_cards_customer on zeny_cards(customer_id);
create index if not exists idx_zeny_cards_numero on zeny_cards(numero_tarjeta);

alter table zeny_cards enable row level security;
drop policy if exists zeny_cards_user_select on zeny_cards;
create policy zeny_cards_user_select on zeny_cards for select to authenticated using (customer_id = (select auth.uid()) or is_admin());
drop policy if exists zeny_cards_admin_all on zeny_cards;
create policy zeny_cards_admin_all on zeny_cards for all to authenticated using (is_admin()) with check (is_admin());

-- 7. Función para que el cliente active su tarjeta desde el portal con el código del reverso
create or replace function activate_zeny_card(p_numero text, p_codigo text)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  card zeny_cards;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesion primero';
  end if;
  select * into card from zeny_cards where customer_id = auth.uid() for update;
  if not found then
    raise exception 'No tienes una tarjeta asignada';
  end if;
  if replace(card.numero_tarjeta, ' ', '') <> replace(p_numero, ' ', '') or card.codigo_activacion <> trim(p_codigo) then
    raise exception 'Número de tarjeta o código de activación incorrecto';
  end if;
  update zeny_cards set estado = 'activa', activada_at = coalesce(activada_at, now()) where id = card.id;
end;
$fn$;
grant execute on function activate_zeny_card(text, text) to authenticated;
