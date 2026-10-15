-- ==============================================================================
-- Migración 30: Consolidación Integral del Sistema Gregory Izquierdo
-- 1. Corrección definitiva del error created_at -> creado en tabla customers
-- 2. Asignación oficial de Códigos RVD (RVD:1001 a RVD:1004) y fusión del duplicado 'PABLO'
-- 3. Limpieza de Tarjetas Zeny (CERO tarjetas en circulación por defecto)
-- 4. Desactivación de cuotas masiva en todos los productos (permite_cuotas = false)
-- 5. Clientes y Revendedores con límite de crédito $0 por defecto
-- 6. Creación de tabla mesa_cambio_caja (Fondo de Liquidez USDT)
-- 7. Aplicación oficial de los 3 Créditos (Evert, Fernisbel, Tony Massimo al 30/10/2026)
-- ==============================================================================

-- 1. Garantizar columnas necesarias en customers
alter table customers add column if not exists es_revendedor boolean default false;
alter table customers add column if not exists codigo_identificacion text;
alter table customers add column if not exists limite_credito numeric(12,2) default 0.00;
alter table customers add column if not exists vendedor_id uuid;
alter table customers add column if not exists vendedor_nombre text;
alter table customers alter column limite_credito set default 0.00;

-- 2. Garantizar columnas en products
alter table products add column if not exists permite_cuotas boolean default false;
alter table products add column if not exists precio_binance_usd numeric(10,2);
alter table products add column if not exists precio_revendedor_usd numeric(10,2);

-- 3. Función get_next_customer_code autocontenida
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

-- A. Limpieza de Tarjetas en Circulación (Regla: CERO tarjetas hasta que se soliciten)
delete from zeny_cards;

-- B. Apagar financiamiento en cuotas en todos los productos por defecto
update products set permite_cuotas = false;

-- C. Estructura para el Fondo de Caja de la Mesa de Cambio (Liquidez USDT)
create table if not exists mesa_cambio_caja (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('ingreso_liquidez', 'egreso_despacho', 'ajuste_manual')),
  monto_usdt numeric(12,2) not null,
  tasa_compra_bs numeric(14,4),
  costo_total_bs numeric(16,2),
  saldo_posterior_usdt numeric(12,2) not null,
  operacion_id uuid references mesa_cambio_operaciones(id) on delete set null,
  notas text,
  created_at timestamptz not null default now()
);

create index if not exists idx_mesa_cambio_caja_fecha on mesa_cambio_caja(created_at desc);
alter table mesa_cambio_caja enable row level security;

drop policy if exists mesa_caja_admin_all on mesa_cambio_caja;
create policy mesa_caja_admin_all on mesa_cambio_caja
  for all to authenticated
  using (is_admin())
  with check (is_admin());

-- D. Bloque principal PL/pgSQL
do $$
declare
  v_pablo_id uuid;
  v_dup_id uuid;
  v_leandro_id uuid;
  v_nelson_id uuid;
  v_josuanny_id uuid;
  v_rate numeric;
  r record;
  v_cust_id uuid;
  v_prof_id uuid;
  v_prod_id uuid;
  v_order_id uuid;
  v_inst_id uuid;
