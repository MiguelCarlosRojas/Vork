/**
 * inMemory.js
 * Almacén en memoria de alta velocidad con soporte de TTL (Time To Live), LRU y limpieza automática.
 */
class InMemoryCache {
  constructor(defaultTtlMs = 60 * 60 * 1000, maxEntries = 5000) {
    this.store = new Map();
    this.defaultTtlMs = defaultTtlMs;
    this.maxEntries = maxEntries;

    // Limpieza pasiva periódica cada 5 minutos
    this.cleanupTimer = setInterval(() => this.cleanup(), 5 * 60 * 1000);
    if (this.cleanupTimer.unref) this.cleanupTimer.unref();
  }

  set(key, value, ttlMs = this.defaultTtlMs) {
    if (this.store.size >= this.maxEntries) {
      // Elimina la primera entrada (LRU FIFO)
      const firstKey = this.store.keys().next().value;
      if (firstKey) this.store.delete(firstKey);
    }

    const expiresAt = Date.now() + ttlMs;
    this.store.set(key, { value, expiresAt });
  }

  get(key) {
    const item = this.store.get(key);
    if (!item) return undefined;

    if (Date.now() > item.expiresAt) {
      this.store.delete(key);
      return undefined;
    }

    return item.value;
  }

  has(key) {
    return this.get(key) !== undefined;
  }

  delete(key) {
    return this.store.delete(key);
  }

  clear() {
    this.store.clear();
  }

  size() {
    return this.store.size;
  }

  cleanup() {
    const now = Date.now();
    for (const [key, item] of this.store.entries()) {
      if (now > item.expiresAt) {
        this.store.delete(key);
      }
    }
  }
}

// Instancia global compartida para la app
const globalCache = new InMemoryCache();

module.exports = {
  InMemoryCache,
  globalCache
};
