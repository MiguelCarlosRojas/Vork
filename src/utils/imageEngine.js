/**
 * imageEngine.js
 * Motor Central de Procesamiento de Imágenes y Estudio de Fondo IA (Pilares 07 y 08)
 * Confinado, seguro contra Path Traversal, SSRF y DoS.
 */

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const axios = require("axios");
const crypto = require("crypto");
const logger = require("./logger");
const { validateSafeUrl } = require("./ssrfGuard");

// Directorio seguro de almacenamiento en caché para imágenes procesadas
const IMAGE_CACHE_DIR = path.resolve(__dirname, "..", "..", "temp_media", "image_cache");
if (!fs.existsSync(IMAGE_CACHE_DIR)) {
  fs.mkdirSync(IMAGE_CACHE_DIR, { recursive: true });
}

// Catálogo en memoria de imágenes procesadas (TTL 60 minutos)
const imageStore = new Map();
const TTL_MS = 60 * 60 * 1000;

// Limpieza periódica de archivos antiguos
setInterval(() => {
  const now = Date.now();
  for (const [id, item] of imageStore.entries()) {
    if (now - item.createdAt > TTL_MS) {
      try {
        if (item.filePath && fs.existsSync(item.filePath)) fs.unlinkSync(item.filePath);
        if (item.inputPath && fs.existsSync(item.inputPath)) fs.unlinkSync(item.inputPath);
      } catch (err) {
        logger.warn(`[ImageEngine] Error al eliminar imagen expirada ${id}: ${err.message}`);
      }
      imageStore.delete(id);
    }
  }
}, 5 * 60 * 1000).unref();

/**
 * Guarda un buffer o base64 en un archivo temporal
 */
function saveTempFile(data, extension = "png") {
  const fileId = "tmp_" + crypto.randomBytes(12).toString("hex");
  const filePath = path.join(IMAGE_CACHE_DIR, `${fileId}.${extension}`);

  let buffer;
  if (Buffer.isBuffer(data)) {
    buffer = data;
  } else if (typeof data === "string") {
    // Si viene en formato Data URL: data:image/png;base64,....
    const cleanBase64 = data.replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, "");
    buffer = Buffer.from(cleanBase64, "base64");
  } else {
    throw new Error("Datos de imagen no válidos para almacenamiento temporal.");
  }

  fs.writeFileSync(filePath, buffer);
  return filePath;
}

/**
 * Descarga una imagen de forma segura verificando SSRF
 */
async function downloadSafeImage(url) {
  await validateSafeUrl(url);
  const response = await axios.get(url, {
    responseType: "arraybuffer",
    timeout: 20000,
    maxContentLength: 40 * 1024 * 1024, // 40MB máx
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    }
  });

  const contentType = (response.headers["content-type"] || "").toLowerCase();

  // Si la respuesta es una página web HTML, extraer imagen principal (og:image / twitter:image)
  if (contentType.includes("text/html")) {
    const htmlText = Buffer.from(response.data).toString("utf8");
    const ogMatch = htmlText.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i) ||
                    htmlText.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i) ||
                    htmlText.match(/<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i) ||
                    htmlText.match(/<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["']/i);
    if (ogMatch && ogMatch[1]) {
      let realImgUrl = ogMatch[1].trim();
      if (realImgUrl.startsWith("//")) {
        realImgUrl = "https:" + realImgUrl;
      } else if (realImgUrl.startsWith("/")) {
        const u = new URL(url);
        realImgUrl = `${u.protocol}//${u.host}${realImgUrl}`;
      }
      logger.info(`[ImageEngine] og:image detectado en página web: ${realImgUrl}`);
      return await downloadSafeImage(realImgUrl);
    }
    throw new Error("La URL ingresada es una página web pero no contiene una imagen meta (og:image) detectable.");
  }

  const buf = Buffer.from(response.data);
  let ext = "png";

  // Detección por Magic Bytes (Firma binaria)
  if (buf.length >= 4) {
    if (buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF) {
      ext = "jpg";
    } else if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) {
      ext = "png";
    } else if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x38) {
      ext = "gif";
    } else if (buf[0] === 0x42 && buf[1] === 0x4D) {
      ext = "bmp";
    } else if (buf[0] === 0x00 && buf[1] === 0x00 && buf[2] === 0x01 && buf[3] === 0x00) {
      ext = "ico";
    } else if (buf.length >= 12 && buf.toString("ascii", 0, 4) === "RIFF" && buf.toString("ascii", 8, 12) === "WEBP") {
      ext = "webp";
    } else if (buf.length >= 12 && buf.toString("ascii", 4, 12).includes("ftypavif")) {
      ext = "avif";
    } else if (contentType.includes("jpeg") || contentType.includes("jpg")) {
      ext = "jpg";
    } else if (contentType.includes("webp")) {
      ext = "webp";
    } else if (contentType.includes("gif")) {
      ext = "gif";
    } else if (contentType.includes("bmp")) {
      ext = "bmp";
    }
  }

  return saveTempFile(buf, ext);
}

