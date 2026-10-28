/**
 * translateController.js
 * Controlador HTTP para el servicio de traducción en la nube.
 */
const logger = require("../utils/logger");
const { STATUS_CODES } = require("../config/config");
const { translationService } = require("../services");
const baseController = require("./baseController");

/**
 * @desc Traduce texto o lista de textos a un idioma objetivo con deduplicación y caché en RAM
 * @param {Object} req - Request con text o texts, targetLanguage, sourceLanguage opcional
 * @param {Object} res - Response object
 * @param {Function} next - Next middleware
 */
exports.translateText = async (req, res, next) => {
  const data = req.method === "GET" ? req.query : req.body;
  const { text, texts, targetLanguage, sourceLanguage } = data;

  try {
    // 1. Manejo de Lotes de Texto (/api/translate con texts: [...])
    if (texts && Array.isArray(texts)) {
      const results = await translationService.translateBatch(texts, targetLanguage, sourceLanguage);
      return res.status(STATUS_CODES.OK).json({
        success: true,
        translatedTexts: results,
        targetLanguage,
        count: results.length
      });
    }

    // 2. Manejo de Texto Unitario (/api/translate con text: "...")
    if (typeof text === "string") {
      const translatedText = await translationService.translateSingle(text, targetLanguage, sourceLanguage);
      const downloadParam = encodeURIComponent(translatedText.slice(0, 500));
      return res.status(STATUS_CODES.OK).json({
        success: true,
        translatedText,
        targetLanguage,
        downloadUrl: `/api/translate/download?translatedText=${downloadParam}`
      });
    }

    return res.status(STATUS_CODES.BAD_REQUEST).json({
      success: false,
      error: "Parámetros inválidos. Debe proporcionar 'text' o 'texts' junto a 'targetLanguage'."
    });
  } catch (error) {
    logger.error(`Error en translateText: ${error.message}`);
    return res.status(STATUS_CODES.SERVER_ERROR).json({
      success: false,
      error: "Error en el servicio de traducción: " + (error.message || "Fallo inesperado")
    });
  }
};

// Re-exports para retrocompatibilidad
exports.getLanguages = baseController.getLanguages;
exports.getHealth = baseController.getHealth;

/**
 * Descarga directa del texto traducido en archivo .txt
 */
exports.downloadTranslation = (req, res) => {
  const data = req.method === "GET" ? req.query : req.body;
  const { text, translatedText } = data;
  const content = translatedText || text || "Traducción vacía";
  res.setHeader("Content-Disposition", 'attachment; filename="traduccion.txt"');
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  return res.send(content);
};
