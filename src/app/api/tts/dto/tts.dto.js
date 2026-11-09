/**
 * tts.dto.js
 * Data Transfer Objects para síntesis de voz.
 */
class SynthesizeRequestDto {
  constructor(data = {}) {
    const rawText = data.text;
    this.text = Array.isArray(rawText) ? rawText.join(" ") : (typeof rawText === "string" ? rawText.trim() : null);
    this.lang = typeof data.lang === "string" ? data.lang.slice(0, 16) : "es";
    this.voiceId = typeof (data.voiceId || data.voice) === "string" ? (data.voiceId || data.voice).slice(0, 64) : undefined;
    this.rate = Math.max(0.25, Math.min(3.0, Number(data.rate) || 1.0));
    this.pitch = Math.max(0.5, Math.min(2.0, Number(data.pitch) || 1.0));
  }

  validate() {
    if (!this.text) {
      return { valid: false, error: "El campo 'text' es obligatorio y debe ser una cadena o arreglo de texto." };
    }
    if (this.text.length > 5000) {
      return { valid: false, error: "El texto excede el límite máximo permitido de 5,000 caracteres por síntesis." };
    }
    return { valid: true };
  }
}

class SynthesizeResponseDto {
  static fromResult(result, inputText) {
    return {
      status: "success",
      service: "Vork TTS Studio (Backend Neural Engine)",
      text: inputText,
      lang: result.voice.lang,
      voice: result.voice.name,
      voiceId: result.voice.id,
      voiceDetails: result.voice,
      audioBase64: result.audioBase64,
      streamUrl: result.streamUrl,
      downloadUrl: result.downloadUrl,
      format: result.format,
      mimeType: result.mimeType,
      sizeBytes: result.sizeBytes,
      source: result.source,
      message: "Audio generado con éxito desde el backend de Vork."
    };
  }
}

module.exports = {
  SynthesizeRequestDto,
  SynthesizeResponseDto
};
