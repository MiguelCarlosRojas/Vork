/**
 * tts.controller.js
 * Controlador HTTP para Texto a Voz Neuronal (TTS Studio)
 */
const ttsService = require("../service/tts.service");
const { streamAudioBuffer } = require("../service/streamHelper");
const { sanitizeId, sanitizeFilenameHeader } = require("../../../util/validator");
const logger = require("../../../util/logger");
const { SynthesizeRequestDto } = require("../dto/tts.dto");
const { TtsMapper } = require("../mapper/tts.mapper");

class TtsController {
  getVoices(req, res) {
    const voices = ttsService.getVoices();
    res.json({
      status: "success",
      total: voices.length,
      voices
    });
  }

  async synthesize(req, res) {
    try {
      const dto = new SynthesizeRequestDto(req.body || {});
      const validation = dto.validate();
      if (!validation.valid) {
        return res.status(400).json({
          status: "error",
          error: validation.error
        });
      }

      const result = await ttsService.generateSpeech(dto.text, {
        voiceId: dto.voiceId,
        lang: dto.lang,
        rate: dto.rate,
        pitch: dto.pitch
      });

      return res.json(TtsMapper.toResponse(result, dto.text));
    } catch (error) {
      logger.error(`Error en ttsController.synthesize: ${error.message}`);
      res.status(500).json({
        status: "error",
        error: "Error interno al sintetizar audio: " + error.message
      });
    }
  }

  streamTts(req, res) {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador de audio inválido o no seguro.");
    }

    const audioItem = ttsService.findAudioById(safeId);
    if (!audioItem) {
      return res.status(404).send("Audio no encontrado o expirado (TTL 30 min).");
    }

    streamAudioBuffer(req, res, audioItem);
  }

  downloadTts(req, res) {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador de audio inválido o no seguro.");
    }

    const audioItem = ttsService.findAudioById(safeId);
    if (!audioItem) {
      return res.status(404).send("Audio no encontrado o expirado para descarga.");
    }

    const ext = audioItem.mimeType && audioItem.mimeType.includes("wav") ? "wav" : "mp3";
    const safeFilename = sanitizeFilenameHeader(`voz-tts-vork.${ext}`);

    res.setHeader("Content-Type", audioItem.mimeType || "audio/mpeg");
    res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
    res.setHeader("Content-Length", audioItem.buffer.length);
    res.send(audioItem.buffer);
  }
}

module.exports = new TtsController();
