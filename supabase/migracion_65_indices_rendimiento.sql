-- Rendimiento: indices adicionales para FKs y columnas filtradas frecuentemente.
-- Aplicar en Supabase SQL Editor. Idempotente.
create index if not exists idx_orders_profile on orders(profile_id);
create index if not exists idx_orders_vendedor on orders(vendedor_id);
create index if not exists idx_orders_estado_vence on orders(estado, vence);
create index if not exists idx_orders_created on orders(created_at desc);
create index if not exists idx_profiles_vendedor on profiles_inventory(vendedor_id);
create index if not exists idx_profiles_assigned on profiles_inventory(assigned_customer_id);
create index if not exists idx_profiles_estado on profiles_inventory(estado);
create index if not exists idx_incidents_vendedor on incidents(vendedor_id);
create index if not exists idx_installments_reseller on installments(reseller_id);
create index if not exists idx_installments_customer on installments(customer_id);
create index if not exists idx_partner_comm_vendedor on partner_commissions(vendedor_id);
create index if not exists idx_mesa_ops_customer on mesa_cambio_operaciones(customer_id);
create index if not exists idx_zeny_cards_customer on zeny_cards(customer_id);
create index if not exists idx_refunds_vendedor on refunds(vendedor_id) ;
-- RLS: asegurar que las politicas usen (select auth.uid()) (ya en migracion_06)
