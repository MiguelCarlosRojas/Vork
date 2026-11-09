/**
 * cors.config.js
 * Configuración CORS de seguridad para la API obtenida desde las variables de entorno.
 */
const cors = require("cors");
const env = require("./env.config");

const allowedOrigins = (!env.CORS_ORIGIN || env.CORS_ORIGIN === "*")
  ? "*"
  : env.CORS_ORIGIN.split(",").map(o => o.trim());

module.exports = cors({
  origin: allowedOrigins,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
  allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With", "Accept"],
  credentials: true,
  optionsSuccessStatus: 204
});
