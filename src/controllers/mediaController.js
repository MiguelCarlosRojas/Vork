/**
 * mediaController.js
 * Controlador HTTP para el Conversor Multimedia Universal (YouTube, TikTok, Instagram a MP3 / MP4)
 * Blindado contra ataques SSRF, DoS, Path Traversal e Inyección de Cabeceras CRLF.
 */
const fs = require("fs");
const path = require("path");
const axios = require("axios");
const { mediaService } = require("../services");
const { MEDIA_CACHE_DIR } = require("../utils/mediaEngine");
const { validateSafeUrl } = require("../utils/ssrfGuard");
const {
  sanitizeId,
  sanitizeFilenameHeader,
  isPathContained
} = require("../utils/securitySanitizer");
const { generateThumbnailSvg } = require("../utils/svgHelper");
const logger = require("../utils/logger");

/**
 * Catálogo de plataformas compatibles
 */
exports.getPlatforms = (req, res) => {
  const platforms = mediaService.getSupportedPlatforms();
  res.json({
    status: "success",
    service: "Vork Media Converter API (Pilar 04)",
    total: platforms.length,
    platforms
  });
};

/**
 * Extracción de metadatos de video (Blindado contra SSRF)
 */
exports.getMediaInfo = async (req, res) => {
  try {
    const { url } = req.body || {};
    if (!url || typeof url !== "string") {
      return res.status(400).json({
        status: "error",
        error: "Debe proporcionar el campo 'url' con el enlace del video (YouTube, TikTok, Instagram, etc.)."
      });
    }

    // 🛡️ Blindaje SSRF: Valida sintaxis, protocolo http/https y resuelve DNS bloqueando IPs privadas
    await validateSafeUrl(url);

    const info = await mediaService.getMediaMetadata(url);
    res.json({
      status: "success",
      ...info
    });
  } catch (error) {
    logger.error(`Error en mediaController.getMediaInfo: ${error.message}`);
    res.status(400).json({
      status: "error",
      error: error.message || "Error al analizar el enlace multimedia."
    });
  }
};

/**
 * Proxy de miniaturas multimedia para evitar bloqueos por CORS o Referer
 * 🛡️ Blindaje SSRF: Valida la URL de destino antes de hacer cualquier petición HTTP
 */
exports.getThumbnailProxy = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");

  const { url, title, platform, author } = req.query;
  if (!url || typeof url !== "string") {
    res.setHeader("Content-Type", "image/svg+xml");
    return res.send(generateThumbnailSvg(title, platform, author));
  }

  try {
    // 🛡️ Blindaje SSRF: Bloquea IPs privadas, loopback (127.0.0.1) y metadatos cloud (169.254.169.254)
    await validateSafeUrl(url);

    const reqHeaders = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
    };

    if (url.includes("tiktok") || url.includes("byteoversea") || url.includes("ibytedtos")) {
      reqHeaders["Referer"] = "https://www.tiktok.com/";
    } else if (url.includes("instagram") || url.includes("cdninstagram") || url.includes("fbcdn")) {
      reqHeaders["Referer"] = "https://www.instagram.com/";
    }

    const imgRes = await axios.get(url, {
      responseType: "stream",
      headers: reqHeaders,
      timeout: 8000,
      maxRedirects: 3
    });

    res.setHeader("Content-Type", imgRes.headers["content-type"] || "image/jpeg");
    res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    imgRes.data.pipe(res);
  } catch (err) {
    logger.warn(`Fallback proxy de miniatura para ${url}: ${err.message}`);
    res.setHeader("Content-Type", "image/svg+xml");
    res.send(generateThumbnailSvg(title, platform, author));
  }
};

/**
 * Miniatura física extraída localmente por FFmpeg durante la conversión
 * Blindado contra Path Traversal
 */
