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

    const platformNames = {
      youtube: "YouTube",
      tiktok: "TikTok",
      instagram: "Instagram Reels",
      facebook: "Facebook Video",
      twitter: "Twitter / X",
      pinterest: "Pinterest Video",
      direct: "Enlace Directo",
      generic: "Multimedia"
    };

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
        { value: "256k", label: "256 kbps (Muy Alta Fidelidad)" },
        { value: "192k", label: "192 kbps (Estándar Recomendado)" },
        { value: "128k", label: "128 kbps (YouTube Original)" },
        { value: "64k", label: "64 kbps (Ahorro de Datos)" }
      ],
      mp4: [
        { value: "1440p", label: "1440p 2K Quad HD" },
        { value: "1080p", label: "1080p Full HD" },
        { value: "720p", label: "720p HD Estándar" },
        { value: "480p", label: "480p SD" },
        { value: "360p", label: "360p Móvil" },
        { value: "240p", label: "240p Ligero" },
        { value: "144p", label: "144p Ahorro Extremo" }
      ]
    };

    function getQualityBadgeLabel(fmt, value) {
      if (fmt === "mp3") {
        if (value === "320k") return "320 kbps";
        if (value === "256k") return "256 kbps";
        if (value === "192k") return "192 kbps";
        if (value === "128k") return "128 kbps";
        if (value === "64k") return "64 kbps";
        return `${value}`;
      } else {
        if (value === "1440p") return "1440p 2K";
        if (value === "1080p") return "1080p Full HD";
        if (value === "720p") return "720p HD";
        if (value === "480p") return "480p SD";
        if (value === "360p") return "360p";
        if (value === "240p") return "240p";
        if (value === "144p") return "144p";
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
      document.querySelectorAll("#batch-results-list audio, #batch-results-list video").forEach(el => {
        try {
          el.pause();
          el.currentTime = 0;
          el.removeAttribute("src");
          el.load();
        } catch {}
      });
    }

    // Ocultar resultado anterior y detener reproducción
    function hidePreviousResult() {
      if (resultCard) resultCard.style.display = "none";
      const batchContainer = document.getElementById("batch-results-container");
      if (batchContainer) batchContainer.style.display = "none";
      const batchList = document.getElementById("batch-results-list");
      if (batchList) batchList.innerHTML = "";
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
      if (progressStatus) progressStatus.textContent = "";
      if (progressPercent) progressPercent.textContent = "0%";
      if (progressBar) progressBar.style.width = "0%";
      const sub = document.getElementById("progress-sub-info");
      if (sub) sub.textContent = "Procesando flujo en alta velocidad...";
    }

    // Animación de clic para botones de formato
    function animateTabClick(btn) {
      if (!btn) return;
      btn.classList.remove("format-tab-animated");
      void btn.offsetWidth; // forzar reflow
      btn.classList.add("format-tab-animated");
      setTimeout(() => btn.classList.remove("format-tab-animated"), 360);
    }

    // Aplicar formato de salida (MP3 / MP4) con sincronización de URL (/converter/mp3 o /converter/mp4)
    function applyFormat(fmt, updateUrl = true) {
      selectedFormat = (fmt || "mp3").toLowerCase() === "mp4" ? "mp4" : "mp3";
      resetProgressBox();
      const formatBadge = document.getElementById("format-badge");

      if (selectedFormat === "mp4") {
        if (btnFormatMp4) {
          btnFormatMp4.classList.add("active");
          if (updateUrl) animateTabClick(btnFormatMp4);
        }
        if (btnFormatMp3) btnFormatMp3.classList.remove("active");
        if (formatBadge) formatBadge.textContent = "VIDEO MP4";
        updateQualityOptions("mp4");
      } else {
        if (btnFormatMp3) {
          btnFormatMp3.classList.add("active");
          if (updateUrl) animateTabClick(btnFormatMp3);
        }
        if (btnFormatMp4) btnFormatMp4.classList.remove("active");
        if (formatBadge) formatBadge.textContent = "AUDIO MP3";
        updateQualityOptions("mp3");
      }

      if (updateUrl && window.history && window.history.pushState) {
        const base = window.location.pathname.startsWith("/media") ? "/media" : "/converter";
        const targetPath = `${base}/${selectedFormat}`;
        if (window.location.pathname !== targetPath) {
          window.history.pushState({ format: selectedFormat }, "", targetPath);
        }
      }
    }

    // Conmutar Pestaña de Formato (Con animación y solo iconos con tooltips)
    if (btnFormatMp3 && !btnFormatMp3._bound) {
      btnFormatMp3._bound = true;
      btnFormatMp3.addEventListener("click", () => applyFormat("mp3", true));
    }

    if (btnFormatMp4 && !btnFormatMp4._bound) {
      btnFormatMp4._bound = true;
      btnFormatMp4.addEventListener("click", () => applyFormat("mp4", true));
    }

    // Detección inicial de formato según la URL (/converter/mp3 o /converter/mp4)
    const initialConvPath = (window.location.pathname || "").toLowerCase();
    if (initialConvPath.endsWith("/mp4")) {
      applyFormat("mp4", false);
    } else if (initialConvPath.endsWith("/mp3")) {
      applyFormat("mp3", false);
    }

    window.addEventListener("popstate", () => {
      const p = (window.location.pathname || "").toLowerCase();
      if (p.endsWith("/mp4")) {
        applyFormat("mp4", false);
      } else if (p.endsWith("/mp3")) {
        applyFormat("mp3", false);
      }
    });

    // Notificación visual flotante de silencio (Mute / Unmute Toast)
    function showMuteToast(isMuted) {
      let toast = document.getElementById("vork-mute-toast");
      if (!toast) {
        toast = document.createElement("div");
        toast.id = "vork-mute-toast";
        toast.style.position = "fixed";
        toast.style.bottom = "32px";
        toast.style.left = "50%";
        toast.style.transform = "translateX(-50%)";
        toast.style.padding = "8px 18px";
        toast.style.background = "rgba(15, 17, 23, 0.94)";
        toast.style.border = "1px solid var(--primary)";
        toast.style.borderRadius = "24px";
        toast.style.color = "#ffffff";
        toast.style.fontFamily = "var(--f-mono, monospace)";
        toast.style.fontSize = "0.82rem";
        toast.style.fontWeight = "700";
        toast.style.letterSpacing = "0.04em";
        toast.style.boxShadow = "0 8px 24px rgba(0,0,0,0.5)";
        toast.style.zIndex = "9999";
        toast.style.pointerEvents = "none";
        toast.style.transition = "opacity 0.25s ease";
        document.body.appendChild(toast);
      }
      toast.innerHTML = isMuted
        ? '🔇 VISTA PREVIA: SILENCIADA (M)'
        : '🔊 VISTA PREVIA: SONIDO ACTIVO (M)';
      toast.style.opacity = "1";
      clearTimeout(toast._timer);
      toast._timer = setTimeout(() => {
        toast.style.opacity = "0";
      }, 1200);
    }

    // Atajo de teclado: 'M' o 'm' silencia o des-silencia la vista previa de audio o video
    window.addEventListener("keydown", (e) => {
      if (e.key === "m" || e.key === "M" || e.code === "KeyM") {
        const target = e.target;
        if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) {
          return;
        }

        const players = [];
        if (videoPlayer) players.push(videoPlayer);
        if (audioPlayer) players.push(audioPlayer);
        document.querySelectorAll(".item-media-player, #batch-results-list video, #batch-results-list audio").forEach(p => {
          if (!players.includes(p)) players.push(p);
        });

        if (players.length === 0) return;

        const activePlaying = players.filter(p => !p.paused && p.currentTime > 0);
        const targetList = activePlaying.length > 0 ? activePlaying : players;

        const shouldMute = targetList.some(p => !p.muted);
        targetList.forEach(p => {
          p.muted = shouldMute;
        });

        showMuteToast(shouldMute);
      }
    });

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
      document.querySelectorAll(".platform-chip").forEach(c => {
        if (detected && c.getAttribute("data-platform") === detected) {
          c.classList.add("active");
        } else {
          c.classList.remove("active");
        }
      });
    }

    // Sincronizar estado visual de los botones de plataforma en modo lote (múltiples enlaces simultáneos)
    function syncDetectedPlatformsFromBatch(text) {
      const tokens = (text || "").split(/[\r\n\s]+/).map(l => l.trim()).filter(Boolean);
      const detectedPlatforms = new Set();
      tokens.forEach(tok => {
        const p = detectPlatformFromUrl(tok);
        if (p) detectedPlatforms.add(p);
      });
      document.querySelectorAll(".platform-chip").forEach(c => {
        const plat = c.getAttribute("data-platform");
        if (detectedPlatforms.has(plat)) {
          c.classList.add("active");
        } else {
          c.classList.remove("active");
        }
      });
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
        syncDetectedPlatformsFromBatch(batchUrls.value);
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

    const singleActionSlot = document.getElementById("single-action-slot");
    const batchActionSlot = document.getElementById("batch-action-slot");

    if (btnToggleBatch && !btnToggleBatch._bound) {
      btnToggleBatch._bound = true;
      btnToggleBatch.addEventListener("click", () => {
        resetProgressBox();
        hidePreviousResult();
        isBatchMode = !isBatchMode;
        if (isBatchMode) {
          singleBox.style.display = "none";
          batchBox.style.display = "block";
          if (batchActionSlot && btnConvert) {
            batchActionSlot.appendChild(btnConvert);
          }
          btnToggleBatch.setAttribute("data-tooltip", "Modo Enlace Único");
          btnToggleBatch.setAttribute("aria-label", "Modo Enlace Único");
          btnToggleBatch.innerHTML = `<svg id="btn-toggle-batch-icon" class="icon" viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`;
          if (btnConvertText) btnConvertText.textContent = "CONVERTIR LOTE";
          syncDetectedPlatformsFromBatch(batchUrls ? batchUrls.value : "");
        } else {
          singleBox.style.display = "block";
          batchBox.style.display = "none";
          if (singleActionSlot && btnConvert) {
            singleActionSlot.appendChild(btnConvert);
          }
          btnToggleBatch.setAttribute("data-tooltip", "Modo Lote (Múltiples Enlaces)");
          btnToggleBatch.setAttribute("aria-label", "Modo Lote (Múltiples Enlaces)");
          btnToggleBatch.innerHTML = `<svg id="btn-toggle-batch-icon" class="icon" viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg>`;
          if (btnConvertText) btnConvertText.textContent = "CONVERTIR MULTIMEDIA";
          syncDetectedPlatform(inputUrl ? inputUrl.value : "");
        }
      });
    }

    // Chips de Plataforma
    document.querySelectorAll(".platform-chip").forEach(chip => {
      chip.addEventListener("click", () => {
        if (isBatchMode) {
          if (batchUrls) batchUrls.focus();
        } else {
          if (inputUrl) inputUrl.focus();
        }
      });
    });

    // Función: Convertir (Con estados idénticos a TRADUCIR TEXTO)
    if (btnConvert && !btnConvert._bound) {
      btnConvert._bound = true;
      btnConvert.addEventListener("click", async () => {
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
              body: JSON.stringify({ urls: rawLines, format: selectedFormat })
            });
            const data = await res.json();
            progressBar.style.width = "100%";
            progressPercent.textContent = "100%";

            if (data.status === "success" && data.items && data.items.length > 0) {
              progressBox.style.display = "none";
              displayBatchResults(data.items);
              btnConvert.innerHTML = ICON_CHECK + ' <span id="btn-convert-text">¡Lote Listo!</span>';
              setTimeout(() => {
                btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR LOTE</span>';
                setFormDisabled(false);
              }, 1800);
            } else {
              progressBox.style.display = "none";
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

        const detected = detectPlatformFromUrl(url) || "generic";
        const platName = (platformNames[detected] || "MULTIMEDIA").split(" ")[0];

        const progressSub = document.getElementById("progress-sub-info");

        hidePreviousResult();
        setFormDisabled(true);
        btnConvert.innerHTML = ICON_LOADING + ' <span id="btn-convert-text">Convirtiendo...</span>';
        progressBox.style.display = "block";
        progressBar.style.width = "30%";
        progressPercent.textContent = "30%";
        if (progressStatus) progressStatus.textContent = `Conectando con servidores de ${platName}...`;
        if (progressSub) progressSub.textContent = `Analizando flujos directos (${selectedFormat.toUpperCase()})...`;

        const timer1 = setTimeout(() => {
          if (progressBar && progressBar.style.width === "30%") {
            progressBar.style.width = "65%";
            progressPercent.textContent = "65%";
            if (progressStatus) progressStatus.textContent = `Extrayendo flujos directos y metadatos...`;
            if (progressSub) progressSub.textContent = "Descargando flujos en paralelo de alta velocidad...";
          }
        }, 350);

        const timer2 = setTimeout(() => {
          if (progressBar && progressBar.style.width === "65%") {
            progressBar.style.width = "88%";
            progressPercent.textContent = "88%";
            if (progressStatus) progressStatus.textContent = `Procesando contenedor ${selectedFormat.toUpperCase()}...`;
            if (progressSub) progressSub.textContent = "Optimizando archivo para reproducción y descarga instantánea...";
          }
        }, 750);

        try {
          const res = await fetch("/api/media/convert", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ url, format: selectedFormat })
          });
          const data = await res.json();

          clearTimeout(timer1);
          clearTimeout(timer2);
          progressBar.style.width = "100%";
          progressPercent.textContent = "100%";

          if (data.status === "success") {
            progressBox.style.display = "none";
            displayResult(data);
            btnConvert.innerHTML = ICON_CHECK + ' <span id="btn-convert-text">¡Listo!</span>';
            setTimeout(() => {
              btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR MULTIMEDIA</span>';
              setFormDisabled(false);
            }, 1800);
          } else {
            progressBox.style.display = "none";
            alert(data.error || "Error en la conversión del video.");
            btnConvert.innerHTML = ICON_CONVERT + ' <span id="btn-convert-text">CONVERTIR MULTIMEDIA</span>';
            setFormDisabled(false);
          }
        } catch (err) {
          clearTimeout(timer1);
          clearTimeout(timer2);
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
      const dMini = document.getElementById("res-duration-mini");
      if (dMini) dMini.textContent = durStr;
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
      const batchContainer = document.getElementById("batch-results-container");
      if (batchContainer) batchContainer.style.display = "none";
      resultCard.style.display = "block";

      // Título y Autor
      if (resTitle) resTitle.textContent = item.title || "Video Multimedia";
      if (resAuthor) resAuthor.textContent = item.author || "Canal / Creador";

      // Miniatura
      if (resThumbnail) {
        resThumbnail.src = item.thumbnail || `/api/media/thumbnail-proxy?title=${encodeURIComponent(item.title || "")}&platform=${encodeURIComponent(item.platform || "")}&author=${encodeURIComponent(item.author || "")}`;
      }

      // Plataforma con color temático
      if (resPlatform) {
        const plat = (item.platformId || item.platform || "multimedia").toLowerCase();
        resPlatform.textContent = (item.platform || "MULTIMEDIA").toUpperCase();
        if (plat.includes("youtube")) {
          resPlatform.style.background = "linear-gradient(135deg, #ff0000 0%, #b80000 100%)";
          resPlatform.style.borderColor = "#ff3b3b";
        } else if (plat.includes("tiktok")) {
          resPlatform.style.background = "#09090b";
          resPlatform.style.borderColor = "#00f2fe";
        } else if (plat.includes("instagram")) {
          resPlatform.style.background = "linear-gradient(45deg, #f09433 0%, #dc2743 50%, #bc1888 100%)";
          resPlatform.style.borderColor = "#f77737";
        } else if (plat.includes("facebook")) {
          resPlatform.style.background = "#1877f2";
          resPlatform.style.borderColor = "#4292f8";
        } else if (plat.includes("twitter") || plat === "x") {
          resPlatform.style.background = "#0f1117";
          resPlatform.style.borderColor = "#ffffff";
        } else {
          resPlatform.style.background = "rgba(0, 0, 0, 0.78)";
          resPlatform.style.borderColor = "rgba(255, 255, 255, 0.18)";
        }
      }

      // Pill de Formato y Calidad (Estilo HD moderno con icono correspondiente)
      const isSingleQuality = ["tiktok", "instagram"].includes((item.platformId || item.platform || "").toLowerCase());
      if (resFormat) {
        const isMp4 = item.format === "mp4";
        const fmtName = isMp4 ? "MP4" : (item.format === "wav" ? "WAV" : "MP3");
        const defaultQ = (item.availableQualities && item.availableQualities[0]?.id) || (isMp4 ? "1080p" : "320k");
        const qualText = isSingleQuality ? "HD ORIGINAL" : (item.quality || defaultQ).toUpperCase();

        resFormat.className = `format-result-pill ${isMp4 ? "pill-mp4" : "pill-mp3"}`;
        resFormat.innerHTML = `
          <span class="pill-media-icon-box">
            ${isMp4
              ? '<svg class="pill-media-icon icon-video" viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="14" x="2" y="5" rx="2"/><polyline points="17 9 22 6 22 18 17 15"/></svg>'
              : '<svg class="pill-media-icon icon-audio" viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>'
            }
          </span>
          <span class="pill-tag-text" id="res-format-tag">${fmtName}</span>
          <span class="pill-divider">·</span>
          <span class="pill-quality-text" id="res-quality-tag">${qualText}</span>
        `;
      }

      // Duración en badges y stats
      const durStr = item.duration && item.duration !== "00:00" ? item.duration : (item.durationSeconds ? `${Math.floor(item.durationSeconds / 60).toString().padStart(2, '0')}:${(item.durationSeconds % 60).toString().padStart(2, '0')}` : "00:00");
      if (resDuration) resDuration.textContent = durStr;
      const dMini = document.getElementById("res-duration-mini");
      if (dMini) dMini.textContent = durStr;
      const dText = document.getElementById("res-duration-text");
      if (dText) dText.textContent = durStr;

      // Tamaño formateado
      if (resSize) {
        const firstQualSize = item.availableQualities && item.availableQualities[0]?.sizeFormatted;
        resSize.textContent = item.sizeFormatted || firstQualSize || (item.sizeBytes ? (item.sizeBytes > 1024 * 1024 ? `${(item.sizeBytes / (1024 * 1024)).toFixed(1)} MB` : `${Math.round(item.sizeBytes / 1024)} KB`) : "12.0 MB");
      }

      // Estado
      const statVal = document.getElementById("res-status-val");
      if (statVal) statVal.textContent = "COMPLETADO";

      // Gestión de Calidad y Pistas de Audio
      let currentQualityId = item.selectedQuality || item.quality || (item.availableQualities && item.availableQualities[0]?.id) || (item.format === "mp4" ? "1080p" : "320k");
      let currentAudioTrackId = item.selectedAudioTrack || (item.audioTracks && item.audioTracks[0]?.id) || null;

      function getActiveMediaUrl() {
        const isMp4 = item.format === "mp4";
        const base = isMp4 ? (item.videoUrl || item.streamUrl) : (item.audioUrl || item.streamUrl || item.videoUrl);
        if (!base) return "";
        let cleanBase = base.replace(/([?&])(audioTrack|quality)=[^&]*/g, "");
        cleanBase = cleanBase.replace(/\?&/, "?").replace(/&&/, "&").replace(/[?&]$/, "");
        const sep = cleanBase.includes("?") ? "&" : "?";
        const params = [];
        if (currentAudioTrackId) params.push(`audioTrack=${encodeURIComponent(currentAudioTrackId)}`);
        if (currentQualityId) params.push(`quality=${encodeURIComponent(currentQualityId)}`);
        return params.length > 0 ? `${cleanBase}${sep}${params.join("&")}` : cleanBase;
      }

      function getDownloadTarget() {
        const base = item.downloadUrl || `/api/media/download?id=${item.id}`;
        let cleanBase = base.replace(/([?&])(audioTrack|quality)=[^&]*/g, "");
        cleanBase = cleanBase.replace(/\?&/, "?").replace(/&&/, "&").replace(/[?&]$/, "");
        const sep = cleanBase.includes("?") ? "&" : "?";
        const params = [];
        if (currentAudioTrackId) params.push(`audioTrack=${encodeURIComponent(currentAudioTrackId)}`);
        if (currentQualityId) params.push(`quality=${encodeURIComponent(currentQualityId)}`);
        return params.length > 0 ? `${cleanBase}${sep}${params.join("&")}` : cleanBase;
      }

      function applyMediaStreamChange() {
        const newUrl = getActiveMediaUrl();

        if (item.format === "mp4") {
          if (videoPlayer) {
            const wasPlaying = !videoPlayer.paused && !videoPlayer.ended && videoPlayer.currentTime > 0;
            const prevTime = videoPlayer.currentTime || 0;
            videoPlayer.src = newUrl;
            try {
              videoPlayer.load();
              if (prevTime > 0) {
                const onMeta = () => {
                  videoPlayer.removeEventListener("loadedmetadata", onMeta);
                  try { videoPlayer.currentTime = prevTime; } catch {}
                  if (wasPlaying) videoPlayer.play().catch(() => {});
                };
                videoPlayer.addEventListener("loadedmetadata", onMeta);
              } else if (wasPlaying) {
                videoPlayer.play().catch(() => {});
              }
            } catch {}
          }
        } else {
          if (audioPlayer) {
            const wasPlaying = !audioPlayer.paused && !audioPlayer.ended && audioPlayer.currentTime > 0;
            const prevTime = audioPlayer.currentTime || 0;
            audioPlayer.src = newUrl;
            try {
              audioPlayer.load();
              if (prevTime > 0) {
                const onMeta = () => {
                  audioPlayer.removeEventListener("loadedmetadata", onMeta);
                  try { audioPlayer.currentTime = prevTime; } catch {}
                  if (wasPlaying) audioPlayer.play().catch(() => {});
                };
                audioPlayer.addEventListener("loadedmetadata", onMeta);
              } else if (wasPlaying) {
                audioPlayer.play().catch(() => {});
              }
            } catch {}
          }
        }
      }

      // Selector de Calidades Dinámicas (Oculto para TikTok e Instagram)
      const qualitiesRow = document.getElementById("res-qualities-row");
      const qualitiesList = document.getElementById("res-qualities-list");

      if (qualitiesRow && qualitiesList) {
        if (!isSingleQuality && item.availableQualities && item.availableQualities.length > 1) {
          qualitiesList.innerHTML = "";
          qualitiesRow.style.display = "flex";

          item.availableQualities.forEach(q => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = `res-quality-chip${q.id === currentQualityId ? " active" : ""}`;
            btn.textContent = q.label;
            if (q.sizeFormatted) {
              btn.title = `Tamaño estimado: ${q.sizeFormatted}`;
            }
            btn.onclick = (e) => {
              e.preventDefault();
              if (currentQualityId === q.id) return;
              currentQualityId = q.id;
              qualitiesList.querySelectorAll(".res-quality-chip").forEach(c => c.classList.remove("active"));
              btn.classList.add("active");

              // Actualizar badge de calidad en cabecera
              const qTag = document.getElementById("res-quality-tag");
              if (qTag) qTag.textContent = q.label.toUpperCase();

              // Actualizar tamaño estimado en metadatos
              if (resSize && q.sizeFormatted) {
                resSize.textContent = q.sizeFormatted;
              }

              applyMediaStreamChange();
            };
            qualitiesList.appendChild(btn);
          });
        } else {
          qualitiesRow.style.display = "none";
        }
      }

      // Pistas de Audio Disponibles (Multi-Audio YouTube)
      const tracksRow = document.getElementById("res-audio-tracks-row");
      const tracksList = document.getElementById("res-audio-tracks-list");

      if (tracksRow && tracksList) {
        if (item.audioTracks && item.audioTracks.length > 1) {
          tracksList.innerHTML = "";
          tracksRow.style.display = "flex";

          item.audioTracks.forEach(track => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = `res-track-chip${track.id === currentAudioTrackId ? " active" : ""}`;
            btn.textContent = track.label;
            btn.onclick = (e) => {
              e.preventDefault();
              if (currentAudioTrackId === track.id) return;
              currentAudioTrackId = track.id;
              tracksList.querySelectorAll(".res-track-chip").forEach(c => c.classList.remove("active"));
              btn.classList.add("active");
              applyMediaStreamChange();
            };
            tracksList.appendChild(btn);
          });
        } else {
          tracksRow.style.display = "none";
        }
      }

      const downloadTooltip = item.format === "mp4" ? "Descargar MP4" : "Descargar MP3";

      if (btnDownload) {
        btnDownload.setAttribute("data-tooltip", downloadTooltip);
        btnDownload.setAttribute("aria-label", downloadTooltip);
        btnDownload.innerHTML = '<svg id="download-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#ffffff" fill="none" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>';

        btnDownload.onclick = () => {
          const a = document.createElement("a");
          a.href = getDownloadTarget();
          a.download = item.filename || `${(item.title || "video").replace(/[^a-zA-Z0-9_\-\s]/g, "")}.${item.format || "mp3"}`;
          document.body.appendChild(a);
          a.click();
          a.remove();

          btnDownload.setAttribute("data-tooltip", "¡Descargando!");
          btnDownload.innerHTML = '<svg id="download-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';

          setTimeout(() => {
            btnDownload.setAttribute("data-tooltip", downloadTooltip);
            btnDownload.innerHTML = '<svg id="download-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#ffffff" fill="none" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>';
          }, 2200);
        };
      }

      if (btnCopyStream) {
        btnCopyStream.setAttribute("data-tooltip", "Copiar Enlace");
        btnCopyStream.setAttribute("aria-label", "Copiar Enlace");
        btnCopyStream.innerHTML = '<svg id="copy-stream-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" fill="none" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';

        btnCopyStream.onclick = () => {
          const downloadTarget = getDownloadTarget();
          const copyUrl = downloadTarget ? (downloadTarget.startsWith("http") ? downloadTarget : `${window.location.origin}${downloadTarget}`) : "";
          navigator.clipboard.writeText(copyUrl);

          btnCopyStream.setAttribute("data-tooltip", "¡Enlace Copiado!");
          btnCopyStream.innerHTML = '<svg id="copy-stream-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#10b981" fill="none" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>';
          btnCopyStream.style.borderColor = "#10b981";

          setTimeout(() => {
            btnCopyStream.setAttribute("data-tooltip", "Copiar Enlace");
            btnCopyStream.style.borderColor = "";
            btnCopyStream.innerHTML = '<svg id="copy-stream-icon" class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" fill="none" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';
          }, 2000);
        };
      }

      const initialMediaUrl = getActiveMediaUrl();
      if (item.format === "mp4") {
        if (audioWrapper) audioWrapper.style.display = "none";
        if (videoWrapper) videoWrapper.style.display = "block";
        if (videoPlayer) {
          videoPlayer.src = initialMediaUrl;
          try { videoPlayer.load(); } catch {}
        }
      } else {
        if (videoWrapper) videoWrapper.style.display = "none";
        if (audioWrapper) audioWrapper.style.display = "block";
        if (audioPlayer) {
          audioPlayer.src = initialMediaUrl;
          try { audioPlayer.load(); } catch {}
        }
      }

      resultCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }

    function escapeHtml(str) {
      if (!str) return "";
      return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }

    function getPlatformBadgeStyle(platformId, platform) {
      const plat = (platformId || platform || "").toLowerCase();
      if (plat.includes("youtube")) {
        return "background: linear-gradient(135deg, #ff0000 0%, #b80000 100%); border-color: #ff3b3b;";
      } else if (plat.includes("tiktok")) {
        return "background: #09090b; border-color: #00f2fe;";
      } else if (plat.includes("instagram")) {
        return "background: linear-gradient(45deg, #f09433 0%, #dc2743 50%, #bc1888 100%); border-color: #f77737;";
      } else if (plat.includes("facebook")) {
        return "background: #1877f2; border-color: #4292f8;";
      } else if (plat.includes("twitter") || plat === "x") {
        return "background: #0f1117; border-color: #ffffff;";
      } else {
        return "background: rgba(0, 0, 0, 0.78); border-color: rgba(255, 255, 255, 0.18);";
      }
    }

    function createResultCardElement(item) {
      const card = document.createElement("div");
      card.className = "result-showcase-card";

      if (item.status === "error") {
        card.innerHTML = `
          <div class="result-card-inner" style="align-items: center; padding: 10px 0;">
            <div style="flex: 1;">
              <span class="res-platform-tag" style="position: static; background: #ef4444; border-color: #f87171; display: inline-block; margin-bottom: 8px;">ERROR EN ENLACE</span>
              <h4 style="margin: 0 0 6px 0; color: var(--ink); font-size: 1.05rem; word-break: break-all;">${escapeHtml(item.url || "Enlace Multimedia")}</h4>
              <p style="margin: 0; color: #ef4444; font-size: 0.88rem;">${escapeHtml(item.error || "No se pudo procesar este enlace")}</p>
            </div>
          </div>
        `;
        return card;
      }

      const isMp4 = item.format === "mp4";
      const fmtName = isMp4 ? "MP4" : (item.format === "wav" ? "WAV" : "MP3");
      const isSingleQuality = ["tiktok", "instagram"].includes((item.platformId || item.platform || "").toLowerCase());
      const defaultQ = (item.availableQualities && item.availableQualities[0]?.id) || (isMp4 ? "1080p" : "320k");
      let currentQualityId = item.selectedQuality || item.quality || defaultQ;
      let currentAudioTrackId = item.selectedAudioTrack || (item.audioTracks && item.audioTracks[0]?.id) || null;

      const durStr = item.duration && item.duration !== "00:00" ? item.duration : (item.durationSeconds ? `${Math.floor(item.durationSeconds / 60).toString().padStart(2, '0')}:${(item.durationSeconds % 60).toString().padStart(2, '0')}` : "00:00");
      const firstQualSize = item.availableQualities && item.availableQualities[0]?.sizeFormatted;
      const initialSize = item.sizeFormatted || firstQualSize || (item.sizeBytes ? (item.sizeBytes > 1024 * 1024 ? `${(item.sizeBytes / (1024 * 1024)).toFixed(1)} MB` : `${Math.round(item.sizeBytes / 1024)} KB`) : "12.0 MB");

      const thumbUrl = item.thumbnail || `/api/media/thumbnail-proxy?title=${encodeURIComponent(item.title || "")}&platform=${encodeURIComponent(item.platform || "")}&author=${encodeURIComponent(item.author || "")}`;
      const platLabel = (item.platform || "MULTIMEDIA").toUpperCase();
      const platStyle = getPlatformBadgeStyle(item.platformId, item.platform);
      const qualTagText = isSingleQuality ? "HD ORIGINAL" : (currentQualityId || defaultQ).toUpperCase();

      function getActiveMediaUrl() {
        const base = isMp4 ? (item.videoUrl || item.streamUrl) : (item.audioUrl || item.streamUrl || item.videoUrl);
        if (!base) return "";
        let cleanBase = base.replace(/([?&])(audioTrack|quality)=[^&]*/g, "");
        cleanBase = cleanBase.replace(/\?&/, "?").replace(/&&/, "&").replace(/[?&]$/, "");
        const sep = cleanBase.includes("?") ? "&" : "?";
        const params = [];
        if (currentAudioTrackId) params.push(`audioTrack=${encodeURIComponent(currentAudioTrackId)}`);
        if (currentQualityId) params.push(`quality=${encodeURIComponent(currentQualityId)}`);
        return params.length > 0 ? `${cleanBase}${sep}${params.join("&")}` : cleanBase;
      }

      function getDownloadTarget() {
        const base = item.downloadUrl || `/api/media/download?id=${item.id}`;
        let cleanBase = base.replace(/([?&])(audioTrack|quality)=[^&]*/g, "");
        cleanBase = cleanBase.replace(/\?&/, "?").replace(/&&/, "&").replace(/[?&]$/, "");
        const sep = cleanBase.includes("?") ? "&" : "?";
        const params = [];
        if (currentAudioTrackId) params.push(`audioTrack=${encodeURIComponent(currentAudioTrackId)}`);
        if (currentQualityId) params.push(`quality=${encodeURIComponent(currentQualityId)}`);
        return params.length > 0 ? `${cleanBase}${sep}${params.join("&")}` : cleanBase;
      }

      const mediaIconSvg = isMp4
        ? '<svg class="pill-media-icon icon-video" viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="14" x="2" y="5" rx="2"/><polyline points="17 9 22 6 22 18 17 15"/></svg>'
        : '<svg class="pill-media-icon icon-audio" viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>';

      card.innerHTML = `
        <div class="result-card-inner">
          <div class="res-thumb-container">
            <div class="res-thumb-frame">
              <img class="res-thumbnail" src="${thumbUrl}" alt="Miniatura de Video" referrerpolicy="no-referrer" onerror="this.onerror=null; this.src='/img/brand/logo.png';">
              <div class="res-thumb-gradient"></div>
              <span class="res-platform-tag" style="${platStyle}">${platLabel}</span>
              <span class="res-duration-tag item-dur-tag">${durStr}</span>
            </div>
          </div>
          <div class="res-details-container">
            <div class="res-header-bar">
              <div class="format-result-pill ${isMp4 ? "pill-mp4" : "pill-mp3"}">
                <span class="pill-media-icon-box">${mediaIconSvg}</span>
                <span class="pill-tag-text">${fmtName}</span>
                <span class="pill-divider">·</span>
                <span class="pill-quality-text item-qual-tag">${qualTagText}</span>
              </div>
            </div>
            <h3 class="res-media-title">${escapeHtml(item.title || "Video Multimedia")}</h3>
            <p class="res-author-name">${escapeHtml(item.author || "Canal / Autor")}</p>
            <div class="res-meta-inline">
              <span>DURACIÓN: <strong class="item-dur-text" style="color: var(--accent);">${durStr}</strong></span>
              <span>TAMAÑO: <strong class="item-size-text" style="color: var(--ink);">${initialSize}</strong></span>
              <span>ESTADO: <strong style="color: #10b981;">COMPLETADO</strong></span>
              <span>TTL EN CACHÉ: <strong style="color: var(--accent);">30 MIN</strong></span>
            </div>
            <div class="res-qualities-row item-qualities-row" style="display: none;">
              <span class="res-tracks-label">
                <svg class="icon" viewBox="0 0 24 24" width="13" height="13" stroke="currentColor" fill="none" stroke-width="2.2"><polygon points="6 3 20 12 6 21 6 3"/></svg>
                CALIDAD:
              </span>
              <div class="res-tracks-list item-qualities-list"></div>
            </div>
            <div class="res-audio-tracks-row item-tracks-row" style="display: none;">
              <span class="res-tracks-label">
                <svg class="icon" viewBox="0 0 24 24" width="13" height="13" stroke="currentColor" fill="none" stroke-width="2.2"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>
                PISTA DE AUDIO:
              </span>
              <div class="res-tracks-list item-tracks-list"></div>
            </div>
            <div class="media-player-wrapper ${isMp4 ? 'video-frame' : 'audio-frame'}">
              ${isMp4
                ? `<video class="item-media-player" controls preload="metadata" src="${getActiveMediaUrl()}"></video>`
                : `<audio class="item-media-player" controls preload="metadata" src="${getActiveMediaUrl()}"></audio>`
              }
            </div>
            <div class="res-actions-footer" style="display: flex; justify-content: space-between; align-items: center; margin-top: 6px; padding-top: 10px; border-top: 1px solid var(--line);">
              <span style="font-size: 0.78rem; color: var(--muted); font-family: var(--f-mono);">Motor Multimedia Vork · Pilar 03</span>
              <div style="display: flex; gap: 8px; margin-left: auto;">
                <button type="button" class="btn-icon-tooltip btn-download-accent item-btn-download" aria-label="${isMp4 ? 'Descargar MP4' : 'Descargar MP3'}" data-tooltip="${isMp4 ? 'Descargar MP4' : 'Descargar MP3'}" style="width: 42px; height: 42px;">
                  <svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#ffffff" fill="none" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>
                </button>
                <button type="button" class="btn-icon-tooltip item-btn-copy" aria-label="Copiar Enlace" data-tooltip="Copiar Enlace" style="width: 42px; height: 42px;">
                  <svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" fill="none" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      `;

      const player = card.querySelector(".item-media-player");
      const durTag = card.querySelector(".item-dur-tag");
      const durText = card.querySelector(".item-dur-text");
      const qualTag = card.querySelector(".item-qual-tag");
      const sizeTextEl = card.querySelector(".item-size-text");
      const qRow = card.querySelector(".item-qualities-row");
      const qList = card.querySelector(".item-qualities-list");
      const tRow = card.querySelector(".item-tracks-row");
      const tList = card.querySelector(".item-tracks-list");
      const btnDl = card.querySelector(".item-btn-download");
      const btnCp = card.querySelector(".item-btn-copy");

      if (player) {
        player.addEventListener("loadedmetadata", () => {
          if (player.duration && isFinite(player.duration) && player.duration > 0) {
            const m = Math.floor(player.duration / 60);
            const s = Math.floor(player.duration % 60);
            const liveDur = `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
            if (durTag) durTag.textContent = liveDur;
            if (durText) durText.textContent = liveDur;
          }
        });
      }

      function applyCardStreamChange() {
        const newUrl = getActiveMediaUrl();
        if (player) {
          const wasPlaying = !player.paused && !player.ended && player.currentTime > 0;
          const prevTime = player.currentTime || 0;
          player.src = newUrl;
          try {
            player.load();
            if (prevTime > 0) player.currentTime = prevTime;
            if (wasPlaying) player.play().catch(() => {});
          } catch {}
        }
      }

      // Qualities
      if (!isSingleQuality && item.availableQualities && item.availableQualities.length > 1 && qRow && qList) {
        qRow.style.display = "flex";
        item.availableQualities.forEach(q => {
          const btn = document.createElement("button");
          btn.type = "button";
          btn.className = `res-quality-chip${q.id === currentQualityId ? " active" : ""}`;
          btn.textContent = q.label;
          if (q.sizeFormatted) btn.title = `Tamaño estimado: ${q.sizeFormatted}`;
          btn.onclick = (e) => {
            e.preventDefault();
            if (currentQualityId === q.id) return;
            currentQualityId = q.id;
            qList.querySelectorAll(".res-quality-chip").forEach(c => c.classList.remove("active"));
            btn.classList.add("active");
            if (qualTag) qualTag.textContent = q.label.toUpperCase();
            if (sizeTextEl && q.sizeFormatted) sizeTextEl.textContent = q.sizeFormatted;
            applyCardStreamChange();
          };
          qList.appendChild(btn);
        });
      }

      // Audio tracks
      if (item.audioTracks && item.audioTracks.length > 1 && tRow && tList) {
        tRow.style.display = "flex";
        item.audioTracks.forEach(tr => {
          const btn = document.createElement("button");
          btn.type = "button";
          btn.className = `res-track-chip${tr.id === currentAudioTrackId ? " active" : ""}`;
          btn.textContent = tr.label;
          btn.onclick = (e) => {
            e.preventDefault();
            if (currentAudioTrackId === tr.id) return;
            currentAudioTrackId = tr.id;
            tList.querySelectorAll(".res-track-chip").forEach(c => c.classList.remove("active"));
            btn.classList.add("active");
            applyCardStreamChange();
          };
          tList.appendChild(btn);
        });
      }

      // Download
      if (btnDl) {
        btnDl.onclick = () => {
          const a = document.createElement("a");
          a.href = getDownloadTarget();
          a.download = item.filename || `${(item.title || "video").replace(/[^a-zA-Z0-9_\-\s]/g, "")}.${item.format || "mp3"}`;
          document.body.appendChild(a);
          a.click();
          a.remove();

          const origTooltip = isMp4 ? "Descargar MP4" : "Descargar MP3";
          btnDl.setAttribute("data-tooltip", "¡Descargando!");
          btnDl.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
          setTimeout(() => {
            btnDl.setAttribute("data-tooltip", origTooltip);
            btnDl.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#ffffff" fill="none" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>';
          }, 2200);
        };
      }

      // Copy Link (Download Link)
      if (btnCp) {
        btnCp.onclick = () => {
          const downloadTarget = getDownloadTarget();
          const copyUrl = downloadTarget ? (downloadTarget.startsWith("http") ? downloadTarget : `${window.location.origin}${downloadTarget}`) : "";
          navigator.clipboard.writeText(copyUrl);

          btnCp.setAttribute("data-tooltip", "¡Enlace Copiado!");
          btnCp.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#10b981" fill="none" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>';
          btnCp.style.borderColor = "#10b981";
          setTimeout(() => {
            btnCp.setAttribute("data-tooltip", "Copiar Enlace");
            btnCp.style.borderColor = "";
            btnCp.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" fill="none" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';
          }, 2000);
        };
      }

      return card;
    }

    function displayBatchResults(items) {
      if (resultCard) resultCard.style.display = "none";
      const batchContainer = document.getElementById("batch-results-container");
      const batchList = document.getElementById("batch-results-list");
      const batchCounter = document.getElementById("batch-results-counter");
      const btnDownloadAll = document.getElementById("btn-download-all-batch");

      if (!batchContainer || !batchList) return;

      batchContainer.style.display = "block";
      if (batchCounter) batchCounter.textContent = `ENLACES CONVERTIDOS (${items.length})`;
      batchList.innerHTML = "";

      items.forEach(item => {
        const card = createResultCardElement(item);
        batchList.appendChild(card);
      });

      if (btnDownloadAll) {
        btnDownloadAll.onclick = () => {
          const successItems = items.filter(i => i.status === "success");
          if (successItems.length === 0) return;
          successItems.forEach((it, idx) => {
            setTimeout(() => {
              const a = document.createElement("a");
              a.href = it.downloadUrl || `/api/media/download?id=${it.id}`;
              a.download = it.filename || `vork_media_${idx + 1}.${it.format || "mp3"}`;
              document.body.appendChild(a);
              a.click();
              a.remove();
            }, idx * 400);
          });
        };
      }

      batchContainer.scrollIntoView({ behavior: "smooth", block: "nearest" });
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
