/**
 * imageController.js
 * Controlador HTTP para Conversión de Imágenes y Estudio de Fondo IA (Pilares 07 y 08)
 * Blindado contra ataques SSRF, DoS, Path Traversal e Inyección de Cabeceras CRLF.
 */

const fs = require("fs");
const path = require("path");
const { imageService } = require("../services");
const { validateSafeUrl } = require("../utils/ssrfGuard");
const {
  sanitizeId,
  sanitizeFilenameHeader,
  isPathContained
} = require("../utils/securitySanitizer");
const logger = require("../utils/logger");

/**
 * Mapeo de extensiones a MIME Types
 */
const MIME_TYPES = {
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  webp: "image/webp",
  gif: "image/gif",
  bmp: "image/bmp",
  tiff: "image/tiff",
  ico: "image/x-icon"
};

/**
 * Lista de formatos soportados por el conversor
 */
exports.getFormats = (req, res) => {
  res.json({
    status: "success",
    service: "Vork Image Studio API",
    formats: [
      { ext: "png", name: "Portable Network Graphics", mime: "image/png", transparency: true },
      { ext: "jpg", name: "JPEG Image", mime: "image/jpeg", transparency: false },
      { ext: "webp", name: "WebP Modern Image", mime: "image/webp", transparency: true },
      { ext: "gif", name: "Graphics Interchange Format", mime: "image/gif", transparency: true },
      { ext: "bmp", name: "Bitmap Image", mime: "image/bmp", transparency: false },
      { ext: "tiff", name: "Tagged Image File Format", mime: "image/tiff", transparency: true },
      { ext: "ico", name: "Icon / Favicon", mime: "image/x-icon", transparency: true }
    ]
  });
};

/**
 * Pilar 07: Conversión de Formatos de Imagen (PNG, JPG, WEBP, GIF, BMP, TIFF, ICO)
 */
exports.convertImage = async (req, res) => {
  try {
    const { imageBase64: rawB64, image: legacyB64, url, targetFormat: rawFmt = "png", format: legacyFmt, quality = 90, width, height } = req.body || {};
    const imageBase64 = rawB64 || legacyB64;
    const targetFormat = rawFmt || legacyFmt || "png";

    if (!imageBase64 && !url) {
      return res.status(400).json({
        status: "error",
        error: "Debe proporcionar una imagen en base64 o una URL válida."
      });
    }

    if (url) {
      if (typeof url !== "string") {
        return res.status(400).json({ status: "error", error: "La URL debe ser una cadena válida." });
      }
      await validateSafeUrl(url);
    }

    if (imageBase64 && (typeof imageBase64 !== "string" || imageBase64.length > 50 * 1024 * 1024)) {
      return res.status(400).json({ status: "error", error: "La imagen base64 supera el límite permitido (50MB)." });
    }

    const result = await imageService.convert({
      imageBase64,
      url,
      targetFormat,
      quality,
      width,
      height
    });

    res.json(result);
  } catch (error) {
    logger.error(`Error en imageController.convertImage: ${error.message}`);
    res.status(400).json({
      status: "error",
      error: error.message || "Error al convertir la imagen."
    });
  }
};

/**
 * Pilar 08: Eliminador y Modificador de Fondo con IA
 */
exports.removeBackground = async (req, res) => {
  try {
    const { imageBase64: rawB64, image: legacyB64, url, mode = "transparent", color = "#FFFFFF", bgImageBase64, prompt, instruction } = req.body || {};
    const imageBase64 = rawB64 || legacyB64;

    if (!imageBase64 && !url) {
      return res.status(400).json({
        status: "error",
        error: "Debe proporcionar una imagen en base64 o una URL para procesar el fondo."
      });
    }

    if (url) {
      if (typeof url !== "string") {
        return res.status(400).json({ status: "error", error: "La URL debe ser una cadena válida." });
      }
      await validateSafeUrl(url);
    }

    if (imageBase64 && (typeof imageBase64 !== "string" || imageBase64.length > 50 * 1024 * 1024)) {
      return res.status(400).json({ status: "error", error: "La imagen supera el límite permitido (50MB)." });
    }

    const result = await imageService.processBackground({
      imageBase64,
      url,
      mode,
      color,
      bgImageBase64,
      instruction: instruction || prompt,
      prompt: prompt || instruction
    });

    res.json(result);
  } catch (error) {
    logger.error(`Error en imageController.removeBackground: ${error.message}`);
    res.status(400).json({
      status: "error",
      error: error.message || "Error al procesar el fondo con IA."
    });
  }
};

/**
 * Generador de Imágenes IA a partir de Prompt (FLUX.1 Neural - Sin Marca de Agua)
 */
