/**
 * mediaController.js
 * Controlador HTTP para el Conversor Multimedia Universal (YouTube, TikTok, Instagram a MP3 / MP4)
 * Blindado contra ataques SSRF, DoS, Path Traversal e Inyección de Cabeceras CRLF.
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const axios = require("axios");
const { spawn } = require("child_process");
const ffmpegPath = require("@ffmpeg-installer/ffmpeg").path;
const mediaService = require("../service/media.service");
const { MEDIA_CACHE_DIR, wrapStreamUrl, extractThumbnailFrame } = require("../service/mediaEngine");
const {
  validateSafeUrl,
  sanitizeId,
  sanitizeFilenameHeader,
  isPathContained
} = require("../../../util/validator");
const { generateThumbnailSvg } = require("../service/svgHelper");
const logger = require("../../../util/logger");

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

  let { url, v, title, platform, author } = req.query;
  if ((!url || typeof url !== "string") && (v && typeof v === "string")) {
    url = v;
  }

  if (!url || typeof url !== "string") {
    res.setHeader("Content-Type", "image/svg+xml");
    return res.send(generateThumbnailSvg(title, platform, author));
  }

  try {
    // 🛡️ Blindaje SSRF: Bloquea IPs privadas, loopback (127.0.0.1) y metadatos cloud (169.254.169.254)
    await validateSafeUrl(url);

    // 1. Servir desde caché física en disco si ya fue extraído previamente (0ms)
    const cacheKey = crypto.createHash("md5").update(url).digest("hex");
    const cachedDiskPath = path.join(MEDIA_CACHE_DIR, `proxy_${cacheKey}.jpg`);

    if (fs.existsSync(cachedDiskPath) && isPathContained(cachedDiskPath, MEDIA_CACHE_DIR)) {
      res.setHeader("Content-Type", "image/jpeg");
      res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
      return fs.createReadStream(cachedDiskPath).pipe(res);
    }

    // 2. Si la URL apunta a un flujo de video (ej. MP4, video.twimg.com, etc.), extraer fotograma real
    const isVideoStream = /\.(mp4|webm|mov|mkv)(\?.*)?$/i.test(url) || /video\.twimg\.com/i.test(url) || /tiktokcdn.*video/i.test(url);
    if (isVideoStream) {
      const ok = await extractThumbnailFrame(url, cachedDiskPath);
      if (ok && fs.existsSync(cachedDiskPath)) {
        res.setHeader("Content-Type", "image/jpeg");
        res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
        return fs.createReadStream(cachedDiskPath).pipe(res);
      }
    }

    // 3. Petición HTTP a la URL remota de la imagen con cabeceras de origen correctas
    const reqHeaders = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
    };

    if (/tiktok|byteoversea|ibytedtos|muscdn|musical\.ly/i.test(url)) {
      reqHeaders["Referer"] = "https://www.tiktok.com/";
    } else if (/tikwm\.com/i.test(url)) {
      reqHeaders["Referer"] = "https://www.tikwm.com/";
    } else if (/instagram|cdninstagram|fbcdn/i.test(url)) {
      reqHeaders["Referer"] = "https://www.instagram.com/";
    } else if (/twitter|twimg|x\.com/i.test(url)) {
      reqHeaders["Referer"] = "https://twitter.com/";
    }

    const imgRes = await axios.get(url, {
      responseType: "stream",
      headers: reqHeaders,
      timeout: 8000,
      maxRedirects: 3
    });

    const contentType = (imgRes.headers["content-type"] || "").toLowerCase();

    // Si el servidor devolvió un flujo de video en vez de imagen, extraer fotograma con FFmpeg
    if (contentType.startsWith("video/")) {
      const ok = await extractThumbnailFrame(url, cachedDiskPath);
      if (ok && fs.existsSync(cachedDiskPath)) {
        res.setHeader("Content-Type", "image/jpeg");
        res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
        return fs.createReadStream(cachedDiskPath).pipe(res);
      }
    }

    res.setHeader("Content-Type", contentType.startsWith("image/") ? contentType : "image/jpeg");
    res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    imgRes.data.pipe(res);
  } catch (err) {
    logger.warn(`Fallback proxy de miniatura para ${url}: ${err.message}`);

    // Si falló la descarga de la imagen pero se cuenta con el video de respaldo (v), extraer fotograma
    if (v && typeof v === "string" && v !== url && v.startsWith("http")) {
      try {
        await validateSafeUrl(v);
        const vKey = crypto.createHash("md5").update(v).digest("hex");
        const vDiskPath = path.join(MEDIA_CACHE_DIR, `proxy_${vKey}.jpg`);
        const ok = await extractThumbnailFrame(v, vDiskPath);
        if (ok && fs.existsSync(vDiskPath)) {
          res.setHeader("Content-Type", "image/jpeg");
          res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
          return fs.createReadStream(vDiskPath).pipe(res);
        }
      } catch {}
    }

    res.setHeader("Content-Type", "image/svg+xml");
    res.send(generateThumbnailSvg(title, platform, author));
  }
};

/**
 * Miniatura física extraída localmente por FFmpeg durante la conversión
 * Blindado contra Path Traversal
 */
