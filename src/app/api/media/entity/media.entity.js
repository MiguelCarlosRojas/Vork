/**
 * media.entity.js
 * Entidad de dominio que representa un trabajo o archivo de conversión multimedia.
 */
class MediaEntity {
  constructor({ id, title, duration, author, platform, format, quality, downloadUrl, streamUrl, sizeBytes, createdAt = new Date() }) {
    this.id = id;
    this.title = title;
    this.duration = duration;
    this.author = author;
    this.platform = platform;
    this.format = format;
    this.quality = quality;
    this.downloadUrl = downloadUrl;
    this.streamUrl = streamUrl;
    this.sizeBytes = sizeBytes;
    this.createdAt = createdAt;
  }
}

module.exports = { MediaEntity };
