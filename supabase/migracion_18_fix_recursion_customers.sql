-- ==============================================================================
-- MIGRACIÓN 18: CORRECCIÓN DE RECURSIÓN INFINITA EN POLÍTICA DE CUSTOMERS
-- ==============================================================================
-- Causa del error: La política 'me_cust_upd' en la tabla 'customers' tenía una
-- subconsulta interna hacia la misma tabla 'customers' (select ... from customers c).
-- En PostgreSQL, consultar la misma tabla dentro de su propia regla RLS genera
-- el error: "infinite recursion detected in policy for relation 'customers'".
--
-- Solución:
-- 1. Eliminar la subconsulta recursiva de la política RLS 'me_cust_upd'.
-- 2. Proteger el saldo Zeny y el límite de crédito mediante un TRIGGER BEFORE UPDATE,
--    garantizando que ningún cliente pueda alterar su saldo mientras se permite la
--    actualización fluida de su perfil, nombre, teléfono y contraseña.
-- ==============================================================================

-- 1. Eliminar la política con subconsulta recursiva y recrearla limpia
drop policy if exists me_cust_upd on customers;

create policy me_cust_upd on customers
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- 2. Trigger para blindar los campos financieros contra alteraciones no autorizadas
create or replace function protect_customer_financial_fields()
returns trigger
language plpgsql
security definer
set search_path = public as $$
begin
  -- Si no es el administrador, el cliente no puede alterar su saldo Zeny ni su límite de crédito
  if not is_admin() then
    new.zeny_balance := old.zeny_balance;
    new.limite_credito := old.limite_credito;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_customer_financial_fields on customers;
create trigger trg_protect_customer_financial_fields
before update on customers
for each row
execute function protect_customer_financial_fields();

-- 3. Blindar también la tabla 'admins' para evitar cualquier recursión en is_admin()
drop policy if exists admin_all on admins;
create policy admin_read on admins for select to authenticated using (true);
create policy admin_manage on admins for all to authenticated using (is_admin()) with check (is_admin());

-- 4. Notificar a PostgREST para recargar el esquema
notify pgrst, 'reload schema';
