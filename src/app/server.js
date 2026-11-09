/**
 * server.js
 * Punto de entrada del servidor Vork con protección anti-crash y graceful shutdown.
 * Los timeouts y puertos se configuran dinámicamente mediante variables de entorno (.env).
 */
const app = require("./app");
const { PORT, SERVER_TIMEOUTS } = require("./config/env.config");
const logger = require("./util/logger");

// Inicio del servidor con timeouts configurados desde .env.production (evita caídas 502)
const server = app.listen(PORT, () => {
  logger.info(`Servidor Vork escuchando en puerto ${PORT}`);
});

server.keepAliveTimeout = SERVER_TIMEOUTS.KEEP_ALIVE;
server.headersTimeout = SERVER_TIMEOUTS.HEADERS;

// Cierre Seguro y Captura de Errores Globales (Graceful Shutdown & Anti-Crash)
function handleGracefulShutdown(signal) {
  logger.info(`Recibida señal ${signal}. Cerrando servidor HTTP de forma ordenada...`);
  server.close(() => {
    logger.info("Servidor HTTP cerrado exitosamente.");
    process.exit(0);
  });

  setTimeout(() => {
    logger.error("Tiempo de espera agotado para el cierre graceful. Forzando terminación.");
    process.exit(1);
  }, SERVER_TIMEOUTS.GRACEFUL).unref();
}

process.on("SIGTERM", () => handleGracefulShutdown("SIGTERM"));
process.on("SIGINT", () => handleGracefulShutdown("SIGINT"));

process.on("uncaughtException", (err) => {
  logger.error(`Excepción no capturada (uncaughtException): ${err.message}\n${err.stack}`);
});

process.on("unhandledRejection", (reason, promise) => {
  logger.error(`Promesa rechazada no manejada (unhandledRejection) en ${promise}: ${reason}`);
});

module.exports = { app, server };
