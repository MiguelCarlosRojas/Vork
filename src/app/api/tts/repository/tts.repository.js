/**
 * tts.repository.js
 * Almacenamiento en RAM de buffers de audio TTS con TTL de 30 minutos.
 */
class TtsRepository {
  constructor(ttlMs = 30 * 60 * 1000) {
    this.audioStore = new Map();
    this.ttlMs = ttlMs;

    this.cleanupTimer = setInterval(() => this.cleanup(), 5 * 60 * 1000);
    if (this.cleanupTimer.unref) this.cleanupTimer.unref();
  }

  save(id, entity) {
    this.audioStore.set(id, {
      ...entity,
      createdAt: Date.now()
    });
  }

  findById(id) {
    const item = this.audioStore.get(id);
    if (!item) return null;
    if (Date.now() - item.createdAt > this.ttlMs) {
      this.audioStore.delete(id);
      return null;
    }
    return item;
  }

  delete(id) {
    return this.audioStore.delete(id);
  }

  cleanup() {
    const now = Date.now();
    for (const [id, item] of this.audioStore.entries()) {
      if (now - item.createdAt > this.ttlMs) {
        this.audioStore.delete(id);
      }
    }
  }
}

module.exports = new TtsRepository();
