/**
 * separator.dto.js
 * Data Transfer Objects para separación de stems.
 */
class SeparationRequestDto {
  constructor(data = {}) {
    this.url = typeof data.url === "string" ? data.url.trim() : null;
    this.audioBase64 = typeof data.audioBase64 === "string" ? data.audioBase64 : null;
    this.filename = typeof data.filename === "string" ? data.filename.slice(0, 100) : undefined;
    this.quality = typeof data.quality === "string" ? data.quality.slice(0, 10) : "320k";
  }

  validate() {
    if (!this.url && !this.audioBase64) {
      return { valid: false, error: "Debe proporcionar una URL multimedia o un archivo de audio/video para separar." };
    }
    if (this.audioBase64 && this.audioBase64.length > 70 * 1024 * 1024) {
      return { valid: false, error: "El archivo base64 supera el tamaño máximo permitido." };
    }
    return { valid: true };
  }
}

module.exports = { SeparationRequestDto };