exports.generateImage = async (req, res) => {
  try {
    const { prompt, width = 1024, height = 1024, seed } = req.body || {};

    if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
      return res.status(400).json({
        status: "error",
        error: "Debe proporcionar una descripción o prompt para generar la imagen."
      });
    }

    const result = await imageService.generate({
      prompt,
      width,
      height,
      seed
    });

    res.json(result);
  } catch (error) {
    logger.error(`Error en imageController.generateImage: ${error.message}`);
    res.status(500).json({
      status: "error",
      error: error.message || "Error al generar la imagen con IA."
    });
  }
};

/**
 * Streaming / Visualización directa de la imagen procesada
 */
exports.streamImage = (req, res) => {
  try {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador de imagen no válido.");
    }

    const item = imageService.findImageById(safeId);
    if (!item) {
      return res.status(404).send("Imagen no encontrada o expirada en el servidor.");
    }

    const filePath = item.filePath;
    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(404).send("Archivo físico no disponible.");
    }

    // 🛡️ Confinamiento de ruta (Path Traversal Guard)
    if (!isPathContained(filePath, imageService.getCacheDir())) {
      logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en streamImage: ${filePath}`);
      return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento seguro.");
    }

    const format = item.format || "png";
    const contentType = MIME_TYPES[format.toLowerCase()] || "application/octet-stream";

    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=3600");
    res.setHeader("Access-Control-Allow-Origin", "*");

    const stream = fs.createReadStream(filePath);
    return stream.pipe(res);
  } catch (error) {
    logger.error(`Error en imageController.streamImage: ${error.message}`);
    res.status(500).send("Error interno al transmitir la imagen.");
  }
};

/**
 * Descarga forzada con cabecera Content-Disposition (Botón Descargar)
 */
exports.downloadImage = (req, res) => {
  try {
    const safeId = sanitizeId(req.query.id);
    if (!safeId) {
      return res.status(400).send("Identificador de imagen inválido o no seguro.");
    }

    const item = imageService.findImageById(safeId);
    if (!item) {
      return res.status(404).send("Imagen no encontrada o expirada para descarga.");
    }

    const filePath = item.filePath;
    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(404).send("Archivo físico no disponible.");
    }

    // 🛡️ Confinamiento de ruta (Path Traversal Guard)
    if (!isPathContained(filePath, imageService.getCacheDir())) {
      logger.warn(`[Seguridad] Intento de Path Traversal bloqueado en downloadImage: ${filePath}`);
      return res.status(403).send("Acceso denegado a archivo fuera del almacenamiento permitido.");
    }

    const format = item.format || "png";
    const contentType = MIME_TYPES[format.toLowerCase()] || "application/octet-stream";
    const safeFilename = sanitizeFilenameHeader(item.filename, `imagen_vork.${format}`);

    const stat = fs.statSync(filePath);
    res.setHeader("Content-Disposition", `attachment; filename="${safeFilename}"`);
    res.setHeader("Content-Type", contentType);
    res.setHeader("Content-Length", stat.size);
    res.setHeader("Access-Control-Allow-Origin", "*");

    const stream = fs.createReadStream(filePath);
    return stream.pipe(res);
  } catch (error) {
    logger.error(`Error en imageController.downloadImage: ${error.message}`);
    res.status(500).send("Error al descargar la imagen.");
  }
};

/**
 * Catálogo de formatos de imagen y capacidades soportadas
 */
exports.getFormats = (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=86400");
  res.json({
    status: "success",
    formats: [
      { extension: "png", name: "PNG (Portable Network Graphics)", mime: "image/png", supportsTransparency: true },
      { extension: "jpg", name: "JPEG / JPG", mime: "image/jpeg", supportsTransparency: false, qualityConfigurable: true },
      { extension: "webp", name: "WebP (Google Modern Web Format)", mime: "image/webp", supportsTransparency: true, qualityConfigurable: true },
      { extension: "gif", name: "GIF (Graphics Interchange Format)", mime: "image/gif", supportsTransparency: true },
      { extension: "bmp", name: "Bitmap Image File", mime: "image/bmp", supportsTransparency: false },
      { extension: "tiff", name: "TIFF (Tagged Image File Format)", mime: "image/tiff", supportsTransparency: true },
      { extension: "ico", name: "Windows Icon (16x16 a 256x256)", mime: "image/x-icon", supportsTransparency: true }
    ],
    bgModes: [
      { mode: "transparent", description: "Recorte alfa con fondo transparente en formato PNG" },
      { mode: "color", description: "Reemplazo de fondo por color sólido HEX (ej: #FFFFFF, #00F0FF)" },
      { mode: "custom_bg", description: "Composición sobre imagen de fondo personalizada" },
      { mode: "prompt", description: "Generación de fondo creativo mediante IA generativa con descripción de texto" }
    ],
    maxUploadLimit: "50MB",
    resamplingEngine: "Pillow LANCZOS",
    aiSegmentation: "rembg U2-Net Deep Neural Salience"
  });
};
