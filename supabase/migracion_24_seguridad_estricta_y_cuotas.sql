-- ==============================================================================
-- Migración 24: Blindaje Estricto de Seguridad y Cálculo Server-Side de Cuotas
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. VERIFICACIÓN ESTRICTA DE SESIÓN GOOGLE PARA ADMINISTRADORES
-- ------------------------------------------------------------------------------
create table if not exists admins (email text primary key);
insert into admins (email) values
  ('emprendimientogregoryizquierdo@gmail.com'),
  ('gregoryizquierdo1990@gmail.com')
on conflict (email) do nothing;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from admins
    where lower(admins.email) = lower(auth.jwt()->>'email')
  )
  and (
    coalesce(auth.jwt()->'app_metadata'->>'provider', '') = 'google'
    or exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method' in ('oauth', 'google'))
    or coalesce(auth.jwt()->>'iss', '') like '%google%'
  );
$$;

revoke execute on function is_admin() from public, anon;
grant execute on function is_admin() to authenticated;


-- ------------------------------------------------------------------------------
-- 2. BLINDAJE DE DATOS DE FRANQUICIADOS PÚBLICOS
-- ------------------------------------------------------------------------------
drop policy if exists franchises_public_select on franchises;

drop policy if exists franchises_admin on franchises;
create policy franchises_admin on franchises for all to authenticated
  using (is_admin()) with check (is_admin());

create or replace view public_franchises with (security_invoker = false) as
  select
    id,
    subdominio,
    nombre_comercial,
    titular_nombre,
    titular_telefono,
    titular_correo,
    logo_url,
    color_primario,
    estado
  from franchises
  where estado = 'activo';

grant select on public_franchises to anon, authenticated;


-- ------------------------------------------------------------------------------
-- 3. TRIGGER DE AUTO-ASCENSO EN CUSTOMERS: SOLO PERMITIR MODIFICAR NOMBRE Y TELÉFONO
-- ------------------------------------------------------------------------------
create or replace function protect_customer_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    new.id := old.id;
    new.email := old.email;
    new.zeny_balance := old.zeny_balance;
    new.limite_credito := old.limite_credito;
    new.nivel_credito := old.nivel_credito;
    new.es_revendedor := old.es_revendedor;
    new.codigo_identificacion := old.codigo_identificacion;
    new.creado := old.creado;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_customer_financial_fields on customers;
drop trigger if exists trg_protect_customer_fields on customers;

create trigger trg_protect_customer_fields
before update on customers
for each row
execute function protect_customer_fields();


-- ------------------------------------------------------------------------------
-- 4. POLÍTICAS RLS EN TABLA INSTALLMENTS (CUOTAS)
-- ------------------------------------------------------------------------------
alter table installments enable row level security;

drop policy if exists installments_user_select on installments;
create policy installments_user_select on installments for select to authenticated
  using (customer_id = (select auth.uid()) or is_admin());

drop policy if exists installments_admin_all on installments;
create policy installments_admin_all on installments for all to authenticated
  using (is_admin()) with check (is_admin());


-- ------------------------------------------------------------------------------
-- 5. FUNCIÓN MAESTRA create_order: CÁLCULO SERVER-SIDE TOTAL
-- ------------------------------------------------------------------------------
drop function if exists create_order(uuid, uuid, text, numeric);
drop function if exists create_order(uuid, uuid, text, numeric, jsonb);
drop function if exists create_order(uuid, uuid, text, numeric, jsonb, boolean);