exports.getThumbnail = (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");

  const safeId = sanitizeId(req.query.id);
  if (!safeId) {
    res.setHeader("Content-Type", "image/svg+xml");
    return res.send(generateThumbnailSvg("Video Multimedia", "MEDIA", ""));
  }

  const item = mediaService.findMediaById(safeId);
  if (item && item.thumbPath && fs.existsSync(item.thumbPath)) {
    // 🛡️ Path Traversal Guard: Confinamiento de ruta dentro de MEDIA_CACHE_DIR
    if (isPathContained(item.thumbPath, MEDIA_CACHE_DIR)) {
      res.setHeader("Content-Type", "image/jpeg");
      res.setHeader("Cache-Control", "public, max-age=86400");
      return fs.createReadStream(path.resolve(item.thumbPath)).pipe(res);
    }
  }

  res.setHeader("Content-Type", "image/svg+xml");
  res.send(generateThumbnailSvg(item ? item.title : "Video Multimedia", item ? item.platform : "MEDIA", item ? item.author : ""));
};

/**
 * Conversión a MP3 o MP4 con calidad seleccionada
 * Blindado contra SSRF y manipulación de parámetros
 */
exports.convertMedia = async (req, res) => {
  try {
    const { url, format = "mp3", quality = "320k" } = req.body || {};
    if (!url || typeof url !== "string") {
      return res.status(400).json({
        status: "error",
        error: "El campo 'url' es obligatorio para realizar la conversión."
      });
    }

    // 🛡️ Blindaje SSRF
    await validateSafeUrl(url);

    const fmtLower = String(format || "").toLowerCase().trim();
    const safeFormat = ["mp4", "wav"].includes(fmtLower) ? fmtLower : "mp3";
    const allowedQualities = [
      "64k", "96k", "128k", "192k", "256k", "320k",
      "140p", "144p", "240p", "360p", "480p", "720p", "720p60", "1080p", "1080p60",
      "1080p60hd", "1080phd", "lossless", "pcm"
    ];
    let cleanQuality = typeof quality === "string" ? quality.toLowerCase().trim() : (safeFormat === "mp4" ? "720p" : (safeFormat === "wav" ? "lossless" : "320k"));
    if (/^\d+$/.test(cleanQuality)) {
      cleanQuality = safeFormat === "mp4" ? `${cleanQuality}p` : `${cleanQuality}k`;
    }
    const safeQuality = allowedQualities.includes(cleanQuality) ? cleanQuality : (safeFormat === "mp4" ? "720p" : (safeFormat === "wav" ? "lossless" : "320k"));

    const result = await mediaService.convertSingleMedia({ url, format: safeFormat, quality: safeQuality });
    res.json(result);
  } catch (error) {
    logger.error(`Error en mediaController.convertMedia: ${error.message}`);
    res.status(400).json({
      status: "error",
      error: error.message || "Error al procesar la conversión multimedia."
    });
  }
};

/**
 * Procesamiento por lotes (múltiples enlaces simultáneos con SSRF Guard)
 */
exports.batchConvert = async (req, res) => {
  try {
    const { urls, format = "mp3", quality = "320k" } = req.body || {};
    if (!urls || !Array.isArray(urls) || urls.length === 0) {
      return res.status(400).json({
        status: "error",
        error: "El campo 'urls' es obligatorio y debe ser un arreglo con al menos un enlace."
      });
    }

    if (urls.length > 10) {
      return res.status(400).json({
        status: "error",
        error: "El límite máximo por lote es de 10 enlaces simultáneos."
      });
    }

    // 🛡️ Blindaje SSRF individual por cada enlace del lote
    for (const link of urls) {
      if (typeof link === "string") {
        await validateSafeUrl(link);
      }
    }

    const safeFormat = format.toLowerCase() === "mp4" ? "mp4" : "mp3";
    const safeQuality = typeof quality === "string" ? quality.slice(0, 10) : "320k";

    const results = await mediaService.convertBatchMedia({ urls, format: safeFormat, quality: safeQuality });

    res.json({
      status: "success",
      total: results.length,
      format: safeFormat,
      quality: safeQuality,
      items: results
    });
  } catch (error) {
    logger.error(`Error en mediaController.batchConvert: ${error.message}`);
    res.status(400).json({
      status: "error",
      error: error.message || "Error en procesamiento por lotes multimedia."
    });
  }
};

