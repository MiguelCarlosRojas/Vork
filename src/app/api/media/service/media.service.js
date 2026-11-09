/**
 * media.service.js
 * Servicio de extracción de metadatos y conversión multimedia.
 */
const mediaRepository = require("../repository/media.repository");
const {
  detectPlatform,
  fetchMediaInfo,
  convertMediaUrl,
  convertMediaUrlInstantly,
  mediaBufferStore,
  SUPPORTED_PLATFORMS
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
    return fetchMediaInfo(url);
  }

  async getMediaInfo(url) {
    return fetchMediaInfo(url);
  }

  async convert(url, options = {}) {
    return convertMediaUrl(url, options);
  }

  async convertInstant(url, options = {}) {
    return convertMediaUrlInstantly(url, options);
  }

  findMediaById(id) {
    return this.repository.findBufferById(id);
  }
}

module.exports = new MediaService();
