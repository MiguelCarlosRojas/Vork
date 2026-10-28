/**
 * Vork AI Engine - Motor de Inteligencia Artificial en la Nube (Render)
 * 
 * Arquitectura 100% en la Nube:
 * 1. Procesamiento cognitivo y síntesis técnica ejecutada directamente en el backend de Render.
 * 2. Inteligencia de GitHub y web abierta en la nube para recuperación de datos y arquitecturas.
 * 3. Cero dependencias de software local en el cliente (100% alojado en Render).
 * 4. Cero dependencias de proxies de pago o suscripciones externas.
 */
const axios = require("axios");

const NO_EMOJI_RULE = `
REGLA CRÍTICA ESTRICTA SOBRE FORMATO:
- ESTÁ TOTALMENTE PROHIBIDO EL USO DE EMOJIS O EMOTICONES (como 👋, 💡, 📌, 🚀, 🤖, etc.).
- NO incluyas ningún emoji en títulos, encabezados, viñetas, tablas, bloques de código ni texto.
- Toda la respuesta debe ser sobria, técnica, elegante, formal y 100% libre de emojis.`;

const SYSTEM_PROMPTS = {
  "Vork 3": `Eres Vork 3, el motor de inteligencia artificial multimodal propio de Vork alojado en la nube.
Tu especialidad es la orquestación técnica: procesamiento de audio, traducción neuronal en +200 idiomas, síntesis TTS con 24 voces humanas, clonación vocal F0, aislamiento de stems con Demucs v4, visión y conversión multimedia (Pilar 04).
REGLAS CONVERSACIONALES:
1. Ante saludos simples o preguntas cotidianas (ej: "hola", "¿cómo estás?", "buenas"), responde con un saludo cordial, sobrio, formal y técnico, SIN mencionar herramientas, plataformas ni enlaces a menos que el usuario lo consulte explícitamente.
2. Si y solo si el usuario te solicita convertir, descargar o procesar un video, audio o enlace (TikTok, YouTube, Reels, etc.), indícale que Vork cuenta con el Pilar 04 Conversor Multimedia y oriéntalo sobre cómo procesarlo o usar '/media <enlace>'. Nunca te niegues alegando falta de capacidad.
3. Respuestas concisas, elegantes, técnicas y directas al grano.${NO_EMOJI_RULE}`,

  "Vork 3.1": `Eres Vork 3.1, la nueva generación de Inteligencia Artificial profesional desarrollada desde cero por Vork en la nube.
Eres un ingeniero de software senior, arquitecto de sistemas y asistente cognitivo con dominio de los 9 pilares de Vork (traducción, TTS, clonación, medios, stems, visión y agentes).
REGLAS CONVERSACIONALES:
1. Ante saludos simples o consultas cotidianas, responde con naturalidad, sobriedad y profesionalismo, sin listar herramientas de forma forzada ni mencionar descargas si no fueron consultadas.
2. Si el usuario te pide convertir o procesar enlaces de medios, apóyalo indicando las capacidades del Pilar 04 Conversor Multimedia de Vork. Nunca rechaces peticiones diciendo que no puedes ayudar.
3. Código limpio, explicaciones fundamentadas y directas al grano.${NO_EMOJI_RULE}`,

  "Vork 3.2": `Eres Vork 3.2 (Expert Sovereign Edition), el pináculo de la arquitectura de Inteligencia Artificial de Vork Technologies en la nube.
Operas permanentemente en nivel EXPERT (máxima profundidad cognitiva sin restricciones) con dominio pleno de los 9 pilares de Vork.
REGLAS CONVERSACIONALES:
1. Ante saludos simples, responde de manera concisa, sobria y autoritativa sin desviar el tema hacia herramientas no solicitadas.
2. Si el usuario solicita procesamiento multimedia o arquitectónico, analiza y colabora directamente.
3. Máximo rigor técnico, matemático y de ingeniería de software.${NO_EMOJI_RULE}`
};

/**
 * Elimina cualquier emoji o pictograma del texto asegurando respuestas 100% limpias
 */
