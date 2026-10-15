-- ==============================================================================
-- Migración 31: Enlace Maestro de Perfiles Activos, Red de Revendedores
--               y Aplicación Oficial de Créditos (Evert, Fernisbel, Tony Massimo)
-- Base de Datos: Supabase (tienda-gregory)
-- ==============================================================================

do $$
declare
  v_pablo_id uuid;
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
  v_prod_netflix_id uuid;
  v_prod_disney_id uuid;
  v_prod_telelatino_id uuid;
  v_seller_id uuid;
  v_seller_nom text;
begin
  -- 1. Tasa oficial del día
  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 50.00);

  -- 2. Localizar IDs de Revendedores Oficiales
  -- Pablo Gonzalez (RVD:1001)
  select id into v_pablo_id from customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or (lower(trim(nombre)) like '%pablo gonzalez%' and es_revendedor = true)
     or codigo_identificacion = 'RVD:1001'
  order by (codigo_identificacion = 'RVD:1001') desc, creado asc limit 1;

  -- Leandro Perdomo (RVD:1002)
  select id into v_leandro_id from customers
  where lower(trim(email)) in ('perdomoleandro39@gmail.com')
     or lower(trim(nombre)) like '%leandro%'
     or codigo_identificacion = 'RVD:1002'
  order by (codigo_identificacion = 'RVD:1002') desc, creado asc limit 1;

  -- Nelson Bustamante (RVD:1003)
  select id into v_nelson_id from customers
  where lower(trim(email)) in ('584120266710@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) like '%nelson%'
     or codigo_identificacion = 'RVD:1003'
  order by (codigo_identificacion = 'RVD:1003') desc, creado asc limit 1;

  -- Josuanny (RVD:1004)
  select id into v_josuanny_id from customers
  where lower(trim(email)) in ('584129939848@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) like '%josuanny%'
     or codigo_identificacion = 'RVD:1004'
  order by (codigo_identificacion = 'RVD:1004') desc, creado asc limit 1;

  -- Asegurar códigos y datos oficiales de los revendedores
  if v_pablo_id is not null then
    update customers set nombre = 'Pablo Gonzalez', es_revendedor = true, codigo_identificacion = 'RVD:1001' where id = v_pablo_id;
  end if;
  if v_leandro_id is not null then
    update customers set nombre = 'Leandro Perdomo', es_revendedor = true, codigo_identificacion = 'RVD:1002' where id = v_leandro_id;
  end if;
  if v_nelson_id is not null then
    update customers set nombre = 'Nelson Bustamante', es_revendedor = true, codigo_identificacion = 'RVD:1003' where id = v_nelson_id;
  end if;
  if v_josuanny_id is not null then
    update customers set nombre = 'Josuanny', es_revendedor = true, codigo_identificacion = 'RVD:1004', telefono = '584129939848' where id = v_josuanny_id;
  end if;

  -- 3. Productos representativos
  select id into v_prod_netflix_id from products where lower(nombre) like '%netflix%' order by id limit 1;
  select id into v_prod_disney_id from products where lower(nombre) like '%disney%' order by id limit 1;
  select id into v_prod_telelatino_id from products where lower(nombre) like '%telelatino%' order by id limit 1;

  -- 4. Asegurar Clientes específicos y vincular con su Revendedor
  -- SILVA -> Josuanny (RVD:1004)
  select id into v_cust_id from customers
  where lower(trim(email)) in ('silva.584129939848@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) = 'silva'
  limit 1;
  if v_cust_id is not null then
    update customers set
      nombre = 'SILVA',
      vendedor_id = v_josuanny_id,
      vendedor_nombre = 'Josuanny',
      es_revendedor = false,
      telefono = '584129939848'
    where id = v_cust_id;
  else
    insert into customers (nombre, email, telefono, es_revendedor, codigo_identificacion, vendedor_id, vendedor_nombre, limite_credito)
    values ('SILVA', 'silva.584129939848@cliente.gregoryizquierdo.xyz', '584129939848', false, 'CLT:1020', v_josuanny_id, 'Josuanny', 0.00)
    returning id into v_cust_id;
  end if;

  -- YOSESTYLE -> Josuanny (RVD:1004)
  select id into v_cust_id from customers
  where lower(trim(email)) in ('yosestyle.584129939848@cliente.gregoryizquierdo.xyz')
     or lower(trim(nombre)) = 'yosestyle'
  limit 1;
  if v_cust_id is not null then
    update customers set
      nombre = 'YOSESTYLE',
      vendedor_id = v_josuanny_id,
      vendedor_nombre = 'Josuanny',
      es_revendedor = false,
      telefono = '584129939848'
    where id = v_cust_id;
  else
    insert into customers (nombre, email, telefono, es_revendedor, codigo_identificacion, vendedor_id, vendedor_nombre, limite_credito)
    values ('YOSESTYLE', 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz', '584129939848', false, 'CLT:1021', v_josuanny_id, 'Josuanny', 0.00)
    returning id into v_cust_id;
  end if;

  -- 5. Enlace masivo de TODOS los clientes del Excel con sus perfiles reales
  -- usando coincidencia flexible de plataforma (ilike)
  for r in
    select * from (values
      ('584128047511@cliente.gregoryizquierdo.xyz', 'FLUJOTV', '%enyerber%', 'PABLO', null),
      ('584245620861@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%marianne%', 'PABLO', null),
      ('584245620861@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%nani 1%', 'PABLO', null),
      ('584245620861@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%nani%2%', 'PABLO', null),
      ('584242843713@cliente.gregoryizquierdo.xyz', 'PARAMOUNT', '%vanessa%', 'PABLO', null),
      ('584242843713@cliente.gregoryizquierdo.xyz', 'MAX', '%vanessa%', 'PABLO', null),
      ('584143848858@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%diogenes 1%', 'PABLO', null),
      ('584143848858@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%diogenes 2%', 'PABLO', null),
      ('584129809304@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%melyta%1%', 'PABLO', null),
      ('584129809304@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%melyta%2%', 'PABLO', null),
      ('584142478459@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%landys%', 'PABLO', null),
      ('584142478459@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%endris%', 'PABLO', null),
      ('584142478459@cliente.gregoryizquierdo.xyz', 'MAX', '%endris%', 'PABLO', null),
      ('584141181778@cliente.gregoryizquierdo.xyz', 'DISNEY', '%fernisbel%', 'PABLO', null),
      ('584142487511@cliente.gregoryizquierdo.xyz', 'TELELATINO', '%tony%', 'PABLO', null),
      ('584142487511@cliente.gregoryizquierdo.xyz', 'TELELATINO', '%maria rodr%', 'PABLO', null),
      ('584143893589@cliente.gregoryizquierdo.xyz', 'FLUJOTV', '%gabriel%', 'PABLO', null),
      ('armando.584120266710@cliente.gregoryizquierdo.xyz', 'DISNEY', '%armando%', 'NELSON', null),
      ('carmennacero.584120266710@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%carmen%nacero%', 'NELSON', null),
      ('keibernacero.584120266710@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%keiber%nacero%', 'NELSON', null),
      ('584128592774@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%ariana%', 'PABLO', null),
      ('584142773768@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%marianela%espinoza%', 'PABLO', null),
      ('18133779985@cliente.gregoryizquierdo.xyz', 'DISNEY', '%isaac%', 'PABLO', null),
      ('18133779985@cliente.gregoryizquierdo.xyz', 'MAX', '%isaac%', 'PABLO', null),
      ('silva.584129939848@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%silvi%', 'JOSUANNY', null),
      ('yosestyle.584129939848@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%yosestyle%', 'JOSUANNY', null),
      ('584142302384@cliente.gregoryizquierdo.xyz', 'FLUJOTV', '%melvin 1%', 'PABLO', null),
      ('584142302384@cliente.gregoryizquierdo.xyz', 'FLUJOTV', '%melvin 2%', 'PABLO', null),
      ('584264078565@cliente.gregoryizquierdo.xyz', 'TELELATINO', '%manuel%', 'PABLO', null),
      ('584124494241@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%elis%', 'PABLO', null),
      ('584142725342@cliente.gregoryizquierdo.xyz', 'FLUJOTV', '%carolina%herrera%', 'PABLO', 'Conec744'),
      ('584242782146@cliente.gregoryizquierdo.xyz', 'DISNEY', '%angelo%', 'PABLO', null),
      ('584242782146@cliente.gregoryizquierdo.xyz', 'MAX', '%angelo%', 'PABLO', null),
      ('584242322095@cliente.gregoryizquierdo.xyz', 'DISNEY', '%yuglis%', 'PABLO', null),
      ('584125872676@cliente.gregoryizquierdo.xyz', 'DISNEY', '%douglas%parra%', 'DIRECTO TIENDA', null),
      ('584120904544@cliente.gregoryizquierdo.xyz', 'CRUNCHYROLL', '%dirwin%', 'PABLO', null),
      ('584143725323@cliente.gregoryizquierdo.xyz', 'PARAMOUNT', '%carlos%', 'PABLO', null),
      ('584129251463@cliente.gregoryizquierdo.xyz', 'PARAMOUNT', '%gepe%', 'PABLO', null),
      ('584241415188@cliente.gregoryizquierdo.xyz', 'FLUJOTV', '%maria%', 'PABLO', null),
      ('584242407603@cliente.gregoryizquierdo.xyz', 'PRIME', '%victoria%', 'PABLO', null),
      ('593978678921@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%evert%', 'PABLO', null),
      ('584120229689@cliente.gregoryizquierdo.xyz', 'DISNEY', '%roymel%', 'PABLO', null),
      ('584122952044@cliente.gregoryizquierdo.xyz', 'CRUNCHYROLL', '%joslex%', 'LEANDRO', null),
      ('pacun1989@gmail.com', 'FLUJOTV', '%pablo%', 'PABLO', null)
    ) as p(email, plataforma, perfil_busqueda, vendedor, cuenta_correo)
  loop
    v_seller_id := case r.vendedor
      when 'PABLO' then v_pablo_id
      when 'NELSON' then v_nelson_id
      when 'JOSUANNY' then v_josuanny_id
      when 'LEANDRO' then v_leandro_id
      else null
    end;

    v_seller_nom := case r.vendedor
      when 'PABLO' then 'Pablo Gonzalez'
      when 'NELSON' then 'Nelson Bustamante'
      when 'JOSUANNY' then 'Josuanny'
      when 'LEANDRO' then 'Leandro Perdomo'
      else null
    end;

    -- Localizar cliente
    select id into v_cust_id from customers where lower(trim(email)) = lower(trim(r.email)) limit 1;

    if v_cust_id is not null and v_seller_id is not null then
      update customers set
        vendedor_id = coalesce(vendedor_id, v_seller_id),
        vendedor_nombre = coalesce(vendedor_nombre, v_seller_nom)
      where id = v_cust_id;
    end if;

    -- Localizar perfil activo
    v_prof_id := null;
    if r.cuenta_correo is not null then
      select pi.id into v_prof_id
      from profiles_inventory pi
      join mother_accounts m on m.id = pi.mother_id
      where (m.plataforma ilike '%' || r.plataforma || '%' or r.plataforma ilike '%' || m.plataforma || '%')
        and m.correo = r.cuenta_correo
      order by pi.id limit 1;
    end if;

    if v_prof_id is null then
      select pi.id into v_prof_id
      from profiles_inventory pi
      join mother_accounts m on m.id = pi.mother_id
      where (m.plataforma ilike '%' || r.plataforma || '%' or r.plataforma ilike '%' || m.plataforma || '%')
        and lower(trim(pi.nombre_perfil)) like lower(r.perfil_busqueda)
      order by (pi.assigned_customer_id = v_cust_id) desc, pi.id limit 1;
    end if;

    -- Si localizamos perfil y cliente, vincularlos formalmente
    if v_prof_id is not null and v_cust_id is not null then
      update profiles_inventory set
        assigned_customer_id = v_cust_id,
        vendedor_id = coalesce(v_seller_id, vendedor_id),
        vendedor = coalesce(v_seller_nom, vendedor),
        estado = 'vendido'
      where id = v_prof_id;

      -- Vincular en orders
      if exists (select 1 from orders where profile_id = v_prof_id) then
        update orders set
          customer_id = v_cust_id,
          vendedor_id = coalesce(v_seller_id, vendedor_id),
          estado = 'entregado'
        where profile_id = v_prof_id;
      else
        insert into orders (
          customer_id, profile_id, total_usd, tasa_bs, total_bs,
          referencia, estado, vendedor_id, inicia, vence
        ) values (
          v_cust_id, v_prof_id, 4.00, v_rate, round(4.00 * v_rate, 2),
          '[IMPORTADO EXCEL] ' || r.plataforma || ' - ' || r.perfil_busqueda,
          'entregado', v_seller_id, current_date, (current_date + interval '30 days')::date
        );
      end if;
    end if;
  end loop;

  -- 6. Aplicar Oficialmente los 3 Créditos con fecha 30/10/2026 (Evert, Fernisbel, Tony Massimo)
  for r in
    select * from (values
      (
        'EVERT IZQUIERDO',
        '593978678921@cliente.gregoryizquierdo.xyz',
        'NETFLIX',
        '%evert%',
        7.00,
        '2026-10-30'::date
      ),
      (
        'FERNISBEL',
        '584141181778@cliente.gregoryizquierdo.xyz',
        'DISNEY',
        '%fernisbel%',
        4.50,
        '2026-10-30'::date
      ),
      (
        'TONY MASSIMO',
        '584142487511@cliente.gregoryizquierdo.xyz',
        'TELELATINO',
        '%tony%',
        4.50,
        '2026-10-30'::date
      )
    ) as t(cliente_nombre, email, plataforma, perfil_busqueda, monto_deuda, fecha_limite)
  loop
    -- A. Localizar o registrar cliente
    v_cust_id := null;
    select id into v_cust_id from customers
    where lower(trim(email)) = lower(trim(r.email))
       or lower(trim(nombre)) = lower(trim(r.cliente_nombre))
    limit 1;

    if v_cust_id is not null then
      update customers set
        vendedor_id = v_pablo_id,
        vendedor_nombre = 'Pablo Gonzalez',
        limite_credito = r.monto_deuda,
        permite_cuotas = true
      where id = v_cust_id;
    else
      insert into customers (nombre, email, telefono, es_revendedor, vendedor_id, vendedor_nombre, limite_credito, permite_cuotas)
      values (r.cliente_nombre, r.email, split_part(r.email, '@', 1), false, v_pablo_id, 'Pablo Gonzalez', r.monto_deuda, true)
      returning id into v_cust_id;
    end if;

    -- B. Localizar perfil con coincidencia flexible
    v_prof_id := null;
    select pi.id into v_prof_id
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    where (m.plataforma ilike '%' || r.plataforma || '%' or r.plataforma ilike '%' || m.plataforma || '%')
      and lower(trim(pi.nombre_perfil)) like lower(r.perfil_busqueda)
    order by (pi.assigned_customer_id = v_cust_id) desc, pi.id limit 1;

    if v_prof_id is not null then
      update profiles_inventory set
        assigned_customer_id = v_cust_id,
        vendedor_id = v_pablo_id,
        vendedor = 'Pablo Gonzalez',
        estado = 'vendido',
        vence = greatest(coalesce(vence, r.fecha_limite), r.fecha_limite)
      where id = v_prof_id;
    end if;

    -- C. Producto asignado
    v_prod_id := case r.plataforma
      when 'NETFLIX' then v_prod_netflix_id
      when 'DISNEY' then v_prod_disney_id
      else v_prod_telelatino_id
    end;

    -- D. Localizar o crear orden a crédito
    v_order_id := null;
    select id into v_order_id from orders
    where customer_id = v_cust_id
    order by (profile_id = v_prof_id) desc, created_at desc limit 1;

    if v_order_id is not null then
      update orders set
        profile_id = coalesce(v_prof_id, profile_id),
        product_id = coalesce(v_prod_id, product_id),
        vendedor_id = v_pablo_id,
        total_usd = r.monto_deuda,
        tasa_bs = v_rate,
        total_bs = round(r.monto_deuda * v_rate, 2),
        estado = 'entregado',
        proximo_pago = r.fecha_limite,
        vence = greatest(coalesce(vence, r.fecha_limite), r.fecha_limite),
        referencia = '[CRÉDITO PABLO GONZALEZ] ' || r.cliente_nombre || ' - ' || r.plataforma || ' ($' || r.monto_deuda || ' USD)'
      where id = v_order_id;
    else
      insert into orders (
        customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs,
        referencia, estado, vendedor_id, inicia, vence, proximo_pago
      ) values (
        v_cust_id, v_prod_id, v_prof_id, r.monto_deuda, v_rate, round(r.monto_deuda * v_rate, 2),
        '[CRÉDITO PABLO GONZALEZ] ' || r.cliente_nombre || ' - ' || r.plataforma || ' ($' || r.monto_deuda || ' USD)',
        'entregado', v_pablo_id, current_date, r.fecha_limite, r.fecha_limite
      ) returning id into v_order_id;
    end if;

    -- E. Insertar o actualizar la cuota en installments
    v_inst_id := null;
    select id into v_inst_id from installments
    where customer_id = v_cust_id
       or order_id = v_order_id
       or lower(referencia) like lower('%' || r.cliente_nombre || '%')
    limit 1;

    if v_inst_id is not null then
      update installments set
        order_id = v_order_id,
        customer_id = v_cust_id,
        numero_cuota = 1,
        total_cuotas = 1,
        monto_usd = r.monto_deuda,
        monto_bs = round(r.monto_deuda * v_rate, 2),
        tasa_bs = v_rate,
        fecha_vencimiento = r.fecha_limite,
        estado = 'pendiente',
        referencia = '[CRÉDITO PABLO GONZALEZ] ' || r.cliente_nombre || ' - ' || r.plataforma || ' PERFIL 30 DIAS ($' || r.monto_deuda || ' USD)'
      where id = v_inst_id;
    else
      insert into installments (
        order_id, customer_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      ) values (
        v_order_id, v_cust_id, 1, 1,
        r.monto_deuda, round(r.monto_deuda * v_rate, 2), v_rate, r.fecha_limite, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] ' || r.cliente_nombre || ' - ' || r.plataforma || ' PERFIL 30 DIAS ($' || r.monto_deuda || ' USD)'
      );
    end if;
  end loop;

end $$;
