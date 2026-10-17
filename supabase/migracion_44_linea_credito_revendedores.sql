-- Migracion 44: Sistema de Línea de Crédito y Cuentas por Pagar para Revendedores
-- Permite que los Revendedores Oficiales (ej. Pablo Gonzalez) vean en su portal su línea de crédito ($30 USD),
-- sus cuentas por pagar por perfiles entregados a crédito (Fernisbel $4.50, Evert $7.00, Tony $4.50),
-- y puedan saldar sus deudas con Saldo Zeny o reportando Pago Móvil/Transferencia a Gregory.

-- 1. Agregar columna reseller_id a installments si no existe
alter table public.installments add column if not exists reseller_id uuid references public.customers(id);
create index if not exists idx_installments_reseller on public.installments(reseller_id, estado);

-- 2. Actualizar políticas RLS de installments para que el revendedor pueda ver sus cuotas/deudas
drop policy if exists installments_user_select on public.installments;
create policy installments_user_select on public.installments for select to authenticated
  using (customer_id = auth.uid() or reseller_id = auth.uid() or is_admin());

-- 3. Vincular las deudas iniciales de crédito a Pablo González y futuros revendedores
do $$
declare
  v_pablo_id uuid;
  v_rate numeric := 1;
begin
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  -- Localizar a Pablo González
  select id into v_pablo_id from public.customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or codigo_identificacion in ('PABLO', 'RVD:1001')
     or lower(trim(nombre)) like '%pablo gonzalez%'
  limit 1;

  if v_pablo_id is not null then
    -- Asegurar límite de crédito en $30.00 USD para Pablo
    update public.customers set
      limite_credito = 30.00,
      es_revendedor = true,
      codigo_identificacion = coalesce(nullif(codigo_identificacion, ''), 'RVD:1001')
    where id = v_pablo_id;

    -- Vincular pedidos de los 3 clientes de Pablo (Evert, Fernisbel, Tony)
    update public.orders set
      vendedor_id = v_pablo_id
    where lower(referencia) like '%pablo gonzalez%'
       or lower(referencia) like '%[crédito pablo%'
       or customer_id in (
         select id from public.customers
         where lower(nombre) like '%evert%'
            or lower(nombre) like '%fernisbel%'
            or lower(nombre) like '%tony%'
       );

    -- Vincular cuotas en installments para que le pertenezcan como reseller_id
    update public.installments set
      reseller_id = v_pablo_id
    where lower(referencia) like '%pablo gonzalez%'
       or lower(referencia) like '%[crédito pablo%'
       or order_id in (
         select id from public.orders where vendedor_id = v_pablo_id
       );

    -- Asegurar que existan las 3 cuotas exactas de los 3 perfiles si faltara alguna
    -- A. EVERT IZQUIERDO ($7.00 USD)
    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%evert%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      )
      select
        o.id, o.customer_id, v_pablo_id, 1, 1,
        7.00, round(7.00 * v_rate, 2), v_rate, '2026-10-30'::date, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] EVERT IZQUIERDO - NETFLIX ($7.00 USD)'
      from public.orders o
      where o.vendedor_id = v_pablo_id and (lower(o.referencia) like '%evert%' or exists (select 1 from customers c where c.id = o.customer_id and lower(c.nombre) like '%evert%'))
      limit 1;
    end if;

    -- B. FERNISBEL ($4.50 USD)
    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%fernisbel%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      )
      select
        o.id, o.customer_id, v_pablo_id, 1, 1,
        4.50, round(4.50 * v_rate, 2), v_rate, '2026-10-30'::date, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] FERNISBEL - DISNEY ($4.50 USD)'
      from public.orders o
      where o.vendedor_id = v_pablo_id and (lower(o.referencia) like '%fernisbel%' or exists (select 1 from customers c where c.id = o.customer_id and lower(c.nombre) like '%fernisbel%'))
      limit 1;
    end if;

    -- C. TONY MASSIMO ($4.50 USD)
    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%tony%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      )
      select
        o.id, o.customer_id, v_pablo_id, 1, 1,
        4.50, round(4.50 * v_rate, 2), v_rate, '2026-10-30'::date, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] TONY MASSIMO - TELELATINO ($4.50 USD)'
      from public.orders o
      where o.vendedor_id = v_pablo_id and (lower(o.referencia) like '%tony%' or exists (select 1 from customers c where c.id = o.customer_id and lower(c.nombre) like '%tony%'))
      limit 1;
    end if;
  end if;

  -- Para cualquier otra orden a crédito con vendedor_id asignado, asociar reseller_id en installments
  update public.installments i
  set reseller_id = o.vendedor_id
  from public.orders o
  where o.id = i.order_id and o.vendedor_id is not null and i.reseller_id is null;
end $$;

