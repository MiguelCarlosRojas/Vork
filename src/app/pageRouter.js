/**
 * pageRouter.js
 * Enrutador de páginas web del portal, overview, salud y scripts de instalación.
 */
const express = require("express");
const path = require("path");
const fs = require("fs");
const router = express.Router();

const webDir = path.join(__dirname, "..", "web");
const cliDir = path.join(__dirname, "..", "cli");
const { PILLARS, API_ENDPOINTS } = require("./pillars");
const translationService = require("./api/translate/service/translate.service");

// --- ENDPOINTS BASE DE SISTEMA ---
router.get("/api/ping", (req, res) => {
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.status(200).send("pong");
});

router.get("/api/health", (req, res) => {
  const mem = process.memoryUsage();
  res.setHeader("Cache-Control", "no-cache");
  res.status(200).json({
    success: true,
    status: "ok",
    uptime: Math.floor(process.uptime()),
    pillars: PILLARS.length,
    platform: "Vork",
    version: "1.0.0",
    cache: translationService.getCacheStats(),
    memory: {
      rssMb: Math.round(mem.rss / 1024 / 1024),
      heapUsedMb: Math.round(mem.heapUsed / 1024 / 1024)
    },
    timestamp: new Date().toISOString()
  });
});

router.get("/api/languages", (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=86400");
  const langKeys = Object.keys(translationService.supportedLanguages).filter(k => k !== "auto");
  res.status(200).json({
    success: true,
    total: langKeys.length,
    languages: langKeys,
    dictionary: translationService.supportedLanguages
  });
});

router.get("/", (req, res) => {
  if (req.accepts("html")) {
    return res.sendFile(path.join(webDir, "index.html"));
  }
  res.json({
    platform: "Vork",
    service: "Vork API REST Multimodal",
    status: "online",
    version: "1.0.0",
    pillars: PILLARS,
    endpoints: API_ENDPOINTS
  });
});

router.get("/api", (req, res) => {
  if (req.accepts("html")) {
    const apiPath = path.join(webDir, "views", "portal", "api.html");
    const fallbackPath = path.join(webDir, "api.html");
    return res.sendFile(fs.existsSync(apiPath) ? apiPath : fallbackPath);
  }
  res.json({
    platform: "Vork",
    service: "Vork API REST",
    status: "online",
    version: "1.0.0",
    pillars: PILLARS,
    endpoints: API_ENDPOINTS
  });
});

// --- ENTREGA DE SCRIPTS DE INSTALACIÓN CLI ---
router.get("/cli/install.ps1", (req, res) => {
  const file = path.join(cliDir, "install.ps1");
  if (fs.existsSync(file)) {
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    return res.sendFile(file);
  }
  res.status(404).send("# Error: install.ps1 no encontrado");
});

router.get("/cli/install.cmd", (req, res) => {
  const file = path.join(cliDir, "install.cmd");
  if (fs.existsSync(file)) {
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    return res.sendFile(file);
  }
  res.status(404).send("@echo off\r\necho Error: install.cmd no encontrado\r\n");
});

router.get("/cli/install.sh", (req, res) => {
  const file = path.join(cliDir, "install.sh");
  if (fs.existsSync(file)) {
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    return res.sendFile(file);
  }
  res.status(404).send("# Error: install.sh no encontrado\n");
});

// --- REDIRECCIONES CANÓNICAS DIRECTAS ---
// Redirigir /converter y /media directamente a /converter/mp3
router.get(["/converter", "/media"], (req, res) => {
  return res.redirect(302, "/converter/mp3");
});

// Redirigir /vocal-remover, /separator y /stems directamente a /vocal-remover/url
router.get(["/vocal-remover", "/separator", "/stems"], (req, res) => {
  return res.redirect(302, "/vocal-remover/url");
});

function serveConverterHtml(req, res, format = "mp3") {
  const filePath = path.join(webDir, "views/pillars/converter.html");
  if (!fs.existsSync(filePath)) return res.status(404).send("Not found");
  let html = fs.readFileSync(filePath, "utf8");
  if (format === "mp4") {
    html = html
      .replace(
        'id="btn-format-mp3" type="button" class="btn-icon-tooltip btn-format-tab active"',
        'id="btn-format-mp3" type="button" class="btn-icon-tooltip btn-format-tab"'
      )
      .replace(
        'id="btn-format-mp4" type="button" class="btn-icon-tooltip btn-format-tab"',
        'id="btn-format-mp4" type="button" class="btn-icon-tooltip btn-format-tab active"'
      )
      .replace(
        '<span id="format-badge" style="color: var(--primary); font-family: var(--f-mono); font-size: 0.75rem; font-weight: 700; text-transform: uppercase;">AUDIO MP3</span>',
        '<span id="format-badge" style="color: var(--primary); font-family: var(--f-mono); font-size: 0.75rem; font-weight: 700; text-transform: uppercase;">VIDEO MP4</span>'
      );
  }
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.send(html);
}

