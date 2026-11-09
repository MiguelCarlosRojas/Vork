/**
 * separator.repository.js
 * Repositorio de acceso a caché de stems.
 */
const {
  STEMS_CACHE_DIR,
  getStemById
} = require("../service/vocalSeparator");

class SeparatorRepository {
  findById(id) {
    return getStemById(id);
  }

  getCacheDir() {
    return STEMS_CACHE_DIR;
  }
}

module.exports = new SeparatorRepository();
