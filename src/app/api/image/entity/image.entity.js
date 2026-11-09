/**
 * image.entity.js
 * Entidad de dominio que representa una imagen procesada o generada con IA.
 */
class ImageEntity {
  constructor({ id, filename, format, mimeType, sizeBytes, width, height, buffer, downloadUrl, streamUrl, createdAt = new Date() }) {
    this.id = id;
    this.filename = filename;
    this.format = format;
    this.mimeType = mimeType;
    this.sizeBytes = sizeBytes;
    this.width = width;
    this.height = height;
    this.buffer = buffer;
    this.downloadUrl = downloadUrl;
    this.streamUrl = streamUrl;
    this.createdAt = createdAt;
  }
}

module.exports = { ImageEntity };
