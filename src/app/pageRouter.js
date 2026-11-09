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

// --- RUTAS Y VISTAS HTML DEL PORTAL ---
const pageMap = [
  // Pilares
  { path: "/translator", file: "views/pillars/translator.html" },
  { path: "/tts", file: "views/pillars/tts.html" },
  { path: "/converter", file: "views/pillars/converter.html" },
  { path: "/media", file: "views/pillars/converter.html" },
  { path: "/vocal-remover", file: "views/pillars/vocal-remover.html" },
  { path: "/separator", file: "views/pillars/vocal-remover.html" },
  { path: "/stems", file: "views/pillars/vocal-remover.html" },
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

router.get("/voice-clone", (req, res) => res.redirect(301, "/"));

module.exports = router;
