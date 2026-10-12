# 📘 GUÍA OFICIAL PARA EL FRANQUICIADO / SOCIO DIGITAL
**Plataforma de Comercio Digital Multi-Tenant**  
*Infraestructura SaaS provista por Gregory Izquierdo*

---

¡Bienvenido a tu propia tienda digital! Has adquirido una franquicia tecnológica lista para operar, vender cuentas de streaming, pantallas compartidas, licencias y productos digitales de manera automatizada.

Esta guía contiene todo lo que necesitas saber para configurar tu portal, cobrar a tus clientes, despachar credenciales y mantener tu negocio activo y rentable.

---

## 1. 🌐 Tu Dirección Web (URL de tu Tienda)

Tu tienda opera en un subdominio exclusivo asignado a tu marca:
- **Ejemplo:** `https://tumarca.gregoryizquierdo.xyz`

> 💡 **Nota importante:** Todos tus clientes entrarán por este enlace. En este portal verán tu nombre comercial, tu logotipo, tus redes de atención y tus métodos de pago.

---

## 2. 🔑 Primer Acceso a tu Panel de Control

1. Ingresa a la URL de tu tienda.
2. Haz clic en el botón superior **"Admin"** o **"Ingresar"**.
3. Inicia sesión con el correo electrónico registrado en tu contrato.
4. Si es tu primera vez o no recuerdas la clave:
   - Haz clic en **"¿Olvidaste tu contraseña?"** o solicita a la central que presione el botón de restauración de clave.
   - Recibirás un enlace seguro a tu bandeja de correo para crear tu clave personal.

---

## 3. ⚙️ Configuración Inicial Obligatoria (Paso a Paso)

Antes de hacer tu primera venta, debes configurar dónde recibirás el dinero de tus clientes:

### A. Configurar tus Métodos de Pago (Dónde te pagan a ti)
1. En el menú lateral del Administrador, entra a **💳 Métodos de Pago**.
2. Pulsa en **"+ Agregar"** para registrar tus cuentas:
   - **Pago Móvil (Venezuela):** Banco, Teléfono (0412/0414/0424/0416), Cédula/RIF y Titular.
   - **Transferencias Bancarias:** Banco, Número de cuenta (20 dígitos), Cédula y Nombre.
   - **Binance Pay / USDT:** Correo de Binance Pay o Pay ID.
   - **Zinli / Zelle / Efectivo:** Correo electrónico registrado o indicaciones de entrega.
3. Puedes activar o pausar cualquier método en cualquier momento con el selector de estado.

> ⚠️ **Recuerda:** Todo el dinero que pagan tus clientes va **100% directo a tus cuentas bancarias**. La central no retiene tu dinero de ventas.

### B. Personalizar Datos de Contacto y Soporte
1. Ve a **⚙️ Ajustes ➔ Negocio**.
2. Verifica y coloca:
   - **Nombre de tu Marca.**
   - **Teléfono de WhatsApp:** Con formato internacional (ej. `+584121234567`). Este número es el que abrirá el botón flotante verde de WhatsApp en tu tienda para atender dudas de clientes.
   - **Telegram:** Tu usuario o bot de soporte.
   - **Correo de Atención al Cliente.**

---

## 4. 🧭 Explicación de Cada Módulo de tu Panel

### 📦 1. Catálogo y Productos (`products`)
- Aquí visualizas las pantallas, cuentas completas y servicios que ofreces.
- Puedes modificar el precio de venta al público en USD, agregar descripciones atractivas o pausar productos que no tengas disponibles temporalmente.
- **Precio Mayorista / Revendedor:** Puedes configurar precios preferenciales para clientes recurrentes que te compren por volumen.

### 🔐 2. Cuentas Madre e Inventario de Perfiles (`mother_accounts` / `profiles_inventory`)
- Es el corazón del sistema donde se almacenan las cuentas originales (Netflix, Disney+, Max, etc.).
- Cada cuenta madre tiene sus credenciales cifradas y se divide en perfiles (Perfil 1, Perfil 2, PIN).
- Cuando un cliente compra y tú apruebas el pedido, el sistema toma automáticamente un perfil disponible y se lo entrega al cliente en su portal.

