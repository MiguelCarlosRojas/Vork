/**
 * translate.controller.js
 * Controlador HTTP para el módulo de traducción.
 */
const { STATUS_CODES, POPULAR_LANGUAGES } = require("../../../config/env.config");
const logger = require("../../../util/logger");
const translationService = require("../service/translate.service");
const { TranslateRequestDto } = require("../dto/translate.dto");
const { TranslationMapper } = require("../mapper/translate.mapper");

class TranslateController {
  async translateText(req, res, next) {
    const rawData = req.method === "GET" ? req.query : req.body;
    const dto = new TranslateRequestDto(rawData);

    const validation = dto.validate();
    if (!validation.valid) {
      return res.status(STATUS_CODES.BAD_REQUEST).json({
        success: false,
        error: validation.error
      });
    }

    try {
      if (dto.texts) {
        const results = await translationService.translateBatch(dto.texts, dto.targetLanguage, dto.sourceLanguage);
        const entity = TranslationMapper.toEntity(dto, results, true);
        return res.status(STATUS_CODES.OK).json(TranslationMapper.toResponse(entity));
      }

      const result = await translationService.translateSingle(dto.text, dto.targetLanguage, dto.sourceLanguage);
      const entity = TranslationMapper.toEntity(dto, result, false);
      return res.status(STATUS_CODES.OK).json(TranslationMapper.toResponse(entity));
    } catch (error) {
      logger.error(`Error en translateText: ${error.message}`);
      return res.status(STATUS_CODES.SERVER_ERROR).json({
        success: false,
        error: "Error interno al procesar la traducción."
      });
    }
  }

  getLanguages(req, res) {
    const langKeys = Object.keys(translationService.supportedLanguages);
    res.setHeader("Cache-Control", "public, max-age=86400");
    return res.status(STATUS_CODES.OK).json({
      success: true,
      total: langKeys.length,
      popular: POPULAR_LANGUAGES,
      languages: langKeys,
      dictionary: translationService.supportedLanguages
    });
  }

  downloadTranslation(req, res) {
    const data = req.method === "GET" ? req.query : req.body;
    const textToDownload = data.translatedText || data.text;

    if (!textToDownload) {
      return res.status(STATUS_CODES.BAD_REQUEST).json({
        success: false,
        error: "No se proporcionó texto traducido para descargar."
      });
    }

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Content-Disposition", 'attachment; filename="traduccion_vork.txt"');
    return res.status(STATUS_CODES.OK).send(textToDownload);
  }
}

module.exports = new TranslateController();
