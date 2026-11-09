/**
 * app.js
 * Configuración central de Express, middlewares y montaje de rutas modulares.
 */
const express = require("express");
const path = require("path");
const hpp = require("hpp");
const cors = require("./config/cors.config");
const { securityHeaders } = require("./config/security.config");
const compressionMiddleware = require("./config/compression.config");
const rateLimiter = require("./config/rateLimiter.config");
const env = require("./config/env.config");
const logger = require("./util/logger");
const apiRoutes = require("./api");
const pageRoutes = require("./pageRouter");

const app = express();

// 1. Ocultar huellas de tecnología (Previene reconocimiento por atacantes)
app.disable("x-powered-by");

// 2. Cabeceras de Seguridad Avanzadas con Helmet (OWASP Hardening)
app.use(securityHeaders);

// 3. Protección contra HTTP Parameter Pollution (HPP)
app.use(hpp());

// 4. Compresión optimizada (Gzip/Deflate)
app.use(compressionMiddleware);

// 5. Limitador global de peticiones (Protección DoS / Abuso)
app.use(rateLimiter.globalLimiter);

// 6. Parsers JSON y URL-encoded (Límite dinámico desde .env.production)
app.use(express.json({ limit: env.BODY_LIMIT }));
app.use(express.urlencoded({ limit: env.BODY_LIMIT, extended: true }));

// 7. CORS
app.use(cors);
app.options("*", cors);

// 8. Redirección de URLs con extensión .html a formato limpio
app.use((req, res, next) => {
  if (req.path.endsWith(".html") && !req.path.startsWith("/google")) {
    const rawPath = req.path.slice(0, -5);
    const cleanPath = (rawPath === "/index" || rawPath === "") ? "/" : rawPath;
    const queryString = req.url.includes("?") ? req.url.slice(req.url.indexOf("?")) : "";
    return res.redirect(301, cleanPath + queryString);
  }
  next();
});

// 9. Rutas de la API REST (/api/*)
app.use("/api", apiRoutes);

// 10. Rutas limpias directas para las páginas del portal y base endpoints
app.use("/", pageRoutes);

// 11. Archivos estáticos optimizados con caché HTTP, ETag y stale-while-revalidate
app.use(express.static(path.join(__dirname, "..", "web"), {
  extensions: ["html"],
  index: false,
  maxAge: "1d",
  etag: true,
  lastModified: true,
  setHeaders: (res, filePath) => {
    if (filePath.match(/\.(css|js|png|jpg|jpeg|svg|ico|woff2|woff)$/i)) {
      res.setHeader("Cache-Control", "public, max-age=86400, stale-while-revalidate=604800");
    }
  }
}));

// 12. Manejador global de errores
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || err.status || 500;
  const isProd = process.env.NODE_ENV === "production";
  logger.error(`[${req.method} ${req.originalUrl}] Error ${statusCode}: ${err.message}${err.stack ? `\n${err.stack}` : ""}`);
  let message = err.message || "Internal Server Error";
  if (statusCode >= 500 && isProd) {
    message = "Ha ocurrido un error interno en el servidor. Por favor inténtelo más tarde.";
  }
  if (res.headersSent) {
    return next(err);
  }
  res.status(statusCode).json({
    status: "error",
    success: false,
    statusCode,
    error: message
  });
});

module.exports = app;