/**
 * Ejecuta el script Python ai_image_studio.py
 */
function runPythonStudio(args) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.resolve(__dirname, "ai_image_studio.py");
    const pythonExe = process.platform === "win32" ? "python" : "python3";

    const proc = spawn(pythonExe, [scriptPath, ...args]);
    let stdoutData = "";
    let stderrData = "";

    proc.stdout.on("data", (data) => {
      stdoutData += data.toString("utf8");
    });

    proc.stderr.on("data", (data) => {
      stderrData += data.toString("utf8");
    });

    proc.on("close", (code) => {
      if (code !== 0) {
        logger.error(`[ImageEngine] Fallo en ai_image_studio.py (código ${code}): ${stderrData}`);
        return reject(new Error(stderrData || `Error en el procesador de imágenes (código ${code})`));
      }

      try {
        const jsonRes = JSON.parse(stdoutData.trim());
        resolve(jsonRes);
      } catch (err) {
        reject(new Error(`Respuesta inválida del procesador de imágenes: ${stdoutData}`));
      }
    });

    proc.on("error", (err) => {
      logger.error(`[ImageEngine] No se pudo invocar Python: ${err.message}`);
      reject(new Error(`No se pudo iniciar el proceso de Python: ${err.message}`));
    });
  });
}

/**
 * Convierte imagen usando FFmpeg nativo como respaldo ultra robusto
 */
async function convertWithFFmpeg(inputPath, outputPath, safeFormat, quality = 90, width, height) {
  let ffmpegExe = "ffmpeg";
  try {
    const installer = require("@ffmpeg-installer/ffmpeg");
    if (installer && installer.path) ffmpegExe = installer.path;
  } catch {}

  const args = ["-y", "-i", inputPath];

  if (width && height) {
    args.push("-vf", `scale=${parseInt(width, 10)}:${parseInt(height, 10)}`);
  } else if (width) {
    args.push("-vf", `scale=${parseInt(width, 10)}:-1`);
  } else if (height) {
    args.push("-vf", `scale=-1:${parseInt(height, 10)}`);
  }

  if (safeFormat === "jpg" || safeFormat === "jpeg") {
    const qscale = Math.max(1, Math.min(31, Math.round(31 - (quality / 100) * 30)));
    args.push("-q:v", String(qscale));
  } else if (safeFormat === "webp") {
    args.push("-quality", String(quality));
  }

  args.push(outputPath);

  return new Promise((resolve, reject) => {
    const proc = spawn(ffmpegExe, args);
    let stderr = "";
    proc.stderr.on("data", d => { stderr += d.toString(); });
    proc.on("close", code => {
      if (code === 0 && fs.existsSync(outputPath) && fs.statSync(outputPath).size > 0) {
        const sizeBytes = fs.statSync(outputPath).size;
        resolve({
          status: "success",
          format: safeFormat,
          size_bytes: sizeBytes,
          width: width || 0,
          height: height || 0,
          orig_width: 0,
          orig_height: 0
        });
      } else {
        reject(new Error(`Error al convertir imagen con FFmpeg (código ${code}): ${stderr.slice(-200)}`));
      }
    });
    proc.on("error", reject);
  });
}

/**
 * Pilar 07: Convierte el formato de una imagen (PNG, JPG, WEBP, GIF, BMP, TIFF, ICO)
 */
