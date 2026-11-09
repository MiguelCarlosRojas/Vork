/**
 * ai.controller.js
 * Controlador HTTP para Vork AI (Vork 3, Vork 3.1, Vork 3.2 Expert)
 */
const aiService = require("../service/ai.service");
const logger = require("../../../util/logger");
const { AiChatRequestDto } = require("../dto/ai.dto");

class AiController {
  async chat(req, res) {
    try {
      const dto = new AiChatRequestDto(req.body || {});
      const validation = dto.validate();
      if (!validation.valid) {
        return res.status(400).json({
          status: "error",
          error: validation.error
        });
      }

      const result = await aiService.processChat({
        message: dto.message,
        messages: dto.messages,
        model: dto.model,
        effort: dto.effort
      });

      return res.json(result);
    } catch (error) {
      logger.error(`[AIController] Error: ${error.message}`);
      return res.status(500).json({
        status: "error",
        error: error.message || "Error al procesar la respuesta con Vork AI."
      });
    }
  }
}

module.exports = new AiController();
