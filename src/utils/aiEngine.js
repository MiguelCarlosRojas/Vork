/**
 * Vork AI Engine - Motor de Inteligencia Artificial para Vork 3, 3.1 y 3.2 Expert
 */
const axios = require("axios");

const SYSTEM_PROMPTS = {
  "Vork 3": `Eres Vork 3, el motor de inteligencia artificial multimodal de Vork.
Tu especialidad es la orquestación multimedia: procesamiento de audio, traducción neuronal en +200 idiomas, síntesis TTS con 24 voces humanas, clonación vocal F0, aislamiento de stems acapella/karaoke con Demucs v4 y conversión de imágenes.
Responde de manera concisa, técnica y útil en el idioma del usuario.`,

  "Vork 3.1": `Eres Vork 3.1, la nueva generación de Inteligencia Artificial profesional desarrollada desde cero por Vork.
Eres un ingeniero de software senior, arquitecto de sistemas y asistente cognitivo avanzado.
Posees habilidades de programación excepcionales en todos los lenguajes (JavaScript, Python, TypeScript, PowerShell, Go, Rust, C++, etc.), diseño de microservicios, optimización algorítmica y razonamiento estructurado.
Tus respuestas son profesionales, precisas, elegantes, bien fundamentadas y directas al grano, acompañadas de bloques de código limpios y listos para producción.`,

  "Vork 3.2": `Eres Vork 3.2 (Expert Sovereign Edition), el pináculo de la arquitectura de Inteligencia Artificial de Vork Technologies.
Operas permanentemente en nivel EXPERT (máxima profundidad cognitiva sin restricciones).
Tus características distintivas son:
1. Máximo rigor técnico, matemático y arquitectónico.
2. Pensamiento de primer nivel (First-Principles Thinking) y síntesis profunda.
3. Análisis exhaustivo de casos borde, concurrencia, escalabilidad, resiliencia y seguridad.
4. Código de estándar industrial con comentarios arquitectónicos y patrones de diseño avanzados (DDD, CQRS, Hexagonal, Event-Driven).
5. Explicaciones magistrales, autoritativas pero accesibles, con diagramas ASCII/Mermaid cuando aporten valor.`
};

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

  // Conectar con el motor neuronal
  const seed = Math.floor(Math.random() * 9999999);
  const targetUrl = `https://text.pollinations.ai/${encodeURIComponent(promptText)}?system=${encodeURIComponent(finalSystemPrompt)}&seed=${seed}`;

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

    return {
      status: "success",
      model: activeModel,
      effort: activeEffort,
      response: answer.trim()
    };
  } catch (err) {
    // Si falla el GET por longitud de URL, intentamos vía POST
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
        seed
      }, { timeout: 45000 });

      let postAnswer = postRes.data;
      if (typeof postAnswer !== "string") {
        postAnswer = JSON.stringify(postAnswer, null, 2);
      }

      return {
        status: "success",
        model: activeModel,
        effort: activeEffort,
        response: postAnswer.trim()
      };
    } catch (fallbackErr) {
      throw new Error(`Error en el motor de Vork AI (${activeModel}): ${fallbackErr.message}`);
    }
  }
}

module.exports = {
  SYSTEM_PROMPTS,
  processAIChat
};
