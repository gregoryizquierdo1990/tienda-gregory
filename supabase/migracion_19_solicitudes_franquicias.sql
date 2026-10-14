-- Migración 19: Tabla para Solicitudes de Franquicias y Notificaciones
create table if not exists franchise_applications (
  id uuid primary key default gen_random_uuid(),
  business_name text not null,
  owner_name text not null,
  email text not null,
  phone text not null,
  telegram_user text,
  notes text,
  status text not null default 'pending' check (status in ('pending', 'contacted', 'approved', 'rejected')),
  ip_address text,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Índices de consulta rápida
create index if not exists idx_franchise_apps_status on franchise_applications(status);
create index if not exists idx_franchise_apps_created on franchise_applications(created_at desc);

-- RLS
alter table franchise_applications enable row level security;

-- Permitir a usuarios anónimos (aspirantes a franquicia) postularse
drop policy if exists franchise_apps_anon_insert on franchise_applications;
create policy franchise_apps_anon_insert on franchise_applications
  for insert to anon
  with check (true);

-- Permitir a administradores gestionar todas las solicitudes
drop policy if exists franchise_apps_admin_all on franchise_applications;
create policy franchise_apps_admin_all on franchise_applications
  for all to authenticated
  using (is_admin())
  with check (is_admin());
