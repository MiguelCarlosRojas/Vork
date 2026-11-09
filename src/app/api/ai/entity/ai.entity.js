/**
 * ai.entity.js
 * Entidad de dominio para conversaciones y mensajes con Vork AI.
 */
class AiMessageEntity {
  constructor({ id, role, content, model, tokensUsed = 0, createdAt = new Date() }) {
    this.id = id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.role = role;
    this.content = content;
    this.model = model;
    this.tokensUsed = tokensUsed;
    this.createdAt = createdAt;
  }
}

module.exports = { AiMessageEntity };
