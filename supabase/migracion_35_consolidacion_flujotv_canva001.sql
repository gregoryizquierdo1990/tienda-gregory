-- ==============================================================================
-- MIGRACIÓN 35: CONSOLIDACIÓN DE CUENTAS MADRE FLUJOTV (Canva001)
-- Unifica Canva002 y Canva003 en la cuenta madre real Canva001
-- ==============================================================================

begin;

do $$
declare
  v_canva001_id uuid;
  v_old_ids uuid[];
begin
  -- 1. Obtener el ID de la cuenta madre real Canva001
  select id into v_canva001_id 
  from mother_accounts 
  where upper(trim(plataforma)) = 'FLUJOTV' 
    and lower(trim(correo)) = lower('Canva001')
  limit 1;

  if v_canva001_id is null then
    raise exception 'No se encontró la cuenta madre FLUJOTV Canva001';
  end if;

  -- 2. Asegurar que Canva001 tenga sus datos actualizados (Alexander Ojeda, vence 2026-11-18, capacidad 3 perfiles)
  update mother_accounts
  set proveedor = 'ALEXANDER OJEDA',
      vence = '2026-11-18'::date,
      max_perfiles = 3,
      activa = true
  where id = v_canva001_id;

  -- 3. Identificar IDs de las cuentas transcritas por error (Canva002 y Canva003)
  select array_agg(id) into v_old_ids
  from mother_accounts
  where upper(trim(plataforma)) = 'FLUJOTV'
    and lower(trim(correo)) in (lower('Canva002'), lower('Canva003'));

  if v_old_ids is not null and array_length(v_old_ids, 1) > 0 then
    -- 4. Reasignar todos los perfiles asociados (como 'melvin 1' y 'gabriel') hacia Canva001
    update profiles_inventory
    set mother_id = v_canva001_id
    where mother_id = any(v_old_ids);

    -- 5. Reasignar compras si existieran registradas a nombre de Canva002 o Canva003
    update purchases
    set mother_id = v_canva001_id
    where mother_id = any(v_old_ids);

    -- 6. Eliminar las cuentas duplicadas Canva002 y Canva003
    delete from mother_accounts
    where id = any(v_old_ids);
  end if;

end $$;

commit;
