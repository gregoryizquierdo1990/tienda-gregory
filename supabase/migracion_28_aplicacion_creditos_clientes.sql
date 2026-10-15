-- ==============================================================================
-- Migración 28: Aplicación Oficial de Créditos a Clientes
-- Clientes: Evert Izquierdo, Fernisbel, Tony Massimo
-- Socio / Revendedor Responsable: Pablo Gonzalez
-- Fecha Límite de Pago: 30 de Octubre de 2026 (30/10/26)
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

do $$
declare
  v_pablo_id uuid;
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

  -- 2. Obtener el ID del revendedor oficial Pablo Gonzalez
  select id into v_pablo_id from customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or (lower(trim(nombre)) like '%pablo gonzalez%' and es_revendedor = true)
  order by created_at asc limit 1;

  if v_pablo_id is null then
    select id into v_pablo_id from customers where es_revendedor = true and lower(trim(nombre)) like '%pablo%' limit 1;
  end if;

  -- 3. Aplicar créditos a los 3 clientes específicos
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
    -- A. Localizar el cliente
    v_cust_id := null;
    select id into v_cust_id from customers
    where lower(trim(email)) = lower(trim(r.email))
       or lower(trim(nombre)) = lower(trim(r.cliente_nombre))
    limit 1;

    if v_cust_id is not null then
      -- Asegurar vendedor Pablo Gonzalez y actualizar límite de crédito
      update customers set
        vendedor_id = v_pablo_id,
        vendedor_nombre = 'Pablo Gonzalez',
        limite_credito = greatest(coalesce(limite_credito, 0.00), r.monto_deuda),
        permite_cuotas = true
      where id = v_cust_id;
    end if;

    -- B. Localizar el producto
    v_prod_id := null;
    select id into v_prod_id from products
    where lower(trim(nombre)) = lower(trim(r.producto_nombre))
       or lower(trim(nombre)) like lower(r.plataforma || '%')
    order by (lower(trim(nombre)) = lower(trim(r.producto_nombre))) desc limit 1;

    -- C. Localizar el perfil activo en profiles_inventory
    v_prof_id := null;
    select pi.id into v_prof_id
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    where m.plataforma = r.plataforma
      and lower(trim(pi.nombre_perfil)) like lower(r.perfil_busqueda)
    order by (pi.assigned_customer_id = v_cust_id) desc, pi.id limit 1;

    if v_prof_id is not null and v_cust_id is not null then
      -- Asegurar que el perfil quede activo y asignado a este cliente y vendedor
      update profiles_inventory set
        assigned_customer_id = v_cust_id,
        vendedor_id = v_pablo_id,
        vendedor = 'Pablo Gonzalez',
        product_id = coalesce(product_id, v_prod_id),
        estado = 'vendido',
        vence = greatest(coalesce(vence, r.fecha_limite), r.fecha_limite)
      where id = v_prof_id;

      -- D. Localizar o crear la orden a crédito
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

      -- E. Insertar o actualizar la cuota en installments
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
