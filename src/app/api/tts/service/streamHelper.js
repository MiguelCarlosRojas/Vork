/**
 * streamHelper.js
 * Utilidades para parseo de cookies y transmisión de audio con soporte HTTP 206 Partial Content.
 */

/**
 * Parseo seguro de Cookies HTTP sin dependencias
 * @param {import("express").Request} req
 * @returns {Record<string, string>}
 */
function parseCookies(req) {
  const cookies = {};
  const header = req.headers.cookie;
  if (header) {
    header.split(";").forEach(c => {
      const parts = c.split("=");
      const key = parts.shift().trim();
      const val = decodeURIComponent(parts.join("="));
      if (key) cookies[key] = val;
    });
  }
  return cookies;
}

/**
 * Streaming de audio de alto rendimiento con soporte HTTP 206 Partial Content
 * @param {import("express").Request} req
 * @param {import("express").Response} res
 * @param {{ buffer: Buffer, mimeType: string }} audioItem
 */
function streamAudioBuffer(req, res, audioItem) {
  const buffer = audioItem.buffer;
  const total = buffer.length;
  const range = req.headers.range;

  if (range) {
    const parts = range.replace(/bytes=/, "").split("-");
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : total - 1;
    const chunksize = (end - start) + 1;
    const sliced = buffer.subarray(start, end + 1);

    res.writeHead(206, {
      "Content-Range": `bytes ${start}-${end}/${total}`,
      "Accept-Ranges": "bytes",
      "Content-Length": chunksize,
      "Content-Type": audioItem.mimeType,
      "Cache-Control": "public, max-age=1800"
    });
    res.end(sliced);
  } else {
    res.writeHead(200, {
      "Content-Length": total,
      "Content-Type": audioItem.mimeType,
      "Accept-Ranges": "bytes",
      "Cache-Control": "public, max-age=1800"
    });
    res.end(buffer);
  }
}

module.exports = {
  parseCookies,
  streamAudioBuffer
};
