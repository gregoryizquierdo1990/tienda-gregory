-- Endurecimiento de permisos de funciones (ya incluido al final de schema.sql)
revoke execute on function apply_ledger(), enc_mother(), enc_profile(), orders_guard(), purchase_from_mother(), handle_new_user() from public, anon, authenticated;
revoke execute on function is_admin(), deliver_order(uuid), reject_order(uuid), transfer_order(uuid,uuid,text,boolean), generate_profiles(uuid,uuid,int,text),
  finanzas(int), reveal_secret(text), refund_order(uuid,numeric,text,text,boolean), my_credentials(), cancel_my_order(uuid) from public, anon;
grant execute on function is_admin(), deliver_order(uuid), reject_order(uuid), transfer_order(uuid,uuid,text,boolean), generate_profiles(uuid,uuid,int,text),
  finanzas(int), reveal_secret(text), refund_order(uuid,numeric,text,text,boolean), my_credentials(), cancel_my_order(uuid) to authenticated;
revoke execute on function stock() from public;
grant execute on function stock() to anon, authenticated;

-- Solo si pg_net quedo en el esquema public (aviso de seguridad de Supabase):
-- drop extension if exists pg_net; create extension if not exists pg_net with schema extensions;