async function processImageConversion({ imageBase64, url, targetFormat = "png", quality = 90, width, height }) {
  let inputPath = null;
  const targetId = "img_" + crypto.randomBytes(12).toString("hex");

  try {
    if (url) {
      inputPath = await downloadSafeImage(url);
    } else if (imageBase64) {
      inputPath = saveTempFile(imageBase64, "input");
    } else {
      throw new Error("Debe proporcionar una imagen en formato base64 o una URL.");
    }

    const normFormat = (targetFormat || "png").toLowerCase().replace(/[^a-z0-9]/g, "");
    const safeFormat = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "ico"].includes(normFormat) ? normFormat : "png";
    const extension = safeFormat === "jpeg" ? "jpg" : safeFormat;

    const outputPath = path.join(IMAGE_CACHE_DIR, `${targetId}.${extension}`);

    let result = null;
    try {
      const args = [
        "convert",
        "--input", inputPath,
        "--output", outputPath,
        "--format", safeFormat,
        "--quality", String(Math.max(1, Math.min(100, parseInt(quality, 10) || 90)))
      ];

      if (width && parseInt(width, 10) > 0) {
        args.push("--width", String(parseInt(width, 10)));
      }
      if (height && parseInt(height, 10) > 0) {
        args.push("--height", String(parseInt(height, 10)));
      }

      result = await runPythonStudio(args);
    } catch (pyErr) {
      logger.warn(`[ImageEngine] Python falló o sin librerías (${pyErr.message}). Utilizando conversor FFmpeg nativo...`);
      result = await convertWithFFmpeg(inputPath, outputPath, safeFormat, quality, width, height);
    }

    // Guardar en almacén
    const itemData = {
      id: targetId,
      filename: `imagen_convertida_${targetId.slice(4, 10)}.${extension}`,
      format: safeFormat,
      filePath: outputPath,
      inputPath,
      sizeBytes: result.size_bytes,
      width: result.width,
      height: result.height,
      createdAt: Date.now()
    };
    imageStore.set(targetId, itemData);

    return {
      status: "success",
      id: targetId,
      filename: itemData.filename,
      format: safeFormat,
      width: result.width,
      height: result.height,
      origWidth: result.orig_width,
      origHeight: result.orig_height,
      sizeBytes: result.size_bytes,
      sizeFormatted: (result.size_bytes / 1024).toFixed(2) + " KB",
      streamUrl: `/api/image/stream?id=${targetId}`,
      downloadUrl: `/api/image/download?id=${targetId}`
    };
  } catch (error) {
    if (inputPath && fs.existsSync(inputPath)) {
      try { fs.unlinkSync(inputPath); } catch (e) {}
    }
    throw error;
  }
}

/**
 * Pilar 08: Remueve el fondo o lo reemplaza (Transparente, Color, Imagen o Prompt IA)
 */