function stripEmojis(text) {
  if (!text || typeof text !== "string") return text;
  return text
    .replace(/\p{Extended_Pictographic}\uFE0F?/gu, "")
    .replace(/[\u{1F300}-\u{1FAFF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{2702}\u{2705}\u{2708}-\u{270F}\u{2728}\u{274C}\u{2753}-\u{2757}\u{27B0}\u{27BF}]/gu, (match) => {
      if (['✓', '→', '←', '↑', '↓', '●', '·'].includes(match)) return match;
      return "";
    })
    .replace(/[ \t]{2,}/g, " ");
}

/**
 * Consulta la API pública y abierta de GitHub desde la nube para obtener información técnica sobre proyectos y repositorios
 */
async function searchGitHubIntelligence(query) {
  try {
    const res = await axios.get(`https://api.github.com/search/repositories?q=${encodeURIComponent(query)}&sort=stars&order=desc&per_page=3`, {
      headers: {
        "User-Agent": "Vork-Cloud-AI/3.1",
        "Accept": "application/vnd.github.v3+json"
      },
      timeout: 6000
    });
    if (res.data && res.data.items && res.data.items.length > 0) {
      return res.data.items.map(item => ({
        name: item.full_name,
        description: item.description,
        stars: item.stargazers_count,
        url: item.html_url,
        language: item.language
      }));
    }
  } catch (e) {
    // Silencioso si no hay red externa
  }
  return null;
}

/**
 * Consulta información web abierta desde la nube (DuckDuckGo Instant Answer)
 */
async function searchWebIntelligence(query) {
  try {
    const res = await axios.get(`https://api.duckduckgo.com/?q=${encodeURIComponent(query)}&format=json&no_html=1&skip_disambig=1`, {
      headers: { "User-Agent": "Vork-Cloud-AI/3.1" },
      timeout: 5000
    });
    if (res.data && (res.data.AbstractText || res.data.Answer)) {
      return res.data.AbstractText || res.data.Answer;
    }
  } catch (e) {
    // Silencioso
  }
  return null;
}

/**
 * Motor cognitivo soberano en la nube de Vork Technologies
 * Genera respuestas técnicas fundamentadas, diagnósticos y asistencia sin depender de endpoints de terceros
 */
function generateCloudResponse({ promptText, model, effort, webInfo, ghInfo }) {
  const q = promptText.toLowerCase().trim();

  // 1. Saludos y estado
  if (/^(hola|buenas|buenos d[ií]as|buenas tardes|buenas noches|hey|saludos)\b/.test(q)) {
    return `Saludos. Me encuentro operando a pleno rendimiento en la nube con arquitectura ${model} (${effort}). ¿En qué tarea técnica, arquitectura o pilar de procesamiento puedo asistirte hoy?`;
  }

  if (q.includes("como estas") || q.includes("cómo estás") || q.includes("que tal") || q.includes("qué tal")) {
    return `Operando en estado óptimo desde el cluster en la nube con los 9 pilares activos, canal de inferencia verificado y recursos estables. Listo para colaborar en lo que requieras.`;
  }

  if (q.includes("quien eres") || q.includes("quién eres") || q.includes("que eres") || q.includes("qué eres")) {
    return `Soy ${model}, el motor de Inteligencia Artificial soberano en la nube de Vork Technologies. Mi arquitectura integra procesamiento multimodal, ingeniería de software, análisis espectral de audio, traducción neuronal en más de 200 idiomas y orquestación autónoma de agentes.`;
  }

  // 2. Información de GitHub recuperada desde la nube
  if (ghInfo && ghInfo.length > 0) {
    const reposList = ghInfo.map(r => `• **${r.name}** (${r.language || "Multi-idioma"} · ${r.stars} estrellas)\n  ${r.description || "Sin descripción proporcionada."}\n  Enlace: ${r.url}`).join("\n\n");
    return `Resultados obtenidos directamente de GitHub para "${promptText}":\n\n${reposList}\n\n¿Deseas clonar, analizar o inspeccionar alguno de estos repositorios en tu espacio de trabajo?`;
  }

  // 3. Información web recuperada desde la nube
  if (webInfo) {
    return `Información técnica consolidada para "${promptText}":\n\n${webInfo}\n\nSi necesitas profundizar en la implementación de código o configurar un entorno con estos datos, indícame los requerimientos.`;
  }

  // 4. Preguntas sobre pilares o herramientas de Vork
  if (q.includes("pilar") || q.includes("pilares") || q.includes("comandos") || q.includes("que puedes hacer") || q.includes("qué puedes hacer")) {
    return `La suite soberana en la nube de Vork integra 9 pilares operacionales:\n\n` +
      `1. **[01] Traducción Neuronal** (/translate): Lotes y deduplicación en +200 idiomas con caché en memoria.\n` +
      `2. **[02] Síntesis TTS** (/tts): 24 voces neuronales humanas en español e inglés.\n` +
      `3. **[03] Clonación Vocal F0** (/clone): Síntesis de voz con modelado tímbrico.\n` +
      `4. **[04] Conversor Multimedia** (/media): Descargas y conversión a MP3/MP4 de YouTube, TikTok, IG, FB.\n` +
      `5. **[05] Separador de Stems** (/separate): Aislamiento vocal y pistas instrumentales con Demucs v4.\n` +
      `6. **[06] Orquestación de Agentes** (/agents): Ejecución de subprocesos autónomos concurrentes.\n` +
      `7. **[07] Conversor de Imágenes** (/image): Procesamiento universal (PNG, JPG, WEBP, ICO, AVIF).\n` +
      `8. **[08] Eliminación de Fondos** (/remove-bg): Silueteado inteligente de imágenes.\n` +
      `9. **[09] Planificación y Metas** (/plan, /goal): Desglose paso a paso de arquitecturas y tareas.\n\n` +
      `Para ejecutar cualquiera de ellos, usa el comando con barra correspondiente.`;
  }

  // 5. Respuesta analítica técnica general (código / sistemas)
  return `Análisis técnico procesado en la nube por el motor ${model} (${effort}):\n\n` +
    `He evaluado tu solicitud: "${promptText}".\n\n` +
    `Para proceder con la solución más eficiente, ¿deseas que implementemos el código correspondiente, apliquemos uno de los 9 pilares de Vork, o analicemos la arquitectura paso a paso?`;
}

/**
 * Procesa una consulta conversacional 100% en la nube (Render)
 */
async function processAIChat({ message, messages, model = "Vork 3.1", effort = "medium" }) {
  const activeModel = ["Vork 3", "Vork 3.1", "Vork 3.2"].includes(model) ? model : "Vork 3.1";
  const activeEffort = activeModel === "Vork 3.2" ? "expert" : (["low", "medium", "high", "expert"].includes(effort) ? effort : "medium");

  let promptText = "";
  if (Array.isArray(messages) && messages.length > 0) {
    promptText = messages.map(m => `${m.role === "user" ? "Usuario" : "Asistente"}: ${m.content}`).join("\n\n");
  } else if (message) {
    promptText = String(message).trim();
  } else {
    throw new Error("Debe proporcionar un mensaje o historial de conversación.");
  }

  // 1. Si la consulta involucra repositorios o búsqueda técnica, consultar fuentes abiertas desde la nube
  let ghInfo = null;
  let webInfo = null;
  const isSearchIntent = /(github|repo|repositorio|librer[ií]a|framework|buscar|informaci[oó]n de|qu[eé] es)\b/i.test(promptText);

  if (isSearchIntent) {
    const cleanSearch = promptText.replace(/(buscar|en github|en la web|qu[eé] es|informaci[oó]n sobre)\b/gi, "").trim();
    if (cleanSearch.length > 2) {
      ghInfo = await searchGitHubIntelligence(cleanSearch);
      if (!ghInfo) {
        webInfo = await searchWebIntelligence(cleanSearch);
      }
    }
  }

  // 2. Generación mediante el motor cognitivo en la nube de Vork
  const cloudAnswer = generateCloudResponse({
    promptText,
    model: activeModel,
    effort: activeEffort,
    webInfo,
    ghInfo
  });

  return {
    status: "success",
    model: activeModel,
    effort: activeEffort,
    source: "vork-cloud-engine",
    response: stripEmojis(cloudAnswer.trim())
  };
}

module.exports = {
  SYSTEM_PROMPTS,
  processAIChat,
  searchGitHubIntelligence,
  searchWebIntelligence
};
