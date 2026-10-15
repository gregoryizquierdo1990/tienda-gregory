-- ==============================================================================
-- Migración 26: Asignación Masiva de Clientes y Perfiles a Revendedores
-- (Pablo, Nelson, Leandro, Josuanny y Directo Tienda)
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- 1. Asegurar columnas en customers, profiles_inventory y orders
alter table customers add column if not exists debe_cambiar_password boolean default false;
alter table customers add column if not exists nivel_credito text not null default 'Bronce';
alter table customers add column if not exists codigo_identificacion text;
alter table customers add column if not exists limite_credito numeric(10,2) default 0.00;
alter table customers alter column limite_credito set default 0.00;
alter table customers add column if not exists zeny_balance numeric(10,2) default 0.00;
alter table customers add column if not exists es_revendedor boolean default false;
alter table customers add column if not exists vendedor_id uuid references customers(id) on delete set null;
alter table customers add column if not exists vendedor_nombre text;

alter table profiles_inventory add column if not exists vendedor text;
alter table profiles_inventory add column if not exists vendedor_id uuid references customers(id) on delete set null;
alter table profiles_inventory add column if not exists assigned_customer_id uuid references customers(id) on delete set null;

alter table orders add column if not exists vendedor_id uuid references customers(id) on delete set null;

-- 2. Desactivar creación automática de Tarjetas Zeny en customers
-- (Los clientes y revendedores deben solicitarlas voluntariamente mediante el botón 'Solicitar Tarjeta Zeny')
drop trigger if exists trg_ensure_customer_zeny_card on customers;

create or replace function ensure_customer_zeny_card()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  return new;
end;
$$;

do $$
declare
  v_pablo_id uuid;
  v_nelson_id uuid;
  v_josuanny_id uuid;
  v_leandro_id uuid;
  v_rate numeric;
  v_cust_id uuid;
  v_seller_id uuid;
  v_seller_nom text;
  v_prof_id uuid;
  v_enc text;
  v_cod text;
  r record;
