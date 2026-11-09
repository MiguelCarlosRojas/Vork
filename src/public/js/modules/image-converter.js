/**
 * image-converter.js
 * Módulo del Pilar 05: Conversor y Compresor de Imágenes WebP/PNG/JPG/AVIF
 */

(function() {
      let currentImageBase64 = null;
      let currentImageUrl = null;
      let currentFile = null;
      let selectedFormat = "png";
      let latestResult = null;

      const dropZone = document.getElementById("drop-zone");
      const fileInput = document.getElementById("file-input");
      const imageUrlInput = document.getElementById("image-url-input");
      const btnLoadUrl = document.getElementById("btn-load-url");
      const btnConvert = document.getElementById("btn-convert");
      const qualitySlider = document.getElementById("quality-slider");
      const qualityVal = document.getElementById("quality-val");
      const formatChips = document.querySelectorAll(".format-chip");
      const loadingSpinner = document.getElementById("loading-spinner");
      const resultSection = document.getElementById("result-section");
      const imgOriginalPreview = document.getElementById("img-original-preview");
      const imgConvertedPreview = document.getElementById("img-converted-preview");
      const originalMeta = document.getElementById("original-meta");
      const convertedMeta = document.getElementById("converted-meta");
      const btnDownload = document.getElementById("btn-download");
      const btnCopyLink = document.getElementById("btn-copy-link");
      const toast = document.getElementById("toast");
      const toastMessage = document.getElementById("toast-message");

      function showToast(msg) {
        toastMessage.textContent = msg;
        toast.classList.add("show");
        setTimeout(() => toast.classList.remove("show"), 3500);
      }

      // Slider de calidad
      qualitySlider.addEventListener("input", (e) => {
        qualityVal.textContent = e.target.value + "%";
      });

      // Selección de formato
      formatChips.forEach(chip => {
        chip.addEventListener("click", () => {
          formatChips.forEach(c => c.classList.remove("active"));
          chip.classList.add("active");
          selectedFormat = chip.dataset.format;
        });
      });

      // Manejo de archivo seleccionado
      function loadFile(file) {
        if (!file || !file.type.startsWith("image/")) {
          alert("Por favor selecciona un archivo de imagen válido.");
          return;
        }
        currentFile = file;
        currentImageUrl = null;
        imageUrlInput.value = "";

        const reader = new FileReader();
        reader.onload = (e) => {
          currentImageBase64 = e.target.result;
          imgOriginalPreview.src = currentImageBase64;
          originalMeta.textContent = `${file.name} • ${(file.size / 1024).toFixed(1)} KB`;
          btnConvert.disabled = false;
          dropZone.style.borderColor = "var(--primary)";
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
            showToast("Imagen pegada desde el portapapeles");
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
        currentFile = null;
        imgOriginalPreview.src = url;
        originalMeta.textContent = `Imagen remota: ${url.slice(0, 40)}...`;
        btnConvert.disabled = false;
        showToast("URL de imagen cargada");
      });

      // Conversión al hacer clic
      btnConvert.addEventListener("click", async () => {
        if (!currentImageBase64 && !currentImageUrl) return;

        btnConvert.disabled = true;
        loadingSpinner.style.display = "block";
        resultSection.style.display = "none";

        const payload = {
          targetFormat: selectedFormat,
          quality: parseInt(qualitySlider.value, 10),
          width: document.getElementById("resize-w").value || undefined,
          height: document.getElementById("resize-h").value || undefined
        };

        if (currentImageUrl) {
          payload.url = currentImageUrl;
        } else {
          payload.imageBase64 = currentImageBase64;
        }

        try {
          const res = await fetch("/api/image/convert", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });

          const data = await res.json();
          if (!res.ok || data.status !== "success") {
            throw new Error(data.error || "Fallo en la conversión.");
          }

          latestResult = data;

          // Mostrar resultados
          imgConvertedPreview.src = data.streamUrl;
          convertedMeta.textContent = `${data.filename} • ${data.sizeFormatted} • ${data.width}×${data.height}px`;

          // Configurar botón descargar
          btnDownload.href = data.downloadUrl;
          btnDownload.setAttribute("download", data.filename);

          resultSection.style.display = "block";
          resultSection.scrollIntoView({ behavior: "smooth" });
          showToast("¡Conversión completada con éxito!");

          if (btnConvert) {
            btnConvert.classList.add("btn-copied");
            const originalHTML = btnConvert.innerHTML;
            btnConvert.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Listo! Convertida</span>';
            setTimeout(() => {
              btnConvert.classList.remove("btn-copied");
              btnConvert.innerHTML = originalHTML;
            }, 1800);
          }

        } catch (err) {
          alert("Error: " + err.message);
        } finally {
          btnConvert.disabled = false;
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
