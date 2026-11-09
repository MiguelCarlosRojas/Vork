/**
 * translate.service.js
 * Lógica de negocio para el motor de traducción en la nube.
 */
const translate = require("google-translate-api-x");
const languages = require("../languages.json");
const logger = require("../../../util/logger");
const translationRepository = require("../repository/translate.repository");

const NON_TRANSLATABLE_REGEX = /^[\d\s\-_.,:;!?()\[\]{}@#$%&*+=/\\|<>'"~`]*$/;

class TranslationService {
  constructor() {
    this.supportedLanguages = languages;
    this.repository = translationRepository;
  }

  async translateInParallelChunks(uniqueTexts, targetLanguage, sourceLanguage = "auto", chunkSize = 35) {
    const chunks = [];
    for (let i = 0; i < uniqueTexts.length; i += chunkSize) {
      chunks.push(uniqueTexts.slice(i, i + chunkSize));
    }

    const chunkPromises = chunks.map(async (chunk) => {
      try {
        const res = await translate(chunk, {
          to: targetLanguage,
          from: sourceLanguage || "auto",
          rejectOnPartialFail: false,
          forceBatch: true
        });
        return Array.isArray(res)
          ? res.map((r, idx) => (r && r.text ? r.text : chunk[idx]))
          : [res && res.text ? res.text : chunk[0]];
      } catch (chunkError) {
        logger.warn(`Fallback individual para chunk de ${chunk.length} elementos: ${chunkError.message}`);
        const individualResults = await Promise.all(
          chunk.map(async (text) => {
            try {
              const singleRes = await translate(text, {
                to: targetLanguage,
                from: sourceLanguage || "auto"
              });
              return singleRes && singleRes.text ? singleRes.text : text;
            } catch {
              return text;
            }
          })
        );
        return individualResults;
      }
    });

    const resolvedChunks = await Promise.all(chunkPromises);
    return resolvedChunks.flat();
  }

  async translateSingle(text, targetLanguage, sourceLanguage = "auto") {
    if (!text || NON_TRANSLATABLE_REGEX.test(text.trim())) {
      return text;
    }

    const cached = this.repository.get(targetLanguage, sourceLanguage, text);
    if (cached !== undefined) {
      return cached;
    }

    const result = await translate(text, {
      to: targetLanguage,
      from: sourceLanguage || "auto"
    });
    const translatedText = result && result.text ? result.text : text;
    this.repository.set(targetLanguage, sourceLanguage, text, translatedText);
    return translatedText;
  }

  async translateBatch(texts, targetLanguage, sourceLanguage = "auto") {
    const totalCount = texts.length;
    const results = new Array(totalCount);
    const missingMap = new Map();

    for (let i = 0; i < totalCount; i++) {
      const original = texts[i];

      if (!original || NON_TRANSLATABLE_REGEX.test(original.trim())) {
        results[i] = original;
        continue;
      }

      const cached = this.repository.get(targetLanguage, sourceLanguage, original);
      if (cached !== undefined) {
        results[i] = cached;
        continue;
      }

      if (!missingMap.has(original)) {
        missingMap.set(original, [i]);
      } else {
        missingMap.get(original).push(i);
      }
    }

    if (missingMap.size === 0) {
      return results;
    }

    const uniqueMissingList = Array.from(missingMap.keys());
    const translatedBatch = await this.translateInParallelChunks(
      uniqueMissingList,
      targetLanguage,
      sourceLanguage,
      35
    );

    for (let k = 0; k < uniqueMissingList.length; k++) {
      const orig = uniqueMissingList[k];
      const trans = translatedBatch[k] || orig;
      this.repository.set(targetLanguage, sourceLanguage, orig, trans);

      const indices = missingMap.get(orig);
      for (let idx = 0; idx < indices.length; idx++) {
        results[indices[idx]] = trans;
      }
    }

    logger.info(`Lote optimizado: ${totalCount} textos procesados (${uniqueMissingList.length} únicos a red) a '${targetLanguage}'`);
    return results;
  }

  getCacheStats() {
    return this.repository.getStats();
  }
}

module.exports = new TranslationService();
