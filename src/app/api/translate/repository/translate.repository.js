/**
 * translate.repository.js
 * Repositorio de persistencia y caché en memoria para traducciones.
 */
class TranslationRepository {
  constructor(maxEntries = 10000) {
    this.cache = new Map();
    this.maxEntries = maxEntries;
    this.hits = 0;
    this.misses = 0;
  }

  _getKey(targetLang, sourceLang, text) {
    return `${targetLang}|${sourceLang}|${text}`;
  }

  get(targetLang, sourceLang, text) {
    const key = this._getKey(targetLang, sourceLang, text);
    if (this.cache.has(key)) {
      const val = this.cache.get(key);
      // LRU refresh
      this.cache.delete(key);
      this.cache.set(key, val);
      this.hits++;
      return val;
    }
    this.misses++;
    return undefined;
  }

  set(targetLang, sourceLang, text, translated) {
    const key = this._getKey(targetLang, sourceLang, text);
    if (this.cache.has(key)) {
      this.cache.delete(key);
    } else if (this.cache.size >= this.maxEntries) {
      const firstKey = this.cache.keys().next().value;
      if (firstKey) this.cache.delete(firstKey);
    }
    this.cache.set(key, translated);
  }

  getStats() {
    return {
      entries: this.cache.size,
      maxEntries: this.maxEntries,
      hits: this.hits,
      misses: this.misses,
      hitRate: this.hits + this.misses > 0
        ? `${((this.hits / (this.hits + this.misses)) * 100).toFixed(2)}%`
        : "0%"
    };
  }

  clear() {
    this.cache.clear();
    this.hits = 0;
    this.misses = 0;
  }
}

module.exports = new TranslationRepository();
