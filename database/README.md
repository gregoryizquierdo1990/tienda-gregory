# 🐘 Suite de Instalación y Arquitectura PostgreSQL Independiente
### Emprendimiento Digital Gregory Izquierdo

Esta carpeta contiene la **Suite de Base de Datos Maestra y Consolidada**, diseñada para que puedas desplegar la base de datos completa de la tienda en **cualquier instancia de PostgreSQL estándar** (Docker, VPS Ubuntu/Debian, AWS RDS, Neon, Railway, Render, etc.) o en una **nueva instancia limpia de Supabase**, sin necesidad de ejecutar las 57 migraciones históricas incrementales ni toparte con scripts repetidos o incompatibles.

---

## ❓ ¿Por qué no correr las 57 migraciones históricas una por una?

1. **Parches vs. Estado Final:** Las migraciones históricas (`migracion_01` a `migracion_57`) fueron parches progresivos creados durante meses de desarrollo. Por ejemplo, la función `renovar_suscripcion_perfil` se modificó 5 veces; ejecutar scripts viejos instalaría versiones obsoletas con bugs que luego tendrías que sobreescribir.
2. **Dependencias y Conflictos de Índices:** Muchas migraciones intermedias modificaron columnas que antes se llamaban de otra forma o crearon índices que después fueron eliminados.
3. **Dependencia de Supabase (`auth.users`, `auth.uid()`, `pg_net`):** Las migraciones asumen que existe el motor GoTrue de Supabase. Si las corres en un PostgreSQL tradicional puro, fallarán en la primera línea al no encontrar el schema `auth` ni la función `auth.uid()`.

---

## 📁 Estructura de la Suite `database/`

Para máxima flexibilidad, tienes la opción de correr los archivos por módulos separados o todo de una sola vez mediante el archivo maestro:

| Archivo | Propósito |
| :--- | :--- |
| [**`00_compatibilidad_auth_y_extensiones.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/00_compatibilidad_auth_y_extensiones.sql) | Extensiones (`pgcrypto`, `uuid-ossp`), Capa de compatibilidad (Shim) de `auth.users`, función universal `auth.uid()` y stub seguro de `net.http_post`. |
| [**`01_tablas_e_indices.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/01_tablas_e_indices.sql) | DDL consolidado de las 35 tablas con todas sus columnas definitivas, llaves foráneas, 2 vistas oficiales y 60+ índices de rendimiento. |
| [**`02_funciones_y_rpcs.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/02_funciones_y_rpcs.sql) | 67 funciones maestras y procedimientos almacenados (RPCs) sin duplicados ni versiones obsoletas. |
| [**`03_triggers.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/03_triggers.sql) | Triggers automáticos para guardas de pedidos, cifrado AES-256 de claves y sincronizaciones. |
| [**`04_seguridad_rls.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/04_seguridad_rls.sql) | Activación de Row Level Security (RLS) y 63 políticas de aislamiento por usuario y revendedor. |
| [**`05_datos_semilla_iniciales.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/05_datos_semilla_iniciales.sql) | Datos semilla iniciales: 4 categorías, 9 métodos de pago (Pago Móvil, Binance, etc.), tasa BCV, clave de cifrado, 69 productos oficiales con precios mayoristas y administradores por defecto. |
| [**`instalar_todo.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/instalar_todo.sql) | **Archivo "All-In-One" consolidado.** Contiene todo lo anterior en el orden exacto para ejecutar con 1 solo clic. |

---

## 🚀 Guía de Instalación Paso a Paso

### Opción A: En un Servidor PostgreSQL Estándar (Docker, VPS Ubuntu, AWS, Railway, Neon)

1. **Crear la base de datos:**
   ```bash
   createdb -U postgres tienda_gregory
   ```

2. **Ejecutar el script maestro `instalar_todo.sql`:**
   ```bash
   psql -U postgres -d tienda_gregory -f database/instalar_todo.sql
   ```
   *(También puedes abrir pgAdmin, DBeaver o Navicat, conectar a tu base de datos y ejecutar el contenido de `database/instalar_todo.sql`).*

3. **¿Cómo funciona la autenticación sin Supabase?**
   - El script `00_compatibilidad_auth_y_extensiones.sql` crea el esquema `auth` y la tabla `auth.users`.
   - La función `auth.uid()` está diseñada para leer el ID del usuario actual mediante la variable de sesión:
     ```sql
     SET LOCAL app.current_user_id = 'b7fa01a4-baf1-4818-a81b-4fcbbfbeae0c';
     -- O vía JWT claim estándar:
     SET LOCAL request.jwt.claim.sub = 'b7fa01a4-baf1-4818-a81b-4fcbbfbeae0c';
     ```
   - Si creas un backend en Node.js, Express, Python o Go, en cada petición del cliente simplemente ejecutas esa sentencia antes de llamar a los RPCs o consultas de la tienda.

---

### Opción B: En una Nueva Instancia de Supabase (Cloud o Self-Hosted)

1. Crea un nuevo proyecto en [Supabase Dashboard](https://supabase.com/dashboard).
2. Ve a la sección **SQL Editor**.
3. Abre o copia el contenido de [**`database/instalar_todo.sql`**](file:///home/admin1/Documentos/tienda-gregory/database/instalar_todo.sql).
4. Presiona **Run** (Ejecutar).
5. Ve a **Project Settings > API** y copia:
   - `Project URL`
   - `anon public key`
6. En tu archivo `.env` o en Vercel, actualiza `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
7. ¡Listo! La aplicación funcionará inmediatamente con el catálogo cargado, métodos de pago y perfiles listos para vender.

---

## 📦 Migraciones Históricas
Las migraciones originales de la 02 a la 57 se conservan en la carpeta `supabase/` únicamente como registro histórico de auditoría de versiones. Para cualquier nueva instalación, utiliza siempre esta suite `database/`.
