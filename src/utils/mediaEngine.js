/**
 * MediaEngine - Motor de Conversión y Descarga Multimedia de Vork
 * Pilar 04: Conversión Universal de Video y Audio para YouTube, TikTok, Instagram,
 * Facebook, Twitter/X, Pinterest, Reddit y Enlaces Directos hacia MP3 y MP4.
 * 
 * Procesamiento 100% nativo en Backend con FFmpeg para garantizar archivos válidos,
 * metadatos exactos de duración y descargas servidas directamente desde Vork.
 */

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const axios = require("axios");
const btch = require("btch-downloader");
let rahad = null;
try {
  rahad = require("rahad-all-downloader-v2");
} catch (e) {
  // Opcional
}
const logger = require("./logger");
const { validateSafeUrl } = require("./ssrfGuard");

// Ruta al binario de FFmpeg con fallback a binario de sistema
let ffmpegPath = "ffmpeg";
try {
  const ffmpegInstaller = require("@ffmpeg-installer/ffmpeg");
  if (ffmpegInstaller && ffmpegInstaller.path) {
    ffmpegPath = ffmpegInstaller.path;
  }
} catch (e) {
  logger.warn(`No se pudo cargar @ffmpeg-installer/ffmpeg, se usará 'ffmpeg' del sistema: ${e.message}`);
}

/**
 * Envoltorio para limitar tiempo de espera en promesas de descarga de terceros
 */
function withTimeout(promise, ms = 12000) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(`Timeout after ${ms}ms`)), ms))
  ]);
}

/**
 * Consulta de alta disponibilidad y concurrencia a proveedores y espejos de extracción para YouTube
 */
async function fetchYouTubeStreams(normalizedUrl) {
  const fetchBtch = async () => {
    const directRes = await withTimeout(btch.youtube(normalizedUrl), 10000);
    if (directRes && (directRes.mp4 || directRes.mp3)) {
      return directRes;
    }
    throw new Error("btch.youtube no retornó streams");
  };

  const fetchMirror1 = async () => {
    const res = await axios.get(`https://backend1.tioo.eu.org/youtube?url=${encodeURIComponent(normalizedUrl)}`, {
      timeout: 10000,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
      }
    });
    if (res.data && (res.data.mp4 || res.data.mp3)) {
      return res.data;
    }
    throw new Error("backend1 tioo no retornó streams");
  };

  const fetchMirror2 = async () => {
    const res = await axios.get(`https://backend2.tioo.eu.org/youtube?url=${encodeURIComponent(normalizedUrl)}`, {
      timeout: 10000,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
      }
    });
    if (res.data && (res.data.mp4 || res.data.mp3)) {
      return res.data;
    }
    throw new Error("backend2 tioo no retornó streams");
  };

  const fetchRahad = async () => {
    if (!rahad || !rahad.alldl) throw new Error("rahad no disponible");
    const r = await withTimeout(rahad.alldl(normalizedUrl), 10000);
    if (r && r.data && r.data.download) {
      const dl = r.data.download;
      let audioUrl = dl.audio || dl.video;
      let videoUrl = dl.video || dl.audio;
      if (audioUrl && audioUrl.includes("googlevideo.com") && !audioUrl.includes("vidsnap.app")) {
        audioUrl = `https://api.vidsnap.app/proxy?u=${encodeURIComponent(audioUrl)}`;
      }
      if (videoUrl && videoUrl.includes("googlevideo.com") && !videoUrl.includes("vidsnap.app")) {
        videoUrl = `https://api.vidsnap.app/proxy?u=${encodeURIComponent(videoUrl)}`;
      }
      if (audioUrl || videoUrl) {
        return {
          title: r.data.title,
          mp4: videoUrl,
          mp3: audioUrl,
          separateAudio: Boolean(videoUrl && audioUrl && videoUrl !== audioUrl),
          thumbnail: r.data.thumbnail ? (r.data.thumbnail.startsWith("http") ? r.data.thumbnail : `https://i.ytimg.com${r.data.thumbnail}`) : null
        };
      }
    }
    throw new Error("rahad no retornó streams");
  };

  // Priorizamos fuentes con video progresivo de alta resolución que ya integran audio (btch, tioo)
  try {
    return await Promise.any([fetchBtch(), fetchMirror1(), fetchMirror2()]);
  } catch (errHighRes) {
    logger.warn(`Proveedores directos de alta resolución fallaron para ${normalizedUrl}, recurriendo a rahad: ${errHighRes.message}`);
    try {
      return await fetchRahad();
    } catch (errRahad) {
      logger.warn(`Todos los proveedores de streams para YouTube fallaron para ${normalizedUrl}: ${errRahad.message}`);
      return null;
    }
  }
}

// Directorio de almacenamiento en caché para medios convertidos físicamente
const MEDIA_CACHE_DIR = path.join(__dirname, "../../data/media_cache");
try {
  if (!fs.existsSync(MEDIA_CACHE_DIR)) {
    fs.mkdirSync(MEDIA_CACHE_DIR, { recursive: true });
  }
} catch (err) {
  logger.error(`Error al inicializar directorio de caché: ${err.message}`);
}

// Almacén en RAM para sesiones de streaming y descargas de medios (TTL: 30 minutos)
const mediaBufferStore = new Map();
const MEDIA_STORE_TTL_MS = 30 * 60 * 1000;

// Caché en RAM para metadatos y streams de URLs extraídas (TTL: 5 minutos)
const mediaInfoCache = new Map();
const MEDIA_INFO_TTL_MS = 5 * 60 * 1000;

// Limpieza periódica de archivos y memoria cada 10 minutos (unref para no bloquear node)
const cleanupInterval = setInterval(() => {
  const now = Date.now();
  for (const [id, item] of mediaBufferStore.entries()) {
    if (now - item.createdAt > MEDIA_STORE_TTL_MS) {
      if (item.filePath && fs.existsSync(item.filePath)) {
        try {
          fs.unlinkSync(item.filePath);
        } catch {}
      }
      if (item.thumbPath && fs.existsSync(item.thumbPath)) {
        try {
          fs.unlinkSync(item.thumbPath);
        } catch {}
      }
      mediaBufferStore.delete(id);
    }
  }
}, 10 * 60 * 1000);
if (cleanupInterval.unref) {
  cleanupInterval.unref();
}

/**
 * Normaliza enlaces de YouTube (shorts, youtu.be, m.youtube) a formato estándar
 */
