-- Confirmar email del usuario de prueba para poder iniciar sesión directamente
update auth.users 
set email_confirmed_at = now() 
where email = 'cliente.prueba@gregoryizquierdo.xyz';

-- Asegurar saldo de prueba Zeny y código CLT
update public.customers
set zeny_balance = 50.00,
    nombre = 'Carlos Mendoza (Prueba)',
    telefono = '+584121112233'
where email = 'cliente.prueba@gregoryizquierdo.xyz';

-- Emitirle una tarjeta Zeny de prueba para que la vea en su portal
insert into public.zeny_cards (
  customer_id,
  numero_tarjeta,
  nombre_titular,
  codigo_activacion,
  fecha_vencimiento,
  estado
)
select 
  id,
  '4532 8910 2345 6789',
  'CARLOS MENDOZA',
  '784',
  '12/31',
  'activa'
from public.customers 
where email = 'cliente.prueba@gregoryizquierdo.xyz'
on conflict (customer_id) do update set
  estado = 'activa',
  numero_tarjeta = '4532 8910 2345 6789',
  codigo_activacion = '784';