create or replace function create_order(
  p_product uuid,
  p_metodo uuid default null,
  p_ref text default null,
  p_zeny numeric default 0,
  p_datos_recarga jsonb default '{}',
  p_es_cuotas boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  pr products;
  pf uuid;
  o uuid;
  rate numeric;
  bal numeric;
  holds numeric;
  z numeric := coalesce(p_zeny, 0);
  pm payment_methods;
  eff_price numeric;
  is_res boolean := false;
  has_active_card boolean := false;
  v_limite numeric := 30.00;
  v_credito_usado numeric := 0;
  v_cuota_1 numeric;
  v_cuota_2 numeric;
  v_order_total numeric;
begin
  if auth.uid() is null then raise exception 'Inicia sesion primero'; end if;
  perform release_expired();

  select * into pr from products where id = p_product and activo;
  if not found then raise exception 'Producto no disponible o inactivo'; end if;

  select coalesce(es_revendedor, false), coalesce(limite_credito, 30.00)
    into is_res, v_limite
  from customers where id = auth.uid();

  if p_metodo is not null then
    select * into pm from payment_methods where id = p_metodo;
  end if;

  -- 1. Determinar precio base (Binance, Revendedor o Minorista)
  if (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  elsif not pr.es_exclusivo_central and is_res and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  -- 2. Descuento del 5% de Tarjeta Zeny si el cliente la tiene activa
  select exists (
    select 1 from zeny_cards
    where customer_id = auth.uid() and estado = 'activa'
  ) into has_active_card;

  if has_active_card then
    eff_price := round(eff_price * 0.95, 2);
  end if;

  -- 3. Lógica de Financiamiento en Cuotas (BNPL)
  if p_es_cuotas then
    if not pr.permite_cuotas then
      raise exception 'Este servicio no permite financiamiento en cuotas';
    end if;

    -- Bloqueo si tiene cuotas vencidas
    if exists (
      select 1 from installments
      where customer_id = auth.uid()
        and (estado = 'vencida' or (estado = 'pendiente' and fecha_vencimiento < current_date))
    ) then
      raise exception 'Tienes cuotas vencidas pendientes. Debes ponerte al día para solicitar un nuevo financiamiento.';
    end if;

    -- Calcular crédito actualmente comprometido
    select coalesce(sum(monto_usd), 0) into v_credito_usado
    from installments
    where customer_id = auth.uid() and estado in ('pendiente', 'en_revision');

    -- Cuota inicial 50% y cuota 2 (saldo a 15 días)
    v_cuota_1 := round(eff_price * 0.50, 2);
    v_cuota_2 := eff_price - v_cuota_1;

    if (v_credito_usado + v_cuota_2) > v_limite then
      raise exception 'El monto a financiar ($%) excede tu límite de crédito disponible ($%)',
        v_cuota_2, greatest(0, v_limite - v_credito_usado);
    end if;

    v_order_total := v_cuota_1;
  else
    v_order_total := eff_price;
  end if;

  -- 4. Validar saldo Zeny aplicado
  if z < 0 or z > v_order_total then raise exception 'Monto Zeny invalido'; end if;
  if z < v_order_total and p_metodo is null then raise exception 'Elige un metodo de pago para el resto'; end if;

  if z > 0 then
    select zeny_balance into bal from customers where id = auth.uid() for update;
    select coalesce(sum(-monto), 0) into holds from zeny_ledger where customer_id = auth.uid() and tipo = 'compra' and estado = 'pendiente';
    if z > coalesce(bal,0) - holds then raise exception 'Saldo Zeny insuficiente'; end if;
  end if;

  -- 5. Asignar perfil si es servicio de streaming con inventario
  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    select id into pf from profiles_inventory where product_id = p_product and estado = 'disponible' order by id limit 1 for update skip locked;
    if pf is null then raise exception 'Agotado'; end if;
    update profiles_inventory set estado = 'reservado' where id = pf;
  end if;

  select bs_por_usd into rate from exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal','1',true);

  -- 6. Insertar el Pedido
  insert into orders(
    customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, metodo_id, referencia, estado, zeny_aplicado, datos_recarga
  )
  values (
    auth.uid(), p_product, pf, v_order_total, rate, v_order_total * coalesce(rate, 0), p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z, coalesce(p_datos_recarga, '{}'::jsonb)
  )
  returning id into o;

  -- 7. Retención Zeny si aplica
  if z > 0 then
    insert into zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retencion pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  -- 8. Si es compra financiada, generar las cuotas directamente en el servidor
  if p_es_cuotas then
    -- Cuota 1 (Inicial)
    insert into installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs, fecha_vencimiento, estado, metodo_id, referencia
    ) values (
      o, auth.uid(), 1, 2, v_cuota_1, rate, v_cuota_1 * coalesce(rate, 0), current_date,
      case when z >= v_cuota_1 then 'pagada' else 'en_revision' end,
      p_metodo, left(coalesce(p_ref,''), 120)
    );

    -- Cuota 2 (Financiada a 15 días)
    insert into installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs, fecha_vencimiento, estado
    ) values (
      o, auth.uid(), 2, 2, v_cuota_2, rate, v_cuota_2 * coalesce(rate, 0), (current_date + interval '15 days')::date, 'pendiente'
    );
  end if;

  return o;
