/**
 * ai.dto.js
 * Data Transfer Objects para peticiones al motor Vork AI.
 */
class AiChatRequestDto {
  constructor(data = {}) {
    this.message = typeof (data.message || data.prompt) === "string" ? (data.message || data.prompt).trim() : null;
    this.messages = Array.isArray(data.messages) ? data.messages : null;
    this.model = typeof data.model === "string" ? data.model : "Vork 3.1";
    this.effort = typeof data.effort === "string" ? data.effort : "medium";
  }

  validate() {
    if (!this.message && (!this.messages || this.messages.length === 0)) {
      return { valid: false, error: "Debe proporcionar un mensaje o una lista de mensajes para procesar con Vork AI." };
    }
    return { valid: true };
  }
}

module.exports = { AiChatRequestDto };
