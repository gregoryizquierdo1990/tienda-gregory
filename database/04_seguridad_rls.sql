-- ==============================================================================
-- 04_SEGURIDAD_RLS.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Políticas de Row Level Security (RLS) y Control de Acceso
-- ==============================================================================

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.franchises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mother_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zeny_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zeny_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.google_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recargas_puntos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recargas_abonos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesa_cambio_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesa_cambio_operaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telegram_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.franchise_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.franchise_wallet_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all" ON public.admins;
CREATE POLICY "admin_all" ON public.admins
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_manage" ON public.admins;
CREATE POLICY "admin_manage" ON public.admins
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_read" ON public.admins;
CREATE POLICY "admin_read" ON public.admins
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "admin_all" ON public.banners;
CREATE POLICY "admin_all" ON public.banners
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_ban" ON public.banners;
CREATE POLICY "pub_ban" ON public.banners
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING ((activo AND ((inicio IS NULL) OR (inicio <= CURRENT_DATE)) AND ((fin IS NULL) OR (fin >= CURRENT_DATE))))
;

DROP POLICY IF EXISTS "admin_all" ON public.bot_commands;
CREATE POLICY "admin_all" ON public.bot_commands
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.categories;
CREATE POLICY "admin_all" ON public.categories
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_cat" ON public.categories;
CREATE POLICY "pub_cat" ON public.categories
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (activo)
;

