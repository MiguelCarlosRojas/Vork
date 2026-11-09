/**
 * pageRoutes.js
 * Rutas de vistas y navegación limpia para las páginas web del portal.
 * Organizado por Pilares (views/pillars), Portal (views/portal) y Legal (views/legal).
 * Incluye resolución segura con fallback para prevenir errores ENOENT.
 */
const express = require("express");
const path = require("path");
const fs = require("fs");
const router = express.Router();
const cliController = require("../controllers/cliController");

const publicDir = path.join(__dirname, "..", "public");

// Rutas de entrega de scripts de instalación de Vork CLI (Pilar 09) desde el Backend
router.get("/cli/install.ps1", cliController.getInstallPs1);
router.get("/cli/install.cmd", cliController.getInstallCmd);
router.get("/cli/vork.ps1", cliController.getVorkPs1);

// Retrocompatibilidad para scripts en /js/*.js que ahora residen en /js/core/
const coreScripts = ["vork.js", "spa-router.js", "cloud-translator.js"];
coreScripts.forEach((scriptName) => {
  router.get(`/js/${scriptName}`, (req, res, next) => {
    res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    const corePath = path.join(publicDir, "js", "core", scriptName);
    const rootPath = path.join(publicDir, "js", scriptName);
    if (fs.existsSync(corePath)) {
      return res.sendFile(corePath);
    }
    if (fs.existsSync(rootPath)) {
      return res.sendFile(rootPath);
    }
    next();
  });
});

// Retrocompatibilidad para /components/components.js y /js/components.js hacia /js/ui.js
router.get(["/components/components.js", "/js/components.js"], (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
  res.sendFile(path.join(publicDir, "js", "ui.js"));
});

// Retrocompatibilidad para hojas de estilo de pilares solicitadas en /css/*.css
const pillarCssFallbacks = ["translator.css", "converter.css", "draw.css", "pillars.css"];
pillarCssFallbacks.forEach((cssName) => {
  router.get(`/css/${cssName}`, (req, res) => {
    res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    res.sendFile(path.join(publicDir, "css", "pillars", cssName));
  });
});

// Retrocompatibilidad para imágenes solicitadas en la ruta raíz antigua /img/:file
router.get("/img/:file", (req, res, next) => {
  const fileName = req.params.file;
  const subdirs = ["brand", "heroes", "payments"];
  for (const sub of subdirs) {
    const candidate = path.join(publicDir, "img", sub, fileName);
    if (fs.existsSync(candidate)) {
      res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
      return res.sendFile(candidate);
    }
  }
  next();
});

// Mapeo modular de vistas organizadas por Pilares, Portal y Legal
const pageMap = [
  // --- PILARES DE VORK (views/pillars) ---
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

  // --- PORTAL E INFORMACIÓN (views/portal) ---
  { path: "/api-docs", file: "views/portal/api.html" },
  { path: "/donate", file: "views/portal/donate.html" },
  { path: "/docs", file: "views/portal/docs.html" },
  { path: "/learn", file: "views/portal/learn.html" },
  { path: "/support", file: "views/portal/support.html" },
  { path: "/help", file: "views/portal/help.html" },
  { path: "/status", file: "views/portal/status.html" },

  // --- LEGAL Y SEGURIDAD (views/legal) ---
  { path: "/privacy", file: "views/legal/privacy.html" },
  { path: "/security", file: "views/legal/security.html" },
  { path: "/terms", file: "views/legal/terms.html" }
];

pageMap.forEach(({ path: routePath, file }) => {
  const handler = (req, res, next) => {
    const targetFile = path.join(publicDir, file);
    if (fs.existsSync(targetFile)) {
      return res.sendFile(targetFile);
    }
    // Fallback automático si estuviese en la raíz de public
    const fallbackFile = path.join(publicDir, path.basename(file));
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
