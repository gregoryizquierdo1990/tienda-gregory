-- ==============================================================================
-- MIGRACIÓN 50: CASCADE EN INVOICES, INSTALLMENTS, REFUNDS Y RPC admin_delete_order()
-- Soluciona: "update or delete on table 'orders' violates foreign key constraint 'invoices_order_id_fkey'"
-- ==============================================================================

begin;

-- 1. Actualizar foreign key en invoices a ON DELETE CASCADE
alter table public.invoices drop constraint if exists invoices_order_id_fkey;
alter table public.invoices
  add constraint invoices_order_id_fkey
  foreign key (order_id) references public.orders(id)
  on delete cascade;

-- 2. Actualizar foreign key en installments a ON DELETE CASCADE
alter table public.installments drop constraint if exists installments_order_id_fkey;
alter table public.installments
  add constraint installments_order_id_fkey
  foreign key (order_id) references public.orders(id)
  on delete cascade;

-- 3. Actualizar foreign key en refunds a ON DELETE CASCADE
alter table public.refunds drop constraint if exists refunds_order_id_fkey;
alter table public.refunds
  add constraint refunds_order_id_fkey
  foreign key (order_id) references public.orders(id)
  on delete cascade;

-- 4. Actualizar foreign key en transfers a ON DELETE CASCADE
alter table public.transfers drop constraint if exists transfers_order_id_fkey;
alter table public.transfers
  add constraint transfers_order_id_fkey
  foreign key (order_id) references public.orders(id)
  on delete cascade;

-- 5. Actualizar foreign key en incidents a ON DELETE SET NULL
alter table public.incidents drop constraint if exists incidents_order_id_fkey;
alter table public.incidents
  add constraint incidents_order_id_fkey
  foreign key (order_id) references public.orders(id)
  on delete set null;

-- 6. Actualizar foreign key en zeny_ledger a ON DELETE SET NULL
alter table public.zeny_ledger drop constraint if exists zeny_ledger_order_id_fkey;
alter table public.zeny_ledger
  add constraint zeny_ledger_order_id_fkey
  foreign key (order_id) references public.orders(id)
  on delete set null;

-- 7. RPC definitiva para eliminar pedidos de forma segura desde el panel administrativo
create or replace function public.admin_delete_order(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_profile_id uuid;
  v_order_estado text;
begin
  if not is_admin() then
    raise exception 'Solo administradores pueden eliminar pedidos.';
  end if;

  select profile_id, estado into v_profile_id, v_order_estado
  from public.orders where id = p_order_id for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Pedido no encontrado');
  end if;

  -- Si el pedido retenía un perfil reservado o pendiente y se elimina, liberar el perfil
  if v_profile_id is not null then
    if not exists (
      select 1 from public.orders
      where profile_id = v_profile_id and id <> p_order_id and estado in ('entregado', 'pagado')
    ) then
      update public.profiles_inventory
      set estado = 'disponible',
          assigned_customer_id = null
      where id = v_profile_id and estado in ('reservado', 'pendiente');
    end if;
  end if;

  -- Limpiar dependencias asociadas a este pedido
  delete from public.installments where order_id = p_order_id;
  delete from public.invoices where order_id = p_order_id;
  delete from public.refunds where order_id = p_order_id;
  delete from public.transfers where order_id = p_order_id;
  update public.incidents set order_id = null where order_id = p_order_id;
  update public.zeny_ledger set order_id = null where order_id = p_order_id;

  -- Eliminar la orden
  delete from public.orders where id = p_order_id;

  return jsonb_build_object('success', true, 'order_id', p_order_id);
end $$;

grant execute on function public.admin_delete_order(uuid) to authenticated;

commit;
