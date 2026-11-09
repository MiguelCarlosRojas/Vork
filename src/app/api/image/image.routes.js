/**
 * image.routes.js
 * Rutas para Pilares 07 y 08: Conversor de Imágenes, Background Remover y AI Image Generator
 */
const express = require("express");
const router = express.Router();
const imageController = require("./controller/image.controller");
const rateLimiter = require("../../config/rateLimiter.config");
const env = require("../../config/env.config");

const heavyImageParser = express.json({ limit: env.HEAVY_BODY_LIMIT });

router.get(["/formats", "/image/formats"], (req, res) => imageController.getFormats(req, res));
router.post(["/convert", "/image/convert"], heavyImageParser, rateLimiter.imageLimiter, (req, res) => imageController.convertImage(req, res));
router.post(["/remove-bg", "/remove-background", "/image/remove-bg", "/image/remove-background"], heavyImageParser, rateLimiter.imageLimiter, (req, res) => imageController.removeBackground(req, res));
router.post(["/generate", "/generate-image", "/image/generate", "/image/generate-image"], heavyImageParser, rateLimiter.imageLimiter, (req, res) => imageController.generateImage(req, res));
router.get(["/stream", "/image/stream"], (req, res) => imageController.streamImage(req, res));
router.get(["/download", "/image/download"], (req, res) => imageController.downloadImage(req, res));

module.exports = router;
