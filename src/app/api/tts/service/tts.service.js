/**
 * tts.service.js
 * Servicio de síntesis de voz neuronal.
 */
const {
  VOICE_CATALOG,
  synthesizeSpeech,
  getAudioById
} = require("./audioSynthesizer");
const ttsRepository = require("../repository/tts.repository");

class TtsService {
  constructor() {
    this.repository = ttsRepository;
  }

  getVoices() {
    return VOICE_CATALOG;
  }

  async generateSpeech(text, options = {}) {
    const { lang = "es", voice, voiceId, rate = 1.0, pitch = 1.0 } = options;
    const selectedVoiceId = voiceId || voice;

    const result = await synthesizeSpeech(text, {
      voiceId: selectedVoiceId,
      lang,
      rate: Number(rate) || 1.0,
      pitch: Number(pitch) || 1.0
    });

    if (result && result.id) {
      this.repository.save(result.id, result);
    }

    return result;
  }

  findAudioById(id) {
    return this.repository.findById(id) || getAudioById(id);
  }
}

module.exports = new TtsService();