function serveVocalRemoverHtml(req, res, mode = "url") {
  const filePath = path.join(webDir, "views/pillars/vocal-remover.html");
  if (!fs.existsSync(filePath)) return res.status(404).send("Not found");
  let html = fs.readFileSync(filePath, "utf8");
  if (mode === "file") {
    html = html
      .replace(
        'id="tab-mode-url" type="button" class="btn-icon-tooltip btn-format-tab active"',
        'id="tab-mode-url" type="button" class="btn-icon-tooltip btn-format-tab"'
      )
      .replace(
        'id="tab-mode-file" type="button" class="btn-icon-tooltip btn-format-tab"',
        'id="tab-mode-file" type="button" class="btn-icon-tooltip btn-format-tab active"'
      )
      .replace(
        '<span id="stem-mode-badge" style="color: var(--primary); font-family: var(--f-mono); font-size: 0.75rem; font-weight: 700; text-transform: uppercase;">ENLACE MULTIMEDIA</span>',
        '<span id="stem-mode-badge" style="color: var(--primary); font-family: var(--f-mono); font-size: 0.75rem; font-weight: 700; text-transform: uppercase;">SUBIDA DE ARCHIVO</span>'
      )
      .replace(
        'id="platforms-chips-row" class="platform-chips-container"',
        'id="platforms-chips-row" class="platform-chips-container" style="display: none;"'
      )
      .replace(
        'id="formats-chips-row" class="platform-chips-container" style="display: none;"',
        'id="formats-chips-row" class="platform-chips-container"'
      )
      .replace(
        '<div id="panel-url" style="margin-bottom: 24px;">',
        '<div id="panel-url" style="display: none; margin-bottom: 24px;">'
      )
      .replace(
        '<div id="panel-file" style="display: none; margin-bottom: 24px;">',
        '<div id="panel-file" style="margin-bottom: 24px;">'
      );
  }
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.send(html);
}

// Rutas de converter con SSR de pestañas activas
router.get(["/converter/mp3", "/media/mp3"], (req, res) => serveConverterHtml(req, res, "mp3"));
router.get(["/converter/mp4", "/media/mp4"], (req, res) => serveConverterHtml(req, res, "mp4"));

// Rutas de vocal-remover con SSR de pestañas activas
router.get(["/vocal-remover/url", "/separator/url", "/stems/url", "/vocal-remover/link", "/vocal-remover/enlace"], (req, res) => serveVocalRemoverHtml(req, res, "url"));
router.get(["/vocal-remover/file", "/separator/file", "/stems/file", "/vocal-remover/upload", "/vocal-remover/archivo"], (req, res) => serveVocalRemoverHtml(req, res, "file"));

// --- RUTAS Y VISTAS HTML DEL PORTAL ---
const pageMap = [
  // Pilares
  { path: "/translator", file: "views/pillars/translator.html" },
  { path: "/tts", file: "views/pillars/tts.html" },
  { path: "/cli", file: "views/pillars/cli.html" },
  { path: "/terminal", file: "views/pillars/cli.html" },
  { path: "/image-converter", file: "views/pillars/image-converter.html" },
  { path: "/img-converter", file: "views/pillars/image-converter.html" },
  { path: "/background-remover", file: "views/pillars/background-remover.html" },
  { path: "/bg-remover", file: "views/pillars/background-remover.html" },
  { path: "/ai-background", file: "views/pillars/background-remover.html" },
  { path: "/desktop", file: "views/pillars/desktop.html" },
  { path: "/vork-desktop", file: "views/pillars/desktop.html" },
  { path: "/draw", file: "views/pillars/draw.html" },
  { path: "/image-generator", file: "views/pillars/draw.html" },
  { path: "/flux", file: "views/pillars/draw.html" },

  // Portal
  { path: "/api-docs", file: "views/portal/api.html" },
  { path: "/donate", file: "views/portal/donate.html" },
  { path: "/docs", file: "views/portal/docs.html" },
  { path: "/learn", file: "views/portal/learn.html" },
  { path: "/support", file: "views/portal/support.html" },
  { path: "/help", file: "views/portal/help.html" },
  { path: "/status", file: "views/portal/status.html" },

  // Legal
  { path: "/privacy", file: "views/legal/privacy.html" },
  { path: "/security", file: "views/legal/security.html" },
  { path: "/terms", file: "views/legal/terms.html" }
];

pageMap.forEach(({ path: routePath, file }) => {
  const handler = (req, res, next) => {
    const targetFile = path.join(webDir, file);
    if (fs.existsSync(targetFile)) {
      return res.sendFile(targetFile);
    }
    const fallbackFile = path.join(webDir, path.basename(file));
    if (fs.existsSync(fallbackFile)) {
      return res.sendFile(fallbackFile);
    }
    next();
  };

  router.get(routePath, handler);
  router.get(`${routePath}.html`, handler);
});

// Soporte de sub-rutas dinámicas para formato en conversor y modo de entrada en vocal-remover
router.get(["/converter/:format", "/media/:format"], (req, res) => {
  const fmt = (req.params.format || "").toLowerCase();
  return serveConverterHtml(req, res, fmt === "mp4" ? "mp4" : "mp3");
});

router.get(["/vocal-remover/:mode", "/separator/:mode", "/stems/:mode"], (req, res) => {
  const m = (req.params.mode || "").toLowerCase();
  const isFile = ["file", "upload", "archivo"].includes(m);
  return serveVocalRemoverHtml(req, res, isFile ? "file" : "url");
});

router.get("/voice-clone", (req, res) => res.redirect(301, "/"));

module.exports = router;
