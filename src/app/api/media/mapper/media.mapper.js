/**
 * media.mapper.js
 * Mapeo de respuestas de conversión multimedia.
 */
class MediaMapper {
  static toResponse(mediaResult) {
    return {
      status: "success",
      ...mediaResult
    };
  }
}

module.exports = { MediaMapper };
