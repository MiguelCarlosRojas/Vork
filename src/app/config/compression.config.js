/**
 * compressionMiddleware.js
 * Compresión de respuestas HTTP (Gzip/Deflate) optimizada para conexiones lentas y bajo ancho de banda.
 */
const compression = require("compression");

module.exports = compression({
  threshold: 256, // Comprimir respuestas mayores a 256 bytes
  filter: (req, res) => {
    if (req.headers["x-no-compression"]) return false;
    return compression.filter(req, res);
  }
});
