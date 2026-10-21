-- ==============================================================================
-- 03_TRIGGERS.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Triggers de Seguridad, Cifrado, Notificaciones y Automatizaciones
-- ==============================================================================

SET search_path = public, extensions;

DROP TRIGGER IF EXISTS t_auto_provision_zeny_card ON public.customers;
CREATE TRIGGER t_auto_provision_zeny_card
  AFTER INSERT ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION trg_auto_provision_zeny_card();

DROP TRIGGER IF EXISTS t_customers_guard ON public.customers;
CREATE TRIGGER t_customers_guard
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION customers_guard();

DROP TRIGGER IF EXISTS t_sync_customer_role ON public.customers;
CREATE TRIGGER t_sync_customer_role
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION trg_sync_customer_role();

DROP TRIGGER IF EXISTS trg_protect_customer_fields ON public.customers;
CREATE TRIGGER trg_protect_customer_fields
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION protect_customer_fields();

DROP TRIGGER IF EXISTS t_notify_incident ON public.incidents;
CREATE TRIGGER t_notify_incident
  AFTER INSERT ON public.incidents
  FOR EACH ROW
  EXECUTE FUNCTION trg_notify_incident();

DROP TRIGGER IF EXISTS t_enc_mother ON public.mother_accounts;
CREATE TRIGGER t_enc_mother
  BEFORE INSERT ON public.mother_accounts
  FOR EACH ROW
  EXECUTE FUNCTION enc_mother();

DROP TRIGGER IF EXISTS t_purchase_mother ON public.mother_accounts;
CREATE TRIGGER t_purchase_mother
  AFTER INSERT ON public.mother_accounts
  FOR EACH ROW
  EXECUTE FUNCTION purchase_from_mother();

DROP TRIGGER IF EXISTS t_notify_order ON public.orders;
CREATE TRIGGER t_notify_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_notify_order();

DROP TRIGGER IF EXISTS t_orders_guard ON public.orders;
CREATE TRIGGER t_orders_guard
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION orders_guard();

DROP TRIGGER IF EXISTS t_orders_sync_installments ON public.orders;
CREATE TRIGGER t_orders_sync_installments
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION orders_sync_installments();

DROP TRIGGER IF EXISTS trg_procesar_comision_socio_orden ON public.orders;
CREATE TRIGGER trg_procesar_comision_socio_orden
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION procesar_comision_socio_orden();

DROP TRIGGER IF EXISTS t_enc_profile ON public.profiles_inventory;
CREATE TRIGGER t_enc_profile
  BEFORE INSERT ON public.profiles_inventory
  FOR EACH ROW
  EXECUTE FUNCTION enc_profile();

DROP TRIGGER IF EXISTS t_ledger ON public.zeny_ledger;
CREATE TRIGGER t_ledger
  AFTER INSERT ON public.zeny_ledger
  FOR EACH ROW
  EXECUTE FUNCTION apply_ledger();

DROP TRIGGER IF EXISTS t_notify_recarga ON public.zeny_ledger;
CREATE TRIGGER t_notify_recarga
  AFTER INSERT ON public.zeny_ledger
  FOR EACH ROW
  EXECUTE FUNCTION trg_notify_recarga();