DROP POLICY IF EXISTS "admin_all" ON public.customers;
CREATE POLICY "admin_all" ON public.customers
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_cust" ON public.customers;
CREATE POLICY "me_cust" ON public.customers
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "me_cust_upd" ON public.customers;
CREATE POLICY "me_cust_upd" ON public.customers
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING ((id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.exchange_rates;
CREATE POLICY "admin_all" ON public.exchange_rates
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_rates" ON public.exchange_rates;
CREATE POLICY "pub_rates" ON public.exchange_rates
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (true)
;

DROP POLICY IF EXISTS "admin_all" ON public.expenses;
CREATE POLICY "admin_all" ON public.expenses
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.faqs;
CREATE POLICY "admin_all" ON public.faqs
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_faq" ON public.faqs;
CREATE POLICY "pub_faq" ON public.faqs
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (activo)
;

DROP POLICY IF EXISTS "fq_app_anon_insert" ON public.franchise_applications;
CREATE POLICY "fq_app_anon_insert" ON public.franchise_applications
  AS PERMISSIVE
  FOR INSERT
  TO anon
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "fq_app_auth_all" ON public.franchise_applications;
CREATE POLICY "fq_app_auth_all" ON public.franchise_applications
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "fq_wallet_anon_select" ON public.franchise_wallet_ledger;
CREATE POLICY "fq_wallet_anon_select" ON public.franchise_wallet_ledger
  AS PERMISSIVE
  FOR SELECT
  TO anon
  USING (true)
;

DROP POLICY IF EXISTS "fq_wallet_auth_all" ON public.franchise_wallet_ledger;
CREATE POLICY "fq_wallet_auth_all" ON public.franchise_wallet_ledger
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "franchises_admin" ON public.franchises;
CREATE POLICY "franchises_admin" ON public.franchises
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "franchises_admin_full" ON public.franchises;
CREATE POLICY "franchises_admin_full" ON public.franchises
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "franchises_public_select" ON public.franchises;
CREATE POLICY "franchises_public_select" ON public.franchises
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (true)
;

DROP POLICY IF EXISTS "admin_all" ON public.google_integrations;
CREATE POLICY "admin_all" ON public.google_integrations
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.incidents;
CREATE POLICY "admin_all" ON public.incidents
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_inc_ins" ON public.incidents;
CREATE POLICY "me_inc_ins" ON public.incidents
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (((customer_id = ( SELECT auth.uid() AS uid)) AND (estado = 'abierta'::text)))
;

DROP POLICY IF EXISTS "me_inc_sel" ON public.incidents;
CREATE POLICY "me_inc_sel" ON public.incidents
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "installments_admin_all" ON public.installments;
CREATE POLICY "installments_admin_all" ON public.installments
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "installments_user_select" ON public.installments;
CREATE POLICY "installments_user_select" ON public.installments
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (((customer_id = auth.uid()) OR (reseller_id = auth.uid()) OR is_admin()))
;

DROP POLICY IF EXISTS "admin_all" ON public.invoices;
CREATE POLICY "admin_all" ON public.invoices
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_inv" ON public.invoices;
CREATE POLICY "me_inv" ON public.invoices
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.login_log;
CREATE POLICY "admin_all" ON public.login_log
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_log" ON public.login_log;
CREATE POLICY "me_log" ON public.login_log
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "mesa_caja_admin_all" ON public.mesa_cambio_caja;
CREATE POLICY "mesa_caja_admin_all" ON public.mesa_cambio_caja
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "mesa_cambio_admin_all" ON public.mesa_cambio_operaciones;
CREATE POLICY "mesa_cambio_admin_all" ON public.mesa_cambio_operaciones
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "mesa_cambio_customer_insert" ON public.mesa_cambio_operaciones;
CREATE POLICY "mesa_cambio_customer_insert" ON public.mesa_cambio_operaciones
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((((customer_id = ( SELECT auth.uid() AS uid)) AND (estado = 'pendiente'::text) AND (notas_admin IS NULL) AND (enviado_at IS NULL)) OR ( SELECT is_admin() AS is_admin)))
;

DROP POLICY IF EXISTS "mesa_cambio_customer_select" ON public.mesa_cambio_operaciones;
CREATE POLICY "mesa_cambio_customer_select" ON public.mesa_cambio_operaciones
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (((customer_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin)))
;

DROP POLICY IF EXISTS "admin_all" ON public.mother_accounts;
CREATE POLICY "admin_all" ON public.mother_accounts
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.orders;
CREATE POLICY "admin_all" ON public.orders
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_orders" ON public.orders;
CREATE POLICY "me_orders" ON public.orders
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "partner_commissions_admin_all" ON public.partner_commissions;
CREATE POLICY "partner_commissions_admin_all" ON public.partner_commissions
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "partner_commissions_reseller_select" ON public.partner_commissions;
CREATE POLICY "partner_commissions_reseller_select" ON public.partner_commissions
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((vendedor_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.payment_methods;
CREATE POLICY "admin_all" ON public.payment_methods
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pm_autenticados" ON public.payment_methods;
CREATE POLICY "pm_autenticados" ON public.payment_methods
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (activo)
;

DROP POLICY IF EXISTS "admin_all" ON public.products;
CREATE POLICY "admin_all" ON public.products
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_prod" ON public.products;
CREATE POLICY "pub_prod" ON public.products
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (activo)
;

DROP POLICY IF EXISTS "admin_all" ON public.profiles_inventory;
CREATE POLICY "admin_all" ON public.profiles_inventory
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.purchases;
CREATE POLICY "admin_all" ON public.purchases
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.push_subscriptions;
CREATE POLICY "admin_all" ON public.push_subscriptions
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "recargas_abonos_admin" ON public.recargas_abonos;
CREATE POLICY "recargas_abonos_admin" ON public.recargas_abonos
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "recargas_puntos_admin" ON public.recargas_puntos;
CREATE POLICY "recargas_puntos_admin" ON public.recargas_puntos
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ref_admin" ON public.refunds;
CREATE POLICY "ref_admin" ON public.refunds
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ref_me" ON public.refunds;
CREATE POLICY "ref_me" ON public.refunds
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.settings;
CREATE POLICY "admin_all" ON public.settings
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_settings" ON public.settings;
CREATE POLICY "admin_settings" ON public.settings
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_settings" ON public.settings;
CREATE POLICY "pub_settings" ON public.settings
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING ((key = ANY (ARRAY['negocio'::text, 'zeny'::text, 'reserva'::text, 'app'::text, 'plantillas_mensajes'::text, 'niveles_beneficios'::text, 'mesa_cambio_config'::text])))
;

DROP POLICY IF EXISTS "telegram_sessions_service_role" ON public.telegram_sessions;
CREATE POLICY "telegram_sessions_service_role" ON public.telegram_sessions
  AS PERMISSIVE
  FOR ALL
  TO public
  USING ((auth.role() = 'service_role'::text))
;

DROP POLICY IF EXISTS "tr_admin_all" ON public.transfers;
CREATE POLICY "tr_admin_all" ON public.transfers
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "zeny_cards_admin_all" ON public.zeny_cards;
CREATE POLICY "zeny_cards_admin_all" ON public.zeny_cards
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "zeny_cards_user_select" ON public.zeny_cards;
CREATE POLICY "zeny_cards_user_select" ON public.zeny_cards
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (((customer_id = ( SELECT auth.uid() AS uid)) OR is_admin()))
;

DROP POLICY IF EXISTS "admin_all" ON public.zeny_ledger;
CREATE POLICY "admin_all" ON public.zeny_ledger
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_ledger" ON public.zeny_ledger;
CREATE POLICY "me_ledger" ON public.zeny_ledger
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "me_recarga" ON public.zeny_ledger;
CREATE POLICY "me_recarga" ON public.zeny_ledger
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (((customer_id = ( SELECT auth.uid() AS uid)) AND (tipo = 'recarga'::text) AND (estado = 'pendiente'::text) AND (monto > (0)::numeric)))
;

