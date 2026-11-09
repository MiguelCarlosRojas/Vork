/**
 * media.dto.js
 * Data Transfer Objects para el conversor multimedia.
 */
class MediaInfoRequestDto {
  constructor(data = {}) {
    this.url = typeof data.url === "string" ? data.url.trim() : "";
  }

  validate() {
    if (!this.url) {
      return { valid: false, error: "Debe proporcionar el campo 'url' con el enlace del video (YouTube, TikTok, Instagram, etc.)." };
    }
    return { valid: true };
  }
}

class MediaConvertRequestDto {
  constructor(data = {}) {
    this.url = typeof data.url === "string" ? data.url.trim() : "";
    this.format = typeof data.format === "string" ? data.format.trim().toLowerCase() : "mp3";
    this.quality = typeof data.quality === "string" ? data.quality.trim().toLowerCase() : "320k";
    this.audioBitrate = typeof data.audioBitrate === "string" ? data.audioBitrate.trim().toLowerCase() : undefined;
    this.videoResolution = typeof data.videoResolution === "string" ? data.videoResolution.trim() : undefined;
  }

  validate() {
    if (!this.url) {
      return { valid: false, error: "Debe proporcionar una URL válida para convertir." };
    }
    return { valid: true };
  }
}

module.exports = {
  MediaInfoRequestDto,
  MediaConvertRequestDto
};
