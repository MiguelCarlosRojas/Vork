/**
 * media.repository.js
 * Acceso al almacén en RAM y disco para conversiones de medios.
 */
const {
  mediaBufferStore,
  convertedJobCache,
  MEDIA_CACHE_DIR
} = require("../service/mediaEngine");

class MediaRepository {
  findBufferById(id) {
    return mediaBufferStore.get(id);
  }

  saveBuffer(id, data) {
    mediaBufferStore.set(id, {
      ...data,
      createdAt: Date.now()
    });
  }

  getCachedJob(cacheKey) {
    return convertedJobCache.get(cacheKey);
  }

  setCachedJob(cacheKey, jobData) {
    convertedJobCache.set(cacheKey, jobData);
  }

  getCacheDir() {
    return MEDIA_CACHE_DIR;
  }
}

module.exports = new MediaRepository();
