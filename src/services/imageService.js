/**
 * imageService.js
 * Capa de servicio para operaciones de imagen, background studio y generación con IA
 */

const {
  processImageConversion,
  processBackgroundOperation,
  generateImageFromPrompt,
  getImageById,
  IMAGE_CACHE_DIR
} = require("../utils/imageEngine");

class ImageService {
  async convert(params) {
    return await processImageConversion(params);
  }

  async processBackground(params) {
    return await processBackgroundOperation(params);
  }

  async generate(params) {
    return await generateImageFromPrompt(params);
  }

  findImageById(id) {
    return getImageById(id);
  }

  getCacheDir() {
    return IMAGE_CACHE_DIR;
  }
}

module.exports = new ImageService();
