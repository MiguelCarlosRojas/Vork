/**
 * imageStudio.js
 * Motor de Procesamiento y Optimización de Imágenes + Eliminador de Fondos IA
 * Pilares 08 y 09 de Vork
 * Blindado contra SSRF, DoS, Path Traversal y Memory Leak.
 */

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const axios = require("axios");
const logger = require("../../../util/logger");
const { validateSafeUrl, sanitizeFilenameHeader, isPathContained } = require("../../../util/validator");

// Directorio de almacenamiento en caché para imágenes procesadas
const IMAGE_CACHE_DIR = path.resolve(process.cwd(), "data/image_cache");
try {
  if (!fs.existsSync(IMAGE_CACHE_DIR)) {
    fs.mkdirSync(IMAGE_CACHE_DIR, { recursive: true });
  }
} catch (err) {
  logger.error(`Error al crear directorio image_cache: ${err.message}`);
}

const AI_STUDIO_PY_PATH = path.join(__dirname, "ai_image_studio.py");

// Almacén en RAM para sesiones de imágenes (TTL: 30 minutos)
const imagesBufferStore = new Map();
const IMAGE_STORE_TTL_MS = 30 * 60 * 1000;

// Limpieza periódica de archivos temporales
const cleanupInterval = setInterval(() => {
  const now = Date.now();
  for (const [id, item] of imagesBufferStore.entries()) {
    if (now - item.createdAt > IMAGE_STORE_TTL_MS) {
      if (item.outputPath && fs.existsSync(item.outputPath)) {
        try { fs.unlinkSync(item.outputPath); } catch {}
      }
      if (item.inputPath && fs.existsSync(item.inputPath)) {
        try { fs.unlinkSync(item.inputPath); } catch {}
      }
      if (item.bgPath && fs.existsSync(item.bgPath)) {
        try { fs.unlinkSync(item.bgPath); } catch {}
      }
      imagesBufferStore.delete(id);
    }
  }
}, 10 * 60 * 1000);
if (cleanupInterval.unref) {
  cleanupInterval.unref();
}

/**
 * Generador de ID criptográficamente seguro
 */
function generateId(prefix = "img") {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
}

/**
 * Guarda un buffer o base64 en archivo temporal
 */
function saveBase64ToDisk(base64Data, filenamePrefix) {
  const cleanBase64 = base64Data.replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, "");
  const buffer = Buffer.from(cleanBase64, "base64");
  const tempPath = path.join(IMAGE_CACHE_DIR, `${filenamePrefix}_${Date.now()}.raw`);
  fs.writeFileSync(tempPath, buffer);
  return tempPath;
}

/**
 * Descarga una imagen remota de forma segura previniendo SSRF
 */
async function downloadRemoteImage(url, filenamePrefix) {
  await validateSafeUrl(url);

  const response = await axios({
    method: "GET",
    url,
    responseType: "arraybuffer",
    timeout: 15000,
    maxContentLength: 35 * 1024 * 1024, // Máximo 35 MB
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Vork/2.5.0 ImageStudio"
    }
  });

  const tempPath = path.join(IMAGE_CACHE_DIR, `${filenamePrefix}_${Date.now()}.raw`);
  fs.writeFileSync(tempPath, Buffer.from(response.data));
  return tempPath;
}

/**
 * Ejecuta el script de Python con argumentos CLI y procesa la salida JSON
 */
function runPythonStudio(args) {
  return new Promise((resolve, reject) => {
    const py = spawn("python", [AI_STUDIO_PY_PATH, ...args]);
    let stdout = "";
    let stderr = "";

    py.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });

    py.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });

    py.on("close", (code) => {
      if (code !== 0) {
        logger.error(`Error en ai_image_studio.py (código ${code}): ${stderr}`);
        return reject(new Error(stderr || `Error en el procesador de imágenes (código ${code})`));
      }
      try {
        const jsonRes = JSON.parse(stdout.trim());
        resolve(jsonRes);
      } catch (err) {
        logger.error(`Error parseando respuesta JSON de ai_image_studio.py: ${stdout}`);
        reject(new Error("Respuesta inválida del motor de procesamiento de imágenes."));
      }
    });

    py.on("error", (err) => {
      logger.error(`Fallo al iniciar ai_image_studio.py: ${err.message}`);
      reject(err);
    });
  });
}

