/**
 * src/server.js
 * Puente de compatibilidad retroactiva para Render y entornos de despliegue.
 * Redirige la ejecución al nuevo entrypoint en src/app/server.js.
 */
module.exports = require("./app/server");
