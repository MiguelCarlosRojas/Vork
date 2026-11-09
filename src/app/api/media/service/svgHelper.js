/**
 * svgHelper.js
 * Generador de plantillas SVG para previsualizaciones de miniaturas multimedia.
 */

/**
 * Genera un SVG como placeholder de miniatura multimedia según la plataforma
 * @param {string} title - Título del video/audio
 * @param {string} platform - Nombre de la plataforma (YouTube, TikTok, etc.)
 * @param {string} author - Autor o canal
 * @returns {string} Código SVG seguro
 */
function generateThumbnailSvg(title, platform = "MEDIA", author = "") {
  const safeTitle = String(title || "Video Multimedia").replace(/[<>&"]/g, "").slice(0, 42);
  const safeAuthor = String(author || "").replace(/[<>&"]/g, "").slice(0, 30);
  const plat = String(platform || "MEDIA").toLowerCase();
  let color = "#00f0ff";
  let platName = String(platform || "MEDIA").toUpperCase();

  if (plat.includes("tiktok")) {
    color = "#ff0050";
    platName = "TIKTOK";
  } else if (plat.includes("instagram")) {
    color = "#e1306c";
    platName = "INSTAGRAM";
  } else if (plat.includes("facebook")) {
    color = "#1877f2";
    platName = "FACEBOOK";
  } else if (plat.includes("twitter") || plat.includes("x")) {
    color = "#1da1f2";
    platName = "X / TWITTER";
  } else if (plat.includes("youtube")) {
    color = "#ff0000";
    platName = "YOUTUBE";
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
    <defs>
      <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#0a0c12"/>
        <stop offset="50%" stop-color="#141824"/>
        <stop offset="100%" stop-color="#0a0c12"/>
      </linearGradient>
    </defs>
    <rect width="100%" height="100%" fill="url(#bg)"/>
    <rect x="15" y="15" width="610" height="330" rx="16" fill="none" stroke="${color}" stroke-opacity="0.4" stroke-width="2"/>
    <circle cx="320" cy="140" r="48" fill="${color}" fill-opacity="0.18" stroke="${color}" stroke-width="2"/>
    <polygon points="310,122 338,140 310,158" fill="${color}"/>
    <rect x="230" y="202" width="180" height="26" rx="13" fill="${color}" fill-opacity="0.18" stroke="${color}" stroke-opacity="0.5" stroke-width="1"/>
    <text x="320" y="219" fill="${color}" font-family="system-ui, -apple-system, sans-serif" font-size="12" font-weight="700" text-anchor="middle" letter-spacing="2">${platName}</text>
    <text x="320" y="262" fill="#ffffff" font-family="system-ui, -apple-system, sans-serif" font-size="20" font-weight="700" text-anchor="middle">${safeTitle}</text>
    ${safeAuthor ? `<text x="320" y="292" fill="#94a3b8" font-family="system-ui, -apple-system, sans-serif" font-size="14" font-weight="500" text-anchor="middle">${safeAuthor.startsWith('@') ? safeAuthor : '@' + safeAuthor}</text>` : ''}
  </svg>`;
}

module.exports = {
  generateThumbnailSvg
};