### 🛒 3. Pedidos (`orders`)
- Cuando un cliente hace una compra en tu tienda, el pedido llega con estado **"pendiente"**.
- En esta tabla verás: Nombre del cliente, producto seleccionado, método de pago usado y número de referencia o captura de pantalla.
- **Botón "Aprobar / Entregar":** Tras verificar en tu app de banco que el dinero cayó en tu cuenta, pulsas este botón y el sistema envía las credenciales de inmediato.
- **Botón "Crédito":** Si es un cliente de confianza o revendedor al que le das financiamiento, puedes activar el servicio a crédito eligiendo los días de plazo (ej. 7 o 15 días).

### 👥 4. Clientes (`customers`)
- Lista de todas las personas registradas en tu tienda.
- Puedes ver su historial de pedidos, saldo de ZenyPoints (puntos de fidelidad) y si tienen compras a cuotas activas.

### 📅 5. Vencimientos y Renovaciones (`vencimientos`)
- Te avisa diariamente qué cuentas o pantallas están por vencer (a 3 días, hoy o vencidas).
- Te permite contactar al cliente por WhatsApp con 1 clic para ofrecerle la renovación antes de que pierda el acceso, asegurando tu ingreso mensual recurrente.

### 💵 6. Finanzas y Ganancias (`finanzas`)
- Gráficas y balances automáticos de tus ingresos en USD y Bolívares.
- Te muestra tu margen de ganancia neta, ticket promedio y productos más vendidos del mes.

### 🤝 7. Revendedores VIP (`revendedores`)
- Si tienes aliados que te revenden perfiles, puedes marcarlos como revendedores para que el sistema les aplique precios mayoristas automáticamente.

---

## 5. 💰 El Canon Mensual de la Franquicia

Para mantener tu tienda activa, servidores de alta velocidad, base de datos en la nube y soporte técnico, se cancela un **Canon Mensual** establecido en tu contrato.

1. **Periodicidad:** Cada 30 días continuos.
2. **Fecha de Vencimiento:** Visible en el expediente de tu franquicia.
3. **Cómo Pagarlo:** Transfiere el canon a las cuentas oficiales de la Central Gregory Izquierdo y envía el comprobante por WhatsApp al menos 24 horas antes del vencimiento.
4. **Mora:** Si el canon no se cancela a tiempo, el sistema pausará temporalmente el acceso público a tu tienda hasta la conciliación del pago.

---

## 6. 🚨 Cláusula de Cumplimiento, Ética y Tolerancia Cero al Fraude

Tu tienda opera con la tecnología y respaldo de red de Gregory Izquierdo SaaS, pero gozas de total autonomía comercial. Con esta autonomía viene una responsabilidad legal:

1. **Garantía al Cliente Final:** Es tu deber atender a tus clientes con amabilidad y reponer los perfiles caídos dentro de los días de garantía estipulados.
2. **Kill-Switch Anti-Fraude:**  
   Si la central recibe denuncias comprobadas de cobros no entregados, estafas o apropiación indebida de dinero:
   - **La tienda será suspendida de inmediato mediante el Kill-Switch de seguridad.**
   - La pantalla mostrará un aviso de suspensión por auditoría de seguridad.
   - El contrato quedará rescindido sin derecho a reembolso del canon.
3. **Deslinde Legal:** En el pie de página de tu tienda se muestra de forma transparente que eres el titular y responsable comercial directo de las ventas ante tus clientes y los entes tributarios.

---

## 7. 📞 Canales de Soporte Técnico para Franquiciados

Si requieres asistencia técnica, fallas de sistema o actualización de módulos:
- **WhatsApp Central:** Contacto directo con el Administrador General.
- **Correo Electrónico:** `emprendimientogregoryizquierdo@gmail.com`
- **Horario de Atención para Franquicias:** Lunes a Sábado de 8:00 AM a 8:00 PM.

---
*¡Te deseamos el mayor de los éxitos en las ventas de tu nueva franquicia digital!*
