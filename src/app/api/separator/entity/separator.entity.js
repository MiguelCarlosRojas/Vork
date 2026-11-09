/**
 * separator.entity.js
 * Entidad de dominio para stems separados (Vocales e Instrumental).
 */
class SeparatorEntity {
  constructor({ id, vocalsUrl, instrumentalUrl, vocalsBuffer, instrumentalBuffer, filename, quality, createdAt = new Date() }) {
    this.id = id;
    this.vocalsUrl = vocalsUrl;
    this.instrumentalUrl = instrumentalUrl;
    this.vocalsBuffer = vocalsBuffer;
    this.instrumentalBuffer = instrumentalBuffer;
    this.filename = filename;
    this.quality = quality;
    this.createdAt = createdAt;
  }
}

module.exports = { SeparatorEntity };
