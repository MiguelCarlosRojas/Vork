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
const logger = require("../../../util/logger");
const { validateSafeUrl } = require("../../../util/validator");
const cheerio = require("cheerio");

/**
 * Normaliza y limpia URLs de stream de medios asegurando acceso directo sin intermediarios defectuosos
 */
function wrapStreamUrl(url) {
  if (!url || typeof url !== "string") return url;
  let clean = url.trim();
  if (clean.includes("api.vidsnap.app/proxy?u=")) {
    try {
      const match = clean.match(/[?&]u=([^&]+)/);
      if (match) clean = decodeURIComponent(match[1]);
    } catch {}
  }
  return clean;
}

/**
 * Decodificación y desencriptación de respuestas ofuscadas de SnapSave
 */
function decodeSnapApp(args) {
  let [h, u, n, t, e, r] = args;
  const tNum = Number(t);
  const eNum = Number(e);
  function decode(d, e, f) {
    const g = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/".split("");
    const hArr = g.slice(0, e);
    const iArr = g.slice(0, f);
    let j = d.split("").reverse().reduce((a, b, c) => {
      const idx = hArr.indexOf(b);
      if (idx !== -1) return a + idx * Math.pow(e, c);
      return a;
    }, 0);
    let k = "";
    while (j > 0) {
      k = iArr[j % f] + k;
      j = Math.floor(j / f);
    }
    return k || "0";
  }
  let result = "";
  for (let i = 0, len = h.length; i < len;) {
    let s = "";
    while (i < len && h[i] !== n[eNum]) {
      s += h[i];
      i++;
    }
    i++;
    for (let j = 0; j < n.length; j++) s = s.replace(new RegExp(n[j], "g"), j.toString());
    result += String.fromCharCode(Number(decode(s, eNum, 10)) - tNum);
  }
  const fixEncoding = (str) => {
    try {
      const bytes = new Uint8Array(str.split("").map((char) => char.charCodeAt(0)));
      return new TextDecoder("utf-8").decode(bytes);
    } catch {
      return str;
    }
  };
  return fixEncoding(result);
}