exports.getThumbnail = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");

  const safeId = sanitizeId(req.query.id);
  if (!safeId) {
    res.setHeader("Content-Type", "image/svg+xml");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    return res.send(generateThumbnailSvg("Video Multimedia", "MEDIA", ""));
  }

  const item = mediaService.findMediaById(safeId);
  const diskThumbPath = path.join(MEDIA_CACHE_DIR, `${safeId}.jpg`);

  // 1. Si el fotograma ya existe físicamente en disco, servirlo inmediatamente como JPEG
  if (fs.existsSync(diskThumbPath) && isPathContained(diskThumbPath, MEDIA_CACHE_DIR)) {
    if (item) item.thumbPath = diskThumbPath;
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    return fs.createReadStream(path.resolve(diskThumbPath)).pipe(res);
  }

  // 2. Si el registro en memoria ya tiene thumbPath y existe
  if (item && item.thumbPath && fs.existsSync(item.thumbPath) && isPathContained(item.thumbPath, MEDIA_CACHE_DIR)) {
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    return fs.createReadStream(path.resolve(item.thumbPath)).pipe(res);
  }

  // 3. Extracción síncrona/inmediata al vuelo si tenemos el flujo de origen o el archivo
  if (item) {
    const videoSource = (item.filePath && fs.existsSync(item.filePath))
      ? item.filePath
      : (item.remoteStreamUrl || item.candidateStreams?.[0] || item.mp4Url);

    if (videoSource) {
      try {
        const ok = await extractThumbnailFrame(videoSource, diskThumbPath);
        if (ok && fs.existsSync(diskThumbPath)) {
          item.thumbPath = diskThumbPath;
          res.setHeader("Content-Type", "image/jpeg");
          res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
          return fs.createReadStream(path.resolve(diskThumbPath)).pipe(res);
        }
      } catch {}
    }
  }

  // 4. Si el registro tiene una miniatura remota válida (no SVG), redirigir hacia ella
  if (item && item.thumbnail && item.thumbnail !== `/api/media/thumbnail?id=${safeId}` && !item.thumbnail.includes("title=")) {
    return res.redirect(item.thumbnail);
  }

  // 5. Fallback SVG transitorio (sin caché agresiva para permitir actualización inmediata al generarse el frame)
  res.setHeader("Content-Type", "image/svg+xml");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.send(generateThumbnailSvg(item ? item.title : "Video Multimedia", item ? item.platform : "MEDIA", item ? item.author : ""));
};

/**
 * Conversión a MP3 o MP4 con calidad seleccionada
 * Blindado contra SSRF y manipulación de parámetros
 */
