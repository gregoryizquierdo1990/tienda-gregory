-- ==============================================================================
-- MIGRACIÓN 58: ENTREGA AUTOMÁTICA E INSTANTÁNEA CON SALDO ZENYPOINTS
-- 1. Si el cliente o revendedor cubre el 100% del pedido con ZenyPoints (o Tarjeta Zeny),
--    la entrega de credenciales se realiza de inmediato en 0 segundos vía _deliver(o).
-- 2. El revendedor recibe el perfil automáticamente asignado a su nombre y vendedor_id.
-- 3. Las renovaciones con Zeny continúan extendiéndose +30 días de forma automática.
-- ==============================================================================

-- 1. Actualizar _deliver para gestionar perfiles reservados en compras nuevas y renovaciones
CREATE OR REPLACE FUNCTION public._deliver(p_order uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  o public.orders;
  pr public.products;
  pf uuid;
  st text;
  v_cur_vence date;
  v_new_vence date;
  v_duracion int := 30;
  v_is_renewal boolean := false;
  v_reseller_name text;
begin
  -- 1. Bloquear y validar orden
  select * into o from public.orders where id = p_order for update;
  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if o.estado not in ('pendiente', 'pagado', 'vencido') then
    raise exception 'Estado de pedido inválido para entrega: %', o.estado;
  end if;

  -- 2. Obtener producto y duración
  select * into pr from public.products where id = o.product_id;
  v_duracion := coalesce(pr.duracion_dias, 30);

  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    pf := o.profile_id;

    -- CASO A: El pedido ya trae un perfil asignado (es una renovación o perfil reservado al comprar)
    if pf is not null then
      select estado, vence into st, v_cur_vence
      from public.profiles_inventory
      where id = pf for update;

      if st is not null then
        if st = 'vendido' then
          v_is_renewal := true;
          -- Renovación: extender desde la fecha actual o desde hoy si expiró
          if v_cur_vence is not null and v_cur_vence >= current_date then
            v_new_vence := v_cur_vence + v_duracion;
          else
            v_new_vence := current_date + v_duracion;
          end if;
        else
          -- Compra nueva que estaba reservada o disponible
          v_is_renewal := false;
          v_new_vence := current_date + v_duracion;
        end if;

        -- Obtener nombre del vendedor si aplica
        if o.vendedor_id is not null then
          select nombre into v_reseller_name from public.customers where id = o.vendedor_id;
        end if;

        -- Actualizar el perfil existente
        update public.profiles_inventory
        set estado = 'vendido',
            inicia = case when v_is_renewal then coalesce(inicia, current_date) else current_date end,
            vence = v_new_vence,
            assigned_customer_id = coalesce(assigned_customer_id, o.customer_id),
            vendedor_id = coalesce(o.vendedor_id, vendedor_id),
            vendedor = coalesce(o.vendedor_nombre, v_reseller_name, vendedor),
            no_renueva = false,
            no_renueva_reportado_at = null,
            no_renueva_motivo = null
        where id = pf;

        -- Marcar pedidos anteriores entregados de este mismo perfil como vencidos para evitar duplicidad de activo
        update public.orders
        set estado = 'vencido',
            no_renueva = false
        where profile_id = pf
          and id <> p_order
          and estado in ('entregado', 'pagado');
      else
        -- El perfil referenciado no existe en la base de datos
        pf := null;
      end if;
    end if;

    -- CASO B: Compra nueva desde catálogo sin perfil pre-asignado
    if pf is null then
      -- B1: Buscar stock propio de franquicia si aplica
      if o.franchise_id is not null then
        select pi.id into pf
        from public.profiles_inventory pi
        join public.mother_accounts m on m.id = pi.mother_id
        where pi.product_id = o.product_id
          and pi.estado = 'disponible'
          and pi.franchise_id = o.franchise_id
          and coalesce(m.activa, true) is true
          and (m.vence is null or m.vence >= current_date)
        order by pi.id limit 1 for update skip locked;
      end if;

      -- B2: Buscar stock central disponible
      if pf is null then
        select pi.id into pf
        from public.profiles_inventory pi
        join public.mother_accounts m on m.id = pi.mother_id
        where pi.product_id = o.product_id
          and pi.estado = 'disponible'
          and (pi.franchise_id is null or o.franchise_id is null)
          and coalesce(m.activa, true) is true
          and (m.vence is null or m.vence >= current_date)
        order by pi.id limit 1 for update skip locked;
      end if;

      if pf is null then
        raise exception 'Sin stock disponible para % (con cuenta madre activa)', coalesce(pr.nombre, 'Servicio');
      end if;

      v_new_vence := current_date + v_duracion;

      if o.vendedor_id is not null then
        select nombre into v_reseller_name from public.customers where id = o.vendedor_id;
      end if;

      update public.profiles_inventory
      set estado = 'vendido',
          inicia = current_date,
          vence = v_new_vence,
          assigned_customer_id = coalesce(assigned_customer_id, o.customer_id),
          vendedor_id = coalesce(o.vendedor_id, vendedor_id),
          vendedor = coalesce(o.vendedor_nombre, v_reseller_name, vendedor),
          no_renueva = false,
          no_renueva_reportado_at = null,
          no_renueva_motivo = null
      where id = pf;
    end if;
  else
    -- Servicios sin perfiles físicos (gaming, saldo móvil)
    v_new_vence := current_date + v_duracion;
  end if;

  -- 3. Actualizar la orden a entregado con fechas sincronizadas
  update public.orders
  set estado = 'entregado',
      estado_recarga = 'recargado',
      profile_id = pf,
      inicia = coalesce(inicia, current_date),
      vence = coalesce(v_new_vence, vence, current_date + v_duracion),
      proximo_pago = coalesce(v_new_vence, proximo_pago, current_date + v_duracion),
      pagado_at = coalesce(pagado_at, now())
  where id = p_order;

  -- 4. Conciliar saldo Zeny retenido en compra
  update public.zeny_ledger
  set estado = 'aprobado'
  where order_id = p_order and tipo = 'compra' and estado = 'pendiente';

  -- 5. Si tenía cuota inicial en revisión, conciliarla
  update public.installments
  set estado = 'pagada',
      pagada_at = coalesce(pagada_at, now())
  where order_id = p_order and numero_cuota = 1 and estado = 'en_revision';

  -- 6. Emitir factura cuadrada
  insert into public.invoices(order_id, customer_id, total_usd, total_bs, tasa_bs, estado, franchise_id)
  select id, customer_id, total_usd, total_bs, tasa_bs, 'emitida', franchise_id
  from public.orders where id = p_order
  on conflict (order_id) do nothing;
end;
$function$;

-- 2. Actualizar create_order para entregar automáticamente cuando el pago sea 100% Zeny
CREATE OR REPLACE FUNCTION public.create_order(
  p_product uuid,
  p_metodo uuid DEFAULT NULL::uuid,
  p_ref text DEFAULT NULL::text,
  p_zeny numeric DEFAULT 0,
  p_datos_recarga jsonb DEFAULT '{}'::jsonb,
  p_es_cuotas boolean DEFAULT false,
  p_franchise_id uuid DEFAULT NULL::uuid
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
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
  v_buyer_name text;
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

  -- 0. PROTECCIÓN MODO DEMOSTRACIÓN:
  select coalesce(es_demo, false) into is_demo_user from public.customers where id = auth.uid();
  if is_demo_user then
    raise exception '🔒 MODO DEMOSTRACIÓN: Has llegado al paso final de la compra. En una cuenta regular el servicio se entregaría de inmediato. Las órdenes reales están desactivadas para cuentas de prueba.';
  end if;

  perform release_expired();

  -- Validación de Franquicia y Kill-Switch
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

  select coalesce(es_revendedor, false), coalesce(limite_credito, 30.00), nombre
    into is_res, v_limite, v_buyer_name
  from public.customers where id = auth.uid();

  if p_metodo is not null then
    select * into pm from public.payment_methods where id = p_metodo;
  end if;

  -- 1. Determinar precio base (Revendedor prevalece sobre Binance)
  if is_res and not coalesce(pr.es_exclusivo_central, false) and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  elsif (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  -- 2. Descuento oficial de Tarjeta Zeny
  select descuento_porcentaje into v_card_desc
  from public.zeny_cards
  where customer_id = auth.uid() and estado = 'activa'
  limit 1;

  if v_card_desc is not null and v_card_desc > 0 then
    eff_price := round(eff_price * (1.0 - (v_card_desc / 100.0)), 2);
  end if;

  -- 3. Financiamiento en Cuotas (BNPL)
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

  -- 4. Validar saldo Zeny aplicado
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
      raise exception 'Saldo Zeny insuficiente. Tu saldo disponible es $% ZP', greatest(0, coalesce(bal, 0) - holds);
    end if;
  end if;

  -- 5. Asignar perfil con cuenta madre activa y no vencida
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

  -- 6. Insertar el Pedido (con asignación de revendedor si aplica)
  insert into public.orders(
    customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs,
    metodo_id, referencia, estado, zeny_aplicado, datos_recarga, franchise_id,
    vendedor_id, vendedor_nombre
  )
  values (
    auth.uid(), p_product, pf, v_order_total, rate, round(v_order_total * coalesce(rate, 0), 2),
    p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z, coalesce(p_datos_recarga, '{}'::jsonb), p_franchise_id,
    case when is_res then auth.uid() else null end,
    case when is_res then v_buyer_name else null end
  )
  returning id into o;

  -- 7. Registro de movimiento Zeny
  if z > 0 then
    insert into public.zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retención pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  -- 8. Si es compra financiada, generar las cuotas
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

  -- 9. ENTREGA AUTOMÁTICA EN 0 SEGUNDOS:
  -- Si el pedido fue pagado al 100% con saldo Zeny (sin financiamiento bancario pendiente),
  -- se entrega de inmediato, descontando el saldo y asignando credenciales en vivo.
  if not p_es_cuotas and z >= v_order_total then
    perform public._deliver(o);
  end if;

  return o;
end $function$;

grant execute on function public._deliver(uuid) to authenticated, anon;
grant execute on function public.create_order(uuid, uuid, text, numeric, jsonb, boolean, uuid) to authenticated;
