/**
 * draw.js
 * Módulo del Pilar 07: Lienzo interactivo y Generador de Imágenes IA (Flux)
 */

document.addEventListener("DOMContentLoaded", function() {
      const promptInput = document.getElementById("prompt-input");
      const promptCounter = document.getElementById("prompt-counter");
      const btnGenerate = document.getElementById("btn-generate");
      const loadingSpinner = document.getElementById("loading-spinner");
      const loadingText = document.getElementById("loading-text");
      const errorBox = document.getElementById("error-box");
      const previewPlaceholder = document.getElementById("preview-placeholder");
      const resultImg = document.getElementById("result-img");
      const resultActions = document.getElementById("result-actions");
      const btnDownload = document.getElementById("btn-download");
      const btnCopyLink = document.getElementById("btn-copy-link");
      const btnFullscreen = document.getElementById("btn-fullscreen");
      const ratioBtns = document.querySelectorAll(".ratio-pill-btn");
      const sampleTags = document.querySelectorAll(".prompt-sample-tag");

      let currentWidth = 1024;
      let currentHeight = 1024;
      let currentImageUrl = "";

      // Contador de caracteres
      promptInput.addEventListener("input", function() {
        promptCounter.textContent = promptInput.value.length + " / 1000";
      });

      // Tags de inspiración
      sampleTags.forEach(function(tag) {
        tag.addEventListener("click", function() {
          promptInput.value = tag.getAttribute("data-prompt");
          promptCounter.textContent = promptInput.value.length + " / 1000";
          promptInput.focus();
        });
      });

      // Selección de ratio
      ratioBtns.forEach(function(btn) {
        btn.addEventListener("click", function() {
          ratioBtns.forEach(function(b) { b.classList.remove("active"); });
          btn.classList.add("active");
          currentWidth = parseInt(btn.getAttribute("data-w"), 10) || 1024;
          currentHeight = parseInt(btn.getAttribute("data-h"), 10) || 1024;
        });
      });

      // Generar Imagen
      btnGenerate.addEventListener("click", async function() {
        const prompt = (promptInput.value || "").trim();
        if (!prompt) {
          errorBox.textContent = "Por favor, escribe una descripción o prompt para generar la imagen.";
          errorBox.style.display = "block";
          promptInput.focus();
          return;
        }

        errorBox.style.display = "none";
        btnGenerate.disabled = true;
        loadingSpinner.style.display = "block";
        previewPlaceholder.style.display = "none";
        resultImg.style.display = "none";
        resultActions.style.display = "none";

        const msgs = [
          "Sintetizando imagen con FLUX.1 Neural Engine...",
          "Calculando transformador de flujo rectificado (Flow Matching)...",
          "Decodificando latentes a alta resolución...",
          "Renderizando detalles finos e iluminación..."
        ];
        let msgIdx = 0;
        const msgTimer = setInterval(function() {
          msgIdx = (msgIdx + 1) % msgs.length;
          loadingText.textContent = msgs[msgIdx];
        }, 2200);

        try {
          const resp = await fetch("/api/image/generate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              prompt: prompt,
              width: currentWidth,
              height: currentHeight,
              seed: Math.floor(Math.random() * 999999) + 1
            })
          });

          clearInterval(msgTimer);

          if (!resp.ok) {
            const errData = await resp.json().catch(function() { return {}; });
            throw new Error(errData.error || "Error al procesar la solicitud en el servidor.");
          }

          const data = await resp.json();
          if (data.status !== "success" || !data.imageUrl) {
            throw new Error(data.error || "No se pudo obtener la imagen generada.");
          }

          currentImageUrl = data.imageUrl;
          resultImg.src = currentImageUrl;
          resultImg.style.display = "block";
          resultActions.style.display = "flex";

          if (data.downloadUrl) {
            btnDownload.href = data.downloadUrl;
          } else {
            btnDownload.href = currentImageUrl;
          }

          loadingSpinner.style.display = "none";
        } catch (err) {
          clearInterval(msgTimer);
          loadingSpinner.style.display = "none";
          previewPlaceholder.style.display = "block";
          errorBox.textContent = err.message || "Error de red al conectar con el motor FLUX.1.";
          errorBox.style.display = "block";
        } finally {
          btnGenerate.disabled = false;
        }
      });

      // Copiar enlace directo
      btnCopyLink.addEventListener("click", function() {
        if (!currentImageUrl) return;
        const fullUrl = currentImageUrl.startsWith("http") ? currentImageUrl : window.location.origin + currentImageUrl;
        navigator.clipboard.writeText(fullUrl).then(function() {
          const orig = btnCopyLink.innerHTML;
          btnCopyLink.innerHTML = "<span>✓ Enlace Copiado</span>";
          setTimeout(function() { btnCopyLink.innerHTML = orig; }, 2000);
        }).catch(function() {
          prompt("Enlace directo:", fullUrl);
        });
      });

      // Pantalla Completa
      btnFullscreen.addEventListener("click", function() {
        if (!currentImageUrl) return;
        const fullUrl = currentImageUrl.startsWith("http") ? currentImageUrl : window.location.origin + currentImageUrl;
        window.open(fullUrl, "_blank");
      });

      // Copiar comando CLI
      const btnCopyInstall = document.getElementById("btn-copy-install");
      if (btnCopyInstall) {
        btnCopyInstall.addEventListener("click", function() {
          const cmd = "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex";
          navigator.clipboard.writeText(cmd).then(function() {
            btnCopyInstall.innerHTML = "<span style='color: var(--accent);'>✓ Copiado</span>";
            setTimeout(function() {
              btnCopyInstall.innerHTML = "<svg class='icon' viewBox='0 0 24 24' width='14' height='14'><rect width='14' height='14' x='8' y='8' rx='2' ry='2'/><path d='M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2'/></svg><span>Copiar</span>";
            }, 2000);
          });
        });
      }
    });