begin
  -- 1. Obtener tasa oficial del día
  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 50.00);

  -- 1.1 Establecer límite de crédito inicial en $0.00 para todos (Cero crédito hasta solicitud o asignación oficial)
  update customers set limite_credito = 0.00;

  -- 2. Consolidar a Pablo Gonzalez como Revendedor Oficial (RVD:1001)
  select id into v_pablo_id from customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
  order by creado asc limit 1;

  if v_pablo_id is null then
    select id into v_pablo_id from customers
    where lower(trim(nombre)) like '%pablo gonzalez%' or lower(trim(nombre)) = 'pablo'
    order by (email is not null and email like '%@%') desc, creado asc limit 1;
  end if;

  if v_pablo_id is not null then
    update customers set
      nombre = 'Pablo Gonzalez',
      email = 'pacun1989@gmail.com',
      telefono = '584129130080',
      es_revendedor = true,
      codigo_identificacion = 'RVD:1001'
    where id = v_pablo_id;

    -- Reasignar y eliminar registro duplicado 'PABLO'
    for v_dup_id in
      select id from customers
      where id <> v_pablo_id
        and (lower(trim(nombre)) in ('pablo', 'pablo revendedor') or lower(trim(email)) in ('584129130080@cliente.gregoryizquierdo.xyz', 'pacun1989@gmail.com'))
    loop
      update customers set vendedor_id = v_pablo_id, vendedor_nombre = 'Pablo Gonzalez' where vendedor_id = v_dup_id;
      update profiles_inventory set vendedor_id = v_pablo_id, vendedor = 'Pablo Gonzalez' where vendedor_id = v_dup_id;
      update orders set vendedor_id = v_pablo_id where vendedor_id = v_dup_id;
      if exists (select 1 from information_schema.tables where table_name = 'partner_commissions') then
        execute 'update partner_commissions set vendedor_id = $1 where vendedor_id = $2' using v_pablo_id, v_dup_id;
      end if;
      delete from customers where id = v_dup_id;
    end loop;
  end if;

  -- 3. Leandro Perdomo (RVD:1002)
  select id into v_leandro_id from customers
  where lower(trim(email)) in ('perdomoleandro39@gmail.com', '584122952044@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) like '%leandro%'
  order by creado asc limit 1;

  if v_leandro_id is not null then
    update customers set
      nombre = 'Leandro Perdomo',
      email = coalesce(email, 'perdomoleandro39@gmail.com'),
      telefono = coalesce(telefono, '584122952044'),
      es_revendedor = true,
      codigo_identificacion = 'RVD:1002'
    where id = v_leandro_id;
  end if;

  -- 4. Nelson Bustamante (RVD:1003)
  select id into v_nelson_id from customers
  where lower(trim(email)) in ('584120266710@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) like '%nelson%'
  order by creado asc limit 1;

  if v_nelson_id is not null then
    update customers set
      nombre = 'Nelson Bustamante',
      telefono = coalesce(telefono, '584120266710'),
      es_revendedor = true,
      codigo_identificacion = 'RVD:1003'
    where id = v_nelson_id;
  end if;

  -- 5. Josuanny (RVD:1004)
  select id into v_josuanny_id from customers
  where lower(trim(email)) in ('584129939848@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) like '%josuanny%'
  order by creado asc limit 1;

  if v_josuanny_id is not null then
    update customers set
      nombre = 'Josuanny',
      telefono = coalesce(telefono, '584129939848'),
      es_revendedor = true,
      codigo_identificacion = 'RVD:1004'
    where id = v_josuanny_id;
  end if;

  -- 6. Asegurar códigos CLT:xxx a clientes que tengan por error RVD
  for r in
    select id from customers
    where (es_revendedor is null or es_revendedor = false)
      and (codigo_identificacion is null or codigo_identificacion like 'RVD%')
    order by creado asc
  loop
    update customers set codigo_identificacion = get_next_customer_code(false) where id = r.id;
  end loop;

  -- 7. Asegurar códigos RVD:xxx a cualquier otro revendedor con código CLT o nulo
  for r in
    select id from customers
    where es_revendedor = true
      and (codigo_identificacion is null or codigo_identificacion like 'CLT%')
    order by creado asc
  loop
    update customers set codigo_identificacion = get_next_customer_code(true) where id = r.id;
  end loop;

  -- 8. Aplicar créditos oficiales con fecha 30/10/2026 (Evert, Fernisbel, Tony Massimo)
  for r in
    select * from (values
      (
        'EVERT IZQUIERDO',
        '593978678921@cliente.gregoryizquierdo.xyz',
        'NETFLIX',
        '%evert%',
        'NETFLIX PERFIL EXTRA NETFLIX 30 DIAS',
        7.00,
        '2026-10-30'::date
      ),
      (
        'FERNISBEL',
        '584141181778@cliente.gregoryizquierdo.xyz',
        'DISNEY',
        '%fernisbel%',
        'DISNEY PERFIL 30 DIAS',
        4.50,
        '2026-10-30'::date
      ),
      (
        'TONY MASSIMO',
        '584142487511@cliente.gregoryizquierdo.xyz',
        'TELELATINO',
        '%tony%',
        'TELELATINO PERFIL 30 DIAS',
        4.50,
        '2026-10-30'::date
      )
    ) as t(cliente_nombre, email, plataforma, perfil_busqueda, producto_nombre, monto_deuda, fecha_limite)
  loop
    -- A. Localizar cliente
    v_cust_id := null;
    select id into v_cust_id from customers
    where lower(trim(email)) = lower(trim(r.email))
       or lower(trim(nombre)) = lower(trim(r.cliente_nombre))
    limit 1;

    if v_cust_id is not null then
      update customers set
        vendedor_id = v_pablo_id,
        vendedor_nombre = 'Pablo Gonzalez',
        limite_credito = greatest(coalesce(limite_credito, 0.00), r.monto_deuda)
      where id = v_cust_id;
    end if;

    -- B. Localizar producto
    v_prod_id := null;
    select id into v_prod_id from products
    where lower(trim(nombre)) = lower(trim(r.producto_nombre))
       or lower(trim(nombre)) like lower(r.plataforma || '%')
    order by (lower(trim(nombre)) = lower(trim(r.producto_nombre))) desc limit 1;

    -- C. Localizar perfil activo en profiles_inventory
    v_prof_id := null;
    select pi.id into v_prof_id
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    where m.plataforma = r.plataforma
      and lower(trim(pi.nombre_perfil)) like lower(r.perfil_busqueda)
    order by (pi.assigned_customer_id = v_cust_id) desc, pi.id limit 1;

    if v_prof_id is not null and v_cust_id is not null then
      update profiles_inventory set
        assigned_customer_id = v_cust_id,
        vendedor_id = v_pablo_id,
        vendedor = 'Pablo Gonzalez',
        product_id = coalesce(product_id, v_prod_id),
        estado = 'vendido',
        vence = greatest(coalesce(vence, r.fecha_limite), r.fecha_limite)
      where id = v_prof_id;

      -- D. Localizar o crear orden a crédito
      v_order_id := null;
      select id into v_order_id from orders
      where profile_id = v_prof_id and customer_id = v_cust_id
      order by created_at desc limit 1;

      if v_order_id is not null then
        update orders set
          vendedor_id = v_pablo_id,
          total_usd = r.monto_deuda,
          tasa_bs = v_rate,
          total_bs = round(r.monto_deuda * v_rate, 2),
          estado = 'entregado',
          proximo_pago = r.fecha_limite,
          vence = greatest(coalesce(vence, r.fecha_limite), r.fecha_limite),
          referencia = '[CRÉDITO] Vence ' || to_char(r.fecha_limite, 'YYYY-MM-DD') || ' ($' || r.monto_deuda || ' USD) · Pablo Gonzalez'
        where id = v_order_id;
      else
        insert into orders (
          customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs,
          referencia, estado, vendedor_id, inicia, vence, proximo_pago
        ) values (
          v_cust_id, v_prod_id, v_prof_id, r.monto_deuda, v_rate, round(r.monto_deuda * v_rate, 2),
          '[CRÉDITO] Vence ' || to_char(r.fecha_limite, 'YYYY-MM-DD') || ' ($' || r.monto_deuda || ' USD) · Pablo Gonzalez',
          'entregado', v_pablo_id, current_date, r.fecha_limite, r.fecha_limite
        ) returning id into v_order_id;
      end if;

      -- E. Localizar o crear cuota en installments
      select id into v_inst_id from installments where order_id = v_order_id limit 1;

      if v_inst_id is not null then
        update installments set
          monto_usd = r.monto_deuda,
          monto_bs = round(r.monto_deuda * v_rate, 2),
          tasa_bs = v_rate,
          fecha_vencimiento = r.fecha_limite,
          estado = 'pendiente',
          referencia = '[CRÉDITO PABLO GONZALEZ] Vence 30/10/2026 ($' || r.monto_deuda || ' USD)'
        where id = v_inst_id;
      else
        insert into installments (
          order_id, customer_id, numero_cuota, total_cuotas,
          monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado,
          referencia
        ) values (
          v_order_id, v_cust_id, 1, 1,
          r.monto_deuda, round(r.monto_deuda * v_rate, 2), v_rate, r.fecha_limite, 'pendiente',
          '[CRÉDITO PABLO GONZALEZ] ' || r.cliente_nombre || ' - ' || r.producto_nombre || ' ($' || r.monto_deuda || ' USD)'
        );
      end if;

    end if;
  end loop;

end $$;
