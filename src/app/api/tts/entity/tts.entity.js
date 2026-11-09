/**
 * tts.entity.js
 * Entidad de dominio que representa una síntesis neuronal de voz.
 */
class TtsEntity {
  constructor({ id, text, voice, audioBuffer, mimeType = "audio/mpeg", sizeBytes, createdAt = new Date() }) {
    this.id = id;
    this.text = text;
    this.voice = voice;
    this.buffer = audioBuffer;
    this.mimeType = mimeType;
    this.sizeBytes = sizeBytes || (audioBuffer ? audioBuffer.length : 0);
    this.createdAt = createdAt;
  }
}

module.exports = { TtsEntity };
