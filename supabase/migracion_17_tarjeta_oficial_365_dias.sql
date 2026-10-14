-- ==============================================================================
-- MIGRACIÓN 17: TARJETA DE DÉBITO OFICIAL ZENY & VENCIMIENTO A 365 DÍAS
-- ==============================================================================
-- 1. Toda tarjeta emitida para cualquier usuario lleva su Nombre y Apellido.
-- 2. Vencimiento automático a exactamente 365 días contados desde la emisión (MM/YY).
-- 3. Trigger automático para asegurar que todo cliente registrado tenga su tarjeta Zeny.
-- 4. Actualización de tarjetas existentes con fecha por defecto.
-- ==============================================================================

-- 1. Función y Trigger automático para garantizar tarjeta oficial a todo cliente
create or replace function ensure_customer_zeny_card()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_card_num text;
  v_cvv text;
  v_clean_tel text;
  v_holder text;
  v_exp text;
begin
  -- Nombre del titular: nombre del cliente o parte inicial del email
  v_holder := upper(trim(coalesce(new.nombre, split_part(new.email, '@', 1), 'CLIENTE VIP')));

  -- Vencimiento a exactamente 365 días desde la emisión
  v_exp := to_char(now() + interval '365 days', 'MM/YY');

  -- Si el cliente ya tiene tarjeta, actualizar el nombre del titular si cambió
  if exists (select 1 from zeny_cards where customer_id = new.id) then
    if new.nombre is not null and trim(new.nombre) <> '' then
      update zeny_cards
      set nombre_titular = v_holder
      where customer_id = new.id;
    end if;
    return new;
  end if;

  -- Generación de número de 16 dígitos y CVV
  v_clean_tel := regexp_replace(coalesce(new.telefono, ''), '\D', '', 'g');
  if length(v_clean_tel) >= 4 then
    v_card_num := '4532 98' || lpad(right(v_clean_tel, 10), 10, '0');
    v_card_num := substring(v_card_num, 1, 4) || ' ' || substring(v_card_num, 5, 4) || ' ' || substring(v_card_num, 9, 4) || ' ' || substring(v_card_num, 13, 4);
    v_cvv := right(v_clean_tel, 3);
  else
    v_card_num := '4532 ' || lpad(floor(1000 + random() * 9000)::text, 4, '0') || ' ' ||
                             lpad(floor(1000 + random() * 9000)::text, 4, '0') || ' ' ||
                             lpad(floor(1000 + random() * 9000)::text, 4, '0');
    v_cvv := lpad(floor(100 + random() * 900)::text, 3, '0');
  end if;

  insert into zeny_cards (
    customer_id,
    numero_tarjeta,
    nombre_titular,
    codigo_activacion,
    fecha_vencimiento,
    estado,
    descuento_porcentaje
  ) values (
    new.id,
    v_card_num,
    v_holder,
    v_cvv,
    v_exp,
    'activa',
    5.00
  ) on conflict (customer_id) do update
  set nombre_titular = excluded.nombre_titular;

  return new;
end;
$$;

drop trigger if exists trg_ensure_customer_zeny_card on customers;
create trigger trg_ensure_customer_zeny_card
after insert or update of nombre on customers
for each row execute function ensure_customer_zeny_card();

-- 2. Actualizar tarjetas existentes que tenían fecha '12/31' para asignarles 365 días desde su creación
update zeny_cards
set fecha_vencimiento = to_char(coalesce(created_at, now()) + interval '365 days', 'MM/YY')
where fecha_vencimiento = '12/31' or fecha_vencimiento is null;

-- 3. Asegurar que las tarjetas existentes de clientes tengan su nombre real en mayúsculas
update zeny_cards z
set nombre_titular = upper(trim(c.nombre))
from customers c
where z.customer_id = c.id
  and c.nombre is not null
  and trim(c.nombre) <> ''
  and z.nombre_titular <> upper(trim(c.nombre));

-- 4. Notificar a PostgREST para refrescar cache de schema
notify pgrst, 'reload schema';
