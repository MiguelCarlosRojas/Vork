/**
 * translate.dto.js
 * Data Transfer Objects y validación de entrada para traducción.
 */
class TranslateRequestDto {
  constructor(data = {}) {
    this.text = typeof data.text === "string" ? data.text.trim() : null;
    this.texts = Array.isArray(data.texts) ? data.texts.map(t => String(t || "")) : null;
    this.targetLanguage = typeof data.targetLanguage === "string" ? data.targetLanguage.trim().toLowerCase() : "es";
    this.sourceLanguage = typeof data.sourceLanguage === "string" ? data.sourceLanguage.trim().toLowerCase() : "auto";
  }

  validate() {
    if (!this.text && (!this.texts || this.texts.length === 0)) {
      return { valid: false, error: "Debe proporcionar 'text' o 'texts' para traducir." };
    }
    if (!this.targetLanguage) {
      return { valid: false, error: "El campo 'targetLanguage' es requerido." };
    }
    if (this.texts && this.texts.length > 500) {
      return { valid: false, error: "El lote de textos no puede exceder 500 elementos por petición." };
    }
    return { valid: true };
  }
}

class TranslateResponseDto {
  static fromSingle(entity) {
    const downloadParam = encodeURIComponent((entity.translatedText || "").slice(0, 500));
    return {
      success: true,
      translatedText: entity.translatedText,
      targetLanguage: entity.targetLanguage,
      sourceLanguage: entity.sourceLanguage,
      downloadUrl: `/api/translate/download?translatedText=${downloadParam}`
    };
  }

  static fromBatch(entity) {
    return {
      success: true,
      translatedTexts: entity.translatedText,
      targetLanguage: entity.targetLanguage,
      sourceLanguage: entity.sourceLanguage,
      count: entity.count
    };
  }
}

module.exports = {
  TranslateRequestDto,
  TranslateResponseDto
};
