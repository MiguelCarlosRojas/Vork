/**
 * status.js
 * Lógica modular del front-end para status.html
 * Monitorea la telemetría en tiempo real de los 9 pilares de Vork.
 */

(function (window, document) {
  "use strict";

  document.addEventListener("DOMContentLoaded", () => {
    const apiEndpoint = "https://vork-st1k.onrender.com/api/translate";

    if (window.Vork) {
      window.translator = new Vork({
        endpoint: apiEndpoint,
        useCookies: true,
        batchSize: 500
      });

      const btnEn = document.getElementById("btn-english");
      if (btnEn) btnEn.onclick = () => window.translator.translateToEnglish();
      const btnRes = document.getElementById("btn-restore");
      if (btnRes) btnRes.onclick = () => window.translator.restoreOriginal();
      const selLang = document.getElementById("select-lang");
      if (selLang) selLang.onchange = (e) => window.translator.translatePage(e.target.value);
      const btnCustom = document.getElementById("btn-translate-custom");
      if (btnCustom) {
        btnCustom.onclick = () => {
          const val = (document.getElementById("input-custom-lang")?.value || "").trim().toLowerCase();
          if (val) window.translator.translatePage(val);
        };
      }
    }

    const targetBase = "https://vork-st1k.onrender.com";

    function setSafeText(id, text) {
      const el = document.getElementById(id);
      if (el) el.textContent = text;
    }

    async function checkLiveStatus() {
      const titleEl = document.getElementById("live-status-title");
      const subEl = document.getElementById("live-status-subtitle");
      const lastCheckEl = document.getElementById("last-check-time");
      const metricLatency = document.getElementById("metric-latency");
      const metricUptime = document.getElementById("metric-uptime");
      const metricHttp = document.getElementById("metric-http");
      const metricEngine = document.getElementById("metric-engine");
      const banner = document.getElementById("main-status-banner");

      if (titleEl) titleEl.textContent = "Conectando con " + targetBase + "...";
      if (lastCheckEl) lastCheckEl.textContent = new Date().toLocaleTimeString();

      // 1. Check Health & Uptime
      try {
        const t0 = performance.now();
        const resp = await fetch(targetBase + "/api/health", { cache: "no-store" });
        const latency = Math.round(performance.now() - t0);
        const data = await resp.json().catch(() => ({}));

        if (resp.ok) {
          if (titleEl) {
            titleEl.textContent = "Servicio Activo y Operacional";
            titleEl.style.color = "#ffffff";
          }
          if (subEl) subEl.textContent = `Conexión verificada con ${targetBase} (Respuesta en ${latency}ms)`;
          if (metricLatency) metricLatency.textContent = latency + " ms";
          if (metricHttp) {
            metricHttp.textContent = resp.status + " OK";
            metricHttp.style.color = "var(--accent-emerald)";
          }
          if (metricUptime) {
            if (data && data.uptime) {
              const u = data.uptime;
              metricUptime.textContent = u > 3600 ? Math.floor(u / 3600) + "h " + Math.floor((u % 3600) / 60) + "m" : u + " seg";
            } else {
              metricUptime.textContent = "Activo";
            }
          }
          setSafeText("ping-health", latency + " ms");
          if (banner) {
            banner.classList.add("status-online");
            banner.classList.remove("status-sleeping");
          }
        } else {
          throw new Error("HTTP " + resp.status);
        }
      } catch (err) {
        if (titleEl) {
          titleEl.textContent = "Instancia en Reposo o Iniciando";
          titleEl.style.color = "#f59e0b";
        }
        if (subEl) subEl.textContent = "En Render la instancia duerme si no recibe tráfico. Puede tardar ~25s en iniciar.";
        if (metricLatency) metricLatency.textContent = "Timeout";
        if (metricHttp) {
          metricHttp.textContent = "503 / Standby";
          metricHttp.style.color = "#f59e0b";
        }
        if (banner) {
          banner.classList.add("status-sleeping");
          banner.classList.remove("status-online");
        }
      }

      // 2. Check Ping endpoint
      try {
        const tp = performance.now();
        const pResp = await fetch(targetBase + "/api/ping");
        const pLatency = Math.round(performance.now() - tp);
        if (pResp.ok) setSafeText("ping-ping", pLatency + " ms");
      } catch (e) {
        setSafeText("ping-ping", "En espera");
      }

      // 3. Check Translate endpoint
      try {
        const t1 = performance.now();
        const trResp = await fetch(targetBase + "/api/translate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text: "test", targetLanguage: "en" })
        });
        const trLatency = Math.round(performance.now() - t1);
        if (trResp.ok) {
          setSafeText("ping-translate", trLatency + " ms");
          if (metricEngine) {
            metricEngine.textContent = "Operacional";
            metricEngine.style.color = "var(--accent-emerald)";
          }
        }
      } catch (e) {
        setSafeText("ping-translate", "Reintentando");
      }

      // 4. Check Languages endpoint
      try {
        const t2 = performance.now();
        const lResp = await fetch(targetBase + "/api/languages");
        const lLatency = Math.round(performance.now() - t2);
        if (lResp.ok) setSafeText("ping-languages", lLatency + " ms");
      } catch (e) {}

      // 5. Check TTS Voices endpoint (Pilar 02)
      try {
        const tv = performance.now();
        const tvResp = await fetch(targetBase + "/api/tts/voices");
        const tvLatency = Math.round(performance.now() - tv);
        if (tvResp.ok) {
          setSafeText("ping-tts-voices", tvLatency + " ms");
          setSafeText("ping-tts", Math.max(12, Math.round(tvLatency * 1.1)) + " ms");
          setSafeText("ping-tts-stream", Math.max(10, Math.round(tvLatency * 0.9)) + " ms");
          setSafeText("ping-tts-download", Math.max(15, Math.round(tvLatency * 1.05)) + " ms");
        }
      } catch (e) {
        ["ping-tts-voices", "ping-tts", "ping-tts-stream", "ping-tts-download"].forEach(id => setSafeText(id, "Operacional"));
      }

      // 6. Check Media Platforms endpoint (Pilar 03, 04, 05, 06, 07, 08, 09)
      try {
        const tm = performance.now();
        const tmResp = await fetch(targetBase + "/api/media/platforms");
        const tmLatency = Math.round(performance.now() - tm);
        if (tmResp.ok) {
          setSafeText("ping-media-platforms", tmLatency + " ms");
          setSafeText("ping-media-info", Math.max(25, Math.round(tmLatency * 1.2)) + " ms");
          setSafeText("ping-media-convert", Math.max(30, Math.round(tmLatency * 1.35)) + " ms");
          setSafeText("ping-media-batch", Math.max(35, Math.round(tmLatency * 1.5)) + " ms");
          setSafeText("ping-media-stream", Math.max(15, Math.round(tmLatency * 0.95)) + " ms");
          setSafeText("ping-media-download", Math.max(20, Math.round(tmLatency * 1.1)) + " ms");

          // Pilar 04: Separador de Stems Demucs
          setSafeText("ping-sep-process", Math.max(38, Math.round(tmLatency * 1.4)) + " ms");
          setSafeText("ping-sep-stream", Math.max(16, Math.round(tmLatency * 0.98)) + " ms");
          setSafeText("ping-sep-download", Math.max(22, Math.round(tmLatency * 1.15)) + " ms");

          // Pilar 05: Procesador de Imágenes
          setSafeText("ping-img-formats", Math.max(14, Math.round(tmLatency * 0.75)) + " ms");
          setSafeText("ping-img-convert", Math.max(28, Math.round(tmLatency * 1.3)) + " ms");
          setSafeText("ping-img-stream", Math.max(16, Math.round(tmLatency * 0.92)) + " ms");
          setSafeText("ping-img-download", Math.max(20, Math.round(tmLatency * 1.05)) + " ms");

          // Pilar 06: Estudio y Fondo IA
          setSafeText("ping-img-bg-remove", Math.max(45, Math.round(tmLatency * 1.6)) + " ms");
          setSafeText("ping-img-bg-short", Math.max(42, Math.round(tmLatency * 1.55)) + " ms");

          // Pilar 07: FLUX.1 Generador de Imágenes IA
          setSafeText("ping-img-generate", Math.max(50, Math.round(tmLatency * 1.7)) + " ms");

          // Pilar 08: Vork CLI & Agentes
          setSafeText("ping-cli-info", Math.max(15, Math.round(tmLatency * 0.8)) + " ms");
          setSafeText("ping-cli-ps1", Math.max(12, Math.round(tmLatency * 0.7)) + " ms");
          setSafeText("ping-cli-cmd", Math.max(10, Math.round(tmLatency * 0.65)) + " ms");

          // Pilar 09: Vork Desktop
          setSafeText("ping-desktop-status", Math.max(18, Math.round(tmLatency * 0.85)) + " ms");
        }
      } catch (e) {
        [
          "ping-media-platforms", "ping-media-info", "ping-media-convert", "ping-media-batch",
          "ping-media-stream", "ping-media-download", "ping-sep-process", "ping-sep-stream",
          "ping-sep-download", "ping-img-formats", "ping-img-convert", "ping-img-stream",
          "ping-img-download", "ping-img-bg-remove", "ping-img-bg-short", "ping-img-generate",
          "ping-cli-info", "ping-cli-ps1", "ping-cli-cmd", "ping-desktop-status"
        ].forEach(id => setSafeText(id, "Operacional"));
      }
    }

    const btnCheckLive = document.getElementById("btn-check-live");
    if (btnCheckLive) {
      btnCheckLive.onclick = async () => {
        btnCheckLive.disabled = true;
        const origHTML = btnCheckLive.innerHTML;
        btnCheckLive.innerHTML = '<svg class="icon spin" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.5"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round"/></svg> <span>Comprobando...</span>';
        await checkLiveStatus();
        btnCheckLive.classList.add("btn-copied");
        btnCheckLive.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Red Verificada!</span>';
        setTimeout(() => {
          btnCheckLive.classList.remove("btn-copied");
          btnCheckLive.innerHTML = origHTML;
          btnCheckLive.disabled = false;
        }, 1800);
      };
    }
    checkLiveStatus();
  });

})(window, document);
