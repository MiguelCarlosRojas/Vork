/**
 * ai.repository.js
 * Repositorio de historial y sesiones en memoria para conversaciones de IA.
 */
class AiRepository {
  constructor() {
    this.sessions = new Map();
  }

  getSession(sessionId) {
    return this.sessions.get(sessionId) || [];
  }

  appendMessage(sessionId, message) {
    const list = this.getSession(sessionId);
    list.push(message);
    this.sessions.set(sessionId, list);
  }

  clearSession(sessionId) {
    this.sessions.delete(sessionId);
  }
}

module.exports = new AiRepository();
