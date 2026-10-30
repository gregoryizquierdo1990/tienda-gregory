import { requireAdmin, sbRest } from './_lib.js';

export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;
  if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: 'Falta GEMINI_API_KEY en las variables de entorno de Vercel' });

  const body = req.body || {};
  let contents = body.contents;
  if (!contents || !Array.isArray(contents) || contents.length === 0) {
    const prompt = String(body.prompt || '').slice(0, 8000);
    if (!prompt) return res.status(400).json({ error: 'Falta el mensaje o prompt' });
    contents = [{ role: 'user', parts: [{ text: prompt }] }];
  }

  // 1. Obtener contexto en tiempo real de la base de datos de la tienda
  let storeContext = null;
  try {
    storeContext = await sbRest('rpc/get_gemini_store_context', { method: 'POST', body: '{}' });
  } catch (err) {
    console.error('Error al obtener contexto de la tienda para Gemini:', err);
  }

  // 2. Construir la instrucción del sistema con toda la base de conocimiento de la tienda
  const contextStr = storeContext
    ? JSON.stringify(storeContext, null, 2)
    : 'No se pudo cargar el contexto dinámico de Supabase en este momento.';

  const systemInstruction = {
    parts: [{
      text: `Eres el Asistente Ejecutivo e Inteligencia de Negocio en tiempo real de "Emprendimiento Gregory Izquierdo" (tienda en línea de cuentas de streaming, entretenimiento digital, perfiles y combos en Venezuela).
Estás conversando directamente con Gregory Izquierdo (Dueño, Fundador y Administrador General del negocio).

TIENES ACCESO DIRECTO Y EN TIEMPO REAL A LA BASE DE DATOS DE LA TIENDA MEDIANTE EL SIGUIENTE REPORTE OPERATIVO ACTUALIZADO:
\`\`\`json
${contextStr}
\`\`\`

REGLAS CRÍTICAS DE CONOCIMIENTO Y RESPUESTA:
1. PRECIOS Y PRODUCTOS:
   - Tienes el catálogo completo con nombres oficiales, duración en días y 3 esquemas de precios:
     * "precio_usd_pvp": Precio de venta al público en USD (cliente final).
     * "precio_revendedor_usd": Precio especial en USD para revendedores mayoristas autorizados.
     * "precio_binance_usdt": Precio preferencial pagando vía cripto / Binance USDT.
   - Si Gregory te pregunta por el precio de cualquier producto o perfil (por ejemplo: "cuánto es el precio de revendedor del Perfil Paramount" o "precio de Netflix"), RESPONDE CON EL PRECIO EXACTO DEL CATÁLOGO. No digas jamás que no tienes acceso a los precios internos, porque los tienes aquí mismo en el JSON.
   - Si solicita precios en Bolívares (Bs.), calcúlalos multiplicando el precio en USD por la "tasa_bcv" oficial del reporte. Muestra siempre ambos valores (USD y Bs.).

2. REVENDEDORES Y FINANZAS / CRÉDITOS:
   - Conoces a los revendedores oficiales registrados con sus códigos, teléfonos y límites de crédito ("revendedores_oficiales").
   - Conoces las deudas pendientes, montos en mora y cuotas a crédito ("deudas_revendedores").
   - Si te consulta sobre la deuda o estado de un revendedor (como Pablo González, etc.), dale el balance detallado con base en esos datos.

3. INVENTARIO Y STOCK:
   - Conoces la cantidad de perfiles totales, vendidos y disponibles por plataforma ("stock_por_plataforma").
   - Conoces los perfiles que vencen en los próximos días ("vencimientos_proximos_perfiles").
   - Si pregunta por disponibilidad o si hay stock de una plataforma, indícaselo basándote en los perfiles libres/disponibles.

4. PEDIDOS RECIENTES:
   - Conoces los últimos pedidos procesados ("ultimos_pedidos") con cliente, revendedor asignado, producto, montos, fecha, referencia y estado (pendiente, completado, cancelado, etc.).

5. OPERATORIA DEL NEGOCIO:
   - Conoces los métodos oficiales de pago ("metodos_pago_oficiales"): Pago Móvil, Zelle, Binance Pay, Zinli, Wally, etc.
   - Asiste en:
     * Respuestas comerciales, redacción de mensajes de WhatsApp y Telegram para clientes y revendedores.
     * Recordatorios de cobro de cuotas o límites de crédito.
     * Notificaciones de entrega o soporte técnico ante caídas de cuentas / reseteo de PIN.
     * Análisis de rentabilidad, combos y sugerencias comerciales para impulsar las ventas.

FORMATO DE RESPUESTA:
- Responde siempre de forma clara, directa, profesional y concisa.
- Utiliza formato Markdown con viñetas, tablas limpias y emojis apropiados para que la lectura sea inmediata y cómoda para Gregory.`
    }]
  };

  try {
    const r = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': process.env.GEMINI_API_KEY
      },
      body: JSON.stringify({ contents, systemInstruction })
    });
    const j = await r.json();
    if (!r.ok) return res.status(502).json({ error: j.error?.message || 'Error de Gemini' });
    const replyText = j.candidates?.[0]?.content?.parts?.map(p => p.text).join('') || '';
    res.json({ text: replyText });
  } catch (err) {
    res.status(500).json({ error: err.message || 'Error interno al consultar Gemini' });
  }
}


