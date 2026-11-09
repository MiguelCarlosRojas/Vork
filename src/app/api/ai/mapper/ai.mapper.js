/**
 * ai.mapper.js
 * Mapeo de respuestas de Vork AI.
 */
class AiMapper {
  static toResponse(aiResult) {
    return {
      status: "success",
      ...aiResult
    };
  }
}

module.exports = { AiMapper };
