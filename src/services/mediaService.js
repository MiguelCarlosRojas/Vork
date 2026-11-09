/**
 * mediaService.js
 * Servicio de Conversión, Extracción de Metadatos y Streaming Multimedia
 */
const {
  SUPPORTED_PLATFORMS,
  extractMediaInfo,
  processConversion,
  getMediaById
} = require("../utils/mediaEngine");

/**
 * Retorna las plataformas multimedia compatibles
 */
function getSupportedPlatforms() {
  return SUPPORTED_PLATFORMS;
}

/**
 * Extrae metadatos de un enlace multimedia
 */
async function getMediaMetadata(url) {
  return extractMediaInfo(url);
}

/**
 * Convierte un enlace multimedia al formato y bitrate solicitados
 */
async function convertSingleMedia({ url, format = "mp3", quality = "320k", audioTrack = null }) {
  return processConversion({ url, format, quality, audioTrack });
}

/**
 * Procesa múltiples enlaces en lote (hasta 10 elementos)
 */
async function convertBatchMedia({ urls, format = "mp3", quality = "320k" }) {
  const selectedUrls = urls.slice(0, 10);
  return Promise.all(
    selectedUrls.map(async (link) => {
      try {
        return await processConversion({ url: link, format, quality });
      } catch (itemErr) {
        return {
          status: "error",
          url: link,
          error: itemErr.message
        };
      }
    })
  );
}

/**
 * Busca un item multimedia en caché por ID
 */
function findMediaById(id) {
  return getMediaById(id);
}

module.exports = {
  getSupportedPlatforms,
  getMediaMetadata,
  convertSingleMedia,
  convertBatchMedia,
  findMediaById
};
