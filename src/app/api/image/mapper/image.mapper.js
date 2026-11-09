/**
 * image.mapper.js
 * Mapeo de respuestas de imagen a formato de API REST.
 */
class ImageMapper {
  static toResponse(result) {
    return {
      status: "success",
      ...result
    };
  }
}

module.exports = { ImageMapper };
