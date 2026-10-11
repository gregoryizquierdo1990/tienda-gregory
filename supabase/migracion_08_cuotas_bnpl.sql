-- Migracion 08: Sistema de Financiamiento / Pago en Cuotas (Estilo BNPL)
-- Permite compras financiadas con pago inicial y cuotas calendarizadas con control en el portal y admin.

-- 1. Tabla de Cuotas (installments)
create table if not exists installments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  numero_cuota int not null default 1, -- 1 = inicial, 2 = cuota 2, 3 = cuota 3
  total_cuotas int not null default 2,
  monto_usd numeric(10,2) not null check (monto_usd > 0),
  monto_bs numeric(14,2),
  tasa_bs numeric(12,4),
  fecha_vencimiento date not null default current_date,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_revision','pagada','vencida')),
  metodo_id uuid references payment_methods(id),
  referencia text,
  comprobante_url text,
  pagada_at timestamptz,
  created_at timestamptz not null default now()
);

-- Indices para busquedas rapidas
create index if not exists idx_installments_order on installments(order_id);
create index if not exists idx_installments_cust on installments(customer_id, estado);
create index if not exists idx_installments_vence on installments(fecha_vencimiento, estado);

-- 2. Habilitar RLS en installments
alter table installments enable row level security;

drop policy if exists installments_user_select on installments;
create policy installments_user_select on installments for select to authenticated
  using (customer_id = auth.uid() or is_admin());

drop policy if exists installments_admin_all on installments;
create policy installments_admin_all on installments for all to authenticated
  using (is_admin()) with check (is_admin());

-- 3. Campos adicionales en customers para crédito / cupo financiado
alter table customers add column if not exists limite_credito numeric(10,2) not null default 30.00;
alter table customers add column if not exists nivel_credito text not null default 'Bronce';

-- 4. RPC para registrar pago de una cuota por el cliente
create or replace function pay_installment(
  p_installment_id uuid,
  p_metodo_id uuid,
  p_referencia text
) returns void language plpgsql security definer set search_path = public as $$
declare
  inst installments;
  r numeric;
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  select * into inst from installments where id = p_installment_id for update;
  if not found then raise exception 'Cuota no encontrada'; end if;
  if inst.customer_id <> auth.uid() and not is_admin() then raise exception 'No autorizado'; end if;
  if inst.estado = 'pagada' then raise exception 'Esta cuota ya está pagada'; end if;

  select bs_por_usd into r from exchange_rates order by fecha desc limit 1;

  update installments set
    estado = 'en_revision',
    metodo_id = p_metodo_id,
    referencia = left(coalesce(p_referencia,''), 120),
    tasa_bs = r,
    monto_bs = inst.monto_usd * coalesce(r, 0)
  where id = p_installment_id;
end $$;

grant execute on function pay_installment(uuid, uuid, text) to authenticated;

-- 5. RPC para conciliar/aprobar cuota por el admin
create or replace function approve_installment(
  p_installment_id uuid
) returns void language plpgsql security definer set search_path = public as $$
declare
  inst installments;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into inst from installments where id = p_installment_id for update;
  if not found then raise exception 'Cuota no encontrada'; end if;

  update installments set
    estado = 'pagada',
    pagada_at = coalesce(pagada_at, now())
  where id = p_installment_id;
end $$;

grant execute on function approve_installment(uuid) to authenticated;
