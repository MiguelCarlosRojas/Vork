/**
 * image.dto.js
 * Data Transfer Objects para operaciones de imagen e IA.
 */
class ImageConvertRequestDto {
  constructor(data = {}) {
    this.url = typeof data.url === "string" ? data.url.trim() : null;
    this.imageBase64 = typeof data.imageBase64 === "string" ? data.imageBase64 : null;
    this.targetFormat = typeof (data.targetFormat || data.format) === "string" ? (data.targetFormat || data.format).toLowerCase() : "png";
    this.quality = Number(data.quality) || 90;
    this.width = Number(data.width) || undefined;
    this.height = Number(data.height) || undefined;
  }

  validate() {
    if (!this.url && !this.imageBase64) {
      return { valid: false, error: "Debe proporcionar una imagen en base64 o una URL válida." };
    }
    return { valid: true };
  }
}

class ImageGenerateRequestDto {
  constructor(data = {}) {
    this.prompt = typeof data.prompt === "string" ? data.prompt.trim() : "";
    this.aspectRatio = typeof data.aspectRatio === "string" ? data.aspectRatio : "1:1";
  }

  validate() {
    if (!this.prompt) {
      return { valid: false, error: "Debe proporcionar un 'prompt' descriptivo para generar la imagen." };
    }
    return { valid: true };
  }
}

module.exports = {
  ImageConvertRequestDto,
  ImageGenerateRequestDto
};
