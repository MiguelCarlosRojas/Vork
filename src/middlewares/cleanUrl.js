/**
 * cleanUrl.js
 * Middleware de URLs limpias: Redirige permanentemente (301) cualquier petición con extensión .html
 */
module.exports = (req, res, next) => {
  if (req.path.endsWith(".html") && !req.path.startsWith("/google")) {
    const rawPath = req.path.slice(0, -5);
    const cleanPath = (rawPath === "/index" || rawPath === "") ? "/" : rawPath;
    const queryString = req.url.includes("?") ? req.url.slice(req.url.indexOf("?")) : "";
    return res.redirect(301, cleanPath + queryString);
  }
  next();
};
