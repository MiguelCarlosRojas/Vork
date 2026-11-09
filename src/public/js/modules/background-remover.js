/**
 * background-remover.js
 * Módulo del Pilar 06: Estudio y Eliminador de Fondo de Imágenes con IA
 */

(function() {
      let currentImageBase64 = null;
      let currentImageUrl = null;
      let currentBgImageBase64 = null;
      let selectedMode = "transparent";
      let latestResult = null;

      const dropZone = document.getElementById("drop-zone");
      const fileInput = document.getElementById("file-input");
      const imageUrlInput = document.getElementById("image-url-input");
      const btnLoadUrl = document.getElementById("btn-load-url");
      const btnProcessBg = document.getElementById("btn-process-bg");
      const modeTabs = document.querySelectorAll(".btn-bg-tab");
      const modePanels = document.querySelectorAll(".mode-panel");
      const loadingSpinner = document.getElementById("loading-spinner");
      const loadingStatusText = document.getElementById("loading-status-text");
      const resultSection = document.getElementById("result-section");
      const imgOriginalPreview = document.getElementById("img-original-preview");
      const imgResultPreview = document.getElementById("img-result-preview");
      const originalMeta = document.getElementById("original-meta");
      const resultMeta = document.getElementById("result-meta");
      const btnDownload = document.getElementById("btn-download");
      const btnCopyLink = document.getElementById("btn-copy-link");
      const toast = document.getElementById("toast");
      const toastMessage = document.getElementById("toast-message");

      const bgColorPicker = document.getElementById("bg-color-picker");
      const bgColorHex = document.getElementById("bg-color-hex");
      const bgFileInput = document.getElementById("bg-file-input");
      const bgFileName = document.getElementById("bg-file-name");
      const aiPromptInput = document.getElementById("ai-prompt-input");

      function showToast(msg) {
        toastMessage.textContent = msg;
        toast.classList.add("show");
        setTimeout(() => toast.classList.remove("show"), 3500);
      }

      // Cambio de Pestañas de Modo
      modeTabs.forEach(tab => {
        tab.addEventListener("click", () => {
          modeTabs.forEach(t => t.classList.remove("active"));
          tab.classList.add("active");
          selectedMode = tab.dataset.mode;

          // Mostrar panel correspondiente
          document.querySelectorAll("[id^='panel-']").forEach(p => p.style.display = "none");
          const activePanel = document.getElementById(`panel-${selectedMode}`);
          if (activePanel) activePanel.style.display = "block";
        });
      });

      // Selector de color
      bgColorPicker.addEventListener("input", (e) => {
        bgColorHex.value = e.target.value.toUpperCase();
      });
      bgColorHex.addEventListener("input", (e) => {
        if (/^#[0-9A-Fa-f]{6}$/.test(e.target.value)) {
          bgColorPicker.value = e.target.value;
        }
      });

      // Presets de color
      document.querySelectorAll(".preset-color-pill").forEach(pill => {
        pill.addEventListener("click", () => {
          const col = pill.dataset.color;
          bgColorPicker.value = col;
          bgColorHex.value = col;
        });
      });

      // Ideas rápidas de prompt
      document.querySelectorAll(".quick-prompt-tag").forEach(tag => {
        tag.addEventListener("click", () => {
          aiPromptInput.value = tag.dataset.prompt;
        });
      });

      // Carga de imagen de fondo personalizada
      bgFileInput.addEventListener("change", (e) => {
        if (e.target.files && e.target.files[0]) {
          const f = e.target.files[0];
          bgFileName.textContent = `${f.name} (${(f.size/1024).toFixed(1)} KB)`;
          const reader = new FileReader();
          reader.onload = (ev) => {
            currentBgImageBase64 = ev.target.result;
          };
          reader.readAsDataURL(f);
        }
      });

      // Carga de la foto principal
      function loadFile(file) {
        if (!file || !file.type.startsWith("image/")) {
          alert("Por favor selecciona un archivo de imagen válido.");
          return;
        }
        currentImageUrl = null;
        imageUrlInput.value = "";

        const reader = new FileReader();
        reader.onload = (e) => {
          currentImageBase64 = e.target.result;
          imgOriginalPreview.src = currentImageBase64;
          originalMeta.textContent = `${file.name} • ${(file.size / 1024).toFixed(1)} KB`;
          btnProcessBg.disabled = false;
          dropZone.style.borderColor = "#c084fc";
        };
        reader.readAsDataURL(file);
      }

      fileInput.addEventListener("change", (e) => {
        if (e.target.files && e.target.files[0]) {
          loadFile(e.target.files[0]);
        }
      });

      // Drag & Drop
      dropZone.addEventListener("dragover", (e) => {
        e.preventDefault();
        dropZone.classList.add("dragover");
      });
      dropZone.addEventListener("dragleave", () => {
        dropZone.classList.remove("dragover");
      });
      dropZone.addEventListener("drop", (e) => {
        e.preventDefault();
        dropZone.classList.remove("dragover");
        if (e.dataTransfer.files && e.dataTransfer.files[0]) {
          loadFile(e.dataTransfer.files[0]);
        }
      });

      // Pegar desde portapapeles (Ctrl+V)
      window.addEventListener("paste", (e) => {
        const items = (e.clipboardData || e.originalEvent.clipboardData).items;
        for (let item of items) {
          if (item.type.indexOf("image") !== -1) {
            const blob = item.getAsFile();
            loadFile(blob);
            showToast("Foto pegada desde el portapapeles");
            break;
          }
        }
      });

      // Cargar desde URL
      btnLoadUrl.addEventListener("click", () => {
        const url = imageUrlInput.value.trim();
        if (!url) return;
        currentImageUrl = url;
        currentImageBase64 = null;
        imgOriginalPreview.src = url;
        originalMeta.textContent = `URL: ${url.slice(0, 40)}...`;
        btnProcessBg.disabled = false;
        showToast("URL de foto cargada");
      });

      // Procesar Fondo con IA
      btnProcessBg.addEventListener("click", async () => {
        if (!currentImageBase64 && !currentImageUrl) return;

        if (selectedMode === "prompt" && !aiPromptInput.value.trim()) {
          alert("Por favor escribe una descripción del fondo que quieres que la IA genere.");
          aiPromptInput.focus();
          return;
        }

        if (selectedMode === "custom_bg" && !currentBgImageBase64) {
          alert("Por favor selecciona una imagen de fondo para colocar detrás.");
          return;
        }

        btnProcessBg.disabled = true;
        loadingSpinner.style.display = "block";
        resultSection.style.display = "none";

        if (selectedMode === "prompt") {
          loadingStatusText.textContent = "Generando nuevo fondo con IA y recortando sujeto con rembg...";
        } else {
          loadingStatusText.textContent = "Extrayendo sujeto con rembg y aplicando nuevo fondo...";
        }

        const payload = {
          mode: selectedMode,
          color: bgColorHex.value || "#FFFFFF",
          bgImageBase64: currentBgImageBase64,
          prompt: aiPromptInput.value.trim()
        };

        if (currentImageUrl) {
          payload.url = currentImageUrl;
        } else {
          payload.imageBase64 = currentImageBase64;
        }

        try {
          const res = await fetch("/api/image/remove-background", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });

          const data = await res.json();
          if (!res.ok || data.status !== "success") {
            throw new Error(data.error || "Fallo en el procesamiento con IA.");
          }

          latestResult = data;

          // Mostrar resultado
          imgResultPreview.src = data.streamUrl;
          resultMeta.textContent = `${data.filename} • ${data.sizeFormatted} • ${data.width}×${data.height}px`;

          // Configurar botón de descarga
          btnDownload.href = data.downloadUrl;
          btnDownload.setAttribute("download", data.filename);

          resultSection.style.display = "block";
          resultSection.scrollIntoView({ behavior: "smooth" });
          showToast("¡Fondo procesado exitosamente por la IA!");

          if (btnProcessBg) {
            btnProcessBg.classList.add("btn-copied");
            const originalHTML = btnProcessBg.innerHTML;
            btnProcessBg.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Listo! Fondo Procesado</span>';
            setTimeout(() => {
              btnProcessBg.classList.remove("btn-copied");
              btnProcessBg.innerHTML = originalHTML;
            }, 1800);
          }

        } catch (err) {
          alert("Error: " + err.message);
        } finally {
          btnProcessBg.disabled = false;
          loadingSpinner.style.display = "none";
        }
      });

      // Botón Copiar Enlace
      btnCopyLink.addEventListener("click", () => {
        if (!latestResult) return;
        const fullUrl = window.location.origin + latestResult.downloadUrl;
        navigator.clipboard.writeText(fullUrl).then(() => {
          showToast("¡Enlace directo copiado al portapapeles!");
          btnCopyLink.classList.add("btn-copied");
          const originalHTML = btnCopyLink.innerHTML;
          btnCopyLink.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Copiado!</span>';
          setTimeout(() => {
            btnCopyLink.classList.remove("btn-copied");
            btnCopyLink.innerHTML = originalHTML;
          }, 1800);
        }).catch(() => {
          prompt("Copia este enlace:", fullUrl);
        });
      });

    })();
