-- ==============================================================================
-- Migración 29: Separación Oficial de Revendedores vs Clientes y Asignación RVD
-- 1. Asignación estricta de códigos RVD (RVD:1001 a RVD:1004) a los 4 revendedores oficiales
-- 2. Eliminación y consolidación del registro duplicado 'PABLO' en 'Pablo Gonzalez'
-- 3. Corrección de códigos CLT en revendedores y normalización de la red
-- 4. Aplicación de los 3 créditos oficiales (30/10/2026) sin errores de schema
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

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

    -- Eliminar registro duplicado 'PABLO' reasignando todo a Pablo Gonzalez
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

  -- 3. Asegurar a Leandro Perdomo (RVD:1002)
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

  -- 4. Asegurar a Nelson Bustamante (RVD:1003)
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

  -- 5. Asegurar a Josuanny (RVD:1004)
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

  -- 6. Normalizar cualquier otro revendedor con código CLT o nulo
  for r in
    select id from customers
    where es_revendedor = true
      and (codigo_identificacion is null or codigo_identificacion like 'CLT%')
    order by creado asc
  loop
    update customers set codigo_identificacion = get_next_customer_code(true) where id = r.id;
  end loop;

  -- 7. Normalizar clientes finales (es_revendedor = false o null) que tengan RVD por error
  for r in
    select id from customers
    where (es_revendedor is null or es_revendedor = false)
      and (codigo_identificacion is null or codigo_identificacion like 'RVD%')
    order by creado asc
  loop
    update customers set codigo_identificacion = get_next_customer_code(false) where id = r.id;
  end loop;

  -- 8. Aplicar créditos a los 3 clientes específicos (Evert, Fernisbel, Tony Massimo)
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
