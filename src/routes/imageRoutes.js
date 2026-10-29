/**
 * imageRoutes.js
 * Rutas de la API REST para los Pilares 08 y 09:
 * - Pilar 08: Conversor y Procesador de Imágenes (PNG, JPG, WEBP, GIF, BMP, TIFF, ICO)
 * - Pilar 09: Estudio y Eliminador de Fondo con IA (rembg U2-Net, Transparencia & Composición)
 */

const express = require("express");
const router = express.Router();
const { imageController } = require("../controllers");
const { imageLimiter } = require("../middlewares/rateLimiter");

// Parser para cargas útiles de imágenes en alta resolución (50MB límite)
const heavyImageParser = express.json({ limit: "50mb" });

// Catálogo de formatos soportados
router.get("/formats", imageController.getFormats);

// Pilar 08: Conversión de Formatos de Imagen
router.post("/convert", heavyImageParser, imageLimiter, imageController.convertImage);

// Pilar 09: Eliminador y Modificador de Fondo con IA (soporta ambas rutas /remove-bg y /remove-background)
router.post("/remove-bg", heavyImageParser, imageLimiter, imageController.removeBackground);
router.post("/remove-background", heavyImageParser, imageLimiter, imageController.removeBackground);

// NUEVO PILAR: Generador de Imágenes IA con FLUX.1 (100% Gratuito, Sin Marca de Agua)
router.post("/generate", heavyImageParser, imageLimiter, imageController.generateImage);
router.post("/generate-image", heavyImageParser, imageLimiter, imageController.generateImage);

// Endpoints comunes de entrega multimedia
router.get("/stream", imageController.streamImage);
router.get("/download", imageController.downloadImage);

module.exports = router;
