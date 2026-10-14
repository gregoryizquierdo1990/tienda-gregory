-- Migración 21: Mesa de Cambio USDT (Venta de USDT por Bolívares con Tasa Manual Exclusiva)

create table if not exists mesa_cambio_operaciones (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id) on delete set null,
  cliente_nombre text,
  cliente_telefono text,
  monto_usdt numeric(10,2) not null check (monto_usdt > 0),
  tasa_bs numeric(14,4) not null check (tasa_bs > 0),
  total_bs numeric(16,2) not null check (total_bs > 0),
  destino_tipo text not null default 'binance_id' check (destino_tipo in ('binance_id', 'binance_email')),
  destino_valor text not null, -- ID de Binance Pay o Correo de Binance
  metodo_pago text not null default 'Pago Móvil',
  referencia_bancaria text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'completado_enviado', 'rechazado')),
  notas_admin text,
  enviado_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_mesa_cambio_estado on mesa_cambio_operaciones(estado);
create index if not exists idx_mesa_cambio_customer on mesa_cambio_operaciones(customer_id);

alter table mesa_cambio_operaciones enable row level security;

drop policy if exists mesa_cambio_customer_select on mesa_cambio_operaciones;
create policy mesa_cambio_customer_select on mesa_cambio_operaciones
  for select to authenticated, anon
  using (customer_id = auth.uid() or is_admin());

drop policy if exists mesa_cambio_customer_insert on mesa_cambio_operaciones;
create policy mesa_cambio_customer_insert on mesa_cambio_operaciones
  for insert to authenticated, anon
  with check (true);

drop policy if exists mesa_cambio_admin_all on mesa_cambio_operaciones;
create policy mesa_cambio_admin_all on mesa_cambio_operaciones
  for all to authenticated
  using (is_admin())
  with check (is_admin());

-- Configuración inicial de la Mesa de Cambio en settings (Tasa manual independiente)
insert into settings (key, value)
values ('mesa_cambio_config', '{
  "activo": true,
  "tasa_usdt_bs": 52.50,
  "min_usdt": 5,
  "max_usdt": 500,
  "metodo_pago": "Pago Móvil (BNC)",
  "banco": "BNC (0191)",
  "telefono": "04242809333",
  "documento": "V 18931731",
  "titular": "Gregory Izquierdo",
  "mensaje_aviso": "⚠️ IMPORTANTE: Por favor verifica cuidadosamente tu ID de Binance Pay o Correo electrónico antes de enviar la solicitud. No nos hacemos responsables ni realizaremos reembolsos por mala identificación de sus datos."
}'::jsonb)
on conflict (key) do nothing;
