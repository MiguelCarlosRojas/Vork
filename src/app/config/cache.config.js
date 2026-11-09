/**
 * cache.config.js
 * Configuración de tiempos de vida (TTL) y capacidades de memoria caché.
 * Centralizado desde env.config.js (.env.production).
 */
const env = require("./env.config");

module.exports = {
  TRANSLATION_CACHE_MAX_ENTRIES: env.CACHE.TRANSLATION_MAX,
  TRANSLATION_CACHE_TTL_MS: env.CACHE.TRANSLATION_TTL_MS,
  MEDIA_CACHE_TTL_MS: env.CACHE.MEDIA_TTL_MS,
  IMAGE_CACHE_TTL_MS: env.CACHE.IMAGE_TTL_MS,
  STEMS_CACHE_TTL_MS: env.CACHE.STEMS_TTL_MS,
  CAPTCHA_CACHE_TTL_MS: env.CACHE.CAPTCHA_TTL_MS
};
