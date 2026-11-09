/**
 * tts.mapper.js
 * Mapeo de síntesis de voz a respuesta DTO.
 */
const { SynthesizeResponseDto } = require("../dto/tts.dto");

class TtsMapper {
  static toResponse(result, text) {
    return SynthesizeResponseDto.fromResult(result, text);
  }
}

module.exports = { TtsMapper };
