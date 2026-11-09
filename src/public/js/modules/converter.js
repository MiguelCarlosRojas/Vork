/**
 * converter.js
 * Lógica modular del front-end para converter.html
 */

(function (window, document) {
  "use strict";

  function initConverterModule() {
    const converterStudio = document.getElementById("converter-studio");
    if (!converterStudio) return;

    // Cargar Footer modular
    if (window.CloudComponents && document.getElementById("footer-placeholder")) {
      document.getElementById("footer-placeholder").innerHTML = window.CloudComponents.getFooterHTML("converter");
    }

    // Estado del Estudio
    let selectedFormat = "mp3";
    let isBatchMode = false;

    const inputUrl = document.getElementById("input-video-url");
    const btnClear = document.getElementById("btn-clear-url");
    const btnToggleBatch = document.getElementById("btn-toggle-batch");
    const singleBox = document.getElementById("single-link-box");
    const batchBox = document.getElementById("batch-link-box");
    const batchUrls = document.getElementById("input-batch-urls");

    const btnFormatMp3 = document.getElementById("btn-format-mp3");
    const btnFormatMp4 = document.getElementById("btn-format-mp4");

    const selectQuality = document.getElementById("select-quality");
    const qualityBadge = document.getElementById("quality-badge");
    const qualityContainer = document.getElementById("quality-combo-container");
    const qualityTrigger = document.getElementById("quality-trigger");
    const qualityCurrent = document.getElementById("quality-current");
    const qualityMenu = document.getElementById("quality-menu");
    const qualityList = document.getElementById("quality-list");

    const btnConvert = document.getElementById("btn-convert");
    const btnConvertText = document.getElementById("btn-convert-text");

    const progressBox = document.getElementById("conversion-progress-box");
    const progressStatus = document.getElementById("progress-status-text");
    const progressPercent = document.getElementById("progress-percent");
    const progressBar = document.getElementById("progress-bar-fill");

    const resultCard = document.getElementById("result-card");
    const resThumbnail = document.getElementById("res-thumbnail");
    const resPlatform = document.getElementById("res-platform-badge");
    const resDuration = document.getElementById("res-duration-badge");
    const resFormat = document.getElementById("res-format-badge");
    const resTitle = document.getElementById("res-title");
    const resAuthor = document.getElementById("res-author");
    const resSize = document.getElementById("res-size");
    const btnDownload = document.getElementById("btn-download-file");
    const btnCopyStream = document.getElementById("btn-copy-stream");

    const audioWrapper = document.getElementById("audio-player-wrapper");
    const audioPlayer = document.getElementById("html5-audio-player");
    const videoWrapper = document.getElementById("video-player-wrapper");
    const videoPlayer = document.getElementById("html5-video-player");

    // Iconos SVG para el botón Convertir (Idénticos al botón TRADUCIR TEXTO)
    const ICON_CONVERT = '<svg id="btn-convert-icon" class="btn-action-icon" viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
    const ICON_LOADING = '<svg class="spin-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" stroke-opacity="0.25" stroke="currentColor"/><path d="M12 2a10 10 0 0 1 10 10" stroke="currentColor"/></svg>';
    const ICON_CHECK = '<svg class="check-pop-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#10b981" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>';

    // Calidades según formato
    const qualityOptions = {
      mp3: [
        { value: "320k", label: "320 kbps (Alta Fidelidad / Studio Master)" },
        { value: "192k", label: "192 kbps (Estándar Recomendado)" },
        { value: "128k", label: "128 kbps (Ahorro de Datos)" }
      ],
      mp4: [
        { value: "1080p", label: "1080p Full HD (60fps)" },
        { value: "720p", label: "720p HD Estándar" },
        { value: "480p", label: "480p SD" },
        { value: "360p", label: "360p Móvil" }
      ]
    };

    function getQualityBadgeLabel(fmt, value) {
      if (fmt === "mp3") {
        if (value === "320k") return "320 kbps";
        if (value === "192k") return "192 kbps";
        if (value === "128k") return "128 kbps";
        return `${value}`;
      } else {
        if (value === "1080p") return "1080p Full HD";
        if (value === "720p") return "720p HD";
        if (value === "480p") return "480p SD";
        if (value === "360p") return "360p Móvil";
        return `${value}`;
      }
    }

    // Renderizar menú desplegable de Calidad (Estilo IDIOMA ORIGEN / DESTINO)
    function renderQualityComboMenu() {
      if (!qualityList) return;
      qualityList.innerHTML = "";
      const opts = qualityOptions[selectedFormat] || [];
      opts.forEach(opt => {
        const row = document.createElement("div");
        row.className = "combo-item" + (opt.value === selectQuality.value ? " is-selected" : "");
        row.setAttribute("data-value", opt.value);
        row.innerHTML = `<span class="combo-item-label">${opt.label}</span><span class="combo-item-code">${opt.value}</span>`;

        row.addEventListener("pointerdown", (e) => {
          e.preventDefault();
          e.stopPropagation();
          selectQualityItem(opt);
        });

        qualityList.appendChild(row);
      });
    }

    function selectQualityItem(opt) {
      if (qualityCurrent) qualityCurrent.textContent = opt.label;
      if (selectQuality) {
        selectQuality.value = opt.value;
        selectQuality.dispatchEvent(new Event("change", { bubbles: true }));
      }
      if (qualityBadge) {
        qualityBadge.textContent = getQualityBadgeLabel(selectedFormat, opt.value);
      }
      if (qualityContainer) qualityContainer.classList.remove("is-open");
      if (qualityTrigger) {
        qualityTrigger.setAttribute("aria-expanded", "false");
        qualityTrigger.focus();
      }
    }

    // Configurar ComboBox de Calidad (Disparador + Menú con opciones)
    if (qualityTrigger && qualityContainer && !qualityTrigger._boundCombo) {
      qualityTrigger._boundCombo = true;

      qualityTrigger.addEventListener("click", (e) => {
        e.stopPropagation();
        const willOpen = !qualityContainer.classList.contains("is-open");
        if (willOpen) {
          renderQualityComboMenu();
          qualityContainer.classList.add("is-open");
          qualityTrigger.setAttribute("aria-expanded", "true");
        } else {
          qualityContainer.classList.remove("is-open");
          qualityTrigger.setAttribute("aria-expanded", "false");
        }
      });

      document.addEventListener("click", (e) => {
        if (qualityContainer && !qualityContainer.contains(e.target)) {
          qualityContainer.classList.remove("is-open");
          if (qualityTrigger) qualityTrigger.setAttribute("aria-expanded", "false");
        }
      });
    }

    function updateQualityOptions(fmt) {
      if (selectQuality) {
        selectQuality.innerHTML = "";
        const opts = qualityOptions[fmt] || [];
        opts.forEach((opt, idx) => {
          const el = document.createElement("option");
          el.value = opt.value;
          el.textContent = opt.label;
          if (idx === 0) el.selected = true;
          selectQuality.appendChild(el);
        });
        const defaultOpt = opts[0];
        if (defaultOpt) {
          selectQuality.value = defaultOpt.value;
          if (qualityCurrent) qualityCurrent.textContent = defaultOpt.label;
          if (qualityBadge) {
            qualityBadge.textContent = getQualityBadgeLabel(fmt, defaultOpt.value);
          }
        }
        renderQualityComboMenu();
      }
    }

    // Detener y limpiar reproductores de medios
    function stopMediaPlayback() {
      if (audioPlayer) {
        audioPlayer.pause();
        audioPlayer.currentTime = 0;
        audioPlayer.removeAttribute("src");
        try { audioPlayer.load(); } catch {}
      }
      if (videoPlayer) {
        videoPlayer.pause();
        videoPlayer.currentTime = 0;
        videoPlayer.removeAttribute("src");
        try { videoPlayer.load(); } catch {}
      }
    }

    // Ocultar resultado anterior y detener reproducción
    function hidePreviousResult() {
      if (resultCard) resultCard.style.display = "none";
      stopMediaPlayback();
    }

    // Deshabilitar / Habilitar todos los controles mientras se procesa
    function setFormDisabled(disabled) {
      if (inputUrl) {
        inputUrl.disabled = disabled;
        inputUrl.style.opacity = disabled ? "0.6" : "1";
        inputUrl.style.cursor = disabled ? "not-allowed" : "text";
      }
      if (batchUrls) {
        batchUrls.disabled = disabled;
        batchUrls.style.opacity = disabled ? "0.6" : "1";
        batchUrls.style.cursor = disabled ? "not-allowed" : "text";
      }
      if (btnClear) btnClear.disabled = disabled;
      if (btnToggleBatch) btnToggleBatch.disabled = disabled;
      if (btnFormatMp3) btnFormatMp3.disabled = disabled;
      if (btnFormatMp4) btnFormatMp4.disabled = disabled;
      if (qualityTrigger) {
        qualityTrigger.disabled = disabled;
        qualityTrigger.style.pointerEvents = disabled ? "none" : "auto";
        qualityTrigger.style.opacity = disabled ? "0.6" : "1";
      }
      if (selectQuality) selectQuality.disabled = disabled;

      if (btnConvert) {
        btnConvert.disabled = disabled;
        btnConvert.style.cursor = disabled ? "not-allowed" : "pointer";
        btnConvert.style.opacity = disabled ? "0.75" : "1";
      }

      const interactiveBtns = [
        btnFormatMp3,
        btnFormatMp4,
        btnClear,
        btnToggleBatch
      ];

      interactiveBtns.forEach(el => {
        if (el) {
          el.style.pointerEvents = disabled ? "none" : "auto";
          el.style.opacity = disabled ? "0.55" : "1";
          el.style.cursor = disabled ? "not-allowed" : "pointer";
        }
      });
    }

    // Reinicia y oculta la barra de estado y mensaje de conversión previa
    function resetProgressBox() {
      if (progressBox) progressBox.style.display = "none";
      if (progressStatus) progressStatus.innerHTML = "";
      if (progressPercent) progressPercent.textContent = "0%";
      if (progressBar) progressBar.style.width = "0%";
    }

    // Animación de clic para botones de formato
    function animateTabClick(btn) {
      if (!btn) return;
      btn.classList.remove("format-tab-animated");
      void btn.offsetWidth; // forzar reflow
      btn.classList.add("format-tab-animated");
      setTimeout(() => btn.classList.remove("format-tab-animated"), 360);
    }

    // Conmutar Pestaña de Formato (Con animación y solo iconos con tooltips)
    if (btnFormatMp3 && !btnFormatMp3._bound) {
      btnFormatMp3._bound = true;
      btnFormatMp3.addEventListener("click", () => {
        animateTabClick(btnFormatMp3);
        resetProgressBox();
        selectedFormat = "mp3";
        btnFormatMp3.classList.add("active");
        btnFormatMp4.classList.remove("active");
        updateQualityOptions("mp3");
      });
    }

    if (btnFormatMp4 && !btnFormatMp4._bound) {
      btnFormatMp4._bound = true;
      btnFormatMp4.addEventListener("click", () => {
        animateTabClick(btnFormatMp4);
        resetProgressBox();
        selectedFormat = "mp4";
        btnFormatMp4.classList.add("active");
        btnFormatMp3.classList.remove("active");
        updateQualityOptions("mp4");
      });
    }

    // Si el usuario cambia la calidad en el select oculto
    if (selectQuality && !selectQuality._bound) {
      selectQuality._bound = true;
      selectQuality.addEventListener("change", () => {
        resetProgressBox();
        if (qualityBadge && selectQuality.selectedOptions.length > 0) {
          const val = selectQuality.value;
          qualityBadge.textContent = getQualityBadgeLabel(selectedFormat, val);
          const currentOpt = (qualityOptions[selectedFormat] || []).find(o => o.value === val);
          if (currentOpt && qualityCurrent) {
            qualityCurrent.textContent = currentOpt.label;
          }
        }
      });
    }

    // Detección automática en tiempo real de la plataforma según la URL
    function detectPlatformFromUrl(url) {
      const u = (url || "").trim().toLowerCase();
      if (!u) return null;
      if (u.includes("youtube.com") || u.includes("youtu.be")) return "youtube";
      if (u.includes("tiktok.com")) return "tiktok";
      if (u.includes("instagram.com")) return "instagram";
      if (u.includes("facebook.com") || u.includes("fb.watch")) return "facebook";
      if (u.includes("twitter.com") || u.includes("x.com")) return "twitter";
      if (u.includes("pinterest.com") || u.includes("pin.it")) return "pinterest";
      if (u.startsWith("http://") || u.startsWith("https://")) return "direct";
      return null;
    }

    // Sincronizar estado visual de los botones de plataforma según la URL
    function syncDetectedPlatform(url) {
      const detected = detectPlatformFromUrl(url);
      const badge = document.getElementById("detected-platform-badge");
      document.querySelectorAll(".platform-chip").forEach(c => {
        if (detected && c.getAttribute("data-platform") === detected) {
          c.classList.add("active");
        } else {
          c.classList.remove("active");
        }
      });

      if (detected && platformNames[detected]) {
        if (badge) badge.textContent = `${platformNames[detected]} DETECTADO`;
        if (platformHoverLabel) platformHoverLabel.textContent = platformNames[detected];
      } else {
        if (badge) badge.textContent = "DETECCIÓN AUTOMÁTICA";
        if (platformHoverLabel) platformHoverLabel.textContent = "7 PLATAFORMAS";
      }
    }

    if (inputUrl && !inputUrl._bound) {
      inputUrl._bound = true;
      inputUrl.addEventListener("input", () => {
        resetProgressBox();
        hidePreviousResult();
        syncDetectedPlatform(inputUrl.value);
      });
    }

    if (batchUrls && !batchUrls._bound) {
      batchUrls._bound = true;
      batchUrls.addEventListener("input", () => {
        resetProgressBox();
        hidePreviousResult();
      });
    }

    if (btnClear && !btnClear._bound) {
      btnClear._bound = true;
      btnClear.addEventListener("click", () => {
        inputUrl.value = "";
        resetProgressBox();
        hidePreviousResult();
        syncDetectedPlatform("");
        inputUrl.focus();
      });
    }

    if (btnToggleBatch && !btnToggleBatch._bound) {
      btnToggleBatch._bound = true;
      btnToggleBatch.addEventListener("click", () => {
        resetProgressBox();
        hidePreviousResult();
        isBatchMode = !isBatchMode;
        if (isBatchMode) {
          singleBox.style.display = "none";
          batchBox.style.display = "block";
          btnToggleBatch.setAttribute("data-tooltip", "Modo Enlace Único");
          btnToggleBatch.setAttribute("aria-label", "Modo Enlace Único");
          btnToggleBatch.innerHTML = `<svg id="btn-toggle-batch-icon" class="icon" viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`;
          if (btnConvertText) btnConvertText.textContent = "CONVERTIR LOTE";
        } else {
          singleBox.style.display = "block";
          batchBox.style.display = "none";
          btnToggleBatch.setAttribute("data-tooltip", "Modo Lote (Múltiples Enlaces)");
          btnToggleBatch.setAttribute("aria-label", "Modo Lote (Múltiples Enlaces)");
          btnToggleBatch.innerHTML = `<svg id="btn-toggle-batch-icon" class="icon" viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg>`;
          if (btnConvertText) btnConvertText.textContent = "CONVERTIR MULTIMEDIA";
        }
      });
    }

    // Chips de Plataforma: Indicadores informativos con hover
    const platformHoverLabel = document.getElementById("platform-hover-label");
    const platformNames = {
      youtube: "YOUTUBE / SHORTS",
      tiktok: "TIKTOK",
      instagram: "INSTAGRAM REELS",
      facebook: "FACEBOOK",
      twitter: "TWITTER / X",
      pinterest: "PINTEREST",
      direct: "ENLACE DIRECTO"
    };

    document.querySelectorAll(".platform-chip").forEach(chip => {
      const plat = chip.getAttribute("data-platform");

      chip.addEventListener("mouseenter", () => {
        if (platformHoverLabel && platformNames[plat]) {
          platformHoverLabel.textContent = platformNames[plat];
        }
      });

      chip.addEventListener("mouseleave", () => {
        if (platformHoverLabel) {
          const detected = detectPlatformFromUrl(inputUrl.value);
          if (detected && platformNames[detected]) {
            platformHoverLabel.textContent = platformNames[detected];
          } else {
            platformHoverLabel.textContent = "7 PLATAFORMAS";
          }
        }
      });

      chip.addEventListener("click", () => {
        if (inputUrl) inputUrl.focus();
      });
    });

    // Función: Convertir (Con estados idénticos a TRADUCIR TEXTO)
    if (btnConvert && !btnConvert._bound) {
      btnConvert._bound = true;
      btnConvert.addEventListener("click", async () => {
        const quality = selectQuality ? selectQuality.value : "320k";

        if (isBatchMode) {
          const rawLines = batchUrls.value.trim().split("\n").map(l => l.trim()).filter(Boolean);
          if (rawLines.length === 0) {
            alert("Introduce al menos un enlace en el modo lote.");
            return;
          }

          hidePreviousResult();
          setFormDisabled(true);
          btnConvert.innerHTML = ICON_LOADING + ' <span id="btn-convert-text">Procesando Lote...</span>';
          progressBox.style.display = "block";
          progressBar.style.width = "40%";
          progressPercent.textContent = "40%";
          progressStatus.innerHTML = `<span class="spinner"></span> Procesando lote de ${rawLines.length} enlaces...`;

          try {
            const res = await fetch("/api/media/batch", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ urls: rawLines, format: selectedFormat, quality })
            });
            const data = await res.json();
            progressBar.style.width = "100%";
            progressPercent.textContent = "100%";

            if (data.status === "success" && data.items && data.items.length > 0) {
              const firstSuccess = data.items.find(i => i.status === "success") || data.items[0];
              displayResult(firstSuccess);
              progressStatus.textContent = `¡Lote completado! ${data.items.length} videos procesados.`;
              btnConvert.innerHTML = ICON_CHECK + ' <span id="btn-convert-text">¡Lote Listo!</span>';
              setTimeout(() => {
                btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR LOTE</span>';
                setFormDisabled(false);
              }, 1800);
            } else {
              alert(data.error || "Error al procesar el lote.");
              btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR LOTE</span>';
              setFormDisabled(false);
            }
          } catch (err) {
            alert("Error en proceso por lotes: " + err.message);
            btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR LOTE</span>';
            setFormDisabled(false);
          }
          return;
        }

        const url = (inputUrl?.value || "").trim();
        if (!url) {
          alert("Por favor introduce un enlace de video.");
          if (inputUrl) inputUrl.focus();
          return;
        }

        hidePreviousResult();
        setFormDisabled(true);
        btnConvert.innerHTML = ICON_LOADING + ' <span id="btn-convert-text">Convirtiendo...</span>';
        progressBox.style.display = "block";
        progressBar.style.width = "25%";
        progressPercent.textContent = "25%";
        progressStatus.innerHTML = `<span class="spinner"></span> Analizando protocolo y extrayendo stream...`;

        try {
          setTimeout(() => {
            if (progressBar && progressBar.style.width === "25%") {
              progressBar.style.width = "65%";
              progressPercent.textContent = "65%";
              progressStatus.innerHTML = `<span class="spinner"></span> Transcodificando a ${selectedFormat.toUpperCase()} (${quality})...`;
            }
          }, 600);

          const res = await fetch("/api/media/convert", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ url, format: selectedFormat, quality })
          });
          const data = await res.json();

          progressBar.style.width = "100%";
          progressPercent.textContent = "100%";

          if (data.status === "success") {
            progressStatus.textContent = "¡Conversión exitosa!";
            displayResult(data);
            btnConvert.innerHTML = ICON_CHECK + ' <span id="btn-convert-text">¡Convertido!</span>';
            setTimeout(() => {
              btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR MULTIMEDIA</span>';
              setFormDisabled(false);
            }, 1800);
          } else {
            alert(data.error || "Error en la conversión del video.");
            btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR MULTIMEDIA</span>';
            setFormDisabled(false);
          }
        } catch (err) {
          alert("Error de red: " + err.message);
          btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR MULTIMEDIA</span>';
          setFormDisabled(false);
        }
      });
    }

    // Actualizar visualización de duración de audio y video
    function updateDurationDisplay(seconds) {
      if (!seconds || isNaN(seconds) || !isFinite(seconds) || seconds <= 0) return;
      const m = Math.floor(seconds / 60);
      const s = Math.floor(seconds % 60);
      const durStr = `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
      if (resDuration) resDuration.textContent = durStr;
      const dText = document.getElementById("res-duration-text");
      if (dText) dText.textContent = durStr;
    }

    if (audioPlayer && !audioPlayer._boundEvents) {
      audioPlayer._boundEvents = true;
      audioPlayer.addEventListener("loadedmetadata", () => {
        updateDurationDisplay(audioPlayer.duration);
      });
      audioPlayer.addEventListener("durationchange", () => {
        updateDurationDisplay(audioPlayer.duration);
      });
    }

    if (videoPlayer && !videoPlayer._boundEvents) {
      videoPlayer._boundEvents = true;
      videoPlayer.addEventListener("loadedmetadata", () => {
        updateDurationDisplay(videoPlayer.duration);
      });
      videoPlayer.addEventListener("durationchange", () => {
        updateDurationDisplay(videoPlayer.duration);
      });
    }

    function displayResult(item) {
      if (!resultCard) return;
      resultCard.style.display = "block";
      if (resTitle) resTitle.textContent = item.title;
      if (resAuthor) resAuthor.textContent = item.author || "Autor";
      if (resThumbnail) {
        resThumbnail.src = item.thumbnail || `/api/media/thumbnail-proxy?title=${encodeURIComponent(item.title)}&platform=${encodeURIComponent(item.platform)}&author=${encodeURIComponent(item.author || "")}`;
      }
      if (resPlatform) resPlatform.textContent = (item.platform || "multimedia").toUpperCase();
      if (resFormat) resFormat.textContent = `${item.format.toUpperCase()} ${item.quality.toUpperCase()}`;
      if (resSize) resSize.textContent = item.size ? (item.size > 1024 * 1024 ? `${(item.size / (1024 * 1024)).toFixed(1)} MB` : `${Math.round(item.size / 1024)} KB`) : "Calculando...";

      if (btnDownload) {
        btnDownload.onclick = () => {
          const downloadUrl = `/api/media/download?url=${encodeURIComponent(item.streamUrl)}&title=${encodeURIComponent(item.title)}&format=${encodeURIComponent(item.format)}`;
          const a = document.createElement("a");
          a.href = downloadUrl;
          a.download = `${item.title.replace(/[^a-zA-Z0-9_\-\s]/g, "")}.${item.format}`;
          document.body.appendChild(a);
          a.click();
          a.remove();

          btnDownload.setAttribute("data-tooltip", "¡Descargando!");
          setTimeout(() => {
            btnDownload.setAttribute("data-tooltip", "Descargar");
          }, 2000);
        };
      }

      if (btnCopyStream) {
        btnCopyStream.onclick = () => {
          navigator.clipboard.writeText(item.streamUrl);
          const ICON_DEFAULT = '<svg id="copy-stream-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" fill="none" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';
          const ICON_SUCCESS = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#10b981" fill="none" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';

          btnCopyStream.setAttribute("data-tooltip", "¡Enlace Copiado!");
          btnCopyStream.innerHTML = ICON_SUCCESS;
          btnCopyStream.style.borderColor = "#10b981";

          setTimeout(() => {
            btnCopyStream.setAttribute("data-tooltip", "Copiar Enlace Directo");
            btnCopyStream.innerHTML = ICON_DEFAULT;
            btnCopyStream.style.borderColor = "";
          }, 2000);
        };
      }

      if (item.format === "mp4") {
        if (audioWrapper) audioWrapper.style.display = "none";
        if (videoWrapper) videoWrapper.style.display = "block";
        if (videoPlayer) {
          videoPlayer.src = item.streamUrl;
          try { videoPlayer.load(); } catch {}
        }
      } else {
        if (videoWrapper) videoWrapper.style.display = "none";
        if (audioWrapper) audioWrapper.style.display = "block";
        if (audioPlayer) {
          audioPlayer.src = item.streamUrl;
          try { audioPlayer.load(); } catch {}
        }
      }

      resultCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }

    // Inicializar combobox de calidad con opciones actuales
    updateQualityOptions(selectedFormat);
  }

  window.initConverterModule = initConverterModule;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initConverterModule);
  } else {
    initConverterModule();
  }
})(window, document);