exports.convertMedia = async (req, res) => {
  try {
    const { url, format = "mp3", quality, audioTrack } = req.body || {};
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
      "140p", "144p", "240p", "360p", "480p", "540p", "720p", "720p60", "1080p", "1080p60",
      "1080p60hd", "1080phd", "1440p", "1440p60", "2160p", "2160p60", "4k", "2k", "lossless", "pcm", "auto", "best"
    ];
    let cleanQuality = typeof quality === "string" ? quality.toLowerCase().trim() : null;
    if (cleanQuality && /^\d+$/.test(cleanQuality)) {
      cleanQuality = safeFormat === "mp4" ? `${cleanQuality}p` : `${cleanQuality}k`;
    }
    const safeQuality = (cleanQuality && allowedQualities.includes(cleanQuality)) ? cleanQuality : (safeFormat === "mp4" ? "best" : (safeFormat === "wav" ? "lossless" : "320k"));

    const result = await mediaService.convertSingleMedia({ url, format: safeFormat, quality: safeQuality, audioTrack });
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
    const safeQuality = typeof quality === "string" ? quality.slice(0, 10) : (safeFormat === "mp4" ? "best" : "320k");

    const results = await mediaService.convertBatchMedia({ urls, format: safeFormat, quality: safeQuality });

    res.json({
      status: "success",
      total: results.length,
      format: safeFormat,
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
/**
 * Servidor auxiliar de archivos con soporte Range 206
 */
function serveFileStream(res, req, filePath, mimeType) {
  if (!isPathContained(filePath, MEDIA_CACHE_DIR)) {
    logger.warn(`[Seguridad] Intento de Path Traversal bloqueado: ${filePath}`);
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
    res.setHeader("Content-Type", mimeType);
    res.setHeader("Access-Control-Allow-Origin", "*");

    const stream = fs.createReadStream(resolvedPath, { start, end });
    return stream.pipe(res);
  }

  res.setHeader("Content-Type", mimeType);
  res.setHeader("Content-Length", total);
  res.setHeader("Accept-Ranges", "bytes");
  res.setHeader("Access-Control-Allow-Origin", "*");
  const stream = fs.createReadStream(resolvedPath);
  return stream.pipe(res);
}

/**
 * Streaming de video o audio en tiempo real con Range 206 y soporte de selección multi-pista
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
    const reqAudioTrack = req.query.audioTrack;
    let reqQuality = req.query.quality ? req.query.quality.toLowerCase().trim() : null;
    if (reqQuality) {
      const match = reqQuality.match(/(\d{3,4})p?/);
      if (match) reqQuality = `${match[1]}p`;
      else if (reqQuality.includes("4k") || reqQuality.includes("2160")) reqQuality = "2160p";
      else if (reqQuality.includes("2k") || reqQuality.includes("1440")) reqQuality = "1440p";
      else if (reqQuality.includes("k")) reqQuality = reqQuality.replace(/[^0-9]/g, "") + "k";
    }

    // Identificar pista de audio seleccionada o predeterminada
    let selectedTrack = null;
    if (item.audioTracks && item.audioTracks.length > 0) {
      if (reqAudioTrack) {
        selectedTrack = item.audioTracks.find(t => t.id === reqAudioTrack);
      }
      if (!selectedTrack) {
        selectedTrack = item.audioTracks.find(t => t.isDefault) || item.audioTracks[0];
      }
    }
    const rawAudioUrl = selectedTrack ? selectedTrack.url : (item.mp3Url || item.remoteStreamUrl);
    const audioUrl = wrapStreamUrl(rawAudioUrl);

    // 0. Si el archivo físico está siendo transcodificado en segundo plano, esperar hasta 8s a que esté listo
    if ((!item.filePath || !fs.existsSync(item.filePath) || fs.statSync(item.filePath).size < 1000) && item.conversionPromise) {
      try {
        await Promise.race([
          item.conversionPromise,
          new Promise(resolve => setTimeout(resolve, 8000))
        ]);
      } catch {}
    }

    // ==========================================
    // 1. STREAMING DE AUDIO (VISTA PREVIA MP3)
    // ==========================================
    if (streamType === "audio") {
      try {
        const variantPath = await mediaService.ensureMediaVariant(item, reqQuality, reqAudioTrack);
        if (variantPath && fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) {
          return serveFileStream(res, req, variantPath, item.mimeType || "audio/mpeg");
        }
      } catch (vErr) {
        logger.warn(`Aviso al obtener variante de audio en streamMedia: ${vErr.message}`);
      }

      // 1.1 Si el archivo físico ya existe en disco, servirlo inmediatamente con Range 206
      if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
        return serveFileStream(res, req, item.filePath, item.mimeType || "audio/mpeg");
      }

      // 1.2 Proxy streaming directo con Range HTTP 206
      if (audioUrl) {
        try {
          const reqHeaders = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            "Accept": "*/*"
          };
          if (req.headers.range) {
            reqHeaders["Range"] = req.headers.range;
          }
          if (/googlevideo|youtube/i.test(audioUrl)) {
            reqHeaders["Referer"] = "https://www.youtube.com/";
          } else if (/tiktok|byteoversea|ibytedtos/i.test(audioUrl)) {
            reqHeaders["Referer"] = "https://www.tiktok.com/";
          } else if (/twitter|twimg|x\.com/i.test(audioUrl)) {
            reqHeaders["Referer"] = "https://twitter.com/";
          } else if (/chocolatemoo53|invidious|nerdvpn/i.test(audioUrl)) {
            reqHeaders["Referer"] = "https://yt.chocolatemoo53.com/";
          }

          const remoteStream = await axios.get(audioUrl, {
            responseType: "stream",
            headers: reqHeaders,
            timeout: 25000
          });
          res.status(remoteStream.status);
          if (remoteStream.headers["content-range"]) {
            res.setHeader("Content-Range", remoteStream.headers["content-range"]);
          }
          if (remoteStream.headers["content-length"]) {
            res.setHeader("Content-Length", remoteStream.headers["content-length"]);
          }
          res.setHeader("Content-Type", remoteStream.headers["content-type"] || "audio/mp4");
          res.setHeader("Accept-Ranges", "bytes");
          res.setHeader("Access-Control-Allow-Origin", "*");
          return remoteStream.data.pipe(res);
        } catch (pipeErr) {
          logger.warn(`Proxy streaming de audio falló (${pipeErr.message})`);
        }
      }

      if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
        return serveFileStream(res, req, item.filePath, item.mimeType || "audio/mpeg");
      }
    }

    // ==========================================
    // 2. STREAMING DE VIDEO (VISTA PREVIA MP4)
    // ==========================================
    if (streamType === "video" || item.format === "mp4") {
      // 2.1 Garantizar archivo físico con la calidad y pista exacta solicitada
      try {
        const variantPath = await mediaService.ensureMediaVariant(item, reqQuality, reqAudioTrack);
        if (variantPath && fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) {
          return serveFileStream(res, req, variantPath, item.mimeType || "video/mp4");
        }
      } catch (err) {
        logger.warn(`Aviso al obtener variante de video en streamMedia: ${err.message}`);
      }

      // Si la conversión física inicial está en curso, esperar si se solicita el archivo base
      if (item.conversionPromise && (!item.filePath || !fs.existsSync(item.filePath) || fs.statSync(item.filePath).size < 1000)) {
        try {
          await Promise.race([
            item.conversionPromise,
            new Promise(resolve => setTimeout(resolve, 8000))
          ]);
        } catch {}
      }

      if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
        return serveFileStream(res, req, item.filePath, item.mimeType || "video/mp4");
      }

      // 2.2 Si disponemos del stream combinado de MP4 (H.264 + AAC integrado en un único archivo), servir con Range 206 nativo
      const effectiveCombinedMp4 = item.combinedMp4Url || (item.format === "mp4" && !item.separateAudio ? (item.mp4Url || item.remoteStreamUrl) : null);
      if (effectiveCombinedMp4) {
        try {
          const reqHeaders = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "*/*"
          };
          if (req.headers.range) {
            reqHeaders["Range"] = req.headers.range;
          }
          if (/googlevideo|youtube/i.test(effectiveCombinedMp4)) {
            reqHeaders["Referer"] = "https://www.youtube.com/";
          } else if (/tiktok|byteoversea|ibytedtos/i.test(effectiveCombinedMp4)) {
            reqHeaders["Referer"] = "https://www.tiktok.com/";
          } else if (/twitter|twimg|x\.com/i.test(effectiveCombinedMp4)) {
            reqHeaders["Referer"] = "https://twitter.com/";
          } else if (/chocolatemoo53|invidious|nerdvpn/i.test(effectiveCombinedMp4)) {
            reqHeaders["Referer"] = "https://yt.chocolatemoo53.com/";
          }

          const remoteStream = await axios.get(effectiveCombinedMp4, {
            responseType: "stream",
            headers: reqHeaders,
            timeout: 25000
          });
          res.status(remoteStream.status);
          if (remoteStream.headers["content-range"]) {
            res.setHeader("Content-Range", remoteStream.headers["content-range"]);
          }
          if (remoteStream.headers["content-length"]) {
            res.setHeader("Content-Length", remoteStream.headers["content-length"]);
          }
          res.setHeader("Content-Type", remoteStream.headers["content-type"] || "video/mp4");
          res.setHeader("Accept-Ranges", "bytes");
          res.setHeader("Access-Control-Allow-Origin", "*");
          return remoteStream.data.pipe(res);
        } catch (combErr) {
          logger.warn(`Proxy streaming de video combinado falló (${combErr.message})`);
        }
      }
    }

    // Servir desde archivo físico en disco (verificando confinamiento en MEDIA_CACHE_DIR)
    if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
      return serveFileStream(res, req, item.filePath, item.mimeType);
    }

    res.status(404).send("Flujo multimedia no disponible para reproducción.");
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

    const reqAudioTrack = req.query.audioTrack;
    let reqQuality = req.query.quality ? req.query.quality.toLowerCase().trim() : null;
    if (reqQuality && item.format === "mp4") {
      const match = reqQuality.match(/(\d{3,4})p?/);
      if (match) reqQuality = `${match[1]}p`;
      else if (reqQuality.includes("4k") || reqQuality.includes("2160")) reqQuality = "2160p";
      else if (reqQuality.includes("2k") || reqQuality.includes("1440")) reqQuality = "1440p";
    } else if (reqQuality && item.format === "mp3") {
      reqQuality = reqQuality.replace(/[^0-9]/g, "") + "k";
    }

    const selectedQuality = reqQuality || item.quality || (item.format === "mp4" ? "1080p" : "320k");
    const safeFilename = sanitizeFilenameHeader(
      item.filename ? item.filename.replace(/\.(mp3|mp4|wav)$/i, `_${selectedQuality}.${item.format || "mp3"}`) : `media_${selectedQuality}.${item.format || "mp3"}`,
      `media.${item.format || "mp3"}`
    );

    // Obtener la variante física garantizada con la calidad y pista exacta
    let finalFilePath = null;
    try {
      const variantPath = await mediaService.ensureMediaVariant(item, reqQuality, reqAudioTrack);
      if (variantPath && fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) {
        finalFilePath = variantPath;
      }
    } catch (vErr) {
      logger.warn(`Aviso al obtener variante en downloadMedia: ${vErr.message}`);
    }

    if (!finalFilePath) {
      if (item.conversionPromise && (!item.filePath || !fs.existsSync(item.filePath) || fs.statSync(item.filePath).size < 1000)) {
        try {
          await item.conversionPromise;
        } catch {}
      }
      if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
        finalFilePath = item.filePath;
      }
    }

    if (finalFilePath) {
      if (!isPathContained(finalFilePath, MEDIA_CACHE_DIR)) {
        logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en downloadMedia: ${finalFilePath}`);
        return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento permitido.");
      }

      const resolvedPath = path.resolve(finalFilePath);
      const stat = fs.statSync(resolvedPath);
      res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
      res.setHeader("Content-Type", item.format === "mp4" ? "video/mp4" : (item.format === "wav" ? "audio/wav" : "audio/mpeg"));
      res.setHeader("Content-Length", stat.size);
      const stream = fs.createReadStream(resolvedPath);
      return stream.pipe(res);
    }

    // Fallback: si no hay archivo local, transmitir directamente desde el stream remoto con cabecera de descarga
    const rawFallbackUrl = item.format === "mp4" ? (item.mp4Url || item.remoteStreamUrl) : (item.mp3Url || item.remoteStreamUrl);
    const fallbackUrl = wrapStreamUrl(rawFallbackUrl);
    if (fallbackUrl) {
      res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
      res.setHeader("Content-Type", item.format === "mp4" ? "video/mp4" : (item.format === "wav" ? "audio/wav" : "audio/mpeg"));
      const remotePipe = await axios.get(fallbackUrl, {
        responseType: "stream",
        timeout: 60000,
        headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
      });
      return remotePipe.data.pipe(res);
    }

    res.status(404).send("Archivo multimedia no disponible para descarga.");
  } catch (err) {
    logger.error(`Error en mediaController.downloadMedia: ${err.message}`);
    res.status(500).send("Error interno en descarga de medios.");
  }
};
