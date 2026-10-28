/**
 * Vork AI Engine - Motor de Inteligencia Artificial para Vork 3, 3.1 y 3.2 Expert
 */
const axios = require("axios");

const NO_EMOJI_RULE = `
REGLA CRÍTICA ESTRICTA SOBRE FORMATO:
- ESTÁ TOTALMENTE PROHIBIDO EL USO DE EMOJIS O EMOTICONES (como 👋, 💡, 📌, 🚀, 🤖, etc.).
- NO incluyas ningún emoji en títulos, encabezados, viñetas, tablas, bloques de código ni texto.
- Toda la respuesta debe ser sobria, técnica, elegante, formal y 100% libre de emojis.`;

const SYSTEM_PROMPTS = {
  "Vork 3": `Eres Vork 3, el motor de inteligencia artificial multimodal de Vork.
Tu especialidad es la orquestación técnica: procesamiento de audio, traducción neuronal en +200 idiomas, síntesis TTS con 24 voces humanas, clonación vocal F0, aislamiento de stems con Demucs v4, visión y conversión multimedia (Pilar 04).
REGLAS CONVERSACIONALES:
1. Ante saludos simples o preguntas cotidianas (ej: "hola", "¿cómo estás?", "buenas"), responde con un saludo cordial, sobrio, formal y técnico, SIN mencionar herramientas, plataformas ni enlaces a menos que el usuario lo consulte explícitamente.
2. Si y solo si el usuario te solicita convertir, descargar o procesar un video, audio o enlace (TikTok, YouTube, Reels, etc.), indícale que Vork cuenta con el Pilar 04 Conversor Multimedia y oriéntalo sobre cómo procesarlo o usar '/media <enlace>'. Nunca te niegues alegando falta de capacidad.
3. Respuestas concisas, elegantes, técnicas y directas al grano.${NO_EMOJI_RULE}`,

  "Vork 3.1": `Eres Vork 3.1, la nueva generación de Inteligencia Artificial profesional desarrollada desde cero por Vork.
Eres un ingeniero de software senior, arquitecto de sistemas y asistente cognitivo con dominio de los 9 pilares de Vork (traducción, TTS, clonación, medios, stems, visión y agentes).
REGLAS CONVERSACIONALES:
1. Ante saludos simples o consultas cotidianas, responde con naturalidad, sobriedad y profesionalismo, sin listar herramientas de forma forzada ni mencionar descargas si no fueron consultadas.
2. Si el usuario te pide convertir o procesar enlaces de medios, apóyalo indicando las capacidades del Pilar 04 Conversor Multimedia de Vork. Nunca rechaces peticiones diciendo que no puedes ayudar.
3. Código limpio, explicaciones fundamentadas y directas al grano.${NO_EMOJI_RULE}`,

  "Vork 3.2": `Eres Vork 3.2 (Expert Sovereign Edition), el pináculo de la arquitectura de Inteligencia Artificial de Vork Technologies.
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
 * Procesa una consulta conversacional con el modelo y nivel de esfuerzo seleccionados
 */
async function processAIChat({ message, messages, model = "Vork 3.1", effort = "medium" }) {
  const activeModel = ["Vork 3", "Vork 3.1", "Vork 3.2"].includes(model) ? model : "Vork 3.1";
  const activeEffort = activeModel === "Vork 3.2" ? "expert" : (["low", "medium", "high", "expert"].includes(effort) ? effort : "medium");

  const baseSystem = SYSTEM_PROMPTS[activeModel] || SYSTEM_PROMPTS["Vork 3.1"];
  const effortInstruction = activeEffort === "expert"
    ? "\nNivel de esfuerzo: EXPERT. Despliega tu máxima capacidad analítica, arquitectura completa y detalle riguroso."
    : activeEffort === "high"
      ? "\nNivel de esfuerzo: HIGH. Razonamiento profundo paso a paso con código exhaustivo y consideraciones técnicas avanzadas."
      : activeEffort === "low"
        ? "\nNivel de esfuerzo: LOW. Respuesta rápida, concisa, directa y sin rodeos."
        : "\nNivel de esfuerzo: MEDIUM. Equilibrio óptimo entre velocidad y profundidad explicativa.";

  const finalSystemPrompt = baseSystem + effortInstruction;

  let promptText = "";
  if (Array.isArray(messages) && messages.length > 0) {
    promptText = messages.map(m => `${m.role === "user" ? "Usuario" : "Asistente"}: ${m.content}`).join("\n\n");
  } else if (message) {
    promptText = String(message).trim();
  } else {
    throw new Error("Debe proporcionar un mensaje o historial de conversación.");
  }

  // Conectar con el motor neuronal gratuito (openai-fast tier)
  const seed = Math.floor(Math.random() * 9999999);
  const targetUrl = `https://text.pollinations.ai/${encodeURIComponent(promptText)}?system=${encodeURIComponent(finalSystemPrompt)}&model=openai-fast&seed=${seed}`;

  try {
    const response = await axios.get(targetUrl, {
      timeout: activeEffort === "expert" || activeEffort === "high" ? 60000 : 35000,
      headers: {
        "User-Agent": "Vork-CLI/3.1 (Neural AI Engine)"
      }
    });

    let answer = response.data;
    if (typeof answer !== "string") {
      answer = JSON.stringify(answer, null, 2);
    }

    const cleanResponse = stripEmojis(answer.trim());

    return {
      status: "success",
      model: activeModel,
      effort: activeEffort,
      response: cleanResponse
    };
  } catch (err) {
    // Si falla el GET por longitud de URL o rate limit, intentamos vía POST con modelo gratuito
    try {
      const postMessages = [
        { role: "system", content: finalSystemPrompt }
      ];
      if (Array.isArray(messages) && messages.length > 0) {
        messages.forEach(m => postMessages.push({ role: m.role || "user", content: m.content }));
      } else {
        postMessages.push({ role: "user", content: promptText });
      }

      const postRes = await axios.post("https://text.pollinations.ai/", {
        messages: postMessages,
        model: "openai-fast",
        seed
      }, { timeout: 45000 });

      let postAnswer = postRes.data;
      if (typeof postAnswer !== "string") {
        postAnswer = JSON.stringify(postAnswer, null, 2);
      }

      const cleanPostResponse = stripEmojis(postAnswer.trim());

      return {
        status: "success",
        model: activeModel,
        effort: activeEffort,
        response: cleanPostResponse
      };
    } catch (fallbackErr) {
      // Fallback soberano inteligente de Vork si el servicio externo de inferencia está ocupado
      const lower = promptText.toLowerCase().trim();
      if (lower === "hola" || lower === "buenas" || lower.includes("como estas") || lower.includes("cómo estás")) {
        return {
          status: "success",
          model: activeModel,
          effort: activeEffort,
          response: `Saludos. Me encuentro operando en nivel óptimo con arquitectura Vork ${activeModel} (${activeEffort}). ¿En qué aspecto técnico o pilar de procesamiento puedo asistirte hoy?`
        };
      }
      throw new Error(`Error temporal de inferencia en Vork AI (${activeModel}): El motor externo está saturado. Intenta de nuevo.`);
    }
  }
}

module.exports = {
  SYSTEM_PROMPTS,
  processAIChat
};
