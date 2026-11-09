/**
 * config/index.js
 * Exportación centralizada de configuraciones y middlewares de entorno.
 */
const env = require("./env.config");
const cors = require("./cors.config");
const jwt = require("./jwt.config");
const cache = require("./cache.config");
const security = require("./security.config");
const rateLimiter = require("./rateLimiter.config");
const compression = require("./compression.config");

module.exports = {
  ...env,
  env,
  cors,
  jwt,
  cache,
  security,
  rateLimiter,
  compression
};
