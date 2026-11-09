/**
 * image.repository.js
 * Repositorio de acceso a caché y disco para imágenes procesadas.
 */
const {
  getImageById,
  IMAGE_CACHE_DIR
} = require("../service/imageEngine");

class ImageRepository {
  findById(id) {
    return getImageById(id);
  }

  getCacheDir() {
    return IMAGE_CACHE_DIR;
  }
}

module.exports = new ImageRepository();
