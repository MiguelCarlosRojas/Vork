/**
 * media.service.js
 * Servicio de extracción de metadatos y conversión multimedia.
 */
const mediaRepository = require("../repository/media.repository");
const {
  SUPPORTED_PLATFORMS,
  detectPlatform,
  extractMediaInfo,
  processConversion,
  processBatchConversion,
  getMediaById
} = require("./mediaEngine");

class MediaService {
  constructor() {
    this.repository = mediaRepository;
  }

  getSupportedPlatforms() {
    return SUPPORTED_PLATFORMS;
  }

  detectPlatform(url) {
    return detectPlatform(url);
  }

  async getMediaMetadata(url) {
    return extractMediaInfo(url);
  }

  async getMediaInfo(url) {
    return extractMediaInfo(url);
  }

  async convertSingleMedia(options = {}) {
    return processConversion(options);
  }

  async convertBatchMedia(options = {}) {
    return processBatchConversion(options);
  }

  findMediaById(id) {
    return getMediaById(id) || this.repository.findBufferById(id);
  }
}

module.exports = new MediaService();
