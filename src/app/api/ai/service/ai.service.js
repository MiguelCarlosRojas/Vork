/**
 * ai.service.js
 * Servicio para el motor conversacional Vork AI.
 */
const aiEngine = require("./aiEngine");
const aiRepository = require("../repository/ai.repository");

class AiService {
  constructor() {
    this.repository = aiRepository;
  }

  async processChat(params) {
    return aiEngine.processAIChat(params);
  }
}

module.exports = new AiService();
