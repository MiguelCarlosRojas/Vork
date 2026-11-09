/**
 * home.js
 * Módulo de la página de inicio (Landing Page): Inicialización de traducción y Demo en vivo.
 */

(function (window, document) {
  "use strict";

  function initHomeModule() {
    // 1. Inicialización del Cliente Vork si existe
    const apiEndpoint = "/api/translate";
    const selectLang = document.getElementById("select-lang");
    const inputCustomLang = document.getElementById("input-custom-lang");
    const btnEnglish = document.getElementById("btn-english");
    const btnTranslateCustom = document.getElementById("btn-translate-custom");
    const btnRestore = document.getElementById("btn-restore");
    const statusPill = document.getElementById("status-pill");
    const statusText = document.getElementById("status-text");

    if (window.Vork && !window.translator) {
      window.translator = new window.Vork({
        endpoint: apiEndpoint,
        defaultLanguage: "en",
        batchSize: 500,
        useCookies: true,
        onStart: (info) => {
          if (statusPill) statusPill.className = "status-pill translating";
          if (statusText) statusText.textContent = `Traduciendo (${info.targetLanguage.toUpperCase()})...`;
        },
        onProgress: (p) => {
          if (statusText) {
            if (p.cached) statusText.textContent = "Desde caché (0ms)";
            else statusText.textContent = "1 consulta enviada";
          }
        },
        onComplete: (stats) => {
          if (statusPill) statusPill.className = "status-pill completed";
          if (statusText) {
            if (stats.restored) {
              statusText.textContent = "Original restaurado";
              if (selectLang) selectLang.value = "es";
              if (inputCustomLang) inputCustomLang.value = "es";
            } else {
              statusText.textContent = `Listo: ${stats.language.toUpperCase()}`;
            }
          }
        },
        onError: () => {
          if (statusPill) statusPill.className = "status-pill";
          if (statusText) statusText.textContent = "Error de conexión";
        }
      });
    }

    if (window.translator) {
      const saved = window.translator.getSavedLanguage();
      if (saved && saved !== "original") {
        if (selectLang) selectLang.value = saved;
        if (inputCustomLang) inputCustomLang.value = saved;
      }
    }

    if (btnEnglish && !btnEnglish._bound) {
      btnEnglish._bound = true;
      btnEnglish.addEventListener("click", () => {
        if (selectLang) selectLang.value = "en";
        if (inputCustomLang) inputCustomLang.value = "en";
        if (window.translator) window.translator.translateToEnglish();
      });
    }

    if (selectLang && !selectLang._bound) {
      selectLang._bound = true;
      selectLang.addEventListener("change", (e) => {
        const val = e.target.value;
        if (inputCustomLang) inputCustomLang.value = val;
        if (!window.translator) return;
        if (val === "es") window.translator.restoreOriginal();
        else window.translator.translatePage(val);
      });
    }

    if (btnTranslateCustom && !btnTranslateCustom._bound) {
      btnTranslateCustom._bound = true;
      btnTranslateCustom.addEventListener("click", () => {
        const val = (inputCustomLang?.value || selectLang?.value || "").trim().toLowerCase();
        if (!window.translator) return;
        if (val === "es") window.translator.restoreOriginal();
        else if (val) window.translator.translatePage(val);
      });
    }

    if (btnRestore && !btnRestore._bound) {
      btnRestore._bound = true;
      btnRestore.addEventListener("click", () => {
        if (window.translator) window.translator.restoreOriginal();
      });
    }

    // 2. Lógica de Prueba Interactiva en Vivo (Live Demo)
    const btnRunDemo = document.getElementById("btn-run-demo");
    const demoInputText = document.getElementById("demo-input-text");
    const demoTargetLang = document.getElementById("demo-target-lang");
    const demoLangBadge = document.getElementById("demo-lang-badge");
    const demoOutputJson = document.getElementById("demo-output-json");
    const demoLatencyBadge = document.getElementById("demo-latency-badge");

    if (demoTargetLang && demoLangBadge && !demoTargetLang._bound) {
      demoTargetLang._bound = true;
      demoTargetLang.addEventListener("change", () => {
        const opt = demoTargetLang.options[demoTargetLang.selectedIndex];
        demoLangBadge.textContent = opt ? opt.text.toUpperCase() : "ENGLISH (EN)";
      });
    }

    if (btnRunDemo && !btnRunDemo._bound) {
      btnRunDemo._bound = true;
      btnRunDemo.addEventListener("click", async () => {
        const txt = (demoInputText?.value || "").trim();
        const target = demoTargetLang?.value || "en";
        if (!txt) return;

        // 1. Bloquear campos de entrada para evitar cambios durante el proceso
        if (demoInputText) demoInputText.disabled = true;
        if (demoTargetLang) demoTargetLang.disabled = true;
        btnRunDemo.disabled = true;

        // 2. Cambiar por icono de cargado animado
        const originalBtnHTML = btnRunDemo.innerHTML;
        btnRunDemo.innerHTML = `<svg class="icon spin" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.5"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round"/></svg> <span>Procesando...</span>`;

        if (demoOutputJson) demoOutputJson.textContent = "Conectando con /api/translate...";
        const t0 = performance.now();

        try {
          const resp = await fetch("/api/translate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ text: txt, to: target })
          });

          const latency = Math.round(performance.now() - t0);
          const data = await resp.json();

          if (demoLatencyBadge) {
            demoLatencyBadge.textContent = "LATENCIA: " + latency + "ms | " + resp.status + " " + resp.statusText;
            demoLatencyBadge.style.display = "inline-block";
          }
          if (demoOutputJson) {
            demoOutputJson.textContent = JSON.stringify(data, null, 2);
          }

          // 3. Cuando termina: mostrar check dentro de un círculo con cambio de color y texto
          btnRunDemo.classList.add("btn-copied");
          btnRunDemo.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Listo!</span>`;

          setTimeout(() => {
            btnRunDemo.classList.remove("btn-copied");
            btnRunDemo.innerHTML = originalBtnHTML;
            // 4. Restaurar campos al terminar
            if (demoInputText) demoInputText.disabled = false;
            if (demoTargetLang) demoTargetLang.disabled = false;
            btnRunDemo.disabled = false;
          }, 1800);

        } catch (e) {
          if (demoOutputJson) demoOutputJson.textContent = "Error: " + e.message;
          btnRunDemo.classList.remove("btn-copied");
          btnRunDemo.innerHTML = originalBtnHTML;
          if (demoInputText) demoInputText.disabled = false;
          if (demoTargetLang) demoTargetLang.disabled = false;
          btnRunDemo.disabled = false;
        }
      });
    }

    // 3. Función Reutilizable para Botones de Copiar (con cambio de color e icono de check en círculo)
    function attachCopyFeedback(button, getTextFn) {
      if (!button || button._bound) return;
      button._bound = true;

      button.addEventListener("click", async () => {
        const text = getTextFn();
        if (!text) return;

        const originalHTML = button.innerHTML;

        try {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(text);
          } else {
            const ta = document.createElement("textarea");
            ta.value = text;
            document.body.appendChild(ta);
            ta.select();
            document.execCommand("copy");
            document.body.removeChild(ta);
          }

          // Cambio de color + icono de check buena dentro de círculo + texto ¡Copiado!
          button.classList.add("btn-copied");
          button.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="15" height="15" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Copiado!</span>`;

          setTimeout(() => {
            button.classList.remove("btn-copied");
            button.innerHTML = originalHTML;
          }, 2000);
        } catch (err) {
          console.warn("Error al copiar:", err);
        }
      });
    }

    // Botón copiar comando CLI
    const btnCopyInstall = document.getElementById("btn-copy-install");
    if (btnCopyInstall) {
      attachCopyFeedback(btnCopyInstall, () => {
        const el = document.getElementById("cli-install-cmd");
        return (el?.innerText || el?.textContent || "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex").trim();
      });
    }

    // Botón copiar respuesta JSON
    const btnCopyDemoJson = document.getElementById("btn-copy-demo-json");
    if (btnCopyDemoJson) {
      attachCopyFeedback(btnCopyDemoJson, () => {
        const el = document.getElementById("demo-output-json");
        return (el?.innerText || el?.textContent || "").trim();
      });
    }
  }

  window.initHomeModule = initHomeModule;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initHomeModule);
  } else {
    initHomeModule();
  }
})(window, document);
