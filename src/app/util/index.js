/**
 * util/index.js
 * Exportación centralizada de helpers y utilidades compartidas.
 */
const jwtCookies = require("./jwtCookies");
const jwtUtils = require("./jwtUtils");
const subdomain = require("./subdomain");
const inMemory = require("./inMemory");
const validator = require("./validator");
const logger = require("./logger");

module.exports = {
  ...jwtCookies,
  ...jwtUtils,
  ...subdomain,
  ...inMemory,
  ...validator,
  logger
};
