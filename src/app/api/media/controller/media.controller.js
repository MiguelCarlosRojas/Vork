/**
 * mediaController.js
 * Controlador HTTP para el Conversor Multimedia Universal (YouTube, TikTok, Instagram a MP3 / MP4)
 * Blindado contra ataques SSRF, DoS, Path Traversal e Inyección de Cabeceras CRLF.
 */
const fs = require("fs");
const path = require("path");
const axios = require("axios");
const { spawn } = require("child_process");
const ffmpegPath = require("@ffmpeg-installer/ffmpeg").path;
const mediaService = require("../service/media.service");
const { MEDIA_CACHE_DIR } = require("../service/mediaEngine");
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
    const audioUrl = selectedTrack ? selectedTrack.url : (item.mp3Url || item.remoteStreamUrl);

    // ==========================================
    // 1. STREAMING DE AUDIO (VISTA PREVIA MP3)
    // ==========================================
    if (streamType === "audio") {
      // Proxy streaming directo con Range HTTP 206 sin bloquear con transcodificaciones lentas
      if (audioUrl) {
        try {
          const reqHeaders = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            "Accept": "*/*"
          };
          if (req.headers.range) {
            reqHeaders["Range"] = req.headers.range;
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
          logger.warn(`Proxy streaming de audio falló (${pipeErr.message}), intentando archivo local...`);
        }
      }

      // Servir desde archivo físico en disco si está disponible
      if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
        return serveFileStream(res, req, item.filePath, item.mimeType || "audio/mpeg");
      }
    }

    // ==========================================
    // 2. STREAMING DE VIDEO (VISTA PREVIA MP4)
    // ==========================================
    if (streamType === "video" || item.format === "mp4") {
      const isDefaultTrack = !reqAudioTrack || (selectedTrack && selectedTrack.id === item.selectedAudioTrack);
      const isDefaultQuality = !reqQuality || reqQuality === item.quality;

      // Si el archivo físico transcrito ya existe en disco Y coincide con la pista y calidad solicitada, servir directo
      if (isDefaultTrack && isDefaultQuality && item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
        return serveFileStream(res, req, item.filePath, item.mimeType || "video/mp4");
      }

      // Si se especificó calidad y existe un stream para dicha resolución en videoStreamsByQuality, usarlo
      let videoStreamUrl = item.mp4Url || item.remoteStreamUrl;
      let effectiveAudioUrl = audioUrl;
      let isSeparateAudio = Boolean(item.separateAudio);
      if (reqQuality && item.videoStreamsByQuality && item.videoStreamsByQuality[reqQuality]) {
        const qVal = item.videoStreamsByQuality[reqQuality];
        if (typeof qVal === "object" && qVal !== null && qVal.videoUrl) {
          videoStreamUrl = qVal.videoUrl;
          if (qVal.audioUrl) {
            effectiveAudioUrl = qVal.audioUrl;
            isSeparateAudio = true;
          }
        } else {
          videoStreamUrl = qVal;
        }
      }

      // Si el video tiene audio separado (YouTube adaptive stream / Facebook 1080p), remuxear en vivo con FFmpeg y la pista de audio seleccionada
      if (videoStreamUrl && effectiveAudioUrl && isSeparateAudio) {
        res.setHeader("Content-Type", "video/mp4");
        res.setHeader("Cache-Control", "no-cache");
        res.setHeader("Access-Control-Allow-Origin", "*");

        const ffArgs = [
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "-i", videoStreamUrl,
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "-i", audioUrl,
          "-map", "0:v:0",
          "-map", "1:a:0",
          "-c:v", "copy",
          "-c:a", "aac",
          "-b:a", "128k",
          "-movflags", "+frag_keyframe+empty_moov+default_base_moof",
          "-f", "mp4",
          "pipe:1"
        ];

        const ff = spawn(ffmpegPath, ffArgs);
        ff.stdout.pipe(res);

        req.on("close", () => {
          try { ff.kill("SIGKILL"); } catch {}
        });

        ff.on("error", (err) => {
          logger.warn(`Error en FFmpeg live remux video: ${err.message}`);
        });
        return;
      }

      // Si el video ya integra audio, proxy directo con Range
      if (videoStreamUrl) {
        try {
          const reqHeaders = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "*/*"
          };
          if (req.headers.range) {
            reqHeaders["Range"] = req.headers.range;
          }
          const remoteStream = await axios.get(videoStreamUrl, {
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
        } catch (vErr) {
          logger.warn(`Proxy streaming de video falló: ${vErr.message}`);
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
    const selectedQuality = reqQuality || item.quality || (item.format === "mp4" ? "720p" : "320k");

    let selectedAudioTrack = null;
    if (item.audioTracks && item.audioTracks.length > 0) {
      if (reqAudioTrack) {
        selectedAudioTrack = item.audioTracks.find(t => t.id === reqAudioTrack);
      }
      if (!selectedAudioTrack) {
        selectedAudioTrack = item.audioTracks.find(t => t.isDefault) || item.audioTracks[0];
      }
    }
    const audioUrl = selectedAudioTrack ? selectedAudioTrack.url : (item.mp3Url || item.remoteStreamUrl);

    let videoStreamUrl = item.mp4Url || item.remoteStreamUrl;
    let effectiveAudioUrl = audioUrl;
    let isSeparateAudio = Boolean(item.separateAudio);
    if (reqQuality && item.videoStreamsByQuality && item.videoStreamsByQuality[reqQuality]) {
      const qVal = item.videoStreamsByQuality[reqQuality];
      if (typeof qVal === "object" && qVal !== null && qVal.videoUrl) {
        videoStreamUrl = qVal.videoUrl;
        if (qVal.audioUrl) {
          effectiveAudioUrl = qVal.audioUrl;
          isSeparateAudio = true;
        }
      } else {
        videoStreamUrl = qVal;
      }
    }

    const safeFilename = sanitizeFilenameHeader(item.filename, `media.${item.format || "mp3"}`);

    // 1. Descarga de Audio (MP3) con la pista y calidad seleccionada
    if (item.format === "mp3" && effectiveAudioUrl) {
      if (reqQuality && reqQuality !== item.quality) {
        const customFilename = sanitizeFilenameHeader(
          item.filename.replace(/\.mp3$/i, `_${selectedQuality}.mp3`),
          `audio_${selectedQuality}.mp3`
        );
        res.setHeader("Content-Disposition", `attachment; filename="${customFilename}"`);
        res.setHeader("Content-Type", "audio/mpeg");
        const ffArgs = [
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "-i", effectiveAudioUrl,
          "-vn",
          "-c:a", "libmp3lame",
          "-b:a", selectedQuality,
          "-f", "mp3",
          "pipe:1"
        ];
        const ff = spawn(ffmpegPath, ffArgs);
        req.on("close", () => { try { ff.kill("SIGKILL"); } catch {} });
        return ff.stdout.pipe(res);
      }

      res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
      res.setHeader("Content-Type", "audio/mpeg");
      const remotePipe = await axios.get(effectiveAudioUrl, {
        responseType: "stream",
        timeout: 60000,
        headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
      });
      return remotePipe.data.pipe(res);
    }

    // 2. Descarga de Video (MP4) si el usuario seleccionó una pista alternativa o calidad diferente a la inicial
    if (item.format === "mp4" && effectiveAudioUrl && videoStreamUrl && isSeparateAudio) {
      const isCustomTrack = reqAudioTrack && reqAudioTrack !== item.selectedAudioTrack;
      const isCustomQuality = reqQuality && reqQuality !== item.quality;
      const hasLocalReady = item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000;

      if (isCustomTrack || isCustomQuality || !hasLocalReady) {
        const customFilename = sanitizeFilenameHeader(
          item.filename.replace(/\.mp4$/i, `_${selectedQuality}.mp4`),
          `video_${selectedQuality}.mp4`
        );
        res.setHeader("Content-Disposition", `attachment; filename="${customFilename}"`);
        res.setHeader("Content-Type", "video/mp4");
        const ffArgs = [
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "-i", videoStreamUrl,
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "-i", effectiveAudioUrl,
          "-map", "0:v:0",
          "-map", "1:a:0",
          "-c:v", "copy",
          "-c:a", "aac",
          "-b:a", "160k",
          "-movflags", "+faststart",
          "-f", "mp4",
          "pipe:1"
        ];
        const ff = spawn(ffmpegPath, ffArgs);
        req.on("close", () => { try { ff.kill("SIGKILL"); } catch {} });
        return ff.stdout.pipe(res);
      }
    }

    // Si la conversión física inicial está en curso, esperar si se descarga el archivo por defecto
    if (item.conversionPromise && (!item.filePath || !fs.existsSync(item.filePath) || fs.statSync(item.filePath).size < 1000)) {
      try {
        await item.conversionPromise;
      } catch (err) {
        logger.warn(`Aviso al esperar conversión asíncrona para descarga: ${err.message}`);
      }
    }

    if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
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

    // Fallback: si no hay archivo local, transmitir directamente desde el stream remoto con cabecera de descarga
    const fallbackUrl = item.format === "mp4" ? (item.mp4Url || item.remoteStreamUrl) : (item.mp3Url || item.remoteStreamUrl);
    if (fallbackUrl) {
      res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
      res.setHeader("Content-Type", item.mimeType);
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
    res.status(500).send("Error al descargar archivo multimedia.");
  }
};
