/**
 * pageRoutes.js
 * Rutas de vistas y navegación limpia para las páginas web del portal.
 */
const express = require("express");
const path = require("path");
const router = express.Router();
const cliController = require("../controllers/cliController");

const publicDir = path.join(__dirname, "..", "public");

// Rutas de entrega de scripts de instalación de Vork CLI (Pilar 09) desde el Backend
router.get("/cli/install.ps1", cliController.getInstallPs1);
router.get("/cli/install.cmd", cliController.getInstallCmd);
router.get("/cli/vork.ps1", cliController.getVorkPs1);

const pageMap = [
  { path: "/translator", file: "translator.html" },
  { path: "/tts", file: "tts.html" },
  { path: "/converter", file: "converter.html" },
  { path: "/media", file: "converter.html" },
  { path: "/vocal-remover", file: "vocal-remover.html" },
  { path: "/separator", file: "vocal-remover.html" },
  { path: "/stems", file: "vocal-remover.html" },
  { path: "/dj", file: "dj.html" },
  { path: "/cloud-dj", file: "dj.html" },
  { path: "/cli", file: "cli.html" },
  { path: "/terminal", file: "cli.html" },
  { path: "/image-converter", file: "image-converter.html" },
  { path: "/img-converter", file: "image-converter.html" },
  { path: "/background-remover", file: "background-remover.html" },
  { path: "/bg-remover", file: "background-remover.html" },
  { path: "/ai-background", file: "background-remover.html" },
  { path: "/desktop", file: "desktop.html" },
  { path: "/vork-desktop", file: "desktop.html" },
  { path: "/draw", file: "draw.html" },
  { path: "/image-generator", file: "draw.html" },
  { path: "/flux", file: "draw.html" },
  { path: "/donate", file: "donate.html" },
  { path: "/docs", file: "docs.html" },
  { path: "/learn", file: "learn.html" },
  { path: "/support", file: "support.html" },
  { path: "/help", file: "help.html" },
  { path: "/status", file: "status.html" },
  { path: "/privacy", file: "privacy.html" },
  { path: "/security", file: "security.html" },
  { path: "/terms", file: "terms.html" }
];

pageMap.forEach(({ path: routePath, file }) => {
  router.get(routePath, (req, res) => {
    res.sendFile(path.join(publicDir, file));
  });
});

router.get("/voice-clone", (req, res) => res.redirect(301, "/"));

module.exports = router;
