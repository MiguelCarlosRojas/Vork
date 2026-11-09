/**
 * translate.mapper.js
 * Mapeo bidireccional entre DTOs y Entidades de dominio.
 */
const { TranslationEntity } = require("../entity/translate.entity");
const { TranslateResponseDto } = require("../dto/translate.dto");

class TranslationMapper {
  static toEntity(dto, translatedResult, isBatch = false) {
    return new TranslationEntity({
      originalText: isBatch ? dto.texts : dto.text,
      translatedText: translatedResult,
      sourceLanguage: dto.sourceLanguage,
      targetLanguage: dto.targetLanguage,
      isBatch,
      count: isBatch ? dto.texts.length : 1
    });
  }

  static toResponse(entity) {
    if (entity.isBatch) {
      return TranslateResponseDto.fromBatch(entity);
    }
    return TranslateResponseDto.fromSingle(entity);
  }
}

module.exports = { TranslationMapper };