/**
 * Streaming de video o audio en tiempo real con Range 206 y Confinamiento de Rutas
 */
exports.streamMedia = async (req, res) => {
  try {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador multimedia inválido o no seguro.");
    }

    const item = mediaService.findMediaById(safeId);
    if (!item) {
      return res.status(404).send("Medio no encontrado o expirado (TTL 30 min).");
    }

    const streamType = (req.query.type || "").toLowerCase();

    // Redirección inteligente si se solicita video para un archivo sólo audio o viceversa
    if (streamType === "video" && item.format !== "mp4" && item.mp4Url) {
      return res.redirect(item.mp4Url);
    }
    if (streamType === "audio" && item.format === "mp4" && item.mp3Url && item.mp3Url !== item.mp4Url) {
      return res.redirect(item.mp3Url);
    }

    // Servir desde archivo físico en disco (verificando confinamiento en MEDIA_CACHE_DIR)
    if (item.filePath && fs.existsSync(item.filePath)) {
      if (!isPathContained(item.filePath, MEDIA_CACHE_DIR)) {
        logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en streamMedia: ${item.filePath}`);
        return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento permitido.");
      }

      const resolvedPath = path.resolve(item.filePath);
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
        res.setHeader("Content-Type", item.mimeType);

        const stream = fs.createReadStream(resolvedPath, { start, end });
        return stream.pipe(res);
      }

      res.setHeader("Content-Type", item.mimeType);
      res.setHeader("Content-Length", total);
      res.setHeader("Accept-Ranges", "bytes");
      const stream = fs.createReadStream(resolvedPath);
      return stream.pipe(res);
    }

    // Respaldo en memoria si existe buffer directo
    if (item.buffer) {
      const total = item.buffer.length;
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
        res.setHeader("Content-Type", item.mimeType);
        return res.send(item.buffer.slice(start, end + 1));
      }
      res.setHeader("Content-Type", item.mimeType);
      res.setHeader("Content-Length", total);
      res.setHeader("Accept-Ranges", "bytes");
      return res.send(item.buffer);
    }

    res.status(404).send("No hay archivo ni buffer multimedia disponible.");
  } catch (err) {
    logger.error(`Error en mediaController.streamMedia: ${err.message}`);
    res.status(500).send("Error interno en streaming de medios.");
  }
};

/**
 * Descarga directa física del archivo (.mp3 o .mp4) con Confinamiento de Rutas y Saneamiento CRLF
 */
exports.downloadMedia = async (req, res) => {
  try {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador multimedia inválido o no seguro.");
    }

    const item = mediaService.findMediaById(safeId);
    if (!item) {
      return res.status(404).send("Medio no encontrado o expirado para descarga.");
    }

    const safeFilename = sanitizeFilenameHeader(item.filename, `media.${item.format || "mp3"}`);

    if (item.filePath && fs.existsSync(item.filePath)) {
      if (!isPathContained(item.filePath, MEDIA_CACHE_DIR)) {
        logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en downloadMedia: ${item.filePath}`);
        return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento permitido.");
      }

      const resolvedPath = path.resolve(item.filePath);
      const stat = fs.statSync(resolvedPath);
      res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
      res.setHeader("Content-Type", item.mimeType);
      res.setHeader("Content-Length", stat.size);
      const stream = fs.createReadStream(resolvedPath);
      return stream.pipe(res);
    }

    if (item.buffer) {
      res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
      res.setHeader("Content-Type", item.mimeType);
      res.setHeader("Content-Length", item.buffer.length);
      return res.send(item.buffer);
    }

    res.status(404).send("Archivo multimedia no disponible para descarga.");
  } catch (err) {
    logger.error(`Error en mediaController.downloadMedia: ${err.message}`);
    res.status(500).send("Error al descargar archivo multimedia.");
  }
};