function getEncodedSnapApp(data) {
  return data.split("decodeURIComponent(escape(r))}(")[1].split("))")[0].split(",").map((v) => v.replace(/"/g, "").trim());
}

function getDecodedSnapSave(data) {
  const errorMessage = data?.split("document.querySelector(\"#alert\").innerHTML = \"")?.[1]?.split("\";")?.[0]?.trim();
  if (errorMessage) throw new Error(errorMessage);
  return data.split("getElementById(\"download-section\").innerHTML = \"")[1].split("\"; document.getElementById(\"inputData\").remove(); ")[0].replace(/\\(\\)?/g, "");
}

function decryptSnapSave(data) {
  return getDecodedSnapSave(decodeSnapApp(getEncodedSnapApp(data)));
}

/**
 * Extrae metadatos nativos de Facebook (título, autor y miniatura original)
 */
async function fetchFacebookMetadata(cleanUrl) {
  let title = null;
  let author = null;
  let thumbnail = null;

  try {
    const r = await axios.get(cleanUrl, {
      headers: {
        "User-Agent": "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      },
      timeout: 8000,
      maxRedirects: 5
    });
    const $ = cheerio.load(r.data);
    const ogTitle = $('meta[property="og:title"]').attr('content') || '';
    const ogDesc = $('meta[property="og:description"]').attr('content') || '';
    const ogThumb = $('meta[property="og:image"]').attr('content') || '';
    const rawTitleTag = $('title').text() || '';

    if (ogDesc && ogDesc.length > 3) {
      title = ogDesc.slice(0, 100);
    } else if (rawTitleTag) {
      title = rawTitleTag.split('|')[0].trim().slice(0, 100);
    }

    if (rawTitleTag.includes('|')) {
      const parts = rawTitleTag.split('|');
      author = parts[parts.length - 1].trim();
    } else if (ogTitle.includes('|')) {
      const parts = ogTitle.split('|');
      author = parts[parts.length - 1].trim();
    }

    if (ogThumb && ogThumb.startsWith('http')) {
      thumbnail = ogThumb;
    }
  } catch {}

  return { title, author, thumbnail };
}

// Ruta al binario de FFmpeg con fallback a binario de sistema
let ffmpegPath = "ffmpeg";
try {
  const ffmpegInstaller = require("@ffmpeg-installer/ffmpeg");
  if (ffmpegInstaller && ffmpegInstaller.path) {
    ffmpegPath = ffmpegInstaller.path;
    if (process.platform !== "win32" && fs.existsSync(ffmpegPath)) {
      try { fs.chmodSync(ffmpegPath, 0o755); } catch {}
    }
  }
} catch (e) {
  logger.warn(`No se pudo cargar @ffmpeg-installer/ffmpeg, se usará 'ffmpeg' del sistema: ${e.message}`);
}

/**
 * Genera los argumentos de cabecera y agente de usuario óptimos para FFmpeg según el origen del medio
 */
function getFfmpegInputArgs(url) {
  const args = [
    "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
  ];
  if (!url || typeof url !== "string" || !url.startsWith("http")) return args;
  try {
    const u = new URL(url);
    if (/googlevideo\.com|youtube\.com/i.test(u.hostname)) {
      args.push("-headers", "Referer: https://www.youtube.com/\r\n");
    } else if (/tiktok|byteoversea|ibytedtos/i.test(u.hostname)) {
      args.push("-headers", "Referer: https://www.tiktok.com/\r\n");
    } else if (/twitter|twimg|x\.com/i.test(u.hostname)) {
      args.push("-headers", "Referer: https://twitter.com/\r\n");
    } else if (/instagram|cdninstagram|fbcdn/i.test(u.hostname)) {
      args.push("-headers", "Referer: https://www.instagram.com/\r\n");
    } else if (/chocolatemoo53|invidious|nerdvpn/i.test(u.hostname)) {
      args.push("-headers", `Referer: ${u.origin}/\r\n`);
    }
  } catch {}
  return args;
}

/**
 * Reescribe URLs directas de GoogleVideo a través del proxy inverso de la instancia de Invidious
 * para eludir bloqueos de IP de datacenters (HTTP 403 Forbidden) en plataformas como Render.
 */
function toInvidiousProxyUrl(inst, streamUrl) {
  if (!streamUrl || typeof streamUrl !== "string") return streamUrl;
  try {
    const parsed = new URL(streamUrl);
    if (parsed.hostname.includes("googlevideo.com")) {
      const instUrl = new URL(inst || "https://yt.chocolatemoo53.com");
      parsed.protocol = instUrl.protocol;
      parsed.host = instUrl.host;
      parsed.port = instUrl.port;
      return parsed.toString();
    }
  } catch {}
  return streamUrl;
}

/**
 * Extrae un fotograma JPEG de alta fidelidad desde un archivo de video o flujo remoto con FFmpeg
 */
async function extractThumbnailFrame(videoSource, targetThumbPath) {
  if (!videoSource || !targetThumbPath) return false;
  let localSource = videoSource;
  let tempLocalFile = null;

  // Si es URL remota, descargar los primeros 512KB vía Axios para eludir el fallo de TLS en FFmpeg estático en Linux
  if (typeof videoSource === "string" && (videoSource.startsWith("http://") || videoSource.startsWith("https://"))) {
    try {
      const parentDir = path.dirname(targetThumbPath);
      if (!fs.existsSync(parentDir)) fs.mkdirSync(parentDir, { recursive: true });
      const tempPath = path.join(parentDir, `temp_thumb_${Date.now()}_${Math.random().toString(36).slice(2, 6)}.tmp`);
      let referer = "https://www.google.com/";
      if (/tiktok|byteoversea|ibytedtos|muscdn|musical\.ly/i.test(videoSource)) referer = "https://www.tiktok.com/";
      else if (/tikwm\.com/i.test(videoSource)) referer = "https://www.tikwm.com/";
      else if (/twitter|twimg|x\.com/i.test(videoSource)) referer = "https://twitter.com/";
      else if (/instagram|cdninstagram|fbcdn/i.test(videoSource)) referer = "https://www.instagram.com/";
      else if (/googlevideo|youtube|youtu\.be/i.test(videoSource)) referer = "https://www.youtube.com/";
      else if (/chocolatemoo53|invidious|nerdvpn/i.test(videoSource)) referer = "https://yt.chocolatemoo53.com/";

      const r = await axios.get(videoSource, {
        headers: {
          "Range": "bytes=0-524288",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "Referer": referer
        },
        responseType: "arraybuffer",
        timeout: 6000
      });
      if (r.data && r.data.length > 1000) {
        fs.writeFileSync(tempPath, r.data);
        localSource = tempPath;
        tempLocalFile = tempPath;
      }
    } catch {}
  }

  try {
    return await new Promise((resolve) => {
      try {
        const parentDir = path.dirname(targetThumbPath);
        if (!fs.existsSync(parentDir)) {
          fs.mkdirSync(parentDir, { recursive: true });
        }

        const args1 = [
          "-y",
          "-ss", "00:00:01",
          "-i", localSource,
          "-vframes", "1",
          "-q:v", "2",
          targetThumbPath
        ];
        const ff = spawn(ffmpegPath, args1);
        const timer = setTimeout(() => {
          try { ff.kill("SIGKILL"); } catch {}
          resolve(false);
        }, 7000);
        ff.on("close", (code) => {
          clearTimeout(timer);
          if (code === 0 && fs.existsSync(targetThumbPath) && fs.statSync(targetThumbPath).size > 500) {
            resolve(true);
          } else {
            try {
              const args2 = ["-y", "-i", localSource, "-vframes", "1", "-q:v", "2", targetThumbPath];
              const ff2 = spawn(ffmpegPath, args2);
              const timer2 = setTimeout(() => {
                try { ff2.kill("SIGKILL"); } catch {}
                resolve(false);
              }, 5000);
              ff2.on("close", (c2) => {
                clearTimeout(timer2);
                resolve(c2 === 0 && fs.existsSync(targetThumbPath) && fs.statSync(targetThumbPath).size > 500);
              });
              ff2.on("error", () => {
                clearTimeout(timer2);
                resolve(false);
              });
            } catch {
              resolve(false);
            }
          }
        });
        ff.on("error", () => {
          clearTimeout(timer);
          resolve(false);
        });
      } catch {
        resolve(false);
      }
    });
  } finally {
    if (tempLocalFile && fs.existsSync(tempLocalFile)) {
      try { fs.unlinkSync(tempLocalFile); } catch {}
    }
  }
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
 * Extrae y normaliza la etiqueta del idioma y tipo de pista de audio a partir de los metadatos y xtags de YouTube
 */
function parseAudioTrackLabel(url) {
  if (!url) return "Audio Estándar";
  try {
    const decoded = decodeURIComponent(decodeURIComponent(url));
    const xtagsMatch = decoded.match(/xtags=([^&]+)/);
    if (xtagsMatch) {
      const xtags = xtagsMatch[1];
      const langMatch = xtags.match(/lang=([a-zA-Z0-9-]+)/);
      const acontMatch = xtags.match(/acont=([a-zA-Z0-9-]+)/);
      const langCode = langMatch ? langMatch[1].toLowerCase() : "";
      const isOriginal = acontMatch ? acontMatch[1].includes("original") : false;
      const isDubbed = acontMatch ? acontMatch[1].includes("dubbed") : false;

      let langName = langCode;
      if (langCode.startsWith("es")) langName = "Español";
      else if (langCode.startsWith("en")) langName = "Inglés";
      else if (langCode.startsWith("pt")) langName = "Portugués";
      else if (langCode.startsWith("ar")) langName = "Árabe";
      else if (langCode.startsWith("ja")) langName = "Japonés";
      else if (langCode.startsWith("fr")) langName = "Francés";
      else if (langCode.startsWith("de")) langName = "Alemán";
      else if (langCode.startsWith("it")) langName = "Italiano";
      else if (langCode.startsWith("ko")) langName = "Coreano";
      else if (langCode.startsWith("ru")) langName = "Ruso";
      else if (langCode.startsWith("zh")) langName = "Chino";
      else if (langCode.startsWith("hi")) langName = "Hindi";
      else if (langCode.startsWith("id")) langName = "Indonesio";
      else if (langCode.startsWith("tr")) langName = "Turco";
      else if (langCode.startsWith("pl")) langName = "Polaco";
      else if (langCode.startsWith("vi")) langName = "Vietnamita";
      else if (langCode.startsWith("th")) langName = "Tailandés";
      else if (langCode.startsWith("nl")) langName = "Holandés";

      if (isOriginal) return `${langName} (Original)`;
      if (isDubbed) return `${langName} (Doblado)`;
      return langName || "Audio Estándar";
    }
  } catch {}
  return "Audio Estándar";
}

/**
 * Consulta de alta disponibilidad y concurrencia a proveedores y espejos de extracción para YouTube
 * Detecta y recopila múltiples pistas de audio disponibles (idiomas, doblajes y originales)
 * y clasifica los flujos de video por resolución nativa (1080p, 720p, 480p, 360p).
 */
async function fetchYouTubeStreams(normalizedUrl) {
  const ytMatch = normalizedUrl.match(/(?:v=|\/embed\/|\/watch\?v=|\/shorts\/)([a-zA-Z0-9_-]{11})/);
  const videoId = ytMatch ? ytMatch[1] : null;

  const fetchInvidious = async () => {
    if (!videoId) throw new Error("Video ID no encontrado para Invidious");
    const instances = [
      "https://yt.chocolatemoo53.com",
      "https://invidious.nerdvpn.de",
      "https://invidious.f5.si"
    ];

    for (const inst of instances) {
      try {
        const res = await axios.get(`${inst}/api/v1/videos/${videoId}`, {
          timeout: 6500,
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            "Accept": "application/json"
          }
        });
        const d = res.data;
        if (!d || (!d.adaptiveFormats && !d.formatStreams)) continue;

        const allFormats = [...(d.adaptiveFormats || []), ...(d.formatStreams || [])];
        const audioFormats = (d.adaptiveFormats || []).filter(f => f.type?.startsWith("audio/"));
        const videoFormats = allFormats.filter(f => f.type?.startsWith("video/"));

        // Deduplicar pistas de audio por idioma/etiqueta priorizando MP4/AAC (itag 140 / mp4a) para máxima compatibilidad web
        audioFormats.sort((a, b) => {
          const isA_AAC = a.type?.includes("mp4a") || a.type?.includes("mp4") || a.container === "m4a";
          const isB_AAC = b.type?.includes("mp4a") || b.type?.includes("mp4") || b.container === "m4a";
          if (isA_AAC && !isB_AAC) return -1;
          if (!isA_AAC && isB_AAC) return 1;
          return (Number(b.bitrate) || 0) - (Number(a.bitrate) || 0);
        });
        const audioTracks = [];
        const seenAudioLabels = new Set();
        audioFormats.forEach(af => {
          if (!af.url) return;
          const proxyUrl = toInvidiousProxyUrl(inst, af.url);
          const label = parseAudioTrackLabel(af.url) || af.audioTrack || "Audio Estándar";
          if (seenAudioLabels.has(label)) return;
          seenAudioLabels.add(label);
          audioTracks.push({
            id: `audio_${audioTracks.length}`,
            label,
            url: wrapStreamUrl(proxyUrl),
            isDefault: label.toLowerCase().includes("original") || audioTracks.length === 0
          });
        });

        // Si se encontró pista original, asegurar que sea la predeterminada
        if (audioTracks.length > 0) {
          const origIdx = audioTracks.findIndex(t => t.label.toLowerCase().includes("original"));
          if (origIdx > 0) {
            audioTracks.forEach(t => { t.isDefault = false; });
            audioTracks[origIdx].isDefault = true;
            const [orig] = audioTracks.splice(origIdx, 1);
            audioTracks.unshift(orig);
            audioTracks.forEach((t, i) => { t.id = `audio_${i}`; });
          }
        }

        // Detectar stream combinado de video + audio integrado (itag 18 / 22) para vista previa instantánea
        const combinedStreams = (d.formatStreams || []).filter(f => f.url && (f.type?.includes("mp4") || f.container === "mp4"));
        combinedStreams.sort((a, b) => {
          const qA = parseInt(a.qualityLabel || a.resolution || "0", 10) || 0;
          const qB = parseInt(b.qualityLabel || b.resolution || "0", 10) || 0;
          return qB - qA;
        });
        const combinedMp4Url = combinedStreams[0]?.url ? wrapStreamUrl(toInvidiousProxyUrl(inst, combinedStreams[0].url)) : null;

        // Mapear streams de video por resolución exacta (2160p, 1440p, 1080p, 720p, 480p, 360p, 240p, 144p)
        // Priorizando H.264 (avc1) para compatibilidad nativa universal con reproductores de video HTML5 en navegadores
        const videoStreamsByQuality = {};
        const qualityRank = {};

        videoFormats.forEach(vf => {
          if (!vf.url) return;
          const qText = (vf.qualityLabel || vf.resolution || vf.quality || "").toLowerCase();
          const match = qText.match(/(\d{3,4})p?/);
          let matchedKey = match ? `${match[1]}p` : null;
          if (!matchedKey) {
            if (qText.includes("4k") || qText.includes("2160")) matchedKey = "2160p";
            else if (qText.includes("2k") || qText.includes("1440")) matchedKey = "1440p";
            else if (qText.includes("1080")) matchedKey = "1080p";
            else if (qText.includes("720")) matchedKey = "720p";
            else if (qText.includes("480")) matchedKey = "480p";
            else if (qText.includes("360")) matchedKey = "360p";
            else if (qText.includes("240")) matchedKey = "240p";
            else if (qText.includes("144")) matchedKey = "144p";
          }

          if (matchedKey) {
            const isH264 = vf.encoding === "h264" || (vf.type && vf.type.includes("avc1"));
            const isMp4 = vf.type?.includes("mp4") || vf.container === "mp4";
            const currentScore = isH264 ? 3 : (isMp4 ? 2 : 1);
            const prevScore = qualityRank[matchedKey] || 0;

            if (currentScore >= prevScore) {
              qualityRank[matchedKey] = currentScore;
              videoStreamsByQuality[matchedKey] = wrapStreamUrl(toInvidiousProxyUrl(inst, vf.url));
            }
          }
        });

        const sortedQualityKeys = Object.keys(videoStreamsByQuality).sort((a, b) => (parseInt(b, 10) || 0) - (parseInt(a, 10) || 0));
        const highestNativeKey = sortedQualityKeys.length > 0 ? sortedQualityKeys[0] : null;
        const bestVideoUrl = wrapStreamUrl((highestNativeKey ? videoStreamsByQuality[highestNativeKey] : null) || videoStreamsByQuality["1080p"] || videoStreamsByQuality["720p"] || toInvidiousProxyUrl(inst, videoFormats[0]?.url) || null);
        const bestAudioUrl = wrapStreamUrl(audioTracks.find(t => t.isDefault)?.url || audioTracks[0]?.url || null);

        return {
          title: d.title || null,
          author: d.author || null,
          thumbnail: d.videoThumbnails?.[0]?.url || (videoId ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg` : null),
          durationSeconds: Number(d.lengthSeconds) || 0,
          mp4: bestVideoUrl,
          mp3: bestAudioUrl,
          combinedMp4Url,
          videoStreamsByQuality,
          audioTracks,
          separateAudio: Boolean(bestVideoUrl && bestAudioUrl && bestVideoUrl !== bestAudioUrl)
        };
      } catch (e) {
        // Continuar con siguiente instancia
      }
    }
    throw new Error("Invidious no pudo obtener streams válidos");
  };

  const fetchBtch = async () => {
    const directRes = await withTimeout(btch.youtube(normalizedUrl), 5000);
    if (directRes && (directRes.mp4 || directRes.mp3)) {
      return {
        ...directRes,
        source: "btch",
        combinedMp4Url: directRes.mp4 || null
      };
    }
    throw new Error("btch.youtube no retornó streams");
  };

  const fetchMirror1 = async () => {
    const res = await axios.get(`https://backend1.tioo.eu.org/youtube?url=${encodeURIComponent(normalizedUrl)}`, {
      timeout: 4500,
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
      timeout: 4500,
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
    const r = await withTimeout(rahad.alldl(normalizedUrl), 5000);
    if (r && r.data && r.data.download) {
      const dl = r.data.download;
      let audioUrl = wrapStreamUrl(dl.audio || dl.video);
      let videoUrl = wrapStreamUrl(dl.video || dl.audio);
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

  try {
    const settled = await Promise.allSettled([fetchInvidious(), fetchRahad(), fetchMirror1(), fetchMirror2(), fetchBtch()]);
    const valid = settled.filter(r => r.status === "fulfilled" && r.value).map(r => r.value);

    if (valid.length === 0) {
      throw new Error("Ningún proveedor de streams respondió con datos válidos");
    }

    // Priorizar datos con Invidious si tuvo éxito por contener mapa completo de pistas y resoluciones
    const invidiousRes = valid.find(v => v.videoStreamsByQuality || (v.audioTracks && v.audioTracks.length > 0));
    const first = invidiousRes || valid[0];

    const title = valid.find(v => v.title)?.title || first.title || null;
    const author = valid.find(v => v.author)?.author || first.author || null;
    const thumbnail = valid.find(v => v.thumbnail)?.thumbnail || first.thumbnail || null;
    const durationSeconds = valid.find(v => v.durationSeconds > 0)?.durationSeconds || first.durationSeconds || 0;

    // Recopilar y fusionar todas las pistas de audio descubiertas por todos los proveedores
    const audioTracks = [];
    const seenAudioLabels = new Set();
    const seenAudioUrls = new Set();

    valid.forEach(v => {
      if (Array.isArray(v.audioTracks)) {
        v.audioTracks.forEach(t => {
          const wrappedUrl = wrapStreamUrl(t.url);
          if (!wrappedUrl || seenAudioUrls.has(wrappedUrl) || seenAudioLabels.has(t.label)) return;
          seenAudioUrls.add(wrappedUrl);
          seenAudioLabels.add(t.label);
          audioTracks.push({
            id: `audio_${audioTracks.length}`,
            label: t.label,
            url: wrappedUrl,
            isDefault: Boolean(t.isDefault)
          });
        });
      }
      const extraAudio = wrapStreamUrl(v.mp3 || v.audio);
      if (extraAudio && !seenAudioUrls.has(extraAudio)) {
        seenAudioUrls.add(extraAudio);
        const label = parseAudioTrackLabel(extraAudio);
        if (!seenAudioLabels.has(label)) {
          seenAudioLabels.add(label);
          audioTracks.push({
            id: `audio_${audioTracks.length}`,
            label,
            url: extraAudio,
            isDefault: false
          });
        }
      }
    });

    if (audioTracks.length > 0) {
      const origIdx = audioTracks.findIndex(t => t.label.toLowerCase().includes("original"));
      if (origIdx > -1) {
        audioTracks.forEach(t => { t.isDefault = false; });
        audioTracks[origIdx].isDefault = true;
        const [orig] = audioTracks.splice(origIdx, 1);
        audioTracks.unshift(orig);
      } else {
        audioTracks[0].isDefault = true;
      }
      audioTracks.forEach((t, i) => { t.id = `audio_${i}`; });
    }

    // Fusionar streams de video por calidad
    const videoStreamsByQuality = {};
    valid.forEach(v => {
      if (v.videoStreamsByQuality) {
        for (const [k, val] of Object.entries(v.videoStreamsByQuality)) {
          if (typeof val === "object" && val !== null && val.videoUrl) {
            videoStreamsByQuality[k] = {
              videoUrl: wrapStreamUrl(val.videoUrl),
              audioUrl: wrapStreamUrl(val.audioUrl)
            };
          } else {
            videoStreamsByQuality[k] = wrapStreamUrl(val);
          }
        }
      }
    });

    const defaultInst = "https://yt.chocolatemoo53.com";
    const sanitizeGv = (u) => (u ? toInvidiousProxyUrl(defaultInst, wrapStreamUrl(u)) : null);

    const primaryVideo = sanitizeGv(invidiousRes?.mp4 || videoStreamsByQuality["1080p"] || videoStreamsByQuality["720p"] || first.mp4 || valid.find(v => v.mp4)?.mp4 || null);
    const primaryAudio = sanitizeGv(invidiousRes?.mp3 || audioTracks.find(t => t.isDefault)?.url || audioTracks[0]?.url || first.mp3 || null);
    const combinedMp4Url = sanitizeGv(invidiousRes?.combinedMp4Url || valid.find(v => v.combinedMp4Url)?.combinedMp4Url || valid.find(v => v.mp4 && !v.separateAudio)?.mp4 || null);

    const safeVideoStreamsByQuality = {};
    for (const [k, val] of Object.entries(videoStreamsByQuality)) {
      if (typeof val === "object" && val !== null && val.videoUrl) {
        safeVideoStreamsByQuality[k] = {
          videoUrl: sanitizeGv(val.videoUrl),
          audioUrl: sanitizeGv(val.audioUrl)
        };
      } else {
        safeVideoStreamsByQuality[k] = sanitizeGv(val);
      }
    }

    const safeAudioTracks = audioTracks.map(t => ({
      ...t,
      url: sanitizeGv(t.url)
    }));

    return {
      title,
      author,
      thumbnail,
      durationSeconds,
      mp4: primaryVideo,
      mp3: primaryAudio,
      combinedMp4Url,
      videoStreamsByQuality: safeVideoStreamsByQuality,
      audioTracks: safeAudioTracks,
      separateAudio: Boolean(primaryVideo && primaryAudio && primaryVideo !== primaryAudio)
    };
  } catch (errAll) {
    logger.warn(`Todos los proveedores de streams para YouTube fallaron para ${normalizedUrl}: ${errAll.message}`);
    return null;
  }
}

// Directorio de almacenamiento en caché para medios convertidos físicamente
const MEDIA_CACHE_DIR = path.resolve(process.cwd(), "data/media_cache");
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
    regex: /(?:facebook\.com\/(?:watch|.*\/videos|reel|reels|share|story|\w+)|fb\.watch\/)/i,
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
    // Si la entrada en caché contiene pistas de audio válidas (o no es YouTube), reutilizar
    const hasAudioTracks = Array.isArray(cached.info?.audioTracks) && cached.info.audioTracks.length > 0;
    const isYouTube = cleanUrl.includes("youtube.com") || cleanUrl.includes("youtu.be");
    if (!isYouTube || hasAudioTracks) {
      const cloned = JSON.parse(JSON.stringify(cached.info));
      cloned.directMediaUrl = requestedFormat === "mp4" ? (cloned.mp4Url || cloned.mp3Url) : (cloned.mp3Url || cloned.mp4Url);
      return cloned;
    }
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
    defaultAuthor = "Facebook";
    const reelMatch = cleanUrl.match(/facebook\.com\/(?:reel|reels)\/(\d+)/i);
    defaultTitle = reelMatch ? `Facebook Reel (${reelMatch[1]})` : "Facebook Video";
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
    directMediaUrl: null,
    separateAudio: false,
    audioTracks: [],
    selectedAudioTrack: null
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

    // 1.1 Consultar streams con los mejores proveedores en paralelo de alta velocidad
    try {
      const ytRes = await fetchYouTubeStreams(normalized);
      if (ytRes) {
        if (ytRes.title && (!info.title || info.title.startsWith("YouTube Video"))) info.title = ytRes.title;
        if (ytRes.author && (info.author === "Desconocido" || info.author === "YouTube Creator")) info.author = ytRes.author;
        if (ytRes.thumbnail && (!info.thumbnail || info.thumbnail.includes("logo.png"))) info.thumbnail = ytRes.thumbnail;
        info.mp4Url = wrapStreamUrl(ytRes.mp4) || null;
        info.mp3Url = wrapStreamUrl(ytRes.mp3) || info.mp4Url || null;
        info.combinedMp4Url = wrapStreamUrl(ytRes.combinedMp4Url) || null;
        info.videoStreamsByQuality = ytRes.videoStreamsByQuality || {};
        info.audioTracks = (ytRes.audioTracks || []).map(t => ({ ...t, url: wrapStreamUrl(t.url) }));
        info.selectedAudioTrack = ytRes.audioTracks?.find(t => t.isDefault)?.id || ytRes.audioTracks?.[0]?.id || null;
        info.separateAudio = Boolean(ytRes.separateAudio || (ytRes.mp4 && ytRes.mp3 && ytRes.mp4 !== ytRes.mp3));
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

      // Solo si falta título y disponemos de videoId, consultar oembed en segundo plano rápido
      if ((!info.title || info.title.startsWith("YouTube Video")) && videoId) {
        try {
          const oembedRes = await axios.get(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`, { timeout: 2000 }).then(r => r.data).catch(() => null);
          if (oembedRes) {
            if (oembedRes.title) info.title = oembedRes.title;
            if (oembedRes.author_name) info.author = oembedRes.author_name;
            if (oembedRes.thumbnail_url) info.thumbnail = oembedRes.thumbnail_url;
          }
        } catch {}
      }
    } catch (err) {
      logger.warn(`Error al obtener streams de YouTube para ${normalized}: ${err.message}`);
    }
  }

  // Estrategia 2: TikTok (Vía TikWM API y rahad.alldl)
  else if (platform.id === "tiktok") {
    const resolvedUrl = await resolveRedirectUrl(cleanUrl);

    // 2.1 Consulta a TikWM API (POST & GET con reintentos multicanal)
    try {
      let tikData = null;
      const tikHeaders = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "application/json",
        "Referer": "https://www.tikwm.com/"
      };

      // Intento 1: POST JSON estándar
      try {
        const tikRes = await axios.post("https://www.tikwm.com/api/", { url: resolvedUrl }, {
          timeout: 8000,
          headers: { ...tikHeaders, "Content-Type": "application/json" }
        });
        if (tikRes.data && tikRes.data.code === 0 && tikRes.data.data) {
          tikData = tikRes.data.data;
        }
      } catch {}

      // Intento 2: GET directo con parámetro url (alta resiliencia en datacenters de Render)
      if (!tikData) {
        try {
          const tikGet = await axios.get(`https://www.tikwm.com/api/?url=${encodeURIComponent(resolvedUrl)}`, {
            timeout: 8000,
            headers: tikHeaders
          });
          if (tikGet.data && tikGet.data.code === 0 && tikGet.data.data) {
            tikData = tikGet.data.data;
          }
        } catch {}
      }

      // Intento 3: Mirror sin subdominio www
      if (!tikData) {
        try {
          const tikAlt = await axios.get(`https://tikwm.com/api/?url=${encodeURIComponent(resolvedUrl)}`, {
            timeout: 8000,
            headers: tikHeaders
          });
          if (tikAlt.data && tikAlt.data.code === 0 && tikAlt.data.data) {
            tikData = tikAlt.data.data;
          }
        } catch {}
      }

      if (tikData) {
        if (tikData.title) info.title = tikData.title.slice(0, 120);
        if (tikData.author?.nickname) info.author = tikData.author.nickname;
        else if (tikData.author?.unique_id) info.author = `@${tikData.author.unique_id}`;
        let cover = tikData.cover || tikData.origin_cover || tikData.dynamic_cover;
        if (cover && typeof cover === "string") {
          if (cover.startsWith("//")) cover = "https:" + cover;
          else if (cover.startsWith("/")) cover = "https://www.tikwm.com" + cover;
          info.thumbnail = cover;
        }
        if (typeof tikData.duration === "number" && tikData.duration > 0) {
          info.durationSeconds = tikData.duration;
          info.duration = formatDurationSeconds(tikData.duration);
        }
        info.mp4Url = tikData.play || tikData.hdplay || null;
        info.mp3Url = tikData.music || tikData.play || null;
        info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);
      }
    } catch (tikErr) {
      logger.warn(`TikWM error para TikTok: ${tikErr.message}`);
    }

    // 2.2 Fallback con rahad-all-downloader-v2
    if (!info.directMediaUrl || !info.thumbnail || info.thumbnail.includes("logo.png")) {
      try {
        const { alldl } = require("rahad-all-downloader-v2");
        const dlData = await withTimeout(alldl(resolvedUrl), 15000);
        if (dlData) {
          const d = dlData.data || dlData;
          if (d.title && (!info.title || info.title === defaultTitle)) info.title = d.title.slice(0, 120);
          const dlAuthor = d.owner?.nickname || d.owner?.username || d.author?.nickname || d.author?.name || dlData.metadata?.author?.name || d.author;
          if (dlAuthor && (info.author === defaultAuthor || info.author === "Desconocido")) {
            info.author = String(dlAuthor).startsWith("@") ? dlAuthor : `@${dlAuthor}`;
          }
          const rawDlThumb = d.thumbnail || dlData.metadata?.thumbnail || d.download?.thumbnail || d.cover || d.origin_cover || d.owner?.avatar || d.author?.avatar;
          if (rawDlThumb && typeof rawDlThumb === "string" && (!info.thumbnail || info.thumbnail.includes("logo.png"))) {
            let tUrl = rawDlThumb;
            if (tUrl.startsWith("//")) tUrl = "https:" + tUrl;
            else if (tUrl.startsWith("/")) tUrl = "https://www.tikwm.com" + tUrl;
            info.thumbnail = tUrl;
          }
          if (!info.mp4Url) info.mp4Url = d.download?.no_watermark || d.download?.url || d.videoUrl || d.video || null;
          if (!info.mp3Url) info.mp3Url = d.download?.music || d.music || info.mp4Url;
          if (!info.directMediaUrl) info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);
        }
      } catch (alldlErr) {
        logger.warn(`rahad.alldl fallback para TikTok: ${alldlErr.message}`);
      }
    }

    // 2.3 Fallback con btch.ttdl
    if (!info.directMediaUrl || !info.thumbnail || info.thumbnail.includes("logo.png")) {
      try {
        const ttRes = await withTimeout(btch.ttdl(resolvedUrl), 10000);
        if (ttRes && ttRes.status) {
          if (ttRes.title && (!info.title || info.title === defaultTitle)) info.title = ttRes.title;
          const rawTtThumb = ttRes.thumbnail || ttRes.cover;
          if (rawTtThumb && typeof rawTtThumb === "string" && (!info.thumbnail || info.thumbnail.includes("logo.png"))) {
            let tUrl = rawTtThumb;
            if (tUrl.startsWith("//")) tUrl = "https:" + tUrl;
            else if (tUrl.startsWith("/")) tUrl = "https://www.tikwm.com" + tUrl;
            info.thumbnail = tUrl;
          }
          const v = Array.isArray(ttRes.video) ? ttRes.video[0] : ttRes.video;
          const a = Array.isArray(ttRes.audio) ? ttRes.audio[0] : ttRes.audio;
          if (!info.mp4Url) info.mp4Url = v || null;
          if (!info.mp3Url) info.mp3Url = a || v || null;
          if (!info.directMediaUrl) info.directMediaUrl = requestedFormat === "mp4" ? (info.mp4Url || info.mp3Url) : (info.mp3Url || info.mp4Url);
        }
      } catch (ttErr) {
        logger.warn(`btch.ttdl fallback fallo: ${ttErr.message}`);
      }
    }
  }

  // Estrategia 3: Instagram Reels y Posts
  else if (platform.id === "instagram") {
    // 1. Proveedor de alta disponibilidad: cakkatrok-instagram-downloader (SnapVideo API)
    try {
      const snapVideo = require("cakkatrok-instagram-downloader");
      const igRes = await withTimeout(snapVideo(cleanUrl), 15000);
      if (igRes && igRes.status === "ok" && Array.isArray(igRes.media) && igRes.media.length > 0) {
        const videoMedia = igRes.media.find(m => m.type === "video") || igRes.media[0];
        if (videoMedia && videoMedia.url) {
          info.mp4Url = videoMedia.url;
          info.mp3Url = videoMedia.url;
          info.directMediaUrl = videoMedia.url;
        }
      }
    } catch (cakkaErr) {
      logger.warn(`cakkatrok falló para Instagram: ${cakkaErr.message}`);
    }

    // 2. Proveedor secundario: SnapInsta API direct
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
    info.videoStreamsByQuality = {};

    // 1. Proveedor preferente de alta fidelidad: btch.twitter (streams nativos de video.twimg.com)
    try {
      const twRes = await withTimeout(btch.twitter(cleanUrl), 10000);
      if (twRes && twRes.status && twRes.url) {
        if (Array.isArray(twRes.url)) {
          twRes.url.forEach(item => {
            const u = item.hd || item.sd || (typeof item === "string" ? item : item.url);
            if (u) {
              const m = u.match(/\/(\d{2,4})x(\d{2,4})\//);
              if (m) {
                const res = Math.min(parseInt(m[1], 10), parseInt(m[2], 10)) + "p";
                info.videoStreamsByQuality[res] = u;
              } else if (item.hd) {
                info.videoStreamsByQuality["720p"] = u;
              } else if (item.sd) {
                info.videoStreamsByQuality["360p"] = u;
              }
            }
          });
        } else if (typeof twRes.url === "object" && twRes.url !== null) {
          if (twRes.url.hd) info.videoStreamsByQuality["720p"] = twRes.url.hd;
          if (twRes.url.sd) info.videoStreamsByQuality["360p"] = twRes.url.sd;
        }

        const sortedTw = Object.keys(info.videoStreamsByQuality).sort((a, b) => (parseInt(b, 10) || 0) - (parseInt(a, 10) || 0));
        const vUrl = (sortedTw.length > 0 ? info.videoStreamsByQuality[sortedTw[0]] : null) ||
                     (Array.isArray(twRes.url) ? twRes.url[0]?.hd || twRes.url[0]?.sd || twRes.url[0] : (twRes.url?.hd || twRes.url?.sd || twRes.url));

        if (vUrl) {
          info.mp4Url = vUrl;
          info.mp3Url = vUrl;
          info.directMediaUrl = vUrl;
        }
        if (twRes.title) info.title = twRes.title;
        const twThumb = twRes.thumb || twRes.thumbnail || twRes.cover || twRes.image;
        if (twThumb) info.thumbnail = twThumb;
      }
    } catch (twErr) {
      logger.warn(`btch.twitter fallo para Twitter/X: ${twErr.message}`);
    }

    // 2. Proveedor secundario: rahad-all-downloader-v2
    if (!info.directMediaUrl || Object.keys(info.videoStreamsByQuality).length === 0) {
      try {
        const { alldl } = require("rahad-all-downloader-v2");
        const dl = await withTimeout(alldl(cleanUrl), 15000);
        if (dl && dl.data) {
          if (dl.data.title && (!info.title || info.title.startsWith("Twitter"))) info.title = dl.data.title;
          if (dl.data.thumbnail && (!info.thumbnail || info.thumbnail.includes("logo.png"))) info.thumbnail = dl.data.thumbnail;
          else if (dl.data.download?.thumbnail) info.thumbnail = dl.data.download.thumbnail;
          if (dl.data.author) info.author = dl.data.author;

          const dObj = dl.data.download || {};
          const hdUrl = dObj.HD || dObj.hd || dl.data.HD || dl.data.hd;
          const sdUrl = dObj.SD || dObj.sd || dl.data.SD || dl.data.sd || dObj.url || dl.data.videoUrl;
          if (hdUrl && !info.videoStreamsByQuality["720p"]) info.videoStreamsByQuality["720p"] = hdUrl;
          if (sdUrl && !info.videoStreamsByQuality["360p"]) info.videoStreamsByQuality["360p"] = sdUrl;

          const vUrl = hdUrl || sdUrl || dObj.best || dObj.url || dl.data.videoUrl;
          if (vUrl && !info.directMediaUrl) {
            info.mp4Url = vUrl;
            info.mp3Url = vUrl;
            info.directMediaUrl = vUrl;
          }
        }
      } catch (twDlErr) {
        logger.warn(`rahad.alldl fallo para Twitter/X: ${twDlErr.message}`);
      }
    }
  }

  // Estrategia 5: Facebook Video (Videos regulares, Reels y enlaces share)
  else if (platform.id === "facebook") {
    info.videoStreamsByQuality = {};

    // 1. Extraer metadatos nativos (título real, autor y portada original)
    try {
      const fbMeta = await withTimeout(fetchFacebookMetadata(cleanUrl), 8000);
      if (fbMeta.title) info.title = fbMeta.title;
      if (fbMeta.author) info.author = fbMeta.author;
      if (fbMeta.thumbnail) info.thumbnail = fbMeta.thumbnail;
    } catch (metaErr) {
      logger.warn(`Metadatos FB fallback: ${metaErr.message}`);
    }

    // 2. Proveedor preferente de alta resolución: SnapSave (Extrae 1080p, 720p, etc.)
    try {
      const formData = new URLSearchParams();
      formData.append("url", cleanUrl);

      const snapRes = await withTimeout(axios.post("https://snapsave.app/action.php?lang=en", formData.toString(), {
        headers: {
          "accept": "*/*",
          "content-type": "application/x-www-form-urlencoded",
          "origin": "https://snapsave.app",
          "referer": "https://snapsave.app/",
          "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
        },
        timeout: 10000
      }), 12000);

      const decodedHtml = decryptSnapSave(snapRes.data);
      const $ = cheerio.load(decodedHtml);

      const snapTitle = $("span.video-des").text().trim();
      if (snapTitle && snapTitle !== "..." && (!info.title || info.title === "Facebook Video" || info.title.startsWith("Facebook Reel"))) {
        info.title = snapTitle;
      }

      const snapThumb = $("article.media > figure").find("img").attr("src");
      if (snapThumb && (!info.thumbnail || info.thumbnail.includes("logo.png"))) {
        info.thumbnail = snapThumb;
      }

      $("tbody > tr").each((_, el) => {
        const $td = $(el).find("td");
        const resolution = $td.eq(0).text().trim();
        let streamUrl = $td.eq(2).find("a").attr("href") || $td.eq(2).find("button").attr("onclick");
        const shouldRender = /get_progressApi/gi.test(streamUrl || "");
        if (shouldRender) {
          streamUrl = "https://snapsave.app" + /get_progressApi\('(.*?)'\)/.exec(streamUrl || "")?.[1];
        }

        if (!streamUrl) return;

        const qMatch = resolution.match(/(\d{3,4})p/i);
        const qKey = qMatch ? `${qMatch[1]}p` : (resolution.toLowerCase().includes("hd") ? "720p" : "360p");

        if (shouldRender && streamUrl.includes("token=")) {
          try {
            const token = streamUrl.split("token=")[1].split("&")[0];
            const parts = token.split(".");
            const payload = JSON.parse(Buffer.from(parts[1], "base64").toString("utf8"));
            if (payload.video_url) {
              info.videoStreamsByQuality[qKey] = {
                videoUrl: payload.video_url,
                audioUrl: payload.audio_url || null,
                renderUrl: streamUrl
              };
              if (payload.duration_s && info.durationSeconds === 0) {
                info.durationSeconds = Math.round(payload.duration_s);
                info.duration = formatDurationSeconds(info.durationSeconds);
              }
            }
          } catch {}
        } else {
          info.videoStreamsByQuality[qKey] = streamUrl;
        }
      });
    } catch (snapErr) {
      logger.warn(`SnapSave falló para Facebook: ${snapErr.message}`);
    }

    // 3. Proveedor complementario: rahad-all-downloader-v2
    try {
      const { alldl } = require("rahad-all-downloader-v2");
      const dl = await withTimeout(alldl(cleanUrl), 12000);
      if (dl && dl.data) {
        if (dl.data.title && dl.data.title !== "Facebook Video" && (!info.title || info.title === "Facebook Video" || info.title.startsWith("Facebook Reel"))) {
          info.title = dl.data.title;
        }
        if (dl.data.thumbnail && (!info.thumbnail || info.thumbnail.includes("logo.png"))) {
          info.thumbnail = dl.data.thumbnail;
        }
        const dObj = dl.data.download || {};
        const hdUrl = dObj.hd || dObj.HD || dl.data.hd || dl.data.HD;
        const sdUrl = dObj.sd || dObj.SD || dObj.normal || dObj.Normal || dl.data.sd || dl.data.SD || dl.data.videoUrl;
        if (hdUrl && !info.videoStreamsByQuality["720p"]) info.videoStreamsByQuality["720p"] = hdUrl;
        if (sdUrl && !info.videoStreamsByQuality["360p"]) info.videoStreamsByQuality["360p"] = sdUrl;
      }
    } catch (fbAllErr) {
      logger.warn(`rahad.alldl fallo para Facebook: ${fbAllErr.message}`);
    }

    // 4. Proveedor de contingencia: btch.fbdown
    if (Object.keys(info.videoStreamsByQuality).length === 0) {
      try {
        const fbRes = await withTimeout(btch.fbdown(cleanUrl), 10000);
        if (fbRes && fbRes.status) {
          const hdUrl = fbRes.HD || fbRes.hd;
          const sdUrl = fbRes.Normal_video || fbRes.SD || fbRes.sd || fbRes.normal || fbRes.video;
          if (hdUrl && !info.videoStreamsByQuality["720p"]) info.videoStreamsByQuality["720p"] = hdUrl;
          if (sdUrl && !info.videoStreamsByQuality["360p"]) info.videoStreamsByQuality["360p"] = sdUrl;
          if (fbRes.title && (!info.title || info.title === "Facebook Video")) info.title = fbRes.title;
          if (fbRes.thumbnail || fbRes.thumb && (!info.thumbnail || info.thumbnail.includes("logo.png"))) {
            info.thumbnail = fbRes.thumbnail || fbRes.thumb;
          }
        }
      } catch (fbErr) {
        logger.warn(`btch.fbdown fallo para Facebook: ${fbErr.message}`);
      }
    }

    // Configurar flujos preferentes
    const sortedFbKeys = Object.keys(info.videoStreamsByQuality).sort((a, b) => (parseInt(b, 10) || 0) - (parseInt(a, 10) || 0));
    if (sortedFbKeys.length > 0) {
      const best = info.videoStreamsByQuality[sortedFbKeys[0]];
      if (typeof best === "object" && best !== null && best.videoUrl) {
        info.mp4Url = best.videoUrl;
        info.mp3Url = best.audioUrl || best.videoUrl;
        info.directMediaUrl = best.videoUrl;
        info.separateAudio = Boolean(best.audioUrl && best.audioUrl !== best.videoUrl);
      } else {
        info.mp4Url = best;
        info.mp3Url = best;
        info.directMediaUrl = best;
      }
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

  // Extraer el stream de video preferente para respaldo o extracción directa de fotogramas
  const candidateStream = info.mp4Url || info.directMediaUrl || (info.videoStreamsByQuality && Object.values(info.videoStreamsByQuality)[0]);
  const streamUrl = (typeof candidateStream === "object" && candidateStream?.videoUrl) ? candidateStream.videoUrl : candidateStream;
  const validStreamUrl = (streamUrl && typeof streamUrl === "string" && streamUrl.startsWith("http")) ? streamUrl : null;

  // Si la miniatura es una URL remota externa (TikTok, Instagram, Twitter, etc.),
  // enrutar a través de nuestro proxy para garantizar que nunca sea bloqueada por CORS o Referer.
  // Si no se obtuvo miniatura remota o es el logo por defecto, intentar usar el stream de video para extraer fotograma
  // o generar miniatura estilizada por proxy SVG.
  if (info.thumbnail && typeof info.thumbnail === "string") {
    let t = info.thumbnail.trim();
    if (t.startsWith("//")) t = "https:" + t;
    if (t.startsWith("http")) {
      if (!t.includes("i.ytimg.com") && !t.includes("/api/media/thumbnail-proxy") && !t.includes("/api/media/thumbnail?")) {
        const vParam = validStreamUrl ? `&v=${encodeURIComponent(validStreamUrl)}` : "";
        info.thumbnail = `/api/media/thumbnail-proxy?url=${encodeURIComponent(t)}${vParam}&title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
      }
    } else if (t.startsWith("/") && !t.includes("logo.png") && !t.includes("/api/media/")) {
      t = `https://www.tikwm.com${t}`;
      const vParam = validStreamUrl ? `&v=${encodeURIComponent(validStreamUrl)}` : "";
      info.thumbnail = `/api/media/thumbnail-proxy?url=${encodeURIComponent(t)}${vParam}&title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
    } else if (!info.thumbnail || info.thumbnail === "/img/logo.png") {
      if (validStreamUrl) {
        info.thumbnail = `/api/media/thumbnail-proxy?url=${encodeURIComponent(validStreamUrl)}&title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
      } else {
        info.thumbnail = `/api/media/thumbnail-proxy?title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
      }
    }
  } else {
    if (validStreamUrl) {
      info.thumbnail = `/api/media/thumbnail-proxy?url=${encodeURIComponent(validStreamUrl)}&title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
    } else {
      info.thumbnail = `/api/media/thumbnail-proxy?title=${encodeURIComponent(info.title)}&platform=${encodeURIComponent(info.platform)}&author=${encodeURIComponent(info.author)}`;
    }
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
 * Descarga acelerada mediante chunks HTTP Range paralelos
 * Multiplica la velocidad hasta 4-6x en proxies y servidores con límite por conexión
 */
async function downloadStreamFast(url, tempFilePath) {
  const targetUrl = wrapStreamUrl(url);
  if (!targetUrl || typeof targetUrl !== "string") return false;

  let referer = "https://www.google.com/";
  if (/tiktok|byteoversea|ibytedtos|muscdn|musical\.ly/i.test(targetUrl)) referer = "https://www.tiktok.com/";
  else if (/tikwm\.com/i.test(targetUrl)) referer = "https://www.tikwm.com/";
  else if (/twitter|twimg|x\.com/i.test(targetUrl)) referer = "https://twitter.com/";
  else if (/instagram|cdninstagram|fbcdn/i.test(targetUrl)) referer = "https://www.instagram.com/";
  else if (/googlevideo|youtube|youtu\.be/i.test(targetUrl)) referer = "https://www.youtube.com/";
  else if (/chocolatemoo53|invidious|nerdvpn/i.test(targetUrl)) referer = "https://yt.chocolatemoo53.com/";

  const commonHeaders = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    "Referer": referer,
    "Accept": "*/*"
  };

  try {
    const headRes = await axios.get(targetUrl, {
      headers: {
        ...commonHeaders,
        "Range": "bytes=0-0"
      },
      timeout: 5000
    });

    const contentRange = headRes.headers["content-range"];
    let totalSize = 0;
    if (contentRange) {
      const match = contentRange.match(/\/(\d+)/);
      if (match) totalSize = parseInt(match[1], 10);
    }

    if (totalSize && totalSize > 50000) {
      const concurrency = totalSize > 8 * 1024 * 1024 ? 6 : 4;
      const chunkSize = Math.ceil(totalSize / concurrency);
      const promises = [];

      for (let i = 0; i < concurrency; i++) {
        const start = i * chunkSize;
        const end = Math.min((i + 1) * chunkSize - 1, totalSize - 1);
        if (start > end) break;

        promises.push(
          axios.get(targetUrl, {
            headers: {
              ...commonHeaders,
              "Range": `bytes=${start}-${end}`
            },
            responseType: "arraybuffer",
            timeout: 25000
          }).then(r => ({ index: i, buffer: Buffer.from(r.data) }))
        );
      }

      const chunks = await Promise.all(promises);
      chunks.sort((a, b) => a.index - b.index);
      const fullBuffer = Buffer.concat(chunks.map(c => c.buffer));
      fs.writeFileSync(tempFilePath, fullBuffer);
      return true;
    }
  } catch (err) {
    logger.warn(`Descarga paralela acelerada omitida (${err.message}), intentando descarga por flujo directo...`);
  }

  // Fallback: Descarga secuencial completa mediante stream directo
  try {
    const streamRes = await axios.get(targetUrl, {
      responseType: "stream",
      headers: commonHeaders,
      timeout: 35000
    });
    await new Promise((resolve, reject) => {
      const writer = fs.createWriteStream(tempFilePath);
      streamRes.data.pipe(writer);
      writer.on("finish", resolve);
      writer.on("error", reject);
      streamRes.data.on("error", reject);
    });
    return fs.existsSync(tempFilePath) && fs.statSync(tempFilePath).size > 1000;
  } catch (streamErr) {
    logger.warn(`Descarga directa por flujo falló: ${streamErr.message}`);
  }
  return false;
}

/**
 * Transcodifica un stream remoto a MP3 puro usando FFmpeg
 */
async function transcodeToMp3(streamUrl, outputPath, quality = "320k") {
  const safeStreamUrl = wrapStreamUrl(streamUrl);
  const bitrateMap = {
    "320k": "320k",
    "256k": "256k",
    "192k": "192k",
    "128k": "128k",
    "96k": "96k",
    "64k": "64k"
  };
  const bitrate = bitrateMap[quality] || (quality.endsWith("k") ? quality : `${quality}k`);

  // Acelerador: Descargar localmente para eludir fallos de red en el binario estático de FFmpeg
  let localInput = safeStreamUrl;
  let tempDownloadedFile = null;

  if (safeStreamUrl && safeStreamUrl.startsWith("http")) {
    const tempCandidate = path.join(MEDIA_CACHE_DIR, `temp_dl_${Date.now()}_${Math.random().toString(36).slice(2, 7)}.tmp`);
    const isDownloaded = await downloadStreamFast(safeStreamUrl, tempCandidate);
    if (isDownloaded && fs.existsSync(tempCandidate) && fs.statSync(tempCandidate).size > 1000) {
      localInput = tempCandidate;
      tempDownloadedFile = tempCandidate;
    }
  }

  try {
    return await new Promise((resolve, reject) => {
      const ffArgs = ["-y"];
      if (localInput.startsWith("http")) {
        ffArgs.push(...getFfmpegInputArgs(localInput));
      }
      ffArgs.push(
        "-i", localInput,
        "-vn",
        "-c:a", "libmp3lame",
        "-b:a", bitrate,
        "-id3v2_version", "3",
        "-write_xing", "1",
        "-f", "mp3",
        outputPath
      );
      const ff = spawn(ffmpegPath, ffArgs);

      let stderr = "";
      ff.stderr.on("data", d => { stderr += d.toString(); });

      ff.on("close", (code, signal) => {
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

        if (tempDownloadedFile) {
          return reject(new Error(`FFmpeg MP3 transcode exited with code ${code}${signal ? ' (señal ' + signal + ')' : ''}: ${stderr.slice(-300)}`));
        }

        // Fallback vía axios stream piping
        logger.warn(`FFmpeg directo terminó con código ${code}, probando stream pipe...`);
        axios({
          method: "get",
          url: safeStreamUrl,
          responseType: "stream",
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
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
          ffPipe.on("close", (pipeCode, pipeSig) => {
            if (pipeCode === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
              const stats = fs.statSync(outputPath);
              return resolve({ sizeBytes: stats.size, duration: null, durationSeconds: 0 });
            }
            reject(new Error(`FFmpeg MP3 transcode exited with code ${pipeCode}${pipeSig ? ' (señal ' + pipeSig + ')' : ''}: ${pipeStderr.slice(-300)}`));
          });
          response.data.on("error", reject);
        }).catch(reject);
      });

      ff.on("error", err => {
        reject(err);
      });
    });
  } finally {
    if (tempDownloadedFile && fs.existsSync(tempDownloadedFile)) {
      try { fs.unlinkSync(tempDownloadedFile); } catch {}
    }
  }
}

/**
 * Transcodifica un stream remoto a WAV puro (Audio PCM 16-bit sin compresión)
 */
async function transcodeToWav(streamUrl, outputPath) {
  const safeStreamUrl = wrapStreamUrl(streamUrl);
  let localInput = safeStreamUrl;
  let tempDownloadedFile = null;

  if (safeStreamUrl && safeStreamUrl.startsWith("http")) {
    const tempCandidate = path.join(MEDIA_CACHE_DIR, `temp_wav_${Date.now()}_${Math.random().toString(36).slice(2, 7)}.tmp`);
    const isDownloaded = await downloadStreamFast(safeStreamUrl, tempCandidate);
    if (isDownloaded && fs.existsSync(tempCandidate) && fs.statSync(tempCandidate).size > 1000) {
      localInput = tempCandidate;
      tempDownloadedFile = tempCandidate;
    }
  }

  try {
    return await new Promise((resolve, reject) => {
      const inArgs = localInput.startsWith("http") ? getFfmpegInputArgs(localInput) : [];
      const ff = spawn(ffmpegPath, [
        "-y",
        ...inArgs,
        "-i", localInput,
        "-vn",
        "-c:a", "pcm_s16le",
        "-f", "wav",
        outputPath
      ]);

      let stderr = "";
      ff.stderr.on("data", d => { stderr += d.toString(); });

      ff.on("close", (code, signal) => {
        if (code === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
          const stats = fs.statSync(outputPath);
          return resolve({ sizeBytes: stats.size, duration: null, durationSeconds: 0 });
        }
        reject(new Error(`FFmpeg WAV falló con código ${code}${signal ? ' (señal ' + signal + ')' : ''}: ${stderr.slice(-250)}`));
      });

      ff.on("error", reject);
    });
  } finally {
    if (tempDownloadedFile && fs.existsSync(tempDownloadedFile)) {
      try { fs.unlinkSync(tempDownloadedFile); } catch {}
    }
  }
}

/**
 * Remuxea o transcodifica un stream remoto a MP4 estándar para reproducción web instantánea
 */
async function transcodeToMp4(streamUrl, outputPath, quality = "1080p", audioStreamUrl = null) {
  const safeStreamUrl = wrapStreamUrl(streamUrl);
  const safeAudioStreamUrl = wrapStreamUrl(audioStreamUrl);
  const hasSeparateAudio = Boolean(safeAudioStreamUrl && safeAudioStreamUrl !== safeStreamUrl);

  let localVideo = safeStreamUrl;
  let localAudio = safeAudioStreamUrl;
  let tempVideoFile = null;
  let tempAudioFile = null;

  // Descarga local previa de streams remotos para eludir fallos de GnuTLS/HTTPS en el binario estático de FFmpeg en Linux
  if (safeStreamUrl && safeStreamUrl.startsWith("http")) {
    const tempVid = path.join(MEDIA_CACHE_DIR, `temp_v_${Date.now()}_${Math.random().toString(36).slice(2, 7)}.tmp`);
    const isDownloaded = await downloadStreamFast(safeStreamUrl, tempVid);
    if (isDownloaded && fs.existsSync(tempVid) && fs.statSync(tempVid).size > 1000) {
      localVideo = tempVid;
      tempVideoFile = tempVid;
    }
  }

  if (hasSeparateAudio && safeAudioStreamUrl && safeAudioStreamUrl.startsWith("http")) {
    const tempAud = path.join(MEDIA_CACHE_DIR, `temp_a_${Date.now()}_${Math.random().toString(36).slice(2, 7)}.tmp`);
    const isDownloaded = await downloadStreamFast(safeAudioStreamUrl, tempAud);
    if (isDownloaded && fs.existsSync(tempAud) && fs.statSync(tempAud).size > 1000) {
      localAudio = tempAud;
      tempAudioFile = tempAud;
    }
  }

  try {
    const vArgs = localVideo.startsWith("http") ? getFfmpegInputArgs(localVideo) : [];
    const aArgs = (hasSeparateAudio && localAudio.startsWith("http")) ? getFfmpegInputArgs(localAudio) : [];

    const runFfmpegAttempt = (args) => new Promise((resAttempt, rejAttempt) => {
      const ff = spawn(ffmpegPath, args);
      let stderr = "";
      ff.stderr.on("data", d => { stderr += d.toString(); });
      ff.on("close", (code, signal) => {
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
          return resAttempt({ sizeBytes: stats.size, duration, durationSeconds });
        }
        rejAttempt(new Error(`FFmpeg terminó con código ${code}${signal ? ' (señal ' + signal + ')' : ''}: ${stderr.slice(-300)}`));
      });
      ff.on("error", rejAttempt);
    });

    // INTENTO 1: Fast Remux (Stream Copy) ultra veloz (< 1s, < 25MB RAM, sin transcodificar video)
    try {
      const fastArgs = ["-y", ...vArgs, "-i", localVideo];
      if (hasSeparateAudio) {
        fastArgs.push(...aArgs, "-i", localAudio, "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-shortest");
      } else {
        fastArgs.push("-c:v", "copy", "-c:a", "aac", "-b:a", "160k");
      }
      fastArgs.push("-movflags", "+faststart", "-f", "mp4", outputPath);

      const fastResult = await runFfmpegAttempt(fastArgs);
      return fastResult;
    } catch (fastErr) {
      logger.warn(`Fast remux no completado (${fastErr.message}), ejecutando transcodificación x264...`);
      if (fs.existsSync(outputPath)) {
        try { fs.unlinkSync(outputPath); } catch {}
      }
    }

    // INTENTO 2: Transcodificación con libx264 con threads limitados para no superar la RAM de Render (512MB)
    let scaleFilter = "";
    const qNumMatch = quality && String(quality).match(/(\d{3,4})p?/);
    if (qNumMatch) {
      const h = parseInt(qNumMatch[1], 10);
      if (h && h > 0) {
        scaleFilter = `scale=-2:${h}:flags=fast_bilinear`;
      }
    }

    const encodeArgs = ["-y", ...vArgs, "-i", localVideo];
    if (hasSeparateAudio) {
      encodeArgs.push(...aArgs, "-i", localAudio);
    }
    if (scaleFilter) {
      encodeArgs.push("-vf", scaleFilter);
    }
    encodeArgs.push(
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-threads", "1",
      "-crf", "26",
      "-c:a", "aac",
      "-b:a", "128k",
      "-ar", "44100",
      "-pix_fmt", "yuv420p"
    );
    if (hasSeparateAudio) {
      encodeArgs.push("-map", "0:v:0?", "-map", "1:a:0?", "-shortest");
    }
    encodeArgs.push("-movflags", "+faststart", "-f", "mp4", outputPath);

    const encodeResult = await runFfmpegAttempt(encodeArgs);
    return encodeResult;
  } finally {
    if (tempVideoFile && fs.existsSync(tempVideoFile)) {
      try { fs.unlinkSync(tempVideoFile); } catch {}
    }
    if (tempAudioFile && fs.existsSync(tempAudioFile)) {
      try { fs.unlinkSync(tempAudioFile); } catch {}
    }
  }
}

/**
 * Estima el tamaño en bytes según duración, formato y calidad seleccionada
 */
function estimateMediaSizeBytes(format, quality, durationSeconds, clen = null) {
  if (clen && Number(clen) > 1000) {
    return Number(clen);
  }
  const s = Math.max(Number(durationSeconds) || 0, 60);
  if (format === "mp3") {
    let kbps = 192;
    const num = parseInt(quality, 10);
    if (!isNaN(num) && num > 0) {
      kbps = num;
    } else if (quality === "320k") kbps = 320;
    else if (quality === "256k") kbps = 256;
    else if (quality === "192k") kbps = 192;
    else if (quality === "128k") kbps = 128;
    else if (quality === "96k") kbps = 96;
    else if (quality === "64k") kbps = 64;
    return Math.round(s * (kbps * 1000 / 8));
  }
  if (format === "wav") {
    return Math.round(s * 44100 * 2 * 2);
  }
  let kbps = 2500;
  if (quality.includes("2160") || quality.includes("4k")) kbps = 16000;
  else if (quality.includes("1440") || quality.includes("2k")) kbps = 8500;
  else if (quality.includes("1080")) kbps = 4500;
  else if (quality.includes("720")) kbps = 2500;
  else if (quality.includes("540")) kbps = 1800;
  else if (quality.includes("480")) kbps = 1200;
  else if (quality.includes("360")) kbps = 800;
  else if (quality.includes("240")) kbps = 450;
  else if (quality.includes("144")) kbps = 250;
  return Math.round(s * (kbps * 1000 / 8));
}

// Almacén en RAM para conversiones ya completadas (clave: url|formato|calidad)
const convertedJobCache = new Map();

/**
 * Procesa la conversión de un video al formato elegido (MP3 o MP4)
 * con respuesta ultra rápida (< 2 segundos) y transcodificación física asíncrona garantizada.
 */
async function processConversion(options = {}) {
  const { url, format = "mp3", quality, audioTrack: reqAudioTrackId } = options;

  if (!url) {
    throw new Error("El parámetro 'url' es obligatorio para la conversión.");
  }

  const fmtLower = String(format || "").toLowerCase().trim();
  const selectedFormat = ["mp4", "wav"].includes(fmtLower) ? fmtLower : "mp3";
  const cleanQuality = typeof quality === "string" ? quality.toLowerCase().trim() : (selectedFormat === "mp4" ? "best" : "320k");
  const cacheKey = `${url.trim()}|${selectedFormat}|${cleanQuality}|${reqAudioTrackId || "default"}`;

  // Comprobar si ya existe una conversión previa en caché en RAM
  const cachedJob = convertedJobCache.get(cacheKey);
  if (cachedJob && (Date.now() - cachedJob.cachedAt < MEDIA_STORE_TTL_MS)) {
    const existingItem = mediaBufferStore.get(cachedJob.jobId);
    if (existingItem) {
      logger.info(`Conversión instantánea desde caché para ${cacheKey} (${cachedJob.jobId})`);
      return cachedJob.response;
    }
  }

  // Extracción ultra rápida de metadatos y streams de alta velocidad (~1.2s)
  const mediaInfo = await extractMediaInfo(url, selectedFormat);

  const audioTracks = mediaInfo.audioTracks || [];
  let selectedTrackObj = null;
  if (audioTracks.length > 0) {
    selectedTrackObj = (reqAudioTrackId && audioTracks.find(t => t.id === reqAudioTrackId)) ||
                       audioTracks.find(t => t.isDefault) ||
                       audioTracks[0];
    if (selectedTrackObj && selectedTrackObj.url) {
      mediaInfo.mp3Url = selectedTrackObj.url;
      if (selectedFormat === "mp3" || selectedFormat === "wav") {
        mediaInfo.directMediaUrl = selectedTrackObj.url;
      }
    }
  }

  const jobId = "media_" + Date.now() + "_" + Math.random().toString(36).slice(2, 8);
  const cleanTitle = sanitizeFilename(mediaInfo.title, `${mediaInfo.platformId}-media`);
  const extension = selectedFormat;
  const mimeType = selectedFormat === "mp4" ? "video/mp4" : (selectedFormat === "wav" ? "audio/wav" : "audio/mpeg");
  const finalDuration = mediaInfo.duration || "00:00";
  const finalDurationSeconds = mediaInfo.durationSeconds || 0;

  // Construir lista de calidades disponibles y normalizar la seleccionada
  let availableQualities = [];
  let selectedQuality = cleanQuality;

  const isSingleQualityPlatform = ["tiktok", "instagram"].includes(mediaInfo.platformId);

  if (isSingleQualityPlatform) {
    // TikTok e Instagram: no ofrecen selector de calidad (solo flujo único nativo)
    availableQualities = [];
    selectedQuality = "original";
  } else if (selectedFormat === "mp4") {
    if (mediaInfo.videoStreamsByQuality && Object.keys(mediaInfo.videoStreamsByQuality).length > 0) {
      // Ordenar todas las resoluciones reales encontradas de mayor a menor (excluyendo 2160p / 4K)
      const existingKeys = Object.keys(mediaInfo.videoStreamsByQuality)
        .filter(k => k !== "2160p" && !k.includes("2160") && !k.toLowerCase().includes("4k"))
        .sort((a, b) => {
          const numA = parseInt(a, 10) || 0;
          const numB = parseInt(b, 10) || 0;
          return numB - numA;
        });

      // Incluir las resoluciones estándar hasta la resolución máxima nativa del video
      const standardOrder = ["1440p", "1080p", "720p", "540p", "480p", "360p", "240p"];
      const maxResNum = existingKeys.length > 0 ? (parseInt(existingKeys[0], 10) || 720) : 720;

      const allQualityKeys = [];
      standardOrder.forEach(q => {
        const qNum = parseInt(q, 10) || 0;
        if (qNum <= maxResNum) {
          allQualityKeys.push(q);
        }
      });
      existingKeys.forEach(k => {
        if (!allQualityKeys.includes(k)) allQualityKeys.push(k);
      });
      allQualityKeys.sort((a, b) => (parseInt(b, 10) || 0) - (parseInt(a, 10) || 0));

      availableQualities = allQualityKeys.map(q => {
        const size = estimateMediaSizeBytes("mp4", q, finalDurationSeconds);
        return {
          id: q,
          label: q.toUpperCase(),
          sizeBytes: size,
          sizeFormatted: formatBytes(size)
        };
      });
    }
    if (availableQualities.length === 0) {
      // Sin 2160p 4K
      const defaultVideoKeys = ["1440p", "1080p", "720p", "540p", "480p", "360p", "240p"];
      availableQualities = defaultVideoKeys.map(q => {
        const size = estimateMediaSizeBytes("mp4", q, finalDurationSeconds);
        return {
          id: q,
          label: q.toUpperCase(),
          sizeBytes: size,
          sizeFormatted: formatBytes(size)
        };
      });
    }

    let matchedQ = cleanQuality;
    const match = cleanQuality && cleanQuality.match(/(\d{3,4})p?/);
    if (match) matchedQ = `${match[1]}p`;
    else if (cleanQuality && (cleanQuality.includes("2k") || cleanQuality.includes("1440"))) matchedQ = "1440p";

    // Si se solicitó 4K o 2160p, cambiar al máximo soportado (1080p o 1440p)
    if (matchedQ === "2160p" || (cleanQuality && cleanQuality.includes("4k"))) {
      matchedQ = availableQualities.some(q => q.id === "1440p") ? "1440p" : "1080p";
    }

    if (cleanQuality !== "best" && cleanQuality !== "auto" && availableQualities.some(q => q.id === matchedQ)) {
      selectedQuality = matchedQ;
    } else {
      selectedQuality = availableQualities[0]?.id || "1080p";
    }
  } else {
    // Formato MP3 o WAV: Todas las calidades estándar de audio disponibles
    const mp3Keys = ["320k", "256k", "192k", "128k", "64k"];
    availableQualities = mp3Keys.map(q => {
      const size = estimateMediaSizeBytes("mp3", q, finalDurationSeconds);
      return {
        id: q,
        label: `${q.replace('k', '')} kbps`,
        sizeBytes: size,
        sizeFormatted: formatBytes(size)
      };
    });
    let matchedQ = cleanQuality ? cleanQuality.replace(/[^0-9]/g, "") + "k" : "320k";
    if (cleanQuality !== "best" && cleanQuality !== "auto" && availableQualities.some(q => q.id === matchedQ)) {
      selectedQuality = matchedQ;
    } else if (cleanQuality !== "best" && cleanQuality !== "auto" && availableQualities.some(q => q.id === cleanQuality)) {
      selectedQuality = cleanQuality;
    } else {
      selectedQuality = "320k";
    }
  }

  const downloadFilename = `Vork_${cleanTitle}.${extension}`;
  const effectiveAudioTrackId = selectedTrackObj ? selectedTrackObj.id : (audioTracks[0]?.id || "audio_0");
  const outputPath = path.join(MEDIA_CACHE_DIR, `${jobId}_${selectedQuality}_${effectiveAudioTrackId}.${extension}`);
  const legacyOutputPath = path.join(MEDIA_CACHE_DIR, `${jobId}_${selectedQuality}.${extension}`);

  // Si es video MP4 y disponemos de streams por resolución, seleccionar el correspondiente a selectedQuality
  if (selectedFormat === "mp4" && mediaInfo.videoStreamsByQuality) {
    const specificVideoStream = mediaInfo.videoStreamsByQuality[selectedQuality] ||
      mediaInfo.videoStreamsByQuality["1080p"] ||
      mediaInfo.videoStreamsByQuality["720p"] ||
      mediaInfo.videoStreamsByQuality["480p"] ||
      mediaInfo.videoStreamsByQuality["360p"] ||
      Object.values(mediaInfo.videoStreamsByQuality)[0];
    if (specificVideoStream) {
      if (typeof specificVideoStream === "object" && specificVideoStream !== null && specificVideoStream.videoUrl) {
        mediaInfo.mp4Url = specificVideoStream.videoUrl;
        mediaInfo.directMediaUrl = specificVideoStream.videoUrl;
        if (specificVideoStream.audioUrl && !selectedTrackObj) {
          mediaInfo.mp3Url = specificVideoStream.audioUrl;
          mediaInfo.separateAudio = true;
        }
      } else {
        mediaInfo.mp4Url = specificVideoStream;
        mediaInfo.directMediaUrl = specificVideoStream;
      }
    }
  }

  // Si es formato MP3 / WAV y se descubrió una pista de audio directa en streams
  if ((selectedFormat === "mp3" || selectedFormat === "wav") && mediaInfo.videoStreamsByQuality) {
    for (const val of Object.values(mediaInfo.videoStreamsByQuality)) {
      if (typeof val === "object" && val !== null && val.audioUrl) {
        mediaInfo.mp3Url = val.audioUrl;
        mediaInfo.directMediaUrl = val.audioUrl;
        break;
      }
    }
  }

  // Construir lista de candidatos según formato y plataforma
  const candidateStreams = [];
  if (selectedFormat === "mp3" || selectedFormat === "wav") {
    if (mediaInfo.mp3Url) {
      const wrapped = wrapStreamUrl(mediaInfo.mp3Url);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
    if (mediaInfo.combinedMp4Url) {
      const wrapped = wrapStreamUrl(mediaInfo.combinedMp4Url);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
    if (mediaInfo.directMediaUrl) {
      const wrapped = wrapStreamUrl(mediaInfo.directMediaUrl);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
    if (mediaInfo.mp4Url) {
      const wrapped = wrapStreamUrl(mediaInfo.mp4Url);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
  } else {
    if (mediaInfo.combinedMp4Url) {
      const wrapped = wrapStreamUrl(mediaInfo.combinedMp4Url);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
    if (mediaInfo.mp4Url) {
      const wrapped = wrapStreamUrl(mediaInfo.mp4Url);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
    if (mediaInfo.directMediaUrl) {
      const wrapped = wrapStreamUrl(mediaInfo.directMediaUrl);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
    if (mediaInfo.mp3Url) {
      const wrapped = wrapStreamUrl(mediaInfo.mp3Url);
      if (!candidateStreams.includes(wrapped)) candidateStreams.push(wrapped);
    }
  }

  const primaryRemoteStream = wrapStreamUrl(candidateStreams[0] || mediaInfo.directMediaUrl || mediaInfo.mp4Url || mediaInfo.mp3Url);
  const initialSizeBytes = estimateMediaSizeBytes(selectedFormat, selectedQuality, finalDurationSeconds);
  const isFallbackSvg = !mediaInfo.thumbnail ||
    mediaInfo.thumbnail === "/img/logo.png" ||
    (typeof mediaInfo.thumbnail === "string" && mediaInfo.thumbnail.startsWith("/api/media/thumbnail-proxy?") && !mediaInfo.thumbnail.includes("url="));

  const finalThumbnail = !isFallbackSvg
    ? mediaInfo.thumbnail
    : `/api/media/thumbnail?id=${jobId}`;

  const itemRecord = {
    id: jobId,
    url: mediaInfo.url,
    title: mediaInfo.title,
    author: mediaInfo.author,
    platform: mediaInfo.platform,
    platformId: mediaInfo.platformId,
    format: selectedFormat,
    quality: selectedQuality,
    mimeType,
    filename: downloadFilename,
    filePath: outputPath,
    thumbPath: null,
    duration: finalDuration,
    durationSeconds: finalDurationSeconds,
    sizeBytes: initialSizeBytes,
    thumbnail: finalThumbnail,
    mp4Url: wrapStreamUrl(mediaInfo.mp4Url) || null,
    mp3Url: wrapStreamUrl(mediaInfo.mp3Url) || null,
    combinedMp4Url: wrapStreamUrl(mediaInfo.combinedMp4Url) || null,
    videoStreamsByQuality: mediaInfo.videoStreamsByQuality || {},
    availableQualities,
    selectedQuality,
    separateAudio: Boolean(mediaInfo.separateAudio),
    separateAudioUrl: mediaInfo.separateAudio ? wrapStreamUrl(mediaInfo.mp3Url || mediaInfo.directMediaUrl) : null,
    audioTracks: audioTracks.map(t => ({
      id: t.id,
      label: t.label,
      url: wrapStreamUrl(t.url),
      isDefault: selectedTrackObj ? t.id === selectedTrackObj.id : Boolean(t.isDefault)
    })),
    selectedAudioTrack: selectedTrackObj ? selectedTrackObj.id : (audioTracks[0]?.id || null),
    remoteStreamUrl: primaryRemoteStream,
    candidateStreams,
    conversionPromise: null,
    isReady: false,
    createdAt: Date.now()
  };

  // Lanzar la transcodificación física en segundo plano (no bloquea la respuesta HTTP)
  itemRecord.conversionPromise = (async () => {
    try {
      const primaryStream = candidateStreams[0];
      const thumbPath = path.join(MEDIA_CACHE_DIR, `${jobId}.jpg`);

      // 1. Extraer inmediatamente el fotograma JPEG en paralelo (rápido: ~300ms)
      if (primaryStream && (!itemRecord.thumbPath || !fs.existsSync(itemRecord.thumbPath))) {
        extractThumbnailFrame(primaryStream, thumbPath).then(ok => {
          if (ok && fs.existsSync(thumbPath)) {
            itemRecord.thumbPath = thumbPath;
            try {
              fs.writeFileSync(path.join(MEDIA_CACHE_DIR, `${jobId}.json`), JSON.stringify(itemRecord), 'utf8');
            } catch {}
          }
        }).catch(() => {});
      }

      for (const streamUrl of candidateStreams) {
        if (!streamUrl) continue;
        try {
          if (selectedFormat === "mp3") {
            const transRes = await transcodeToMp3(streamUrl, outputPath, cleanQuality);
            if (transRes && transRes.sizeBytes) {
              itemRecord.sizeBytes = transRes.sizeBytes;
              if (transRes.duration && (!itemRecord.duration || itemRecord.duration === "00:00")) {
                itemRecord.duration = transRes.duration;
                itemRecord.durationSeconds = transRes.durationSeconds;
              }
            }
            // Generar o confirmar miniatura física JPEG extraída con FFmpeg
            if (!itemRecord.thumbPath || !fs.existsSync(itemRecord.thumbPath)) {
              const frameOk = await extractThumbnailFrame(streamUrl, thumbPath);
              if (frameOk && fs.existsSync(thumbPath)) {
                itemRecord.thumbPath = thumbPath;
                itemRecord.thumbnail = `/api/media/thumbnail?id=${jobId}`;
              }
            }
            itemRecord.isReady = true;
            if (fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
              try {
                if (legacyOutputPath && !fs.existsSync(legacyOutputPath)) {
                  fs.copyFileSync(outputPath, legacyOutputPath);
                }
              } catch {}
            }
            break;
          } else if (selectedFormat === "wav") {
            const transRes = await transcodeToWav(streamUrl, outputPath);
            if (transRes && transRes.sizeBytes) {
              itemRecord.sizeBytes = transRes.sizeBytes;
            }
            if (!itemRecord.thumbPath || !fs.existsSync(itemRecord.thumbPath)) {
              const frameOk = await extractThumbnailFrame(streamUrl, thumbPath);
              if (frameOk && fs.existsSync(thumbPath)) {
                itemRecord.thumbPath = thumbPath;
                itemRecord.thumbnail = `/api/media/thumbnail?id=${jobId}`;
              }
            }
            itemRecord.isReady = true;
            if (fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
              try {
                if (legacyOutputPath && !fs.existsSync(legacyOutputPath)) {
                  fs.copyFileSync(outputPath, legacyOutputPath);
                }
              } catch {}
            }
            break;
          } else {
            const separateAudioUrl = mediaInfo.separateAudio ? (mediaInfo.mp3Url || mediaInfo.directMediaUrl) : null;
            const transRes = await transcodeToMp4(streamUrl, outputPath, cleanQuality, separateAudioUrl);
            if (transRes && transRes.sizeBytes) {
              itemRecord.sizeBytes = transRes.sizeBytes;
              if (transRes.duration && (!itemRecord.duration || itemRecord.duration === "00:00")) {
                itemRecord.duration = transRes.duration;
                itemRecord.durationSeconds = transRes.durationSeconds;
              }
            }
            // Generar o confirmar miniatura física JPEG extraída directamente del archivo MP4 renderizado
            if (!itemRecord.thumbPath || !fs.existsSync(itemRecord.thumbPath)) {
              const srcForThumb = fs.existsSync(outputPath) ? outputPath : streamUrl;
              const frameOk = await extractThumbnailFrame(srcForThumb, thumbPath);
              if (frameOk && fs.existsSync(thumbPath)) {
                itemRecord.thumbPath = thumbPath;
                itemRecord.thumbnail = `/api/media/thumbnail?id=${jobId}`;
              }
            }
            itemRecord.isReady = true;
            if (fs.existsSync(outputPath) && fs.statSync(outputPath).size > 1000) {
              try {
                if (legacyOutputPath && !fs.existsSync(legacyOutputPath)) {
                  fs.copyFileSync(outputPath, legacyOutputPath);
                }
              } catch {}
            }
            break;
          }
        } catch (convErr) {
          logger.warn(`Transcodificación en segundo plano falló para ${streamUrl}: ${convErr.message}`);
          if (fs.existsSync(outputPath)) {
            try { fs.unlinkSync(outputPath); } catch {}
          }
        }
      }

      // Guardar metadata en disco ante reinicios
      try {
        fs.writeFileSync(path.join(MEDIA_CACHE_DIR, `${jobId}.json`), JSON.stringify(itemRecord), 'utf8');
      } catch {}
    } catch (globalErr) {
      logger.error(`Error en tarea asíncrona de conversión (${jobId}): ${globalErr.message}`);
    }
  })();

  // Guardar en almacén en RAM
  mediaBufferStore.set(jobId, itemRecord);

  // Acelerador de respuesta: esperar hasta 4.5 segundos si la transcodificación física termina rápido
  try {
    await Promise.race([
      itemRecord.conversionPromise,
      new Promise(resolve => setTimeout(resolve, 4500))
    ]);
  } catch {}

  const baseUrl = "";
  const trackSuffix = itemRecord.selectedAudioTrack ? `&audioTrack=${encodeURIComponent(itemRecord.selectedAudioTrack)}` : "";
  const qualitySuffix = `&quality=${encodeURIComponent(selectedQuality)}`;
  const downloadUrl = `${baseUrl}/api/media/download?id=${jobId}${trackSuffix}${qualitySuffix}`;
  const isMp4 = selectedFormat === "mp4";
  const mediaStreamUrl = `${baseUrl}/api/media/stream?id=${jobId}&type=${isMp4 ? "video" : "audio"}${trackSuffix}${qualitySuffix}`;

  const responsePayload = {
    status: "success",
    id: jobId,
    title: mediaInfo.title,
    author: mediaInfo.author,
    platform: mediaInfo.platform,
    platformId: mediaInfo.platformId,
    format: selectedFormat,
    thumbnail: finalThumbnail,
    duration: finalDuration,
    durationSeconds: finalDurationSeconds,
    ...(isMp4 ? { videoUrl: mediaStreamUrl } : { audioUrl: mediaStreamUrl }),
    downloadUrl,
    filename: downloadFilename,
    mimeType,
    sizeBytes: initialSizeBytes,
    quality: selectedQuality,
    selectedQuality,
    availableQualities: itemRecord.availableQualities || [],
    audioTracks: (itemRecord.audioTracks || []).map(t => ({ id: t.id, label: t.label, isDefault: t.isDefault })),
    selectedAudioTrack: itemRecord.selectedAudioTrack || null,
    message: `Conversión completada a formato ${selectedFormat.toUpperCase()}. Descarga directa disponible desde Vork.`
  };

  // Guardar en caché de conversiones para responder de inmediato si se repite la consulta
  try {
    convertedJobCache.set(cacheKey, {
      jobId,
      response: responsePayload,
      cachedAt: Date.now()
    });
  } catch {}

  return responsePayload;
}

/**
 * Obtiene el registro de un medio por su ID
 */
function getMediaById(id) {
  if (!id) return null;
  let item = mediaBufferStore.get(id);
  if (!item) {
    // Intentar recuperar desde almacenamiento físico si el proceso se reinició
    const metaPath = path.join(MEDIA_CACHE_DIR, `${id}.json`);
    let meta = null;
    if (fs.existsSync(metaPath)) {
      try { meta = JSON.parse(fs.readFileSync(metaPath, 'utf8')); } catch {}
    }

    const possibleExts = ["mp4", "mp3", "wav", "webm"];
    let diskPath = null;
    let foundExt = meta?.format || "mp3";
    for (const ext of possibleExts) {
      let candidate = path.join(MEDIA_CACHE_DIR, `${id}.${ext}`);
      if (!fs.existsSync(candidate)) {
        try {
          const files = fs.readdirSync(MEDIA_CACHE_DIR);
          const found = files.find(f => f.startsWith(`${id}_`) && f.endsWith(`.${ext}`));
          if (found) candidate = path.join(MEDIA_CACHE_DIR, found);
        } catch {}
      }
      if (fs.existsSync(candidate)) {
        diskPath = candidate;
        foundExt = ext;
        break;
      }
    }

    if (diskPath || meta) {
      const stats = diskPath && fs.existsSync(diskPath) ? fs.statSync(diskPath) : null;
      item = {
        ...(meta || {}),
        id,
        format: foundExt,
        mimeType: foundExt === "mp4" ? "video/mp4" : (foundExt === "wav" ? "audio/wav" : "audio/mpeg"),
        filePath: diskPath || meta?.filePath || null,
        filename: meta?.filename || `Vork_Media_${id}.${foundExt}`,
        sizeBytes: stats ? stats.size : (meta?.sizeBytes || 0),
        mp4Url: wrapStreamUrl(meta?.mp4Url),
        mp3Url: wrapStreamUrl(meta?.mp3Url),
        remoteStreamUrl: wrapStreamUrl(meta?.remoteStreamUrl),
        candidateStreams: Array.isArray(meta?.candidateStreams) ? meta.candidateStreams.map(wrapStreamUrl) : [],
        audioTracks: Array.isArray(meta?.audioTracks) ? meta.audioTracks.map(t => ({ ...t, url: wrapStreamUrl(t.url) })) : [],
        videoStreamsByQuality: meta?.videoStreamsByQuality || {},
        createdAt: meta?.createdAt || stats?.mtimeMs || Date.now()
      };
      mediaBufferStore.set(id, item);
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

/**
 * Procesa múltiples conversiones en lote (hasta 10 elementos simultáneos)
 */
async function processBatchConversion({ urls = [], format = "mp3", quality = "320k" } = {}) {
  const selectedUrls = urls.slice(0, 10);
  return Promise.all(
    selectedUrls.map(async (link) => {
      try {
        return await processConversion({ url: link, format, quality });
      } catch (itemErr) {
        return {
          status: "error",
          url: link,
          error: itemErr.message
        };
      }
    })
  );
}

// Almacén de promesas de generación de variantes multimedia para evitar transcodes duplicados
const variantPromises = new Map();

/**
 * Garantiza que exista en disco la variante exacta de video/audio con la calidad y pista solicitada.
 * Si ya existe, retorna su ruta física inmediatamente (< 1ms).
 * Si no existe, realiza remux ultra-rápido (< 2s) y retorna la ruta en cuanto esté lista.
 * Mantiene mutex / cache de promesas para solicitudes concurrentes (como bytes=0- de navegadores).
 */
async function ensureMediaVariant(item, targetQuality, targetAudioTrackId) {
  if (!item) return null;

  const isMp4 = item.format === "mp4";
  const defaultTrackId = item.selectedAudioTrack || (item.audioTracks?.find(t => t.isDefault)?.id) || item.audioTracks?.[0]?.id || "audio_0";
  const finalTrackId = targetAudioTrackId || defaultTrackId;

  let finalQuality = targetQuality;
  if (!finalQuality || finalQuality === "best" || finalQuality === "auto") {
    finalQuality = item.selectedQuality || item.quality || (item.availableQualities && item.availableQualities[0]?.id) || (isMp4 ? "1080p" : "320k");
  }
  if (isMp4) {
    const match = String(finalQuality).match(/(\d{3,4})p?/);
    if (match) finalQuality = `${match[1]}p`;
  } else {
    finalQuality = String(finalQuality).replace(/[^0-9]/g, "") + "k";
    if (finalQuality === "k") finalQuality = "320k";
  }

  const ext = item.format || (isMp4 ? "mp4" : "mp3");
  const variantFilename = `${item.id}_${finalQuality}_${finalTrackId}.${ext}`;
  const variantPath = path.join(MEDIA_CACHE_DIR, variantFilename);

  // 1. Si el archivo exacto con la pista y calidad ya existe físicamente en disco y tiene tamaño válido:
  if (fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) {
    return variantPath;
  }

  // 2. Si es la pista por defecto, verificar si existe con la nomenclatura previa `${item.id}_${finalQuality}.${ext}`
  if (finalTrackId === defaultTrackId) {
    const legacyPath = path.join(MEDIA_CACHE_DIR, `${item.id}_${finalQuality}.${ext}`);
    if (fs.existsSync(legacyPath) && fs.statSync(legacyPath).size > 1000) {
      return legacyPath;
    }
    if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) {
      if (item.filePath.includes(finalQuality) || item.quality === finalQuality) {
        return item.filePath;
      }
    }
  }

  // 3. Si la conversión inicial está corriendo y coincide con la calidad y pista por defecto, esperar:
  if (finalTrackId === defaultTrackId && (finalQuality === item.selectedQuality || finalQuality === item.quality)) {
    if (item.conversionPromise) {
      try {
        await Promise.race([
          item.conversionPromise,
          new Promise(res => setTimeout(res, 8000))
        ]);
      } catch {}
      if (fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) return variantPath;
      const legacyPath = path.join(MEDIA_CACHE_DIR, `${item.id}_${finalQuality}.${ext}`);
      if (fs.existsSync(legacyPath) && fs.statSync(legacyPath).size > 1000) return legacyPath;
      if (item.filePath && fs.existsSync(item.filePath) && fs.statSync(item.filePath).size > 1000) return item.filePath;
    }
  }

  // 4. Si ya hay una promesa activa transcodificando esta combinación específica, reutilizarla
  const mutexKey = `${item.id}_${finalQuality}_${finalTrackId}.${ext}`;
  if (variantPromises.has(mutexKey)) {
    try {
      const existingRes = await variantPromises.get(mutexKey);
      if (existingRes && fs.existsSync(existingRes) && fs.statSync(existingRes).size > 1000) {
        return existingRes;
      }
    } catch {}
  }

  // 5. Generar la variante requerida
  const generationPromise = (async () => {
    try {
      if (isMp4) {
        // Resolver URL de video para finalQuality
        let videoUrl = null;
        if (item.videoStreamsByQuality) {
          const entry = item.videoStreamsByQuality[finalQuality];
          if (entry) {
            videoUrl = typeof entry === "object" ? entry.videoUrl : entry;
          }
          if (!videoUrl) {
            const availableKeys = Object.keys(item.videoStreamsByQuality).sort((a, b) => (parseInt(b, 10) || 0) - (parseInt(a, 10) || 0));
            const exactOrBelow = availableKeys.find(k => (parseInt(k, 10) || 0) <= (parseInt(finalQuality, 10) || 1080));
            const chosenKey = exactOrBelow || availableKeys[0];
            if (chosenKey) {
              const chEntry = item.videoStreamsByQuality[chosenKey];
              videoUrl = typeof chEntry === "object" ? chEntry.videoUrl : chEntry;
            }
          }
        }
        if (!videoUrl) {
          videoUrl = item.mp4Url || item.remoteStreamUrl;
        }

        // Resolver URL de audio para finalTrackId
        let audioUrl = null;
        if (item.audioTracks && item.audioTracks.length > 0) {
          const trObj = item.audioTracks.find(t => t.id === finalTrackId);
          if (trObj && trObj.url) {
            audioUrl = trObj.url;
          }
        }
        if (!audioUrl) {
          audioUrl = item.mp3Url || item.remoteStreamUrl;
        }

        logger.info(`Generando variante MP4: ${item.id} (${finalQuality}, pista ${finalTrackId})...`);
        const transResult = await transcodeToMp4(videoUrl, variantPath, finalQuality, item.separateAudio ? audioUrl : null);
        if (transResult && fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) {
          logger.info(`Variante MP4 lista: ${variantFilename} (${formatBytes(transResult.sizeBytes)})`);
          return variantPath;
        }
      } else {
        // Formato Audio (MP3 o WAV)
        let audioUrl = null;
        if (item.audioTracks && item.audioTracks.length > 0) {
          const trObj = item.audioTracks.find(t => t.id === finalTrackId);
          if (trObj && trObj.url) {
            audioUrl = trObj.url;
          }
        }
        if (!audioUrl) {
          audioUrl = item.mp3Url || item.remoteStreamUrl;
        }

        logger.info(`Generando variante Audio: ${item.id} (${finalQuality}, pista ${finalTrackId})...`);
        if (ext === "wav") {
          await transcodeToWav(audioUrl, variantPath);
        } else {
          await transcodeToMp3(audioUrl, variantPath, finalQuality);
        }
        if (fs.existsSync(variantPath) && fs.statSync(variantPath).size > 1000) {
          logger.info(`Variante Audio lista: ${variantFilename}`);
          return variantPath;
        }
      }
    } catch (genErr) {
      logger.warn(`Error al generar variante ${mutexKey}: ${genErr.message}`);
      if (fs.existsSync(variantPath)) {
        try { fs.unlinkSync(variantPath); } catch {}
      }
    }
    return null;
  })();

  variantPromises.set(mutexKey, generationPromise);
  try {
    const resultPath = await generationPromise;
    return resultPath;
  } finally {
    variantPromises.delete(mutexKey);
  }
}

module.exports = {
  MEDIA_CACHE_DIR,
  SUPPORTED_PLATFORMS,
  detectPlatform,
  extractMediaInfo,
  extractThumbnailFrame,
  processConversion,
  processBatchConversion,
  getMediaById,
  ensureMediaVariant,
  formatBytes,
  formatDurationSeconds,
  sanitizeFilename,
  wrapStreamUrl,
  mediaBufferStore,
  convertedJobCache
};