function normalizeYouTubeUrl(url) {
  if (!url || typeof url !== "string") return url;
  let clean = url.trim();
  const shortsMatch = clean.match(/youtube\.com\/shorts\/([a-zA-Z0-9_-]+)/i);
  if (shortsMatch) {
    return `https://www.youtube.com/watch?v=${shortsMatch[1]}`;
  }
  const youtuMatch = clean.match(/youtu\.be\/([a-zA-Z0-9_-]+)/i);
  if (youtuMatch) {
    return `https://www.youtube.com/watch?v=${youtuMatch[1]}`;
  }
  return clean;
}

/**
 * Resuelve enlaces acortados (vm.tiktok.com, vt.tiktok.com, etc.) a su URL canónica
 */
async function resolveRedirectUrl(url) {
  if (!url || typeof url !== "string") return url;
  const clean = url.trim();
  if (/vm\.tiktok\.com|vt\.tiktok\.com|tiktok\.com\/t\//i.test(clean)) {
    try {
      const resp = await axios.get(clean, {
        maxRedirects: 5,
        headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" },
        timeout: 6000
      });
      const resolved = resp.request?.res?.responseUrl || resp.config?.url;
      if (resolved) return resolved;
    } catch (err) {
      if (err.response?.headers?.location) {
        return err.response.headers.location;
      }
    }
  }
  return clean;
}

/**
 * Catálogo de plataformas soportadas con sus configuraciones visuales y de formato
 */