/**
 * Determina el Content-Type según el formato de imagen
 */
function getMimeType(format) {
  const norm = (format || "").toLowerCase().replace(".", "");
  const mimeMap = {
    png: "image/png",
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    webp: "image/webp",
    gif: "image/gif",
    bmp: "image/bmp",
    tiff: "image/tiff",
    tif: "image/tiff",
    ico: "image/x-icon",
    svg: "image/svg+xml"
  };
  return mimeMap[norm] || "application/octet-stream";
}

/**
 * Pilar 08: Conversor Universal de Imágenes
 */
async function processImageConversion({
  url,
  imageBase64,
  targetFormat = "png",
  quality = 90,
  width,
  height
}) {
  if (!url && !imageBase64) {
    throw new Error("Debe proporcionar una imagen en base64 o una URL remota.");
  }

  const id = generateId("img_conv");
  let inputPath = null;

  try {
    if (imageBase64) {
      inputPath = saveBase64ToDisk(imageBase64, `${id}_in`);
    } else {
      inputPath = await downloadRemoteImage(url, `${id}_in`);
    }

    const normFormat = (targetFormat || "png").toLowerCase().replace(".", "").trim();
    const outputPath = path.join(IMAGE_CACHE_DIR, `${id}_out.${normFormat}`);

    const pyArgs = [
      "convert",
      "--input", inputPath,
      "--output", outputPath,
      "--format", normFormat,
      "--quality", String(Math.max(1, Math.min(100, Number(quality) || 90)))
    ];

    if (width && Number(width) > 0) {
      pyArgs.push("--width", String(parseInt(width, 10)));
    }
    if (height && Number(height) > 0) {
      pyArgs.push("--height", String(parseInt(height, 10)));
    }

    const pyResult = await runPythonStudio(pyArgs);

    const sessionItem = {
      id,
      type: "convert",
      format: normFormat,
      mimeType: getMimeType(normFormat),
      inputPath,
      outputPath,
      width: pyResult.width,
      height: pyResult.height,
      origWidth: pyResult.orig_width,
      origHeight: pyResult.orig_height,
      sizeBytes: pyResult.size_bytes,
      createdAt: Date.now()
    };

    imagesBufferStore.set(id, sessionItem);

    return {
      status: "success",
      id,
      format: normFormat,
      mimeType: sessionItem.mimeType,
      width: sessionItem.width,
      height: sessionItem.height,
      origWidth: sessionItem.origWidth,
      origHeight: sessionItem.origHeight,
      sizeBytes: sessionItem.sizeBytes,
      streamUrl: `/api/image/stream?id=${id}`,
      downloadUrl: `/api/image/download?id=${id}`
    };
  } catch (error) {
    if (inputPath && fs.existsSync(inputPath)) {
      try { fs.unlinkSync(inputPath); } catch {}
    }
    throw error;
  }
}

/**
 * Pilar 09: Eliminación y Modificación de Fondo con IA (rembg U2-Net)
 */
