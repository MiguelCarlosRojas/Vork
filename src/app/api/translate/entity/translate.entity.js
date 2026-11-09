/**
 * translate.entity.js
 * Entidad de dominio que representa una traducción o lote de traducciones.
 */
class TranslationEntity {
  constructor({ id = null, originalText, translatedText, sourceLanguage = "auto", targetLanguage, isBatch = false, count = 1, createdAt = new Date() }) {
    this.id = id || `tr_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.originalText = originalText;
    this.translatedText = translatedText;
    this.sourceLanguage = sourceLanguage;
    this.targetLanguage = targetLanguage;
    this.isBatch = isBatch;
    this.count = count;
    this.createdAt = createdAt;
  }
}

module.exports = { TranslationEntity };