end $$;

-- Sobrecargas para compatibilidad
create or replace function create_order(
  p_product uuid,
  p_metodo uuid,
  p_ref text,
  p_zeny numeric,
  p_datos_recarga jsonb
) returns uuid language sql security definer set search_path = public as $$
  select create_order(p_product, p_metodo, p_ref, p_zeny, p_datos_recarga, false);
$$;

create or replace function create_order(
  p_product uuid,
  p_metodo uuid,
  p_ref text,
  p_zeny numeric
) returns uuid language sql security definer set search_path = public as $$
  select create_order(p_product, p_metodo, p_ref, p_zeny, '{}'::jsonb, false);
$$;

revoke execute on function create_order(uuid,uuid,text,numeric,jsonb,boolean) from public, anon;
grant execute on function create_order(uuid,uuid,text,numeric,jsonb,boolean) to authenticated;
grant execute on function create_order(uuid,uuid,text,numeric,jsonb) to authenticated;
grant execute on function create_order(uuid,uuid,text,numeric) to authenticated;


-- ------------------------------------------------------------------------------
-- 6. MARCAR CUOTAS VENCIDAS (CRON / AUTOMATIZACIÓN)
-- ------------------------------------------------------------------------------
create or replace function check_overdue_installments()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_count int := 0;
begin
  update installments
  set estado = 'vencida'
  where estado = 'pendiente'
    and fecha_vencimiento < current_date;
  get diagnostics v_count = row_count;
  return jsonb_build_object('success', true, 'cuotas_vencidas', v_count);
end;
$$;

grant execute on function check_overdue_installments() to authenticated;


-- ------------------------------------------------------------------------------
-- 7. CÓDIGO DE ACTIVACIÓN DE TARJETA ZENY: OCULTO POR DEFECTO HASTA ACTIVAR
-- ------------------------------------------------------------------------------
create or replace view my_zeny_cards as
  select
    id,
    customer_id,
    numero_tarjeta,
    nombre_titular,
    fecha_vencimiento,
    estado,
    descuento_porcentaje,
    activada_at,
    created_at,
    case
      when is_admin() then codigo_activacion
      when estado = 'activa' then codigo_activacion
      else '***'
    end as codigo_activacion
  from zeny_cards;

grant select on my_zeny_cards to authenticated;

create or replace function activate_zeny_card(p_numero text, p_codigo text)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  card zeny_cards;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión primero';
  end if;
  select * into card from zeny_cards where customer_id = auth.uid() for update;
  if not found then
    raise exception 'No tienes una tarjeta asignada';
  end if;
  if card.estado = 'activa' then
    raise exception 'Tu tarjeta ya se encuentra activa';
  end if;
  if replace(card.numero_tarjeta, ' ', '') <> replace(p_numero, ' ', '') or card.codigo_activacion <> trim(p_codigo) then
    raise exception 'Código de activación incorrecto. Solicita tu código al administrador por WhatsApp.';
  end if;
  update zeny_cards set estado = 'activa', activada_at = coalesce(activada_at, now()) where id = card.id;
end;
$fn$;

grant execute on function activate_zeny_card(text, text) to authenticated;