async function processBackgroundRemoval({
  url,
  imageBase64,
  mode = "transparent",
  color = "#FFFFFF",
  bgUrl,
  bgBase64
}) {
  if (!url && !imageBase64) {
    throw new Error("Debe proporcionar una imagen de entrada.");
  }

  const id = generateId("img_bg");
  let inputPath = null;
  let bgPath = null;

  try {
    if (imageBase64) {
      inputPath = saveBase64ToDisk(imageBase64, `${id}_in`);
    } else {
      inputPath = await downloadRemoteImage(url, `${id}_in`);
    }

    const normMode = ["transparent", "color", "custom_bg", "prompt"].includes(mode) ? mode : "transparent";
    const outExt = normMode === "color" ? "jpg" : "png";
    const outputPath = path.join(IMAGE_CACHE_DIR, `${id}_out.${outExt}`);

    const pyArgs = [
      "remove-bg",
      "--input", inputPath,
      "--output", outputPath,
      "--mode", normMode
    ];

    if (normMode === "color") {
      pyArgs.push("--color", color || "#FFFFFF");
    } else if (normMode === "custom_bg" || normMode === "prompt") {
      if (bgBase64) {
        bgPath = saveBase64ToDisk(bgBase64, `${id}_bg`);
      } else if (bgUrl) {
        bgPath = await downloadRemoteImage(bgUrl, `${id}_bg`);
      }
      if (!bgPath) {
        throw new Error("El modo 'custom_bg' requiere una imagen de fondo (bgBase64 o bgUrl).");
      }
      pyArgs.push("--bg-image", bgPath);
    }

    const pyResult = await runPythonStudio(pyArgs);

    const sessionItem = {
      id,
      type: "remove-bg",
      mode: normMode,
      format: pyResult.format || outExt,
      mimeType: getMimeType(pyResult.format || outExt),
      inputPath,
      outputPath,
      bgPath,
      width: pyResult.width,
      height: pyResult.height,
      sizeBytes: pyResult.size_bytes,
      createdAt: Date.now()
    };

    imagesBufferStore.set(id, sessionItem);

    return {
      status: "success",
      id,
      mode: normMode,
      format: sessionItem.format,
      mimeType: sessionItem.mimeType,
      width: sessionItem.width,
      height: sessionItem.height,
      sizeBytes: sessionItem.sizeBytes,
      streamUrl: `/api/image/stream?id=${id}`,
      downloadUrl: `/api/image/download?id=${id}`
    };
  } catch (error) {
    if (inputPath && fs.existsSync(inputPath)) {
      try { fs.unlinkSync(inputPath); } catch {}
    }
    if (bgPath && fs.existsSync(bgPath)) {
      try { fs.unlinkSync(bgPath); } catch {}
    }
    throw error;
  }
}

/**
 * Obtiene el registro de imagen procesada en RAM
 */
function getImageById(id) {
  return imagesBufferStore.get(id);
}

/**
 * Catálogo de formatos y capacidades soportadas
 */
function getSupportedFormats() {
  return {
    formats: [
      { extension: "png", name: "PNG (Portable Network Graphics)", mime: "image/png", supportsTransparency: true },
      { extension: "jpg", name: "JPEG / JPG", mime: "image/jpeg", supportsTransparency: false, qualityConfigurable: true },
      { extension: "webp", name: "WebP (Google Modern Web Format)", mime: "image/webp", supportsTransparency: true, qualityConfigurable: true },
      { extension: "gif", name: "GIF (Graphics Interchange Format)", mime: "image/gif", supportsTransparency: true },
      { extension: "bmp", name: "Bitmap Image File", mime: "image/bmp", supportsTransparency: false },
      { extension: "tiff", name: "TIFF (Tagged Image File Format)", mime: "image/tiff", supportsTransparency: true },
      { extension: "ico", name: "Windows Icon (16x16 a 256x256)", mime: "image/x-icon", supportsTransparency: true }
    ],
    bgRemoverModes: [
      { mode: "transparent", description: "Recorte alfa con fondo 100% transparente en formato PNG sin compresión" },
      { mode: "color", description: "Reemplazo de fondo por cualquier color sólido HEX (ej. #FFFFFF, #00F0FF)" },
      { mode: "custom_bg", description: "Composición del sujeto recortado sobre una imagen de fondo personalizada" }
    ],
    engine: "Pillow LANCZOS Resampling + rembg U2-Net Deep Neural Salience",
    maxUploadSizeBytes: 30 * 1024 * 1024,
    sessionTTLSeconds: 1800
  };
}

module.exports = {
  IMAGE_CACHE_DIR,
  processImageConversion,
  processBackgroundRemoval,
  getImageById,
  getSupportedFormats,
  getMimeType
};