const SUPPORTED_PLATFORMS = [
  {
    id: "youtube",
    name: "YouTube",
    badge: "YouTube / Shorts",
    color: "#ff0000",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["320kbps", "192kbps", "128kbps"],
    qualitiesMp4: ["1080p", "720p", "480p", "360p"],
    regex: /(?:youtube\.com\/(?:watch\?.*v=|shorts\/|embed\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/i,
    exampleUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  },
  {
    id: "tiktok",
    name: "TikTok",
    badge: "TikTok (Sin Marca de Agua)",
    color: "#ff0050",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["320kbps", "192kbps", "128kbps"],
    qualitiesMp4: ["1080p (HD)", "720p (Original)"],
    regex: /(?:tiktok\.com\/@[\w.-]+\/video\/(\d+)|vm\.tiktok\.com\/(\w+)|vt\.tiktok\.com\/(\w+)|tiktok\.com\/t\/(\w+))/i,
    exampleUrl: "https://www.tiktok.com/@tiktok/video/7106594312292453678"
  },
  {
    id: "instagram",
    name: "Instagram",
    badge: "Instagram Reels & Posts",
    color: "#e1306c",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["320kbps", "192kbps", "128kbps"],
    qualitiesMp4: ["1080p (HD)", "720p"],
    regex: /(?:instagram\.com\/(?:p|reel|reels|tv)\/([a-zA-Z0-9_-]+))/i,
    exampleUrl: "https://www.instagram.com/reel/C8..."
  },
  {
    id: "facebook",
    name: "Facebook",
    badge: "Facebook Watch & Videos",
    color: "#1877f2",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["320kbps", "192kbps", "128kbps"],
    qualitiesMp4: ["HD", "SD"],
    regex: /(?:facebook\.com\/(?:watch\/?\?v=|.*\/videos\/)|fb\.watch\/)([a-zA-Z0-9_-]+)/i,
    exampleUrl: "https://www.facebook.com/watch/?v=123..."
  },
  {
    id: "twitter",
    name: "Twitter / X",
    badge: "X (Twitter) Video",
    color: "#1da1f2",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["320kbps", "192kbps"],
    qualitiesMp4: ["720p", "480p"],
    regex: /(?:twitter\.com|x\.com)\/[a-zA-Z0-9_]+\/status\/(\d+)/i,
    exampleUrl: "https://x.com/user/status/123456789"
  },
  {
    id: "pinterest",
    name: "Pinterest",
    badge: "Pinterest Video & Pins",
    color: "#bd081c",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["192kbps"],
    qualitiesMp4: ["720p", "480p"],
    regex: /(?:pinterest\.com\/pin\/|pin\.it\/)([a-zA-Z0-9_-]+)/i,
    exampleUrl: "https://www.pinterest.com/pin/123..."
  },
  {
    id: "reddit",
    name: "Reddit",
    badge: "Reddit Video",
    color: "#ff4500",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["192kbps"],
    qualitiesMp4: ["720p", "480p"],
    regex: /(?:reddit\.com\/r\/[^\/]+\/comments\/|v\.redd\.it\/)([a-zA-Z0-9_-]+)/i,
    exampleUrl: "https://www.reddit.com/r/videos/comments/..."
  },
  {
    id: "direct",
    name: "Enlace Directo",
    badge: "Archivo Web Directo",
    color: "#00f0ff",
    formats: ["mp3", "mp4"],
    qualitiesMp3: ["Original", "320kbps"],
    qualitiesMp4: ["Original", "1080p"],
    regex: /\.(mp4|webm|mov|mkv|mp3|wav|ogg|m4a|aac)(\?.*)?$/i,
    exampleUrl: "https://example.com/video.mp4"
  }
];

/**
 * Detecta la plataforma basándose en la URL suministrada
 */
function detectPlatform(url) {
  if (!url || typeof url !== "string") return null;
  const cleanUrl = url.trim();

  for (const plat of SUPPORTED_PLATFORMS) {
    if (plat.regex.test(cleanUrl)) {
      return plat;
    }
  }

  if (/^https?:\/\//i.test(cleanUrl)) {
    return {
      id: "generic",
      name: "Enlace Web",
      badge: "Media Universal",
      color: "#3b82f6",
      formats: ["mp3", "mp4"],
      qualitiesMp3: ["320kbps", "192kbps", "128kbps"],
      qualitiesMp4: ["1080p", "720p", "480p"]
    };
  }

  return null;
}

/**
 * Sanitiza nombres de archivo para descargas seguras en cualquier OS
 */
function sanitizeFilename(name, fallback = "media-convertido") {
  if (!name) return fallback;
  const clean = String(name)
    .replace(/[<>:"/\\|?*\x00-\x1F]/g, "")
    .replace(/\s+/g, "_")
    .trim();
  return clean.slice(0, 80) || fallback;
}

/**
 * Formatea bytes en formato legible (KB, MB, GB)
 */
function formatBytes(bytes) {
  if (!bytes || bytes <= 0) return "Desconocido";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
}

/**
 * Formatea segundos a tiempo legible (MM:SS o HH:MM:SS)
 */
function formatDurationSeconds(totalSeconds) {
  const s = Math.floor(Number(totalSeconds) || 0);
  if (s <= 0) return "00:00";
  const hours = Math.floor(s / 3600);
  const minutes = Math.floor((s % 3600) / 60);
  const seconds = s % 60;
  if (hours > 0) {
    return `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  }
  return `${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
}

/**
 * Genera un buffer de audio WAV sintético con tono y voz informativa
 * cuando los proveedores upstream aplican bloqueo total por IP.
 */
function generateFallbackAudio(title, platform) {
  const sampleRate = 22050;
  const duration = 4.0;
  const numSamples = Math.floor(sampleRate * duration);
  const dataSize = numSamples * 2;
  const buffer = Buffer.alloc(44 + dataSize);

  // Cabecera RIFF WAVE
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write("WAVE", 8);
  buffer.write("fmt ", 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20); // PCM
  buffer.writeUInt16LE(1, 22); // Mono
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(dataSize, 40);

  let offset = 44;
  const baseFreq = 440;
  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    const envelope = Math.sin(Math.PI * (t / duration));
    const wave = Math.sin(2 * Math.PI * baseFreq * t) * 0.6 +
                 Math.sin(2 * Math.PI * (baseFreq * 1.5) * t) * 0.3 +
                 Math.sin(2 * Math.PI * (baseFreq * 2) * t) * 0.1;
    const sample = Math.max(-1, Math.min(1, wave * envelope * 0.7));
    buffer.writeInt16LE(Math.floor(sample * 32767), offset);
    offset += 2;
  }

  return buffer;
}

/**
 * Extrae metadatos y opciones de conversión de un enlace de video
 */
async function extractMediaInfo(url, requestedFormat = "mp3") {
  if (!url || typeof url !== "string") {
    throw new Error("Debe proporcionar una URL válida de video.");
  }

  const cleanUrl = url.trim();

  // Validación y mitigación SSRF de URLs entrantes
  await validateSafeUrl(cleanUrl);

  // Comprobar caché en RAM para acelerar conversiones consecutivas del mismo enlace
  const cached = mediaInfoCache.get(cleanUrl);
  if (cached && (Date.now() - cached.cachedAt < MEDIA_INFO_TTL_MS)) {
    const cloned = JSON.parse(JSON.stringify(cached.info));
    cloned.directMediaUrl = requestedFormat === "mp4" ? (cloned.mp4Url || cloned.mp3Url) : (cloned.mp3Url || cloned.mp4Url);
    return cloned;
  }

  const platform = detectPlatform(cleanUrl);

  if (!platform) {
    throw new Error("La URL suministrada no pertenece a un servicio soportado ni es un enlace multimedia válido.");
  }

  let defaultAuthor = "Desconocido";
  let defaultTitle = "Video Multimedia";

  if (platform.id === "tiktok") {
    const uMatch = cleanUrl.match(/tiktok\.com\/@([a-zA-Z0-9_.-]+)/i);
    defaultAuthor = uMatch ? `@${uMatch[1]}` : "@tiktok_creator";
    defaultTitle = uMatch ? `TikTok de @${uMatch[1]}` : "TikTok Video";
  } else if (platform.id === "instagram") {
    const igMatch = cleanUrl.match(/instagram\.com\/(?:p|reel|reels|tv)\/([a-zA-Z0-9_-]+)/i);
    defaultAuthor = "Instagram Creator";
    defaultTitle = igMatch ? `Instagram Reel (${igMatch[1]})` : "Instagram Video";
  } else if (platform.id === "twitter") {
    const twMatch = cleanUrl.match(/(?:twitter\.com|x\.com)\/([a-zA-Z0-9_]+)\/status\/(\d+)/i);
    defaultAuthor = twMatch ? `@${twMatch[1]}` : "X / Twitter Creator";
    defaultTitle = twMatch ? `X (Twitter) Video de @${twMatch[1]}` : "Twitter / X Video";
  } else if (platform.id === "facebook") {
    defaultAuthor = "Facebook Watch";
    defaultTitle = "Facebook Video";
  } else if (platform.id === "pinterest") {
    defaultAuthor = "Pinterest Creator";
    defaultTitle = "Pinterest Pin";
  } else if (platform.id === "reddit") {
    defaultAuthor = "Reddit User";
    defaultTitle = "Reddit Video";
  }

  let info = {
    url: cleanUrl,
    platform: platform.name,
    platformId: platform.id,
    platformColor: platform.color,
    platformBadge: platform.badge,
    title: defaultTitle,
    author: defaultAuthor,
    duration: "00:00",
    durationSeconds: 0,
    thumbnail: "/img/logo.png",
    description: "",
    formats: [
      {
        type: "mp3",
        label: "Audio MP3 (Música / Voz)",
        extension: "mp3",
        mimeType: "audio/mpeg",
        qualities: [
          { id: "320k", label: "320 kbps (Calidad Máxima)", recommended: true, sizeEstimate: "7.8 MB" },
          { id: "192k", label: "192 kbps (Estándar Recomendado)", sizeEstimate: "4.7 MB" },
          { id: "128k", label: "128 kbps (Ahorro de Datos)", sizeEstimate: "3.1 MB" }
        ]
      },
      {
        type: "mp4",
        label: "Video MP4 (HD / Full HD)",
        extension: "mp4",
        mimeType: "video/mp4",
        qualities: [
          { id: "1080p", label: "1080p Full HD (60fps)", recommended: true, sizeEstimate: "38.5 MB" },
          { id: "720p", label: "720p HD", sizeEstimate: "22.1 MB" },
          { id: "480p", label: "480p SD", sizeEstimate: "14.2 MB" },
          { id: "360p", label: "360p Móvil", sizeEstimate: "8.6 MB" }
        ]
      }
    ],
    mp4Url: null,
    mp3Url: null,
    directMediaUrl: null
  };

  // Estrategia 1: YouTube y YouTube Shorts
  if (platform.id === "youtube") {
    const normalized = normalizeYouTubeUrl(cleanUrl);
    const ytMatch = normalized.match(/(?:v=|\/embed\/|\/watch\?v=|\/shorts\/)([a-zA-Z0-9_-]{11})/);
    const videoId = ytMatch ? ytMatch[1] : null;

    if (videoId) {
      info.thumbnail = `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
      info.title = `YouTube Video (${videoId})`;
      info.author = "YouTube Creator";
    }

    // 1.1 Consultar streams y metadatos oEmbed en paralelo ultra rápido
    try {
      const [ytRes, oembedRes] = await Promise.all([
        fetchYouTubeStreams(normalized),
        videoId ? axios.get(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`, { timeout: 3500 }).then(r => r.data).catch(() => null) : null
      ]);

      if (oembedRes) {
        if (oembedRes.title) info.title = oembedRes.title;
        if (oembedRes.author_name) info.author = oembedRes.author_name;
        if (oembedRes.thumbnail_url) info.thumbnail = oembedRes.thumbnail_url;
      }

      if (ytRes) {
        if (ytRes.title && (!info.title || info.title.startsWith("YouTube Video"))) info.title = ytRes.title;
        if (ytRes.author && (info.author === "Desconocido" || info.author === "YouTube Creator")) info.author = ytRes.author;
        if (ytRes.thumbnail && (!info.thumbnail || info.thumbnail.includes("logo.png"))) info.thumbnail = ytRes.thumbnail;
        info.mp4Url = ytRes.mp4 || null;
        info.mp3Url = ytRes.mp3 || ytRes.mp4 || null;
        info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);

        // Si aún no se obtuvo duración, extraer desde el parámetro dur del stream de Google Video
        if (info.durationSeconds === 0) {
          const rawStream = ytRes.mp4 || ytRes.mp3 || "";
          const decodedStream = decodeURIComponent(rawStream);
          const durMatch = decodedStream.match(/[?&]dur=([0-9.]+)/);
          if (durMatch) {
            info.durationSeconds = Math.round(parseFloat(durMatch[1]));
            info.duration = formatDurationSeconds(info.durationSeconds);
          }
        }
      }
    } catch (err) {
      logger.warn(`Error al obtener streams de YouTube para ${normalized}: ${err.message}`);
    }
  }

  // Estrategia 2: TikTok (Vía TikWM API y rahad.alldl)
  else if (platform.id === "tiktok") {
    const resolvedUrl = await resolveRedirectUrl(cleanUrl);

    // 2.1 Consulta a TikWM API (POST & GET)
    try {
      const tikRes = await axios.post("https://www.tikwm.com/api/", { url: resolvedUrl }, {
        timeout: 9000,
        headers: { "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
      });
      if (tikRes.data && tikRes.data.code === 0 && tikRes.data.data) {
        const d = tikRes.data.data;
        if (d.title) info.title = d.title.slice(0, 120);
        if (d.author?.nickname) info.author = d.author.nickname;
        else if (d.author?.unique_id) info.author = `@${d.author.unique_id}`;
        if (d.cover || d.origin_cover) info.thumbnail = d.cover || d.origin_cover;
        if (typeof d.duration === "number" && d.duration > 0) {
          info.durationSeconds = d.duration;
          info.duration = formatDurationSeconds(d.duration);
        }
        info.mp4Url = d.play || d.hdplay || null;
        info.mp3Url = d.music || d.play || null;
        info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);
      }
    } catch (tikErr) {
      logger.warn(`TikWM error para TikTok: ${tikErr.message}`);
    }

    // 2.2 Fallback con rahad-all-downloader-v2
    if (!info.directMediaUrl) {
      try {
        const { alldl } = require("rahad-all-downloader-v2");
        const dlData = await withTimeout(alldl(resolvedUrl), 15000);
        if (dlData && dlData.data) {
          if (dlData.data.title) info.title = dlData.data.title;
          if (dlData.data.thumbnail) info.thumbnail = dlData.data.thumbnail;
          else if (dlData.data.download?.thumbnail) info.thumbnail = dlData.data.download.thumbnail;
          if (dlData.data.author?.nickname || dlData.data.author?.name) {
            info.author = dlData.data.author.nickname || dlData.data.author.name;
          }
          info.mp4Url = dlData.data.download?.url || dlData.data.download?.no_watermark || dlData.data.videoUrl || null;
          info.mp3Url = dlData.data.download?.music || info.mp4Url;
          info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);
        }
      } catch (alldlErr) {
        logger.warn(`rahad.alldl fallback para TikTok: ${alldlErr.message}`);
      }
    }

    // 2.3 Fallback con btch.ttdl
    if (!info.directMediaUrl) {
      try {
        const ttRes = await withTimeout(btch.ttdl(resolvedUrl), 10000);
        if (ttRes && ttRes.status) {
          if (ttRes.title) info.title = ttRes.title;
          if (ttRes.thumbnail) info.thumbnail = ttRes.thumbnail;
          const v = Array.isArray(ttRes.video) ? ttRes.video[0] : ttRes.video;
          const a = Array.isArray(ttRes.audio) ? ttRes.audio[0] : ttRes.audio;
          info.mp4Url = v || null;
          info.mp3Url = a || v || null;
          info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);
        }
      } catch (ttErr) {
        logger.warn(`btch.ttdl fallback fallo: ${ttErr.message}`);
      }
    }
  }

  // Estrategia 3: Instagram Reels y Posts
  else if (platform.id === "instagram") {
    // 1. Proveedor de alta disponibilidad: SnapInsta API direct
    try {
      const qs = require("querystring");
      const normalizedIgUrl = cleanUrl.replace(/instagram\.com\/reels\//i, "instagram.com/reel/");
      const snapRes = await withTimeout(axios.post("https://snapinsta.lc/process", qs.stringify({
        q: normalizedIgUrl,
        scope: "home",
        lang: "en"
      }), {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Origin": "https://snapinsta.lc",
          "Referer": "https://snapinsta.lc/",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        },
        timeout: 10000
      }), 12000);

      const html = snapRes.data;
      if (html && typeof html === "string") {
        const regex = /data-media-type="(video|image)"\s+data-media-src="([^"]+)"/gi;
        let match;
        const mediaItems = [];
        while ((match = regex.exec(html)) !== null) {
          mediaItems.push({ type: match[1], src: match[2].replace(/&amp;/g, "&") });
        }
        const videoItem = mediaItems.find(m => m.type === "video") || mediaItems[0];
        if (videoItem && videoItem.src) {
          info.mp4Url = videoItem.src;
          info.mp3Url = videoItem.src;
          info.directMediaUrl = videoItem.src;
        }

        const posterMatch = html.match(/data-media-poster="([^"]+)"/i);
        if (posterMatch && posterMatch[1]) {
          info.thumbnail = posterMatch[1].replace(/&amp;/g, "&");
        }
      }
    } catch (snapErr) {
      logger.warn(`snapinsta falló para Instagram: ${snapErr.message}`);
    }

    if (!info.directMediaUrl) {
      try {
        const { alldl } = require("rahad-all-downloader-v2");
        const dl = await withTimeout(alldl(cleanUrl), 15000);
        if (dl && dl.data) {
          if (dl.data.title) info.title = dl.data.title;
          if (dl.data.thumbnail) info.thumbnail = dl.data.thumbnail;
          else if (dl.data.download?.thumbnail) info.thumbnail = dl.data.download.thumbnail;
          if (dl.data.author) info.author = dl.data.author;
          const vUrl = dl.data.videoUrl || dl.data.download?.url || dl.data.download?.no_watermark || dl.data.url;
          if (vUrl) {
            info.mp4Url = vUrl;
            info.mp3Url = vUrl;
            info.directMediaUrl = vUrl;
          }
        }
      } catch (alldlErr) {
        logger.warn(`rahad.alldl fallo para Instagram: ${alldlErr.message}`);
      }
    }

    if (!info.directMediaUrl) {
      try {
        const igRes = await withTimeout(btch.igdl(cleanUrl), 10000);
        if (igRes && igRes.status && igRes.result) {
          const items = Array.isArray(igRes.result) ? igRes.result : [igRes.result];
          const media = items.find(m => m && (m.url || m.video || m.download_url)) || items[0];
          if (media) {
            const vUrl = media.url || media.video || media.download_url;
            if (vUrl) {
              info.mp4Url = vUrl;
              info.mp3Url = vUrl;
              info.directMediaUrl = vUrl;
            }
            if (media.thumbnail || media.thumb) info.thumbnail = media.thumbnail || media.thumb;
            if (media.title) info.title = media.title;
            if (media.author) info.author = media.author;
          }
        }
      } catch (igErr) {
        logger.warn(`btch.igdl fallo para Instagram: ${igErr.message}`);
      }
    }
  }

  // Estrategia 4: Twitter / X
  else if (platform.id === "twitter") {
    try {
      const { alldl } = require("rahad-all-downloader-v2");
      const dl = await withTimeout(alldl(cleanUrl), 15000);
      if (dl && dl.data) {
        if (dl.data.title) info.title = dl.data.title;
        if (dl.data.thumbnail) info.thumbnail = dl.data.thumbnail;
        else if (dl.data.download?.thumbnail) info.thumbnail = dl.data.download.thumbnail;
        if (dl.data.author) info.author = dl.data.author;
        const vUrl = dl.data.download?.HD || dl.data.download?.url || dl.data.videoUrl;
        if (vUrl) {
          info.mp4Url = vUrl;
          info.mp3Url = vUrl;
          info.directMediaUrl = vUrl;
        }
      }
    } catch (twDlErr) {
      logger.warn(`rahad.alldl fallo para Twitter/X: ${twDlErr.message}`);
    }

    if (!info.directMediaUrl) {
      try {
        const twRes = await withTimeout(btch.twitter(cleanUrl), 10000);
        if (twRes && twRes.status && twRes.url) {
          const vUrl = Array.isArray(twRes.url) ? twRes.url[0]?.hd || twRes.url[0]?.sd || twRes.url[0] : twRes.url;
          if (vUrl) {
            info.mp4Url = vUrl;
            info.mp3Url = vUrl;
            info.directMediaUrl = vUrl;
          }
          if (twRes.title) info.title = twRes.title;
          if (twRes.thumb) info.thumbnail = twRes.thumb;
        }
      } catch (twErr) {
        logger.warn(`btch.twitter fallo para Twitter/X: ${twErr.message}`);
      }
    }
  }

  // Estrategia 5: Facebook Video
  else if (platform.id === "facebook") {
    try {
      const fbRes = await withTimeout(btch.fbdown(cleanUrl), 10000);
      if (fbRes && fbRes.status) {
        const vUrl = fbRes.Normal_video || fbRes.HD || fbRes.video;
        if (vUrl) {
          info.mp4Url = vUrl;
          info.mp3Url = vUrl;
          info.directMediaUrl = vUrl;
        }
        if (fbRes.title) info.title = fbRes.title;
        if (fbRes.thumbnail || fbRes.thumb) info.thumbnail = fbRes.thumbnail || fbRes.thumb;
      }
    } catch (fbErr) {
      logger.warn(`btch.fbdown fallo para Facebook: ${fbErr.message}`);
    }
  }

  // Estrategia 6: Pinterest Video
  else if (platform.id === "pinterest") {
    try {
      const pinRes = await withTimeout(btch.pinterest(cleanUrl), 10000);
      if (pinRes && pinRes.status && pinRes.result) {
        const vUrl = pinRes.result.url || pinRes.result.video;
        if (vUrl) {
          info.mp4Url = vUrl;
          info.mp3Url = vUrl;
          info.directMediaUrl = vUrl;
        }
        if (pinRes.result.title) info.title = pinRes.result.title;
      }
    } catch (pinErr) {
      logger.warn(`btch.pinterest fallo para Pinterest: ${pinErr.message}`);
    }
  }

  // Estrategia 7: Enlace Directo Multimedia
  else if (platform.id === "direct" || /^https?:\/\/.+\.(mp4|webm|mov|mkv|mp3|wav|ogg|m4a|aac)(\?.*)?$/i.test(cleanUrl)) {
    const filenameMatch = cleanUrl.match(/\/([^\/?#]+)[^/]*$/);
    const rawFilename = filenameMatch ? filenameMatch[1] : "archivo-multimedia";
    info.title = decodeURIComponent(rawFilename);
    info.directMediaUrl = cleanUrl;
    info.mp4Url = cleanUrl;
    info.mp3Url = cleanUrl;
  }

  // Asegurar autor y título descriptivos (nunca "Desconocido")
  if (!info.author || info.author === "Desconocido") {
    info.author = defaultAuthor !== "Desconocido" ? defaultAuthor : platform.name;
  }
  if (!info.title || info.title === "Video Multimedia") {
    info.title = defaultTitle;
  }

  // Si la miniatura es una URL remota externa (TikTok, Instagram, Twitter, etc.),
  // enrutar a través de nuestro proxy para garantizar que nunca sea bloqueada por CORS o Referer.
  // Si no se obtuvo miniatura remota o es el logo por defecto, generar miniatura estilizada por proxy SVG.
  if (info.thumbnail && typeof info.thumbnail === "string" && info.thumbnail.startsWith("http")) {
    if (!info.thumbnail.includes("i.ytimg.com") && !info.thumbnail.includes("/api/media/thumbnail-proxy")) {
      info.thumbnail = `/api/media/thumbnail-proxy?url=${encodeURIComponent(info.thumbnail)}&title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
    }
  } else if (!info.thumbnail || info.thumbnail === "/img/logo.png") {
    info.thumbnail = `/api/media/thumbnail-proxy?title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
  }

  // Almacenar en caché en RAM para acelerar conversiones subsecuentes del mismo enlace
  try {
    mediaInfoCache.set(cleanUrl, {
      info: JSON.parse(JSON.stringify(info)),
      cachedAt: Date.now()
    });
  } catch {}

  return info;
}

/**
 * Transcodifica un stream remoto a MP3 puro usando FFmpeg
 */
function transcodeToMp3(streamUrl, outputPath, quality = "320k") {
  return new Promise((resolve, reject) => {
    try {
      const bitrateMap = {
        "320k": "320k",
        "256k": "256k",
        "192k": "192k",
        "128k": "128k",
        "96k": "96k",
        "64k": "64k"
      };
      const bitrate = bitrateMap[quality] || (quality.endsWith("k") ? quality : `${quality}k`);

      // Intento 1: Ejecución nativa directa de FFmpeg con soporte de HTTP seeking
      const ff = spawn(ffmpegPath, [
        "-y",
        "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "-i", streamUrl,
        "-vn",
        "-c:a", "libmp3lame",
        "-b:a", bitrate,
        "-id3v2_version", "3",
        "-write_xing", "1",
        "-f", "mp3",
        outputPath
      ]);

      let stderr = "";
      ff.stderr.on("data", d => { stderr += d.toString(); });

      ff.on("close", (code) => {
        if (code === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
          const stats = fs.statSync(outputPath);
          let duration = null;
          let durationSeconds = 0;
          const durMatch = stderr.match(/Duration:\s*(\d{2}):(\d{2}):(\d{2})/);
          if (durMatch) {
            const h = parseInt(durMatch[1], 10);
            const m = parseInt(durMatch[2], 10);
            const s = parseInt(durMatch[3], 10);
            durationSeconds = h * 3600 + m * 60 + s;
            duration = h > 0 ? `${durMatch[1]}:${durMatch[2]}:${durMatch[3]}` : `${durMatch[2]}:${durMatch[3]}`;
          }
          return resolve({ sizeBytes: stats.size, duration, durationSeconds });
        }

        // Intento 2: Fallback vía axios stream piping
        logger.warn(`FFmpeg directo terminó con código ${code}, probando stream pipe...`);
        axios({
          method: "get",
          url: streamUrl,
          responseType: "stream",
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "*/*"
          },
          timeout: 45000
        }).then(response => {
          const ffPipe = spawn(ffmpegPath, [
            "-y",
            "-i", "pipe:0",
            "-vn",
            "-c:a", "libmp3lame",
            "-b:a", bitrate,
            "-id3v2_version", "3",
            "-write_xing", "1",
            "-f", "mp3",
            outputPath
          ]);
          let pipeStderr = "";
          ffPipe.stderr.on("data", d => { pipeStderr += d.toString(); });
          response.data.pipe(ffPipe.stdin);
          ffPipe.on("close", (pipeCode) => {
            if (pipeCode === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
              const stats = fs.statSync(outputPath);
              return resolve({ sizeBytes: stats.size, duration: null, durationSeconds: 0 });
            }
            reject(new Error(`FFmpeg MP3 transcode exited with code ${pipeCode}: ${pipeStderr.slice(-300)}`));
          });
          response.data.on("error", reject);
        }).catch(reject);
      });

      ff.on("error", err => {
        reject(err);
      });
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Transcodifica un stream remoto a WAV puro (Audio PCM 16-bit sin compresión)
 */
function transcodeToWav(streamUrl, outputPath) {
  return new Promise((resolve, reject) => {
    try {
      const ff = spawn(ffmpegPath, [
        "-y",
        "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "-i", streamUrl,
        "-vn",
        "-c:a", "pcm_s16le",
        "-f", "wav",
        outputPath
      ]);

      let stderr = "";
      ff.stderr.on("data", d => { stderr += d.toString(); });

      ff.on("close", (code) => {
        if (code === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
          const stats = fs.statSync(outputPath);
          return resolve({ sizeBytes: stats.size, duration: null, durationSeconds: 0 });
        }

        // Intento 2: Fallback vía Axios stream pipe
        axios({
          method: "get",
          url: streamUrl,
          responseType: "stream",
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "*/*"
          },
          timeout: 45000
        }).then(response => {
          const ffPipe = spawn(ffmpegPath, [
            "-y",
            "-i", "pipe:0",
            "-vn",
            "-c:a", "pcm_s16le",
            "-f", "wav",
            outputPath
          ]);
          let pipeStderr = "";
          ffPipe.stderr.on("data", d => { pipeStderr += d.toString(); });
          response.data.pipe(ffPipe.stdin);
          ffPipe.on("close", (pipeCode) => {
            if (pipeCode === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
              const statsPipe = fs.statSync(outputPath);
              return resolve({ sizeBytes: statsPipe.size, duration: null, durationSeconds: 0 });
            }
            reject(new Error(`FFmpeg WAV transcode failed with code ${pipeCode}: ${pipeStderr.slice(-250)}`));
          });
          response.data.on("error", reject);
        }).catch(reject);
      });

      ff.on("error", reject);
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Remuxea o transcodifica un stream remoto a MP4 estándar para reproducción web instantánea
 */
function transcodeToMp4(streamUrl, outputPath, quality = "1080p", audioStreamUrl = null) {
  return new Promise((resolve, reject) => {
    try {
      const hasSeparateAudio = Boolean(audioStreamUrl && audioStreamUrl !== streamUrl);
      const directArgs = [
        "-y",
        "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "-i", streamUrl
      ];

      if (hasSeparateAudio) {
        directArgs.push(
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
          "-i", audioStreamUrl,
          "-c:v", "copy",
          "-c:a", "aac",
          "-b:a", "192k",
          "-map", "0:v:0?",
          "-map", "1:a:0?",
          "-shortest"
        );
      } else {
        directArgs.push("-c", "copy");
      }

      directArgs.push("-movflags", "+faststart", "-f", "mp4", outputPath);

      const ff = spawn(ffmpegPath, directArgs);

      let stderr = "";
      ff.stderr.on("data", d => { stderr += d.toString(); });

      ff.on("close", (code) => {
        if (code === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
          const stats = fs.statSync(outputPath);
          let duration = null;
          let durationSeconds = 0;
          const durMatch = stderr.match(/Duration:\s*(\d{2}):(\d{2}):(\d{2})/);
          if (durMatch) {
            const h = parseInt(durMatch[1], 10);
            const m = parseInt(durMatch[2], 10);
            const s = parseInt(durMatch[3], 10);
            durationSeconds = h * 3600 + m * 60 + s;
            duration = h > 0 ? `${durMatch[1]}:${durMatch[2]}:${durMatch[3]}` : `${durMatch[2]}:${durMatch[3]}`;
          }
          return resolve({ sizeBytes: stats.size, duration, durationSeconds });
        }

        // Intento 2: Transcodificación directa si -c copy falla o requiere remuxing complejo
        logger.warn(`FFmpeg copy directo terminó con código ${code}, probando transcodificación...`);
        const transArgs = [
          "-y",
          "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
          "-i", streamUrl
        ];
        if (hasSeparateAudio) {
          transArgs.push(
            "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "-i", audioStreamUrl,
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "128k",
            "-map", "0:v:0?",
            "-map", "1:a:0?",
            "-shortest"
          );
        } else {
          transArgs.push(
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "128k"
          );
        }
        transArgs.push("-movflags", "+faststart", "-f", "mp4", outputPath);

        const ffTrans = spawn(ffmpegPath, transArgs);
        let stderrTrans = "";
        ffTrans.stderr.on("data", d => { stderrTrans += d.toString(); });
        ffTrans.on("close", (tCode) => {
          if (tCode === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
            const statsTrans = fs.statSync(outputPath);
            return resolve({ sizeBytes: statsTrans.size, duration: null, durationSeconds: 0 });
          }

          if (!hasSeparateAudio) {
            axios({
              method: "get",
              url: streamUrl,
              responseType: "stream",
              headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                "Accept": "*/*"
              },
              timeout: 60000
            }).then(response => {
              const ffPipe = spawn(ffmpegPath, [
                "-y",
                "-i", "pipe:0",
                "-c", "copy",
                "-movflags", "+faststart",
                "-f", "mp4",
                outputPath
              ]);
              response.data.pipe(ffPipe.stdin);
              ffPipe.on("close", (pCode) => {
                if (pCode === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
                  return resolve({ sizeBytes: fs.statSync(outputPath).size, duration: null, durationSeconds: 0 });
                }
                reject(new Error(`FFmpeg MP4 transcode failed: ${stderrTrans.slice(-250)}`));
              });
              response.data.on("error", reject);
            }).catch(() => reject(new Error(`FFmpeg MP4 transcode failed: ${stderrTrans.slice(-250)}`)));
          } else {
            reject(new Error(`FFmpeg MP4 transcode failed: ${stderrTrans.slice(-250)}`));
          }
        });
        ffTrans.on("error", reject);
      });

      ff.on("error", err => {
        reject(err);
      });
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Procesa la conversión de un video al formato elegido (MP3 o MP4)
 * de forma 100% nativa en el backend y almacena el archivo físico en el servidor.
 */
async function processConversion(options = {}) {
  const { url, format = "mp3", quality = "320k" } = options;

  if (!url) {
    throw new Error("El parámetro 'url' es obligatorio para la conversión.");
  }

  const fmtLower = String(format || "").toLowerCase().trim();
  const selectedFormat = ["mp4", "wav"].includes(fmtLower) ? fmtLower : "mp3";
  const mediaInfo = await extractMediaInfo(url, selectedFormat);

  const jobId = "media_" + Date.now() + "_" + Math.random().toString(36).slice(2, 8);
  const cleanTitle = sanitizeFilename(mediaInfo.title, `${mediaInfo.platformId}-media`);
  const extension = selectedFormat;
  const mimeType = selectedFormat === "mp4" ? "video/mp4" : (selectedFormat === "wav" ? "audio/wav" : "audio/mpeg");
  const downloadFilename = `Vork_${cleanTitle}.${extension}`;
  const outputPath = path.join(MEDIA_CACHE_DIR, `${jobId}.${extension}`);

  // Construir lista de candidatos según formato y plataforma
  const candidateStreams = [];
  if (selectedFormat === "mp3" || selectedFormat === "wav") {
    // Para MP3 o WAV: preferir siempre el stream de audio directo (mucho más rápido y ligero)
    if (mediaInfo.mp3Url) candidateStreams.push(mediaInfo.mp3Url);
    if (mediaInfo.directMediaUrl && !candidateStreams.includes(mediaInfo.directMediaUrl)) {
      candidateStreams.push(mediaInfo.directMediaUrl);
    }
    if (mediaInfo.mp4Url && !candidateStreams.includes(mediaInfo.mp4Url)) {
      candidateStreams.push(mediaInfo.mp4Url);
    }
  } else {
    // Para MP4: preferir stream directo de video (no mezclar con audio puro)
    if (mediaInfo.mp4Url) candidateStreams.push(mediaInfo.mp4Url);
    if (mediaInfo.directMediaUrl && !candidateStreams.includes(mediaInfo.directMediaUrl)) {
      candidateStreams.push(mediaInfo.directMediaUrl);
    }
  }

  let finalDuration = mediaInfo.duration;
  let finalDurationSeconds = mediaInfo.durationSeconds;
  let sizeBytes = 0;
  let transSuccess = false;
  let lastConvError = null;

  for (const streamUrl of candidateStreams) {
    if (!streamUrl) continue;
    try {
      if (selectedFormat === "mp3") {
        const transRes = await transcodeToMp3(streamUrl, outputPath, quality);
        sizeBytes = transRes.sizeBytes;
        if (transRes.duration && (finalDuration === "00:00" || !finalDurationSeconds)) {
          finalDuration = transRes.duration;
          finalDurationSeconds = transRes.durationSeconds;
        }
        transSuccess = true;
        break;
      } else if (selectedFormat === "wav") {
        const transRes = await transcodeToWav(streamUrl, outputPath);
        sizeBytes = transRes.sizeBytes;
        transSuccess = true;
        break;
      } else {
        const separateAudioUrl = mediaInfo.separateAudio ? mediaInfo.mp3Url : null;
        const transRes = await transcodeToMp4(streamUrl, outputPath, quality, separateAudioUrl);
        sizeBytes = transRes.sizeBytes;
        if (transRes.duration && (finalDuration === "00:00" || !finalDurationSeconds)) {
          finalDuration = transRes.duration;
          finalDurationSeconds = transRes.durationSeconds;
        }
        transSuccess = true;
        break;
      }
    } catch (convErr) {
      logger.warn(`Intento de transcodificación FFmpeg falló con stream: ${convErr.message}`);
      lastConvError = convErr.message;
      if (fs.existsSync(outputPath)) {
        try { fs.unlinkSync(outputPath); } catch {}
      }
    }
  }

  // Si no se pudo generar archivo desde ningún stream, notificar error explícito sin generar audio falso
  if (!transSuccess || !fs.existsSync(outputPath) || sizeBytes < 1000) {
    const detail = lastConvError ? ` (${lastConvError})` : '';
    throw new Error(`No se pudo procesar la conversión a ${selectedFormat.toUpperCase()} (${quality}) para este enlace${detail}. Por favor verifique el enlace e intente nuevamente.`);
  }

  const thumbPath = path.join(MEDIA_CACHE_DIR, `${jobId}_thumb.jpg`);
  let finalThumbnail = mediaInfo.thumbnail;

  if (selectedFormat === "mp4" && fs.existsSync(outputPath)) {
    try {
      const ffThumb = spawn(ffmpegPath, [
        "-y",
        "-ss", "00:00:01",
        "-i", outputPath,
        "-vframes", "1",
        "-q:v", "2",
        thumbPath
      ]);
      await new Promise(res => ffThumb.on("close", res));
      if (fs.existsSync(thumbPath) && fs.statSync(thumbPath).size > 0) {
        finalThumbnail = `/api/media/thumbnail?id=${jobId}`;
      }
    } catch {}
  }

  if (!finalThumbnail || finalThumbnail === "/img/logo.png") {
    finalThumbnail = `/api/media/thumbnail-proxy?title=${encodeURIComponent(mediaInfo.title)}&platform=${encodeURIComponent(mediaInfo.platform)}&author=${encodeURIComponent(mediaInfo.author)}`;
  }
  const itemRecord = {
    id: jobId,
    url: mediaInfo.url,
    title: mediaInfo.title,
    author: mediaInfo.author,
    platform: mediaInfo.platform,
    platformId: mediaInfo.platformId,
    format: selectedFormat,
    quality,
    mimeType,
    filename: downloadFilename,
    filePath: outputPath,
    thumbPath,
    duration: finalDuration,
    durationSeconds: finalDurationSeconds,
    sizeBytes,
    thumbnail: finalThumbnail,
    mp4Url: mediaInfo.mp4Url || null,
    mp3Url: mediaInfo.mp3Url || null,
    createdAt: Date.now()
  };

  // Guardar metadata en disco para persistencia ante reinicios
  const metaDiskPath = path.join(MEDIA_CACHE_DIR, `${jobId}.json`);
  try {
    fs.writeFileSync(metaDiskPath, JSON.stringify(itemRecord), 'utf8');
  } catch {}

  // Guardar en almacén en RAM con enlace al archivo físico en disco
  mediaBufferStore.set(jobId, itemRecord);

  const baseUrl = ""; // Rutas relativas para compatibilidad universal
  const streamUrl = `${baseUrl}/api/media/stream?id=${jobId}`;
  const videoStreamUrl = `${baseUrl}/api/media/stream?id=${jobId}&type=video`;
  const audioStreamUrl = `${baseUrl}/api/media/stream?id=${jobId}&type=audio`;
  const downloadUrl = `${baseUrl}/api/media/download?id=${jobId}`;

  return {
    status: "success",
    id: jobId,
    title: mediaInfo.title,
    author: mediaInfo.author,
    platform: mediaInfo.platform,
    platformId: mediaInfo.platformId,
    format: selectedFormat,
    quality,
    thumbnail: mediaInfo.thumbnail,
    duration: finalDuration,
    durationSeconds: finalDurationSeconds,
    streamUrl,
    videoStreamUrl,
    audioStreamUrl,
    directVideoUrl: mediaInfo.mp4Url || null,
    directAudioUrl: mediaInfo.mp3Url || null,
    downloadUrl,
    filename: downloadFilename,
    mimeType,
    sizeBytes,
    sizeFormatted: formatBytes(sizeBytes),
    message: `Conversión completada a formato ${selectedFormat.toUpperCase()} (${quality}). Descarga directa disponible desde Vork.`
  };
}

/**
 * Obtiene el registro de un medio por su ID
 */
function getMediaById(id) {
  if (!id) return null;
  let item = mediaBufferStore.get(id);
  if (!item) {
    // Intentar recuperar desde almacenamiento físico si el proceso se reinició
    const possibleExts = ["mp4", "mp3", "wav", "webm"];
    for (const ext of possibleExts) {
      const diskPath = path.join(MEDIA_CACHE_DIR, `${id}.${ext}`);
      if (fs.existsSync(diskPath)) {
        const stats = fs.statSync(diskPath);
        const metaPath = path.join(MEDIA_CACHE_DIR, `${id}.json`);
        let meta = {};
        if (fs.existsSync(metaPath)) {
          try { meta = JSON.parse(fs.readFileSync(metaPath, 'utf8')); } catch {}
        }
        item = {
          id,
          format: ext,
          mimeType: ext === "mp4" ? "video/mp4" : ext === "wav" ? "audio/wav" : "audio/mpeg",
          filePath: diskPath,
          filename: meta.filename || `Vork_Media_${id}.${ext}`,
          sizeBytes: stats.size,
          mp4Url: meta.mp4Url || null,
          mp3Url: meta.mp3Url || null,
          createdAt: meta.createdAt || stats.mtimeMs || Date.now()
        };
        mediaBufferStore.set(id, item);
        break;
      }
    }
  }
  if (!item) return null;
  if (Date.now() - item.createdAt > MEDIA_STORE_TTL_MS) {
    if (item.filePath && fs.existsSync(item.filePath)) {
      try { fs.unlinkSync(item.filePath); } catch {}
    }
    const metaPath = path.join(MEDIA_CACHE_DIR, `${id}.json`);
    if (fs.existsSync(metaPath)) {
      try { fs.unlinkSync(metaPath); } catch {}
    }
    mediaBufferStore.delete(id);
    return null;
  }
  return item;
}

module.exports = {
  MEDIA_CACHE_DIR,
  SUPPORTED_PLATFORMS,
  detectPlatform,
  extractMediaInfo,
  processConversion,
  getMediaById,
  formatBytes,
  formatDurationSeconds,
  sanitizeFilename
};
