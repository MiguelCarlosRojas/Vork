/**
 * separator.mapper.js
 * Mapeo de respuestas de separación de stems.
 */
class SeparatorMapper {
  static toResponse(result) {
    return {
      status: "success",
      ...result
    };
  }
}

module.exports = { SeparatorMapper };