-- 4. RPC: my_reseller_debts()
-- Devuelve las deudas y créditos pendientes del revendedor autenticado
create or replace function public.my_reseller_debts()
returns table (
  id uuid,
  order_id uuid,
  cliente_id uuid,
  cliente_nombre text,
  cliente_telefono text,
  servicio text,
  nombre_perfil text,
  monto_usd numeric,
  monto_bs numeric,
  tasa_bs numeric,
  fecha_vencimiento date,
  estado text,
  referencia text,
  pagada_at timestamptz,
  created_at timestamptz
)
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then return; end if;

  return query
  select distinct
    i.id,
    i.order_id,
    c.id as cliente_id,
    coalesce(c.nombre, 'Cliente Asignado') as cliente_nombre,
    coalesce(c.telefono, '') as cliente_telefono,
    coalesce(p.nombre, m.plataforma, 'Servicio Digital') as servicio,
    coalesce(pi.nombre_perfil, 'Perfil 1') as nombre_perfil,
    i.monto_usd,
    i.monto_bs,
    i.tasa_bs,
    i.fecha_vencimiento,
    i.estado,
    i.referencia,
    i.pagada_at,
    i.created_at
  from public.installments i
  left join public.orders o on o.id = i.order_id
  left join public.customers c on c.id = coalesce(i.customer_id, o.customer_id)
  left join public.products p on p.id = o.product_id
  left join public.profiles_inventory pi on pi.id = o.profile_id
  left join public.mother_accounts m on m.id = pi.mother_id
  where (
    i.reseller_id = v_user_id
    or o.vendedor_id = v_user_id
    or (i.customer_id = v_user_id and exists (select 1 from public.customers cust where cust.id = v_user_id and cust.es_revendedor = true))
  )
  order by (i.estado = 'pendiente') desc, (i.estado = 'en_revision') desc, i.fecha_vencimiento asc;
end;
$$;

revoke execute on function public.my_reseller_debts() from public, anon;
grant execute on function public.my_reseller_debts() to authenticated;

-- 5. RPC: pagar_deuda_revendedor()
-- Permite que un revendedor pague una cuota/deuda a crédito con saldo Zeny o reporte transferencia/pago móvil
create or replace function public.pagar_deuda_revendedor(
  p_installment_id uuid,
  p_metodo text, -- 'zeny' o 'transferencia'
  p_metodo_id uuid default null,
  p_referencia text default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
  v_inst public.installments%rowtype;
  v_zeny_bal numeric(12,2) := 0;
  v_seller_nom text := 'Revendedor';
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para pagar deudas.';
  end if;

  select * into v_inst from public.installments where id = p_installment_id;
  if not found then
    raise exception 'Registro de crédito no encontrado.';
  end if;

  -- Verificar pertenencia
  if not is_admin() and v_inst.reseller_id <> v_user_id and v_inst.customer_id <> v_user_id then
    raise exception 'No estás autorizado para pagar este crédito.';
  end if;

  if v_inst.estado = 'pagada' then
    raise exception 'Esta cuenta por pagar ya fue saldada previamente.';
  end if;

  select nombre into v_seller_nom from public.customers where id = v_user_id;

  if p_metodo = 'zeny' then
    -- Verificar saldo Zeny
    select coalesce(sum(monto), 0) into v_zeny_bal
    from public.zeny_ledger
    where customer_id = v_user_id and estado in ('aprobado', 'completado');

    if v_zeny_bal < v_inst.monto_usd then
      raise exception 'Saldo Zeny insuficiente. Tu saldo es $% USD y el monto a pagar es $% USD.', v_zeny_bal, v_inst.monto_usd;
    end if;

    -- Descontar del zeny_ledger
    insert into public.zeny_ledger (customer_id, tipo, monto, estado, referencia)
    values (v_user_id, 'compra', -v_inst.monto_usd, 'aprobado', 'Pago de Crédito Mayorista: ' || coalesce(v_inst.referencia, 'Cuota'));

    -- Actualizar balance en customers
    update public.customers set zeny_balance = coalesce(zeny_balance, 0) - v_inst.monto_usd where id = v_user_id;

    -- Marcar cuota como pagada
    update public.installments set
      estado = 'pagada',
      pagada_at = now(),
      referencia = coalesce(referencia, '') || ' [PAGADO CON ZENY]'
    where id = p_installment_id;

    -- Actualizar orden si aplica
    if v_inst.order_id is not null then
      update public.orders set
        referencia = coalesce(referencia, '') || ' [CRÉDITO SALDADO ZENY]'
      where id = v_inst.order_id;
    end if;

    return jsonb_build_object(
      'success', true,
      'estado', 'pagada',
      'mensaje', 'Deuda saldada exitosamente con saldo Zeny.'
    );

  elsif p_metodo = 'transferencia' then
    if p_referencia is null or trim(p_referencia) = '' then
      raise exception 'Debes ingresar el número de referencia bancaria.';
    end if;

    update public.installments set
      estado = 'en_revision',
      metodo_id = p_metodo_id,
      referencia = coalesce(referencia, '') || ' [REF PAGO: ' || trim(p_referencia) || ']'
    where id = p_installment_id;

    return jsonb_build_object(
      'success', true,
      'estado', 'en_revision',
      'mensaje', 'Comprobante de pago registrado. Gregory verificará la referencia.'
    );

  else
    raise exception 'Método no soportado (debe ser zeny o transferencia).';
  end if;
end;
$$;

revoke execute on function public.pagar_deuda_revendedor(uuid, text, uuid, text) from public, anon;
grant execute on function public.pagar_deuda_revendedor(uuid, text, uuid, text) to authenticated;