begin
  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 50.00);

  -- Obtener IDs de los 4 Revendedores Oficiales
  select id into v_pablo_id from customers where lower(email) in ('pacun1989@gmail.com', '584129130080@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1001' limit 1;
  select id into v_nelson_id from customers where lower(email) in ('584120266710@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1003' limit 1;
  select id into v_josuanny_id from customers where lower(email) in ('584129939848@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1004' limit 1;
  select id into v_leandro_id from customers where lower(email) in ('perdomoleandro39@gmail.com', '584122952044@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1002' limit 1;

  -- ----------------------------------------------------------------------------
  -- A. REGISTRO Y VINCULACIÓN DE LOS 35 CLIENTES ÚNICOS
  -- (Crédito $0.00, clave temporal = últimos 6 dígitos de su WhatsApp o 123456)
  -- ----------------------------------------------------------------------------
  for r in
    select * from (values
      ('FREDERICK RAMOS', '', 'frederickramos1604@gmail.com', 'DIRECTO TIENDA', '123456'),
      ('YOSEMIT', '573215601336', '573215601336@cliente.gregoryizquierdo.xyz', 'PABLO', '601336'),
      ('ENYERBER ESTEVEZ', '584128047511', '584128047511@cliente.gregoryizquierdo.xyz', 'PABLO', '047511'),
      ('MARIANNE AGUDO', '584245620861', '584245620861@cliente.gregoryizquierdo.xyz', 'PABLO', '562086'),
      ('VANESSA', '584242843713', '584242843713@cliente.gregoryizquierdo.xyz', 'PABLO', '843713'),
      ('DIOGENES', '584143848858', '584143848858@cliente.gregoryizquierdo.xyz', 'PABLO', '384858'),
      ('MELYTA', '584129809304', '584129809304@cliente.gregoryizquierdo.xyz', 'PABLO', '980904'),
      ('LANDYS', '584142478459', '584142478459@cliente.gregoryizquierdo.xyz', 'PABLO', '478459'),
      ('FERNISBEL', '584141181778', '584141181778@cliente.gregoryizquierdo.xyz', 'PABLO', '181778'),
      ('TONY MASSIMO', '584142487511', '584142487511@cliente.gregoryizquierdo.xyz', 'PABLO', '487511'),
      ('GABRIEL RODRIGUEZ', '584143893589', '584143893589@cliente.gregoryizquierdo.xyz', 'PABLO', '389359'),
      ('ARMANDO', '584120266710', 'armando.584120266710@cliente.gregoryizquierdo.xyz', 'NELSON', '266710'),
      ('CARMEN NACERO', '584120266710', 'carmennacero.584120266710@cliente.gregoryizquierdo.xyz', 'NELSON', '266710'),
      ('KEIBER NACERO', '584120266710', 'keibernacero.584120266710@cliente.gregoryizquierdo.xyz', 'NELSON', '266710'),
      ('ARIANA HERRERA', '584128592774', '584128592774@cliente.gregoryizquierdo.xyz', 'PABLO', '859277'),
      ('MARIANELA ESPINOZA', '584142773768', '584142773768@cliente.gregoryizquierdo.xyz', 'PABLO', '277376'),
      ('ISAAC TOVAR', '18133779985', '18133779985@cliente.gregoryizquierdo.xyz', 'PABLO', '779985'),
      ('SILVA', '584129939848', 'silva.584129939848@cliente.gregoryizquierdo.xyz', 'JOSUANNY', '939848'),
      ('YOSESTYLE', '584129939848', 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz', 'JOSUANNY', '939848'),
      ('MELVIN AMUNDARAIN', '584142302384', '584142302384@cliente.gregoryizquierdo.xyz', 'PABLO', '230238'),
      ('MANUEL GONZALEZ', '584264078565', '584264078565@cliente.gregoryizquierdo.xyz', 'PABLO', '078565'),
      ('ELIS', '584124494241', '584124494241@cliente.gregoryizquierdo.xyz', 'PABLO', '449241'),
      ('CAROLINA HERRERA', '584142725342', '584142725342@cliente.gregoryizquierdo.xyz', 'PABLO', '725342'),
      ('ANGELO', '584242782146', '584242782146@cliente.gregoryizquierdo.xyz', 'PABLO', '278214'),
      ('YUGLISLELO PEREZ', '584242322095', '584242322095@cliente.gregoryizquierdo.xyz', 'PABLO', '232209'),
      ('DOUGLAS PARRA', '584125872676', '584125872676@cliente.gregoryizquierdo.xyz', 'DIRECTO TIENDA', '587267'),
      ('DIRWIN CARABALLO', '584120904544', '584120904544@cliente.gregoryizquierdo.xyz', 'PABLO', '090454'),
      ('CARLOS LEON', '584143725323', '584143725323@cliente.gregoryizquierdo.xyz', 'PABLO', '372532'),
      ('GEPETO', '584129251463', '584129251463@cliente.gregoryizquierdo.xyz', 'PABLO', '251463'),
      ('MARIA', '584241415188', '584241415188@cliente.gregoryizquierdo.xyz', 'PABLO', '141518'),
      ('VICTORIA GUEVARA', '584242407603', '584242407603@cliente.gregoryizquierdo.xyz', 'PABLO', '240760'),
      ('EVERT IZQUIERDO', '593978678921', '593978678921@cliente.gregoryizquierdo.xyz', 'PABLO', '786789'),
      ('ROYMEL', '584120229689', '584120229689@cliente.gregoryizquierdo.xyz', 'PABLO', '022968'),
      ('JOSLEX', '584122952044', '584122952044@cliente.gregoryizquierdo.xyz', 'LEANDRO', '295204'),
      ('PABLO GONZALEZ', '584129130080', 'pacun1989@gmail.com', 'PABLO', '130080')
    ) as t(nombre, telefono, email, vendedor, clave)
  loop
    v_seller_id := case r.vendedor when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
    v_seller_nom := case r.vendedor when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;

    select id into v_cust_id from auth.users where lower(email) = lower(r.email);
    v_enc := extensions.crypt(r.clave, extensions.gen_salt('bf'));

    if v_cust_id is null then
      v_cust_id := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
      values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', lower(r.email), v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre', r.nombre, 'telefono', r.telefono, 'full_name', r.nombre), now(), now());
    else
      update auth.users
      set encrypted_password = v_enc,
          raw_user_meta_data = jsonb_build_object('nombre', r.nombre, 'telefono', r.telefono, 'full_name', r.nombre)
      where id = v_cust_id;
    end if;

    v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
    insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
    values (v_cust_id, r.nombre, lower(r.email), r.telefono, v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
    on conflict (id) do update set
      nombre = excluded.nombre,
      telefono = excluded.telefono,
      vendedor_id = excluded.vendedor_id,
      vendedor_nombre = excluded.vendedor_nombre,
      limite_credito = coalesce(customers.limite_credito, 0.00),
      debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);
  end loop;

  -- ----------------------------------------------------------------------------
  -- B. ASIGNACIÓN DE LOS 46 PERFILES Y ÓRDENES VENDIDAS
  -- ----------------------------------------------------------------------------
  for r in
    select * from (values
      ('frederickramos1604@gmail.com', 'CRUNCHYROLL', '%frederick%', 'DIRECTO TIENDA', null),
      ('573215601336@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%yosemit%', 'PABLO', null),
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
      ('silva.584129939848@cliente.gregoryizquierdo.xyz', 'NETFLIX', '%silvia%', 'JOSUANNY', null),
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
    v_seller_id := case r.vendedor when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
    v_seller_nom := case r.vendedor when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;

    select id into v_cust_id from customers where lower(email) = lower(r.email) limit 1;

    v_prof_id := null;
    if r.cuenta_correo is not null then
      select pi.id into v_prof_id
      from profiles_inventory pi
      where pi.mother_id in (select id from mother_accounts where plataforma = r.plataforma and correo = r.cuenta_correo)
      order by pi.id limit 1;
    end if;

    if v_prof_id is null then
      select pi.id into v_prof_id
      from profiles_inventory pi
      where pi.mother_id in (select id from mother_accounts where plataforma = r.plataforma)
        and lower(trim(pi.nombre_perfil)) like lower(r.perfil_busqueda)
      order by pi.id limit 1;
    end if;

    if v_prof_id is not null and v_cust_id is not null then
      update profiles_inventory
      set assigned_customer_id = v_cust_id,
          vendedor_id = v_seller_id,
          vendedor = v_seller_nom,
          estado = 'vendido'
      where id = v_prof_id;

      if exists (select 1 from orders where profile_id = v_prof_id) then
        update orders
        set customer_id = v_cust_id,
            vendedor_id = v_seller_id,
            estado = 'entregado'
        where profile_id = v_prof_id;
      else
        insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
        select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
        from profiles_inventory pi
        left join products pr on pr.id = pi.product_id
        where pi.id = v_prof_id;
      end if;
    end if;
  end loop;

end $$;
