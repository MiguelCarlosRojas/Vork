/**
 * subdomain.js
 * Extracción, validación y enrutamiento dinámico basado en subdominios (ej. api.vork.com, app.vork.com).
 */

/**
 * Extrae el subdominio de una petición HTTP
 * @param {import("express").Request} req
 * @returns {string|null} Nombre del subdominio o null si es dominio principal / localhost
 */
function getSubdomain(req) {
  const host = req.headers.host || "";
  const hostname = host.split(":")[0];

  // Si es IP directa o localhost puro
  if (/^(\d{1,3}\.){3}\d{1,3}$/.test(hostname) || hostname === "localhost") {
    return null;
  }

  const parts = hostname.split(".");
  // Ej: api.vork.com -> parts = ['api', 'vork', 'com'] -> subdominio = 'api'
  if (parts.length > 2) {
    return parts[0].toLowerCase();
  }

  return null;
}

/**
 * Middleware para exigir o filtrar peticiones por un subdominio específico
 * @param {string|string[]} allowedSubdomains
 */
function requireSubdomain(allowedSubdomains) {
  const allowed = Array.isArray(allowedSubdomains) ? allowedSubdomains : [allowedSubdomains];

  return (req, res, next) => {
    const sub = getSubdomain(req);
    if (!sub || !allowed.includes(sub)) {
      return res.status(404).json({
        success: false,
        error: "Subdominio no autorizado o no encontrado"
      });
    }
    req.subdomain = sub;
    next();
  };
}

module.exports = {
  getSubdomain,
  requireSubdomain
};
