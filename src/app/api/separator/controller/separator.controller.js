/**
 * separatorController.js
 * Controlador HTTP para Separador de Voz e Instrumental (Vocal Remover & Stems Splitter)
 * Blindado contra ataques SSRF, DoS, Path Traversal e Inyección de Cabeceras CRLF.
 */
const fs = require("fs");
const path = require("path");
const separatorService = require("../service/separator.service");
const { STEMS_CACHE_DIR } = require("../service/vocalSeparator");
const {
  validateSafeUrl,
  sanitizeId,
  sanitizeFilenameHeader,
  isPathContained
} = require("../../../util/validator");
const logger = require("../../../util/logger");

/**
 * Procesa la separación de voz e instrumental desde URL o archivo subido
 * Blindado contra SSRF y Payload Bomb
 */
exports.processSeparation = async (req, res) => {
  try {
    const { url, audioBase64, filename, quality = "320k" } = req.body || {};
    if (!url && !audioBase64) {
      return res.status(400).json({
        status: "error",
        error: "Debe proporcionar una URL multimedia o un archivo de audio/video para separar."
      });
    }

    // 🛡️ Blindaje SSRF si se proporciona URL
    if (url) {
      if (typeof url !== "string") {
        return res.status(400).json({ status: "error", error: "El campo 'url' debe ser una cadena válida." });
      }
      await validateSafeUrl(url);
    }

    // 🛡️ Blindaje de tamaño máximo para base64 (70MB límite en caracteres)
    if (audioBase64) {
      if (typeof audioBase64 !== "string" || audioBase64.length > 70 * 1024 * 1024) {
        return res.status(400).json({ status: "error", error: "El archivo base64 supera el tamaño máximo permitido." });
      }
    }

    const safeQuality = typeof quality === "string" ? quality.slice(0, 10) : "320k";
    const safeFilename = typeof filename === "string" ? filename.slice(0, 100) : undefined;

    const result = await separatorService.separateAudio({ url, audioBase64, filename: safeFilename, quality: safeQuality });
    res.json(result);
  } catch (error) {
    logger.error(`Error en separatorController.processSeparation: ${error.message}`);
    res.status(400).json({
      status: "error",
      error: error.message || "Error al procesar la separación de voz e instrumental."
    });
  }
};

/**
 * Streaming de pista aislada (type=vocals o type=instrumental) con HTTP 206 y Confinamiento de Rutas
 */
exports.streamStem = (req, res) => {
  try {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador de pista inválido o no seguro.");
    }

    const safeType = req.query.type === "vocals" ? "vocals" : "instrumental";
    const stemItem = separatorService.findStemById(safeId);
    if (!stemItem) {
      return res.status(404).send("Pista no encontrada o sesión expirada (TTL 30 min).");
    }

    const filePath = safeType === "vocals" ? stemItem.vocalsPath : stemItem.instrumentalPath;
    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(404).send("Archivo de pista no disponible.");
    }

    // 🛡️ Confinamiento de ruta (Path Traversal Guard)
    if (!isPathContained(filePath, STEMS_CACHE_DIR)) {
      logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en streamStem: ${filePath}`);
      return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento permitido.");
    }

    const resolvedPath = path.resolve(filePath);
    const stat = fs.statSync(resolvedPath);
    const total = stat.size;
    const range = req.headers.range;

    if (range) {
      const parts = range.replace(/bytes=/, "").split("-");
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : total - 1;
      const chunkSize = end - start + 1;

      res.status(206);
      res.setHeader("Content-Range", `bytes ${start}-${end}/${total}`);
      res.setHeader("Accept-Ranges", "bytes");
      res.setHeader("Content-Length", chunkSize);
      res.setHeader("Content-Type", "audio/mpeg");

      const stream = fs.createReadStream(resolvedPath, { start, end });
      return stream.pipe(res);
    }

    res.setHeader("Content-Type", "audio/mpeg");
    res.setHeader("Content-Length", total);
    res.setHeader("Accept-Ranges", "bytes");
    const stream = fs.createReadStream(resolvedPath);
    return stream.pipe(res);
  } catch (err) {
    logger.error(`Error en separatorController.streamStem: ${err.message}`);
    res.status(500).send("Error interno en streaming de pista.");
  }
};

/**
 * Descarga directa de pista aislada con Confinamiento de Rutas y Saneamiento CRLF
 */
exports.downloadStem = (req, res) => {
  try {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador de pista inválido o no seguro.");
    }

    const safeType = req.query.type === "vocals" ? "vocals" : "instrumental";
    const stemItem = separatorService.findStemById(safeId);
    if (!stemItem) {
      return res.status(404).send("Pista no encontrada o expirada para descarga.");
    }

    const filePath = safeType === "vocals" ? stemItem.vocalsPath : stemItem.instrumentalPath;
    const rawFilename = safeType === "vocals" ? stemItem.vocalsFilename : stemItem.instrumentalFilename;
    const safeFilename = sanitizeFilenameHeader(rawFilename, `stem_${safeType}.mp3`);

    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(404).send("Archivo físico no disponible para descarga.");
    }

    // 🛡️ Confinamiento de ruta (Path Traversal Guard)
    if (!isPathContained(filePath, STEMS_CACHE_DIR)) {
      logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en downloadStem: ${filePath}`);
      return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento permitido.");
    }

    const resolvedPath = path.resolve(filePath);
    const stat = fs.statSync(resolvedPath);
    res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
    res.setHeader("Content-Type", "audio/mpeg");
    res.setHeader("Content-Length", stat.size);
    const stream = fs.createReadStream(resolvedPath);
    return stream.pipe(res);
  } catch (err) {
    logger.error(`Error en separatorController.downloadStem: ${err.message}`);
    res.status(500).send("Error al descargar pista.");
  }
};
