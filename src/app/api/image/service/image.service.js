/**
 * image.service.js
 * Servicio de procesamiento de imagen, background removal y generación con IA.
 */
const {
  processImageConversion,
  processBackgroundOperation,
  generateImageFromPrompt
} = require("./imageEngine");
const imageRepository = require("../repository/image.repository");

class ImageService {
  constructor() {
    this.repository = imageRepository;
  }

  async convert(params) {
    return processImageConversion(params);
  }

  async processBackground(params) {
    return processBackgroundOperation(params);
  }

  async generate(params) {
    return generateImageFromPrompt(params);
  }

  findImageById(id) {
    return this.repository.findById(id);
  }

  getCacheDir() {
    return this.repository.getCacheDir();
  }
}

module.exports = new ImageService();
