// API Endpoint para "Dev Studio AI": Agente Desarrollador Autónomo y Puente GitHub / Supabase
import { requireAdmin, getSecret, setSecret, sbRest } from './_lib.js';

export default async function handler(req, res) {
  const adminUser = await requireAdmin(req, res);
  if (!adminUser) return;

  const body = req.body || {};
  const action = body.action || 'status';

  // Obtener credenciales desde secrets de Supabase o process.env
  const geminiKey = (await getSecret('gemini_api_key')) || process.env.GEMINI_API_KEY || '';
  const githubPat = (await getSecret('github_pat')) || process.env.GITHUB_PAT || process.env.GITHUB_TOKEN || '';
  const githubRepo = (await getSecret('github_repo')) || process.env.GITHUB_REPO || 'gregoryizquierdo1990/tienda-gregory';

  // 1. ESTADO DE CONFIGURACIÓN
  if (action === 'status') {
    return res.json({
      ok: true,
      gemini_configured: !!geminiKey,
      github_configured: !!githubPat,
      repo: githubRepo,
      branch: 'main',
      user: adminUser.email
    });
  }

  // 2. GUARDAR CONFIGURACIÓN DE APIS (GEMINI Y GITHUB)
  if (action === 'save_config') {
    const { gemini_api_key, github_pat, github_repo: newRepo } = body;
    if (gemini_api_key) await setSecret('gemini_api_key', gemini_api_key.trim());
    if (github_pat) await setSecret('github_pat', github_pat.trim());
    if (newRepo) await setSecret('github_repo', newRepo.trim());

    return res.json({
      ok: true,
      message: 'Configuración guardada exitosamente en Supabase Secrets.'
    });
  }

  // 3. OBTENER LISTA DE COMMITS DE GITHUB
  if (action === 'list_commits') {
    if (!githubPat) {
      return res.status(400).json({ error: 'Falta configurar el GitHub Personal Access Token (PAT).' });
    }
    try {
      const ghRes = await fetch(`https://api.github.com/repos/${githubRepo}/commits?per_page=15`, {
        headers: {
          Authorization: `Bearer ${githubPat}`,
          Accept: 'application/vnd.github.v3+json',
          'User-Agent': 'TiendaGregory-DevStudio'
        }
      });
      if (!ghRes.ok) {
        const errText = await ghRes.text();
        return res.status(ghRes.status).json({ error: 'GitHub API error: ' + errText });
      }
      const commits = await ghRes.json();
      const list = (commits || []).map(c => ({
        sha: c.sha ? c.sha.slice(0, 7) : '',
        full_sha: c.sha,
        message: c.commit?.message || '',
        author: c.commit?.author?.name || c.author?.login || 'Admin',
        date: c.commit?.author?.date || '',
        html_url: c.html_url
      }));
      return res.json({ ok: true, commits: list, repo: githubRepo });
    } catch (err) {
      return res.status(500).json({ error: 'Error consultando commits: ' + err.message });
    }
  }

  // 4. OBTENER LISTA DE ARCHIVOS DEL REPOSITORIO
  if (action === 'list_files') {
    if (!githubPat) {
      // Fallback a archivos comunes conocidos si no hay token GitHub todavía
      return res.json({
        ok: true,
        files: [
          'tienda/index.html',
          'tienda/admin-extra.js',
          'tienda/api/conciliar-bdv.js',
          'tienda/api/notify-event.js',
          'tienda/api/telegram.js',
          'tienda/api/gemini.js',
          'tienda/api/dev-studio.js',
          'tienda/vercel.json'
        ]
      });
    }
    try {
      const ghRes = await fetch(`https://api.github.com/repos/${githubRepo}/git/trees/main?recursive=1`, {
        headers: {
          Authorization: `Bearer ${githubPat}`,
          Accept: 'application/vnd.github.v3+json',
          'User-Agent': 'TiendaGregory-DevStudio'
        }
      });
      if (!ghRes.ok) {
        return res.status(ghRes.status).json({ error: 'Error al listar árbol de GitHub' });
      }
      const tree = await ghRes.json();
      const files = (tree.tree || [])
        .filter(t => t.type === 'blob' && !t.path.startsWith('.git') && !t.path.endsWith('.png') && !t.path.endsWith('.ico'))
        .map(t => t.path);
      return res.json({ ok: true, files, repo: githubRepo });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  // 5. LEER CONTENIDO DE UN ARCHIVO
  if (action === 'get_file') {
    const path = body.path;
    if (!path) return res.status(400).json({ error: 'Falta parámetro path' });
    if (!githubPat) {
      return res.status(400).json({ error: 'Se requiere GitHub PAT para leer archivos del repositorio remoto.' });
    }
    try {
      const ghRes = await fetch(`https://api.github.com/repos/${githubRepo}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}?ref=main`, {
        headers: {
          Authorization: `Bearer ${githubPat}`,
          Accept: 'application/vnd.github.v3+json',
          'User-Agent': 'TiendaGregory-DevStudio'
        }
      });
      if (!ghRes.ok) {
        return res.status(ghRes.status).json({ error: 'Archivo no encontrado en GitHub o sin permisos.' });
      }
      const fileData = await ghRes.json();
      const content = Buffer.from(fileData.content || '', 'base64').toString('utf-8');
      return res.json({
        ok: true,
        path: fileData.path,
        sha: fileData.sha,
        size: fileData.size,
        content
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  // 6. GUARDAR Y HACER COMMIT DE UN ARCHIVO A GITHUB
  if (action === 'commit_file') {
    const { path, content, message, sha } = body;
    if (!path || content == null) {
      return res.status(400).json({ error: 'Faltan parámetros path o content' });
    }
    if (!githubPat) {
      return res.status(400).json({ error: 'Falta configurar GitHub PAT para guardar commits.' });
    }

    try {
      // Si no se proporcionó el SHA previo, obtenerlo para evitar conflicto
      let fileSha = sha;
      if (!fileSha) {
        const curRes = await fetch(`https://api.github.com/repos/${githubRepo}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}?ref=main`, {
          headers: {
            Authorization: `Bearer ${githubPat}`,
            Accept: 'application/vnd.github.v3+json',
            'User-Agent': 'TiendaGregory-DevStudio'
          }
        });
        if (curRes.ok) {
          const curData = await curRes.json();
          fileSha = curData.sha;
        }
      }

      const commitPayload = {
        message: message || `feat(dev-studio): actualizar ${path} vía Agente Dev Studio`,
        content: Buffer.from(content, 'utf-8').toString('base64'),
        branch: 'main'
      };
      if (fileSha) commitPayload.sha = fileSha;

      const putRes = await fetch(`https://api.github.com/repos/${githubRepo}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${githubPat}`,
          Accept: 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
          'User-Agent': 'TiendaGregory-DevStudio'
        },
        body: JSON.stringify(commitPayload)
      });

      if (!putRes.ok) {
        const putErr = await putRes.text();
        return res.status(putRes.status).json({ error: 'Error de GitHub al guardar: ' + putErr });
      }

      const resData = await putRes.json();
      return res.json({
        ok: true,
        message: 'Commit realizado con éxito en rama main. Vercel comenzará el despliegue automático.',
        commit_sha: resData.commit?.sha?.slice(0, 7),
        html_url: resData.commit?.html_url,
        new_sha: resData.content?.sha
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  // 7. EJECUTAR CONSULTA SQL EN SUPABASE
  if (action === 'run_sql') {
    const { query } = body;
    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'Falta la consulta SQL' });
    }

    try {
      // Llamar a RPC o REST en Supabase
      const sqlResult = await sbRest('rpc/exec_sql_dev', {
        method: 'POST',
        body: JSON.stringify({ p_query: query })
      }).catch(async () => {
        // Fallback a consulta directa si no existe el RPC
        return null;
      });

      return res.json({ ok: true, result: sqlResult });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  // 8. CHAT INTERACTIVO CON EL AGENTE DEVELOPER DE GEMINI
  if (action === 'chat') {
    if (!geminiKey) {
      return res.status(400).json({ error: 'Falta configurar la GEMINI_API_KEY en ajustes.' });
    }

    const { prompt, history, active_file, active_code, model = 'gemini-2.5-flash' } = body;
    if (!prompt) return res.status(400).json({ error: 'Falta el prompt del usuario' });

    // Preparar el historial
    const contents = (history || []).map(h => ({
      role: h.role === 'user' ? 'user' : 'model',
      parts: [{ text: h.text }]
    }));
    contents.push({ role: 'user', parts: [{ text: prompt }] });

    const systemPrompt = `Eres "Dev Studio AI", el Agente Senior de Inteligencia Artificial y Arquitecto de Software oficial de "Emprendimiento Gregory Izquierdo" (repositorio: ${githubRepo}).
Tu misión es asistir a Gregory Izquierdo a inspeccionar, escribir, depurar, mejorar y desplegar código en la plataforma.

CONOCIMIENTO ARQUITECTÓNICO DEL PROYECTO:
1. FRONTEND:
   - "tienda/index.html": Aplicación SPA reactiva modular en Vanilla JS. Contiene el portal de clientes, catálogo, checkout interactivo, billetera Zeny, mesa de cambio y navegación de administración.
   - "tienda/admin-extra.js": Módulos de administración extendidos (órdenes, revendedores, cuotas BNPL, comisiones de socios, franquicias, calendarios).
2. BACKEND (Vercel Serverless Functions en "tienda/api/"):
   - "conciliar-bdv.js": Receptor de notificaciones bancarias de MacroDroid (BDV y BNC) y entrega automática de credenciales.
   - "notify-event.js": Enrutador de alertas enriquecidas para Telegram (Bot Julián) y Web Push.
   - "dev-studio.js": Este endpoint de control del agente y conexión con GitHub API.
3. BASE DE DATOS (Supabase PostgreSQL):
   - Tablas clave: orders, customers, profiles_inventory, mother_accounts, products, categories, installments, zeny_ledger, zeny_cards, franchises.

DIRECTIVAS PARA TUS RESPUESTAS:
- Sé preciso, técnico, conciso y profesional.
- Cuando propongas cambios de código, indica el archivo exacto.
- Si generas un archivo completo o un bloque reemplazable, utiliza bloques markdown con el lenguaje correspondiente (ej: \`\`\`javascript).
- Si sugieres un parche de código listo para aplicar en el editor de Dev Studio, añade al inicio del bloque una directiva en comentario con el nombre del archivo, por ejemplo:
  \`\`\`javascript
  // ARCHIVO: tienda/admin-extra.js
  // Tu código aquí...
  \`\`\`
- Si el usuario te pide una consulta SQL, proporciónala en un bloque \`\`\`sql para que pueda probarla de inmediato en la pestaña de Base de Datos.
${active_file ? `\nARCHIVO ACTUALMENTE ABIERTO EN EL EDITOR:\nNombre: ${active_file}\nCódigo actual:\n\`\`\`\n${(active_code || '').slice(0, 10000)}\n\`\`\`\n` : ''}`;

    try {
      const targetModel = model.includes('pro') ? 'gemini-3.1-pro-preview' : 'gemini-3.5-flash-lite';
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${geminiKey}`;

      const aiRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiKey
        },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemPrompt }] },
          contents,
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 8192
          }
        })
      });

      if (!aiRes.ok) {
        const aiErr = await aiRes.text();
        return res.status(aiRes.status).json({ error: 'Error de Gemini API: ' + aiErr });
      }

      const aiData = await aiRes.json();
      const reply = aiData.candidates?.[0]?.content?.parts?.[0]?.text || 'No se recibió respuesta del modelo.';

      return res.json({
        ok: true,
        reply,
        model: targetModel
      });
    } catch (err) {
      return res.status(500).json({ error: 'Fallo al procesar con IA: ' + err.message });
    }
  }

  return res.status(400).json({ error: 'Acción no reconocida' });
}
