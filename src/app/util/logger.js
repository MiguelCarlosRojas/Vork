/**
 * logger.js
 * Winston logger centralizado para Vork.
 * Nivel y directorio configurables dinámicamente mediante .env.production.
 */
const fs = require("fs");
const path = require("path");
const winston = require("winston");
const { LOG_LEVEL, LOGS_DIR } = require("../config/env.config");

const logsDir = path.resolve(process.cwd(), LOGS_DIR || "logs");
if (!fs.existsSync(logsDir)) {
  try {
    fs.mkdirSync(logsDir, { recursive: true });
  } catch (e) {}
}

const logger = winston.createLogger({
  level: LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    new winston.transports.File({
      filename: path.join(logsDir, "error.log"),
      level: "error",
      maxsize: 5 * 1024 * 1024,
      maxFiles: 5
    }),
    new winston.transports.File({
      filename: path.join(logsDir, "combined.log"),
      maxsize: 10 * 1024 * 1024,
      maxFiles: 5
    })
  ]
});

module.exports = logger;
