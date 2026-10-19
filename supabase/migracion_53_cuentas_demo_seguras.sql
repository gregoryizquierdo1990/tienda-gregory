-- ==============================================================================
-- MIGRACIÓN 53: CREACIÓN DE CUENTAS DEMO SEGURAS Y MODO DEMOSTRACIÓN
-- Crea 2 instancias: Cliente Demo (CLT:DEMO) y Revendedor Demo (RVD:DEMO)
-- Protegidas a nivel de base de datos para no alterar órdenes, saldo o inventario real
-- ==============================================================================

-- 1. Agregar columna es_demo en customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS es_demo boolean DEFAULT false;

-- 2. Asegurar que protect_customer_fields permita cambios del superusuario y service_role
CREATE OR REPLACE FUNCTION public.protect_customer_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if current_user in ('postgres', 'service_role') or is_admin() then
    return new;
  end if;

  new.id := old.id;
  new.email := old.email;
  new.zeny_balance := old.zeny_balance;
  new.limite_credito := old.limite_credito;
  new.nivel_credito := old.nivel_credito;
  new.es_revendedor := old.es_revendedor;
  new.codigo_identificacion := old.codigo_identificacion;
  new.creado := old.creado;
  return new;
end;
$function$;

-- 3. Proteger la función create_order para bloquear compras en cuentas demo
-- (La RPC lanza excepción amigable antes de tocar inventario o registrar órdenes)
CREATE OR REPLACE FUNCTION public.create_order(p_product uuid, p_metodo uuid DEFAULT NULL::uuid, p_ref text DEFAULT NULL::text, p_zeny numeric DEFAULT 0, p_datos_recarga jsonb DEFAULT '{}'::jsonb, p_es_cuotas boolean DEFAULT false, p_franchise_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  pr public.products;
  pf uuid;
  o uuid;
  rate numeric;
  bal numeric;
  holds numeric;
  z numeric := coalesce(p_zeny, 0);
  pm public.payment_methods;
  eff_price numeric;
  is_res boolean := false;
  is_demo_user boolean := false;
  v_card_desc numeric := 0;
  v_limite numeric := 30.00;
  v_credito_usado numeric := 0;
  v_cuota_1 numeric;
  v_cuota_2 numeric;
  v_order_total numeric;
  v_fran_estado text;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión primero';
  end if;

  -- BLOQUEO MODO DEMOSTRACIÓN:
  select coalesce(es_demo, false) into is_demo_user from public.customers where id = auth.uid();
  if is_demo_user then
    raise exception '🔒 MODO DEMOSTRACIÓN: Has llegado al paso final de la compra. En una cuenta regular el servicio se entregaría de inmediato. Las órdenes reales están desactivadas para cuentas de prueba.';
  end if;

  perform release_expired();

  if p_franchise_id is not null then
    select estado into v_fran_estado from public.franchises where id = p_franchise_id;
    if not found then
      raise exception 'Franquicia no encontrada';
    end if;
    if v_fran_estado in ('suspendido_fraude', 'suspendido_mora') then
      raise exception 'Portal de franquicia suspendido temporalmente por la administración Central';
    end if;
  end if;

  select * into pr from public.products where id = p_product and activo;
  if not found then
    raise exception 'Producto no disponible o inactivo';
  end if;

  if p_franchise_id is not null and (pr.es_exclusivo_central or pr.tipo in ('gaming', 'recarga_telefonica')) then
    raise exception 'Este producto es exclusivo de la tienda central';
  end if;

  select coalesce(es_revendedor, false), coalesce(limite_credito, 30.00)
    into is_res, v_limite
  from public.customers where id = auth.uid();

  if p_metodo is not null then
    select * into pm from public.payment_methods where id = p_metodo;
  end if;

  if is_res and not coalesce(pr.es_exclusivo_central, false) and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  elsif (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  select descuento_porcentaje into v_card_desc
  from public.zeny_cards
  where customer_id = auth.uid() and estado = 'activa'
  limit 1;

  if v_card_desc is not null and v_card_desc > 0 then
    eff_price := round(eff_price * (1.0 - (v_card_desc / 100.0)), 2);
  end if;

  if p_es_cuotas then
    if not pr.permite_cuotas then
      raise exception 'Este servicio no permite financiamiento en cuotas';
    end if;

    if exists (
      select 1 from public.installments
      where customer_id = auth.uid()
        and (estado = 'vencida' or (estado = 'pendiente' and fecha_vencimiento < current_date))
    ) then
      raise exception 'Tienes cuotas vencidas pendientes. Debes ponerte al día para solicitar un nuevo financiamiento.';
    end if;

    select coalesce(sum(monto_usd), 0) into v_credito_usado
    from public.installments
    where customer_id = auth.uid() and estado in ('pendiente', 'en_revision');

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

  if z < 0 or z > v_order_total then
    raise exception 'Monto Zeny inválido';
  end if;

  if z < v_order_total and p_metodo is null then
    raise exception 'Elige un método de pago para el monto restante';
  end if;

  if z > 0 then
    select zeny_balance into bal from public.customers where id = auth.uid() for update;
    select coalesce(sum(-monto), 0) into holds
    from public.zeny_ledger
    where customer_id = auth.uid() and tipo = 'compra' and estado = 'pendiente';

    if z > coalesce(bal, 0) - holds then
      raise exception 'Saldo Zeny insuficiente';
    end if;
  end if;

  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    if p_franchise_id is not null then
      select pi.id into pf
      from public.profiles_inventory pi
      join public.mother_accounts m on m.id = pi.mother_id
      where pi.product_id = p_product
        and pi.estado = 'disponible'
        and pi.franchise_id = p_franchise_id
        and coalesce(m.activa, true) is true
        and (m.vence is null or m.vence >= current_date)
      order by pi.id limit 1 for update skip locked;
    end if;

    if pf is null then
      select pi.id into pf
      from public.profiles_inventory pi
      join public.mother_accounts m on m.id = pi.mother_id
      where pi.product_id = p_product
        and pi.estado = 'disponible'
        and (pi.franchise_id is null or p_franchise_id is null)
        and coalesce(m.activa, true) is true
        and (m.vence is null or m.vence >= current_date)
      order by pi.id limit 1 for update skip locked;
    end if;

    if pf is null then
      raise exception 'Agotado (sin inventario disponible con cuenta madre activa)';
    end if;

    update public.profiles_inventory set estado = 'reservado' where id = pf;
  end if;

  select bs_por_usd into rate from public.exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal', '1', true);

  insert into public.orders(
    customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs,
    metodo_id, referencia, estado, zeny_aplicado, datos_recarga, franchise_id
  )
  values (
    auth.uid(), p_product, pf, v_order_total, rate, round(v_order_total * coalesce(rate, 0), 2),
    p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z, coalesce(p_datos_recarga, '{}'::jsonb), p_franchise_id
  )
  returning id into o;

  if z > 0 then
    insert into public.zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retención pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  if p_es_cuotas then
    insert into public.installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs,
      fecha_vencimiento, estado, metodo_id, referencia
    ) values (
      o, auth.uid(), 1, 2, v_cuota_1, rate, round(v_cuota_1 * coalesce(rate, 0), 2), current_date,
      case when z >= v_cuota_1 then 'pagada' else 'en_revision' end,
      p_metodo, left(coalesce(p_ref,''), 120)
    );

    insert into public.installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs,
      fecha_vencimiento, estado
    ) values (
      o, auth.uid(), 2, 2, v_cuota_2, rate, round(v_cuota_2 * coalesce(rate, 0), 2),
      (current_date + interval '15 days')::date, 'pendiente'
    );
  end if;

  return o;
end $function$;