async function processBackgroundOperation({
  imageBase64,
  url,
  mode = "transparent",
  color = "#FFFFFF",
  bgImageBase64,
  prompt
}) {
  let inputPath = null;
  let bgPath = null;
  const targetId = "bg_" + crypto.randomBytes(12).toString("hex");

  try {
    if (url) {
      inputPath = await downloadSafeImage(url);
    } else if (imageBase64) {
      inputPath = saveTempFile(imageBase64, "input");
    } else {
      throw new Error("Debe proporcionar una imagen para procesar.");
    }

    const safeMode = ["transparent", "color", "custom_bg", "prompt"].includes(mode) ? mode : "transparent";

    // Si el modo es prompt (IA generativa gratuita de Pollinations para crear el fondo exacto descrito por el usuario)
    if (safeMode === "prompt") {
      if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
        throw new Error("Debe especificar una descripción de lo que desea cambiar en el fondo.");
      }

      const cleanPrompt = encodeURIComponent(prompt.trim().slice(0, 300));
      const seed = Math.floor(Math.random() * 999999);
      const pollinationsUrl = `https://image.pollinations.ai/prompt/${cleanPrompt}?width=1024&height=1024&nologo=true&seed=${seed}`;

      logger.info(`[ImageEngine] Generando nuevo fondo con IA Pollinations: ${prompt}`);
      const bgResponse = await axios.get(pollinationsUrl, {
        responseType: "arraybuffer",
        timeout: 25000,
        headers: { "User-Agent": "Vork/2.5.0" }
      });
      bgPath = saveTempFile(Buffer.from(bgResponse.data), "jpg");
    } else if (safeMode === "custom_bg" && bgImageBase64) {
      bgPath = saveTempFile(bgImageBase64, "bg");
    }

    const extension = safeMode === "color" ? "jpg" : "png";
    const outputPath = path.join(IMAGE_CACHE_DIR, `${targetId}.${extension}`);

    const args = [
      "remove-bg",
      "--input", inputPath,
      "--output", outputPath,
      "--mode", safeMode
    ];

    if (safeMode === "color") {
      const safeColor = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/.test(color) ? color : "#FFFFFF";
      args.push("--color", safeColor);
    } else if ((safeMode === "custom_bg" || safeMode === "prompt") && bgPath) {
      args.push("--bg-image", bgPath);
    }

    let result = null;
    try {
      result = await runPythonStudio(args);
    } catch (pyErr) {
      logger.warn(`[ImageEngine] Procesador local Python no disponible (${pyErr.message}). Utilizando motor IA de silueta BRIA-RMBG-1.4...`);
      const { Client } = require("@gradio/client");
      const client = await Client.connect("briaai/BRIA-RMBG-1.4");
      const imgBuffer = fs.readFileSync(inputPath);
      const blob = new Blob([imgBuffer], { type: "image/png" });
      const hfRes = await client.predict("/run", { image: blob });

      if (!hfRes || !hfRes.data || !hfRes.data[1] || !hfRes.data[1].url) {
        throw new Error("No se pudo obtener la silueta transparente del modelo IA.");
      }

      const cutoutUrl = hfRes.data[1].url;
      const cutoutResp = await axios.get(cutoutUrl, { responseType: "arraybuffer", timeout: 30000 });
      const tempCutoutPath = path.join(IMAGE_CACHE_DIR, `${targetId}_cutout.png`);
      fs.writeFileSync(tempCutoutPath, Buffer.from(cutoutResp.data));

      const ffmpeg = require("@ffmpeg-installer/ffmpeg").path;
      const { execFileSync } = require("child_process");

      if (safeMode === "transparent") {
        fs.renameSync(tempCutoutPath, outputPath);
      } else if (safeMode === "color") {
        const safeColor = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/.test(color) ? color : "#FFFFFF";
        execFileSync(ffmpeg, [
          "-y",
          "-i", tempCutoutPath,
          "-filter_complex", `color=c=${safeColor}:s=16x16[c];[c][0:v]scale2ref=iw:ih[bg][fg];[bg][fg]overlay=format=auto[out]`,
          "-map", "[out]",
          "-vframes", "1",
          outputPath
        ]);
        try { fs.unlinkSync(tempCutoutPath); } catch (e) {}
      } else if ((safeMode === "custom_bg" || safeMode === "prompt") && bgPath) {
        execFileSync(ffmpeg, [
          "-y",
          "-i", tempCutoutPath,
          "-i", bgPath,
          "-filter_complex", "[1:v][0:v]scale2ref=iw:ih[bg][fg];[bg][fg]overlay=format=auto[out]",
          "-map", "[out]",
          "-vframes", "1",
          outputPath
        ]);
        try { fs.unlinkSync(tempCutoutPath); } catch (e) {}
      } else {
        fs.renameSync(tempCutoutPath, outputPath);
      }

      const stats = fs.statSync(outputPath);
      result = {
        size_bytes: stats.size,
        width: 1024,
        height: 1024
      };
    }

    const itemData = {
      id: targetId,
      filename: `fondo_ia_${safeMode}_${targetId.slice(3, 9)}.${extension}`,
      format: extension,
      filePath: outputPath,
      inputPath,
      bgPath,
      sizeBytes: result.size_bytes,
      width: result.width,
      height: result.height,
      mode: safeMode,
      prompt: safeMode === "prompt" ? prompt : null,
      createdAt: Date.now()
    };
    imageStore.set(targetId, itemData);

    return {
      status: "success",
      id: targetId,
      filename: itemData.filename,
      mode: safeMode,
      format: extension,
      width: result.width,
      height: result.height,
      sizeBytes: result.size_bytes,
      sizeFormatted: (result.size_bytes / 1024).toFixed(2) + " KB",
      prompt: itemData.prompt,
      streamUrl: `/api/image/stream?id=${targetId}`,
      downloadUrl: `/api/image/download?id=${targetId}`
    };
  } catch (error) {
    if (inputPath && fs.existsSync(inputPath)) {
      try { fs.unlinkSync(inputPath); } catch (e) {}
    }
    if (bgPath && fs.existsSync(bgPath)) {
      try { fs.unlinkSync(bgPath); } catch (e) {}
    }
    throw error;
  }
}

/**
 * Obtiene el registro de una imagen por su ID
 */
function getImageById(id) {
  if (!id) return null;
  return imageStore.get(id) || null;
}

module.exports = {
  IMAGE_CACHE_DIR,
  processImageConversion,
  processBackgroundOperation,
  getImageById
};
