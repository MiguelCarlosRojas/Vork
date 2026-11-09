/**
 * baseController.js
 * Endpoints base de salud, ping, idiomas y documentación interactiva.
 */
const path = require("path");
const fs = require("fs");
const { STATUS_CODES, POPULAR_LANGUAGES } = require("../config/config");
const { PILLARS, API_ENDPOINTS } = require("../constants/pillars");
const { translationService } = require("../services");

/**
 * Ping ultrarrápido (0ms) para keep-alive en Render Free Tier
 */
exports.getPing = (req, res) => {
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.status(STATUS_CODES.OK).send("pong");
};

/**
 * Estado de salud del servicio con telemetría de memoria y caché
 */
exports.getHealth = (req, res) => {
  const mem = process.memoryUsage();
  const cacheStats = translationService.getCacheStats();

  res.setHeader("Cache-Control", "no-cache");
  res.status(STATUS_CODES.OK).json({
    success: true,
    status: "ok",
    uptime: Math.floor(process.uptime()),
    pillars: PILLARS.length,
    platform: "Vork",
    version: "3.0.0",
    services: {
      translator: { name: "Vork Traductor en la Nube", status: "online" },
      tts: { name: "Vork Voz Neuronal", status: "online" },
      mediaConverter: { name: "Vork Conversor Multimedia", status: "online" },
      separator: { name: "Vork Separador de Stems", status: "online" },
      imageConverter: { name: "Vork Procesador de Imágenes", status: "online" },
      backgroundStudio: { name: "Vork Fondo IA Studio", status: "online" },
      flux: { name: "Vork Generador de Imágenes IA", status: "online" },
      cli: { name: "Vork CLI (Terminal & Agentes)", status: "online" }
    },
    cache: cacheStats,
    memory: {
      rssMb: Math.round(mem.rss / 1024 / 1024),
      heapUsedMb: Math.round(mem.heapUsed / 1024 / 1024)
    },
    timestamp: new Date().toISOString()
  });
};

/**
 * Lista oficial y completa de más de 200 idiomas soportados
 */
exports.getLanguages = (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=86400, s-maxage=86400");
  const langKeys = Object.keys(translationService.supportedLanguages).filter((k) => k !== "auto");
  res.status(STATUS_CODES.OK).json({
    success: true,
    total: langKeys.length,
    popular: POPULAR_LANGUAGES,
    languages: langKeys,
    dictionary: translationService.supportedLanguages
  });
};

/**
 * Endpoint raíz: Landing page para navegadores web o JSON descriptivo para API
 */
exports.getRootOverview = (req, res) => {
  if (req.accepts("html")) {
    return res.sendFile(path.join(__dirname, "..", "public", "index.html"));
  }
  res.json({
    platform: "Vork",
    service: "Vork API REST Multimodal",
    status: "online",
    version: "3.0.0",
    pillars: PILLARS,
    documentation: "https://vork-st1k.onrender.com/docs",
    endpoints: API_ENDPOINTS
  });
};

/**
 * Endpoint /api: Documentación interactiva para navegadores o JSON informativo para peticiones API directas
 */
exports.getApiOverview = (req, res) => {
  if (req.accepts("html")) {
    const apiPath = path.join(__dirname, "..", "public", "views", "portal", "api.html");
    const fallbackPath = path.join(__dirname, "..", "public", "api.html");
    return res.sendFile(fs.existsSync(apiPath) ? apiPath : fallbackPath);
  }
  res.json({
    platform: "Vork",
    service: "Vork API REST",
    status: "online",
    version: "3.0.0",
    pillars: PILLARS,
    documentation: "https://vork-st1k.onrender.com/api",
    endpoints: API_ENDPOINTS
  });
};
