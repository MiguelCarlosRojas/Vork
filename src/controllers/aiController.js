/**
 * Controlador de Vork AI (Vork 3, Vork 3.1, Vork 3.2 Expert)
 */
const aiEngine = require("../utils/aiEngine");
const logger = require("../utils/logger");

exports.chat = async (req, res) => {
  try {
    const { message, messages, prompt, model = "Vork 3.1", effort = "medium" } = req.body || {};
    const inputMessage = message || prompt;

    if (!inputMessage && (!Array.isArray(messages) || messages.length === 0)) {
      return res.status(400).json({
        status: "error",
        error: "Debe proporcionar un mensaje o una lista de mensajes para procesar con Vork AI."
      });
    }

    const result = await aiEngine.processAIChat({
      message: inputMessage,
      messages,
      model,
      effort
    });

    return res.json(result);
  } catch (error) {
    logger.error(`[AIController] Error: ${error.message}`);
    return res.status(500).json({
      status: "error",
      error: error.message || "Error al procesar la respuesta con Vork AI."
    });
  }
};
