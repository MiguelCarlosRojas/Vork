/**
 * vocal-remover.js
 * Lógica modular del front-end para vocal-remover.html
 */

(function (window, document) {
  "use strict";

document.addEventListener("DOMContentLoaded", () => {
      // Elementos de Modo y Pestañas
      const tabUrl = document.getElementById("tab-mode-url");
      const tabFile = document.getElementById("tab-mode-file");
      const panelUrl = document.getElementById("panel-url");
      const panelFile = document.getElementById("panel-file");
      const platformsBox = document.getElementById("platforms-selector-box");
      const platformsBoxTitle = document.getElementById("platforms-box-title");
      const platformsChipsRow = document.getElementById("platforms-chips-row");
      const formatsChipsRow = document.getElementById("formats-chips-row");
      const stemModeBadge = document.getElementById("stem-mode-badge");

      const urlActionSlot = document.getElementById("url-action-slot");
      const fileActionSlot = document.getElementById("file-action-slot");

      let currentMode = "url";
      let selectedFormat = "mp3";
      let selectedFileBase64 = null;
      let selectedFileName = "";

      // Elementos del Proceso y Controles
      const inputUrl = document.getElementById("input-media-url");
      const btnClear = document.getElementById("btn-clear-url");
      const btnPaste = document.getElementById("btn-paste-clipboard");

      const btnProcess = document.getElementById("btn-process-split");
      const progressBox = document.getElementById("progress-box");
      const progressBar = document.getElementById("progress-bar");
      const progressPercent = document.getElementById("progress-percent");
      const progressStatus = document.getElementById("progress-status");
      const progressSubInfo = document.getElementById("progress-sub-info");
      const resultBox = document.getElementById("result-box");

      const audioInst = document.getElementById("audio-inst");
      const audioVoc = document.getElementById("audio-voc");

      // Iconos SVG para el botón de Separación (Idénticos al Conversor)
      const ICON_SPLIT = '<svg id="btn-split-icon" class="btn-action-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/></svg>';
      const ICON_LOADING = '<svg class="spin-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" stroke-opacity="0.25" stroke="currentColor"/><path d="M12 2a10 10 0 0 1 10 10" stroke="currentColor"/></svg>';
      const ICON_CHECK = '<svg class="check-pop-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#10b981" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>';

      function animateTabClick(btn) {
        if (!btn) return;
        btn.classList.remove("format-tab-animated");
        void btn.offsetWidth;
        btn.classList.add("format-tab-animated");
        setTimeout(() => btn.classList.remove("format-tab-animated"), 360);
      }

      // Detener y limpiar reproductores de medios
      function stopMediaPlayback() {
        if (audioInst) {
          audioInst.pause();
          audioInst.currentTime = 0;
          audioInst.removeAttribute("src");
          try { audioInst.load(); } catch {}
        }
        if (audioVoc) {
          audioVoc.pause();
          audioVoc.currentTime = 0;
          audioVoc.removeAttribute("src");
          try { audioVoc.load(); } catch {}
        }
        updateMasterPlayState(false);
      }

      // Ocultar resultado anterior y detener reproducción
      function hidePreviousResult() {
        resultBox.style.display = "none";
        stopMediaPlayback();
      }

      // Reinicia y oculta la barra de estado y progreso previo
      function resetProgressBox() {
        progressBox.style.display = "none";
        progressStatus.textContent = "";
        if (progressSubInfo) progressSubInfo.textContent = "";
        progressPercent.textContent = "0%";
        progressBar.style.width = "0%";
      }

      // Deshabilitar / Habilitar todos los controles mientras se procesa (Igual a Conversor)
      function setFormDisabled(disabled) {
        if (inputUrl) {
          inputUrl.disabled = disabled;
          inputUrl.style.opacity = disabled ? "0.6" : "1";
          inputUrl.style.cursor = disabled ? "not-allowed" : "text";
        }
        if (btnClear) btnClear.disabled = disabled;
        if (btnPaste) btnPaste.disabled = disabled;
        if (tabUrl) tabUrl.disabled = disabled;
        if (tabFile) tabFile.disabled = disabled;

        if (btnProcess) {
          btnProcess.disabled = disabled;
          btnProcess.style.cursor = disabled ? "not-allowed" : "pointer";
          btnProcess.style.opacity = disabled ? "0.75" : "1";
        }

        const interactiveEls = [
          btnProcess,
          tabUrl,
          tabFile,
          btnClear,
          btnPaste
        ];

        interactiveEls.forEach(el => {
          if (el) {
            el.style.pointerEvents = disabled ? "none" : "auto";
            el.style.opacity = disabled ? "0.6" : "1";
            el.style.cursor = disabled ? "not-allowed" : "pointer";
          }
        });

        if (disabled) {
          btnProcess.innerHTML = ICON_LOADING + ' <span id="btn-split-text">Separando Stems...</span>';
        } else {
          btnProcess.innerHTML = ICON_SPLIT + ' <span id="btn-split-text">SEPARAR VOZ E INSTRUMENTAL</span>';
        }
      }

      // Conmutar Pestañas de Modo (MÉTODO DE ENTRADA en Cabecera)
      function switchMode(mode) {
        resetProgressBox();
        hidePreviousResult();
        currentMode = mode;

        if (mode === "url") {
          animateTabClick(tabUrl);
          if (tabUrl) tabUrl.classList.add("active");
          if (tabFile) tabFile.classList.remove("active");
          if (stemModeBadge) stemModeBadge.textContent = "ENLACE MULTIMEDIA";
          if (platformsBoxTitle) platformsBoxTitle.textContent = "PLATAFORMAS COMPATIBLES (DETECCIÓN AUTOMÁTICA)";
          if (platformsChipsRow) platformsChipsRow.style.display = "flex";
          if (formatsChipsRow) formatsChipsRow.style.display = "none";

          const metaPanel = document.getElementById("file-meta-panel");
          if (metaPanel) metaPanel.style.display = "none";

          if (panelUrl) panelUrl.style.display = "block";
          if (panelFile) panelFile.style.display = "none";

          if (urlActionSlot && btnProcess) {
            urlActionSlot.appendChild(btnProcess);
            btnProcess.style.display = "inline-flex";
          }
        } else {
          animateTabClick(tabFile);
          if (tabFile) tabFile.classList.add("active");
          if (tabUrl) tabUrl.classList.remove("active");
          if (stemModeBadge) stemModeBadge.textContent = "SUBIDA DE ARCHIVO";
          if (platformsBoxTitle) platformsBoxTitle.textContent = "FORMATOS COMPATIBLES (DETECCIÓN AUTOMÁTICA)";
          if (platformsChipsRow) platformsChipsRow.style.display = "none";
          if (formatsChipsRow) formatsChipsRow.style.display = "flex";

          if (panelFile) panelFile.style.display = "block";
          if (panelUrl) panelUrl.style.display = "none";

          if (fileActionSlot && btnProcess) {
            fileActionSlot.appendChild(btnProcess);
            btnProcess.style.display = selectedFileBase64 ? "inline-flex" : "none";
          }
        }
      }

      if (tabUrl) {
        tabUrl.addEventListener("click", () => switchMode("url"));
      }

      if (tabFile) {
        tabFile.addEventListener("click", () => switchMode("file"));
      }

      // Formateo de bytes para metadatos
      function formatBytes(bytes) {
        if (!bytes || bytes === 0) return "0 B";
        const k = 1024;
        const sizes = ["B", "KB", "MB", "GB"];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
      }

      // Extractor y visor de metadatos de audio/video
      async function extractAndDisplayMetadata(file) {
        const metaPanel = document.getElementById("file-meta-panel");
        if (!metaPanel) return;

        const elDuration = document.getElementById("meta-val-duration");
        const elSize = document.getElementById("meta-val-size");
        const elFormat = document.getElementById("meta-val-format");
        const elChannels = document.getElementById("meta-val-channels");
        const elSampleRate = document.getElementById("meta-val-sample-rate");
        const elBitrate = document.getElementById("meta-val-bitrate");
        const elMime = document.getElementById("meta-val-mime");
        const elModified = document.getElementById("meta-val-modified");

        const ext = (file.name.split(".").pop() || "").toUpperCase();
        if (elFormat) elFormat.textContent = ext || "AUDIO";
        if (elSize) elSize.textContent = formatBytes(file.size);
        if (elMime) {
          const mimeStr = file.type || ("audio/" + ext.toLowerCase());
          elMime.textContent = mimeStr;
          elMime.title = mimeStr;
        }
        if (elModified) {
          const modDate = file.lastModified ? new Date(file.lastModified).toLocaleDateString() : "Hoy";
          elModified.textContent = modDate;
        }

        if (elDuration) elDuration.textContent = "Calculando...";
        if (elBitrate) elBitrate.textContent = "Calculando...";
        if (elChannels) elChannels.textContent = "Estéreo (2ch)";
        if (elSampleRate) elSampleRate.textContent = "44.1 kHz";

        // 1. Obtener duración y bitrate estimado mediante objeto multimedia
        try {
          const objectUrl = URL.createObjectURL(file);
          const isVideo = (file.type && file.type.startsWith("video")) || ext === "MP4" || ext === "MKV";
          const media = isVideo ? document.createElement("video") : new Audio();
          media.preload = "metadata";
          media.src = objectUrl;

          await new Promise((resolve) => {
            media.onloadedmetadata = () => resolve();
            media.onerror = () => resolve();
            setTimeout(resolve, 2200);
          });

          if (media.duration && !isNaN(media.duration) && isFinite(media.duration)) {
            const totalSec = Math.round(media.duration);
            const mins = Math.floor(totalSec / 60);
            const secs = totalSec % 60;
            const formattedDur = `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
            if (elDuration) elDuration.textContent = formattedDur;

            if (totalSec > 0) {
              const kbps = Math.round((file.size * 8) / totalSec / 1000);
              if (elBitrate) elBitrate.textContent = `~${kbps} kbps`;
            }
          } else {
            if (elDuration) elDuration.textContent = "N/D";
            if (elBitrate) elBitrate.textContent = "~320 kbps";
          }
          URL.revokeObjectURL(objectUrl);
        } catch (e) {
          if (elDuration) elDuration.textContent = "N/D";
          if (elBitrate) elBitrate.textContent = "~320 kbps";
        }

        // 2. Extraer Sample Rate y Canales reales con Web Audio API
        try {
          const AudioContextClass = window.AudioContext || window.webkitAudioContext;
          if (AudioContextClass && file.size <= 25 * 1024 * 1024) {
            const ctx = new AudioContextClass();
            const arrayBuf = await file.arrayBuffer();
            const audioBuf = await ctx.decodeAudioData(arrayBuf);
            if (audioBuf) {
              if (elSampleRate) {
                const khz = (audioBuf.sampleRate / 1000).toFixed(1);
                elSampleRate.textContent = `${khz} kHz`;
              }
              if (elChannels) {
                elChannels.textContent = audioBuf.numberOfChannels === 1 ? "Mono (1ch)" : audioBuf.numberOfChannels === 2 ? "Estéreo (2ch)" : `${audioBuf.numberOfChannels} Canales`;
              }
            }
            try { ctx.close(); } catch {}
          }
        } catch (e) {
          // Fallback seguro ya presente
        }
      }

      // Detección automática de formato de archivo seleccionado
      function detectFormatFromFileName(name) {
        if (!name) return null;
        const ext = name.split(".").pop().toLowerCase().trim();
        const map = {
          mp3: "mp3",
          wav: "wav",
          flac: "flac",
          m4a: "m4a",
          aac: "aac",
          ogg: "ogg",
          mp4: "mp4",
          mkv: "mp4",
          mov: "mp4",
          webm: "ogg"
        };
        return map[ext] || null;
      }

      function syncDetectedFormat(fileName) {
        const detected = detectFormatFromFileName(fileName);
        document.querySelectorAll("#formats-chips-row .format-chip").forEach(c => {
          if (detected && c.getAttribute("data-format") === detected) {
            c.classList.add("active");
          } else {
            c.classList.remove("active");
          }
        });
      }

      // Manejo de archivo local
      const dropZone = document.getElementById("drop-zone");
      const fileInput = document.getElementById("file-input");
      const fileInfo = document.getElementById("file-info-badge");
      const fileNameEl = document.getElementById("file-info-name");
      const btnRemoveFile = document.getElementById("btn-remove-file");
      const fileAnalyzingCard = document.getElementById("file-analyzing-card");
      const metaTagVerified = document.getElementById("meta-tag-verified");

      if (dropZone && fileInput) {
        dropZone.addEventListener("click", () => {
          dropZone.classList.remove("clicking");
          void dropZone.offsetWidth;
          dropZone.classList.add("clicking");
          fileInput.click();
        });
        fileInput.addEventListener("click", (e) => {
          e.stopPropagation();
        });

        dropZone.addEventListener("dragover", (e) => {
          e.preventDefault();
          dropZone.classList.add("dragover");
          const dropTitle = document.getElementById("drop-zone-title");
          if (dropTitle) dropTitle.textContent = "¡Suelta tu archivo aquí para analizarlo!";
        });
        dropZone.addEventListener("dragleave", () => {
          dropZone.classList.remove("dragover");
          const dropTitle = document.getElementById("drop-zone-title");
          if (dropTitle) dropTitle.textContent = "Arrastra y suelta tu archivo aquí";
        });
        dropZone.addEventListener("drop", (e) => {
          e.preventDefault();
          dropZone.classList.remove("dragover");
          const dropTitle = document.getElementById("drop-zone-title");
          if (dropTitle) dropTitle.textContent = "Arrastra y suelta tu archivo aquí";
          if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length) {
            handleFile(e.dataTransfer.files[0]);
          }
        });

        fileInput.addEventListener("change", () => {
          if (fileInput.files && fileInput.files.length) {
            handleFile(fileInput.files[0]);
          }
        });
      }

      async function handleFile(file) {
        if (!file) return;
        resetProgressBox();
        hidePreviousResult();
        selectedFileName = file.name;

        const metaPanel = document.getElementById("file-meta-panel");

        // Fase 1: Iniciar animación visual de análisis en vivo (Metadatos permanecen 100% ocultos)
        if (metaPanel) metaPanel.style.display = "none";
        if (dropZone) dropZone.style.display = "none";
        if (fileInfo) fileInfo.style.display = "none";
        if (btnProcess) btnProcess.style.display = "none";
        if (fileAnalyzingCard) fileAnalyzingCard.style.display = "flex";

        if (metaTagVerified) {
          metaTagVerified.style.color = "#ff6600";
          metaTagVerified.innerHTML = '<span class="analyzing-pulse-spinner" style="width: 12px; height: 12px; border-width: 2px;"></span> ANALIZANDO...';
        }

        // Resaltar inmediatamente el formato del archivo subido en naranja
        syncDetectedFormat(file.name);

        // Disparar extracción de metadatos y esperar animación fluida (~580ms)
        const metaPromise = extractAndDisplayMetadata(file);
        await Promise.all([
          metaPromise,
          new Promise(r => setTimeout(r, 580))
        ]);

        // Fase 2: Revelar archivo listo y telemetría analizada (SOLO al finalizar el análisis)
        if (fileAnalyzingCard) fileAnalyzingCard.style.display = "none";
        if (fileNameEl) fileNameEl.textContent = file.name;
        if (fileInfo) {
          fileInfo.style.display = "flex";
          fileInfo.classList.remove("file-badge-pop");
          void fileInfo.offsetWidth;
          fileInfo.classList.add("file-badge-pop");
        }
        if (btnProcess) {
          btnProcess.style.display = "inline-flex";
          btnProcess.classList.remove("file-badge-pop");
          void btnProcess.offsetWidth;
          btnProcess.classList.add("file-badge-pop");
        }

        // AHORA SÍ: Revelar el panel de metadatos con animación suave
        if (metaPanel) {
          metaPanel.style.display = "block";
          metaPanel.classList.remove("file-badge-pop");
          void metaPanel.offsetWidth;
          metaPanel.classList.add("file-badge-pop");
        }

        if (metaTagVerified) {
          metaTagVerified.style.color = "#10b981";
          metaTagVerified.innerHTML = '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="#10b981" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> ARCHIVO ANALIZADO';
          metaTagVerified.classList.remove("meta-check-pop");
          void metaTagVerified.offsetWidth;
          metaTagVerified.classList.add("meta-check-pop");
        }

        const reader = new FileReader();
        reader.onload = (e) => {
          selectedFileBase64 = e.target.result;
        };
        reader.readAsDataURL(file);
      }

      if (btnRemoveFile) {
        btnRemoveFile.addEventListener("click", (e) => {
          e.stopPropagation();
          resetProgressBox();
          hidePreviousResult();
          selectedFileBase64 = null;
          selectedFileName = "";
          if (fileInput) fileInput.value = "";
          if (fileInfo) fileInfo.style.display = "none";
          if (fileAnalyzingCard) fileAnalyzingCard.style.display = "none";
          if (dropZone) dropZone.style.display = "flex";
          if (btnProcess && currentMode === "file") btnProcess.style.display = "none";

          const metaPanel = document.getElementById("file-meta-panel");
          if (metaPanel) metaPanel.style.display = "none";

          syncDetectedFormat(null);
        });
      }

      // Detección automática de plataformas
      const platformHoverLabel = document.getElementById("platform-hover-label");
      const detectedPlatformBadge = document.getElementById("detected-platform-badge");

      const platformNames = {
        youtube: "YouTube",
        tiktok: "TikTok",
        instagram: "Instagram",
        facebook: "Facebook",
        twitter: "Twitter / X",
        pinterest: "Pinterest",
        direct: "Enlace Directo"
      };

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

      inputUrl.addEventListener("input", () => {
        resetProgressBox();
        hidePreviousResult();
        syncDetectedPlatform(inputUrl.value);
      });

      btnClear.addEventListener("click", () => {
        resetProgressBox();
        hidePreviousResult();
        inputUrl.value = "";
        syncDetectedPlatform("");
        inputUrl.focus();
      });

      // Botón Pegar Enlace del Portapapeles (Identico a Conversor)
      if (btnPaste) {
        btnPaste.addEventListener("click", async () => {
          try {
            const clipText = await navigator.clipboard.readText();
            if (clipText) {
              if (currentMode !== "url") {
                tabUrl.click();
              }
              inputUrl.value = clipText.trim();
              resetProgressBox();
              hidePreviousResult();
              syncDetectedPlatform(inputUrl.value);
            }
          } catch {
            inputUrl.focus();
          }
        });
      }

      // Clic en chips de plataforma solo enfoca el campo de texto (sin rellenar URL por defecto)
      document.querySelectorAll("#platforms-chips-row .platform-chip").forEach(chip => {
        chip.addEventListener("click", () => {
          inputUrl.focus();
        });
      });

      // Generador de Barras y Visualizadores Reactivos de Estudio (Dual-Polarity DAW Waveforms)
      const VIZ_BAR_COUNT = 64;
      const instBars = [];
      const vocBars = [];

      // Perfiles de onda acústica de estudio precalculados
      const instBaseProfile = [];
      const vocBaseProfile = [];
      for (let i = 0; i < VIZ_BAR_COUNT; i++) {
        const norm = i / VIZ_BAR_COUNT;
        const env1 = 0.28 + 0.35 * Math.sin(norm * Math.PI) + 0.16 * Math.sin(norm * Math.PI * 4) * Math.cos(norm * Math.PI * 2);
        const micro1 = ((i * 17) % 13) * 0.02 - 0.1;
        instBaseProfile.push(Math.max(0.18, Math.min(0.85, env1 + micro1)));

        const env2 = 0.22 + 0.42 * Math.pow(Math.sin(norm * Math.PI), 1.25) + 0.15 * Math.sin(norm * Math.PI * 5);
        const micro2 = ((i * 23) % 11) * 0.022 - 0.09;
        vocBaseProfile.push(Math.max(0.16, Math.min(0.88, env2 + micro2)));
      }

      function resetBarsToIdle(bars, profile) {
        for (let i = 0; i < bars.length; i++) {
          const h = Math.round((profile[i] || 0.3) * 75);
          bars[i].style.height = `${Math.max(16, h)}%`;
          bars[i].classList.remove("past-progress");
          bars[i].classList.remove("future-progress");
        }
      }

      function initVisualizerBars(containerId, barsArray, profile) {
        const box = document.getElementById(containerId);
        if (!box) return;
        box.innerHTML = "";
        barsArray.length = 0;
        for (let i = 0; i < VIZ_BAR_COUNT; i++) {
          const bar = document.createElement("div");
          bar.className = "wave-bar";
          box.appendChild(bar);
          barsArray.push(bar);
        }
        resetBarsToIdle(barsArray, profile);
      }

      initVisualizerBars("viz-inst", instBars, instBaseProfile);
      initVisualizerBars("viz-voc", vocBars, vocBaseProfile);

      // Función: Separar Voz e Instrumental (Comportamiento Idéntico a Convertir)
      btnProcess.addEventListener("click", async () => {
        let payload = { format: selectedFormat };
        if (currentMode === "url") {
          const u = inputUrl.value.trim();
          if (!u) {
            alert("Por favor introduce un enlace multimedia válido.");
            inputUrl.focus();
            return;
          }
          payload.url = u;
        } else {
          if (!selectedFileBase64) {
            alert("Por favor selecciona o arrastra un archivo de audio o video.");
            return;
          }
          payload.audioBase64 = selectedFileBase64;
          payload.filename = selectedFileName;
        }

        hidePreviousResult();
        setFormDisabled(true);
        progressBox.style.display = "block";
        progressBar.style.width = "25%";
        progressPercent.textContent = "25%";
        progressStatus.textContent = "Analizando entrada y extrayendo audio maestro...";
        if (progressSubInfo) progressSubInfo.textContent = "Validando canales estéreo y tasa de muestreo...";

        let t1 = null;
        let t2 = null;

        try {
          t1 = setTimeout(() => {
            if (progressBar.style.width === "25%") {
              progressBar.style.width = "60%";
              progressPercent.textContent = "60%";
              progressStatus.textContent = "Conectando con red neuronal Demucs v4 (Meta AI)...";
              if (progressSubInfo) progressSubInfo.textContent = "Descomponiendo espectrograma en tensores en memoria RAM...";
            }
          }, 800);

          t2 = setTimeout(() => {
            if (progressBar.style.width === "60%") {
              progressBar.style.width = "85%";
              progressPercent.textContent = "85%";
              progressStatus.textContent = "Desacoplando Acapella e Instrumental Puro...";
              if (progressSubInfo) progressSubInfo.textContent = "Aislamiento acústico a -48 dB sin diafonía armónica...";
            }
          }, 2400);

          const res = await fetch("/api/separator/process", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });

          if (t1) clearTimeout(t1);
          if (t2) clearTimeout(t2);

          const data = await res.json();

          progressBar.style.width = "100%";
          progressPercent.textContent = "100%";

          if (data.status === "success") {
            progressStatus.textContent = "¡Separación neuronal completada con éxito!";
            if (progressSubInfo) progressSubInfo.textContent = "Stems de alta fidelidad listos para preescucha y descarga.";
            displaySeparationResult(data);
            if (btnProcess) {
              btnProcess.innerHTML = ICON_CHECK + ' <span id="btn-split-text">¡Stems Listos!</span>';
              setTimeout(() => {
                btnProcess.innerHTML = ICON_SPLIT + ' <span id="btn-split-text">SEPARAR VOZ E INSTRUMENTAL</span>';
                setFormDisabled(false);
              }, 1800);
            }
          } else {
            alert(data.error || "No se pudo procesar la separación.");
            btnProcess.innerHTML = ICON_SPLIT + ' <span id="btn-split-text">SEPARAR VOZ E INSTRUMENTAL</span>';
            setFormDisabled(false);
          }
        } catch (err) {
          alert("Error de red: " + err.message);
          btnProcess.innerHTML = ICON_SPLIT + ' <span id="btn-split-text">SEPARAR VOZ E INSTRUMENTAL</span>';
          setFormDisabled(false);
        } finally {
          if (t1) clearTimeout(t1);
          if (t2) clearTimeout(t2);
        }
      });

      function displaySeparationResult(data) {
        resultBox.style.display = "block";
        document.getElementById("res-title").textContent = data.title;
        document.getElementById("res-platform").textContent = data.platform;
        document.getElementById("res-duration").textContent = data.duration;
        document.getElementById("time-total").textContent = data.duration;
        document.getElementById("res-thumb").src = data.thumbnail || "/img/logo.png";

        const badgeStem = document.getElementById("res-stem-badge");
        if (badgeStem && data.engine) {
          badgeStem.innerHTML = `<svg class="icon" viewBox="0 0 24 24" style="width: 14px; height: 14px;"><polyline points="20 6 9 17 4 12"/></svg> ${data.engine.toUpperCase()}`;
        }

        // Configurar fuentes de audio
        audioInst.src = data.instrumental.streamUrl;
        audioVoc.src = data.vocals.streamUrl;

        // Almacenar datos globales de separación para descargas y enlaces
        window.currentSeparationData = data;

        // Configurar botones de descarga directa
        const btnDlInst = document.getElementById("btn-dl-inst");
        btnDlInst.href = data.instrumental.downloadUrl;
        btnDlInst.setAttribute("download", data.instrumental.filename);

        const btnDlVoc = document.getElementById("btn-dl-voc");
        btnDlVoc.href = data.vocals.downloadUrl;
        btnDlVoc.setAttribute("download", data.vocals.filename);

        // Configurar botones de copia directa
        function triggerCopyFeedback(btn) {
          if (!btn) return;
          const origHtml = btn.innerHTML;
          const origBg = btn.style.background;
          const origColor = btn.style.color;
          const origBorder = btn.style.borderColor;
          btn.classList.add("btn-copied");
          btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Copiado!</span>`;
          btn.style.background = "var(--primary)";
          btn.style.color = "#000000";
          btn.style.borderColor = "var(--primary)";
          btn.style.fontWeight = "700";
          setTimeout(() => {
            btn.classList.remove("btn-copied");
            btn.innerHTML = origHtml;
            btn.style.background = origBg;
            btn.style.color = origColor;
            btn.style.borderColor = origBorder;
            btn.style.fontWeight = "";
          }, 2000);
        }

        const btnCopyStreamInst = document.getElementById("btn-copy-stream-inst");
        if (btnCopyStreamInst) {
          btnCopyStreamInst.onclick = () => {
            const downloadFull = window.location.origin + data.instrumental.downloadUrl;
            navigator.clipboard.writeText(downloadFull);
            triggerCopyFeedback(btnCopyStreamInst);
          };
        }

        const btnCopyStreamVoc = document.getElementById("btn-copy-stream-voc");
        if (btnCopyStreamVoc) {
          btnCopyStreamVoc.onclick = () => {
            const downloadFull = window.location.origin + data.vocals.downloadUrl;
            navigator.clipboard.writeText(downloadFull);
            triggerCopyFeedback(btnCopyStreamVoc);
          };
        }

        audioInst.load();
        audioVoc.load();

        // Modo por defecto al renderizar: Solo Instrumental
        applyListeningMode("inst");

        resultBox.scrollIntoView({ behavior: "smooth", block: "nearest" });
      }

      // Selector Interactivo de Modo de Escucha: Solo Instrumental / Solo Voz / Ambos
      const btnModeInst = document.getElementById("btn-mode-inst");
      const btnModeVoc = document.getElementById("btn-mode-voc");
      const btnModeBoth = document.getElementById("btn-mode-both");
      const currentListenLabel = document.getElementById("current-listen-label");

      const volInst = document.getElementById("vol-inst");
      const volVoc = document.getElementById("vol-voc");
      const volInstText = document.getElementById("vol-inst-text");
      const volVocText = document.getElementById("vol-voc-text");
      const btnMuteInst = document.getElementById("btn-mute-inst");
      const btnMuteVoc = document.getElementById("btn-mute-voc");

      const volIconActive = `<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>`;
      const volIconMuted = `<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/>`;

      function updateMuteButtonState(btn, isMuted) {
        const ttId = btn.id === "btn-mute-inst" ? "tt-mute-inst" : "tt-mute-voc";
        btn.removeAttribute("title");
        if (isMuted) {
          btn.classList.add("is-muted");
          btn.setAttribute("aria-label", "Silenciado");
          btn.innerHTML = `<svg class="icon mute-icon" viewBox="0 0 24 24" style="width: 17px; height: 17px;">${volIconMuted}</svg><span class="tooltip-text" id="${ttId}">Silenciado</span>`;
        } else {
          btn.classList.remove("is-muted");
          btn.setAttribute("aria-label", "Silenciar");
          btn.innerHTML = `<svg class="icon mute-icon" viewBox="0 0 24 24" style="width: 17px; height: 17px;">${volIconActive}</svg><span class="tooltip-text" id="${ttId}">Silenciar</span>`;
        }
      }

      function applyListeningMode(mode) {
        btnModeInst.classList.remove("active");
        btnModeVoc.classList.remove("active");
        btnModeBoth.classList.remove("active");

        if (mode === "inst") {
          btnModeInst.classList.add("active");
          currentListenLabel.textContent = "SOLO INSTRUMENTAL (KARAOKE)";
          audioInst.muted = false;
          audioVoc.muted = true;
          audioInst.volume = Math.min(1, Math.max(0, (parseFloat(volInst.value) || 100) / 100));
          audioVoc.volume = 0;
          updateMuteButtonState(btnMuteInst, false);
          updateMuteButtonState(btnMuteVoc, true);
        } else if (mode === "voc") {
          btnModeVoc.classList.add("active");
          currentListenLabel.textContent = "SOLO VOZ (ACAPELLA)";
          audioVoc.muted = false;
          audioInst.muted = true;
          audioVoc.volume = Math.min(1, Math.max(0, (parseFloat(volVoc.value) || 100) / 100));
          audioInst.volume = 0;
          updateMuteButtonState(btnMuteInst, true);
          updateMuteButtonState(btnMuteVoc, false);
        } else if (mode === "both") {
          btnModeBoth.classList.add("active");
          currentListenLabel.textContent = "AMBOS SINCRONIZADOS";
          audioInst.muted = false;
          audioVoc.muted = false;
          audioInst.volume = Math.min(1, Math.max(0, (parseFloat(volInst.value) || 100) / 100));
          audioVoc.volume = Math.min(1, Math.max(0, (parseFloat(volVoc.value) || 100) / 100));
          updateMuteButtonState(btnMuteInst, false);
          updateMuteButtonState(btnMuteVoc, false);
        }
        updateVisualizerStates();
      }

      btnModeInst.addEventListener("click", () => applyListeningMode("inst"));
      btnModeVoc.addEventListener("click", () => applyListeningMode("voc"));
      btnModeBoth.addEventListener("click", () => applyListeningMode("both"));

      // Controles del Reproductor Sincronizado
      const btnMasterPlay = document.getElementById("btn-master-play");
      const masterIcon = document.getElementById("master-play-icon");
      const masterScrubber = document.getElementById("master-scrubber");
      const timeCurrent = document.getElementById("time-current");
      const vizContainerInst = document.getElementById("viz-container-inst");
      const vizContainerVoc = document.getElementById("viz-container-voc");
      const vizInst = document.getElementById("viz-inst");
      const vizVoc = document.getElementById("viz-voc");

      let isPlaying = false;
      let animFrameId = null;

      function animateVisualizers(now) {
        const t = now * 0.0035;
        const progress = (audioInst.duration > 0) ? (audioInst.currentTime / audioInst.duration) : 0;
        const currentBarIdx = Math.floor(progress * VIZ_BAR_COUNT);

        const instActive = isPlaying && !audioInst.muted && audioInst.volume > 0;
        const vocActive = isPlaying && !audioVoc.muted && audioVoc.volume > 0;

        if (instActive) {
          const vol = audioInst.volume;
          for (let i = 0; i < VIZ_BAR_COUNT; i++) {
            const base = instBaseProfile[i] || 0.3;
            const h1 = Math.sin(t * 3.6 + i * 0.24);
            const h2 = Math.sin(t * 7.2 + i * 0.48);
            const h3 = Math.cos(t * 1.8 + i * 0.14);
            const wave = (h1 * 0.22 + h2 * 0.14 + h3 * 0.10) * vol;
            const finalH = Math.min(96, Math.max(16, Math.round((base * 0.55 + wave + 0.22) * 100)));
            instBars[i].style.height = `${finalH}%`;

            if (i <= currentBarIdx) {
              instBars[i].classList.add("past-progress");
              instBars[i].classList.remove("future-progress");
            } else {
              instBars[i].classList.remove("past-progress");
              instBars[i].classList.add("future-progress");
            }
          }
        } else {
          resetBarsToIdle(instBars, instBaseProfile);
        }

        if (vocActive) {
          const vol = audioVoc.volume;
          for (let i = 0; i < VIZ_BAR_COUNT; i++) {
            const base = vocBaseProfile[i] || 0.3;
            const vocalFocus = Math.pow(Math.sin((i / VIZ_BAR_COUNT) * Math.PI), 1.2);
            const h1 = Math.sin(t * 4.6 + i * 0.32);
            const h2 = Math.cos(t * 8.4 + i * 0.58);
            const h3 = Math.sin(t * 2.3 + i * 0.16);
            const wave = (h1 * 0.24 + h2 * 0.16 + h3 * 0.12) * (0.5 + vocalFocus * 0.8) * vol;
            const finalH = Math.min(96, Math.max(14, Math.round((base * 0.55 + wave + 0.20) * 100)));
            vocBars[i].style.height = `${finalH}%`;

            if (i <= currentBarIdx) {
              vocBars[i].classList.add("past-progress");
              vocBars[i].classList.remove("future-progress");
            } else {
              vocBars[i].classList.remove("past-progress");
              vocBars[i].classList.add("future-progress");
            }
          }
        } else {
          resetBarsToIdle(vocBars, vocBaseProfile);
        }

        if (isPlaying) {
          animFrameId = requestAnimationFrame(animateVisualizers);
        } else {
          animFrameId = null;
        }
      }

      function updateVisualizerStates() {
        const instActive = isPlaying && !audioInst.muted && audioInst.volume > 0;
        const vocActive = isPlaying && !audioVoc.muted && audioVoc.volume > 0;

        if (vizContainerInst) {
          if (instActive) vizContainerInst.classList.add("active");
          else vizContainerInst.classList.remove("active");
        }
        if (vizInst) {
          if (instActive) vizInst.classList.add("active");
          else vizInst.classList.remove("active");
        }

        if (vizContainerVoc) {
          if (vocActive) vizContainerVoc.classList.add("active");
          else vizContainerVoc.classList.remove("active");
        }
        if (vizVoc) {
          if (vocActive) vizVoc.classList.add("active");
          else vizVoc.classList.remove("active");
        }

        if (isPlaying) {
          if (!animFrameId) {
            animFrameId = requestAnimationFrame(animateVisualizers);
          }
        } else {
          if (animFrameId) {
            cancelAnimationFrame(animFrameId);
            animFrameId = null;
          }
          resetBarsToIdle(instBars, instBaseProfile);
          resetBarsToIdle(vocBars, vocBaseProfile);
        }
      }

      function updateMasterPlayState(playing) {
        isPlaying = playing;
        if (playing) {
          masterIcon.innerHTML = `<rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/>`;
        } else {
          masterIcon.innerHTML = `<polygon points="5 3 19 12 5 21 5 3"/>`;
        }
        updateVisualizerStates();
      }

      btnMasterPlay.addEventListener("click", () => {
        if (isPlaying) {
          audioInst.pause();
          audioVoc.pause();
          updateMasterPlayState(false);
        } else {
          audioVoc.currentTime = audioInst.currentTime;
          Promise.all([audioInst.play(), audioVoc.play()]).then(() => {
            updateMasterPlayState(true);
          }).catch(err => {
            console.warn("Error en reproducción sincronizada:", err);
          });
        }
      });

      // Actualizar scrubber durante reproducción
      audioInst.addEventListener("timeupdate", () => {
        if (!audioInst.duration) return;
        const pct = (audioInst.currentTime / audioInst.duration) * 100;
        masterScrubber.value = pct;
        
        const m = Math.floor(audioInst.currentTime / 60);
        const s = Math.floor(audioInst.currentTime % 60);
        timeCurrent.textContent = `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;

        if (Math.abs(audioInst.currentTime - audioVoc.currentTime) > 0.08) {
          audioVoc.currentTime = audioInst.currentTime;
        }
      });

      // Scrubber manual
      masterScrubber.addEventListener("input", () => {
        if (!audioInst.duration) return;
        const targetTime = (masterScrubber.value / 100) * audioInst.duration;
        audioInst.currentTime = targetTime;
        audioVoc.currentTime = targetTime;
      });

      // Fin de reproducción
      audioInst.addEventListener("ended", () => {
        updateMasterPlayState(false);
        masterScrubber.value = 0;
        timeCurrent.textContent = "00:00";
      });

      // Control de volumen independiente (Bajar y Subir al 100% sin bugs)
      volInst.addEventListener("input", () => {
        const val = Math.min(100, Math.max(0, parseFloat(volInst.value) || 0));
        volInstText.textContent = `${Math.round(val)}%`;
        const ratio = val / 100;
        if (ratio > 0 && audioInst.muted) {
          audioInst.muted = false;
          updateMuteButtonState(btnMuteInst, false);
        } else if (ratio === 0 && !audioInst.muted) {
          audioInst.muted = true;
          updateMuteButtonState(btnMuteInst, true);
        }
        audioInst.volume = ratio;
        updateVisualizerStates();
      });

      volVoc.addEventListener("input", () => {
        const val = Math.min(100, Math.max(0, parseFloat(volVoc.value) || 0));
        volVocText.textContent = `${Math.round(val)}%`;
        const ratio = val / 100;
        if (ratio > 0 && audioVoc.muted) {
          audioVoc.muted = false;
          updateMuteButtonState(btnMuteVoc, false);
        } else if (ratio === 0 && !audioVoc.muted) {
          audioVoc.muted = true;
          updateMuteButtonState(btnMuteVoc, true);
        }
        audioVoc.volume = ratio;
        updateVisualizerStates();
      });

      // Botones de Mute individuales con icono y tooltip
      btnMuteInst.addEventListener("click", () => {
        audioInst.muted = !audioInst.muted;
        if (audioInst.muted) {
          audioInst.dataset.prevVol = volInst.value;
          audioInst.volume = 0;
        } else {
          let restoreVal = parseFloat(audioInst.dataset.prevVol || volInst.value) || 100;
          if (restoreVal <= 0) restoreVal = 100;
          volInst.value = restoreVal;
          volInstText.textContent = `${Math.round(restoreVal)}%`;
          audioInst.volume = restoreVal / 100;
        }
        updateMuteButtonState(btnMuteInst, audioInst.muted);
        updateVisualizerStates();
      });

      btnMuteVoc.addEventListener("click", () => {
        audioVoc.muted = !audioVoc.muted;
        if (audioVoc.muted) {
          audioVoc.dataset.prevVol = volVoc.value;
          audioVoc.volume = 0;
        } else {
          let restoreVal = parseFloat(audioVoc.dataset.prevVol || volVoc.value) || 100;
          if (restoreVal <= 0) restoreVal = 100;
          volVoc.value = restoreVal;
          volVocText.textContent = `${Math.round(restoreVal)}%`;
          audioVoc.volume = restoreVal / 100;
        }
        updateMuteButtonState(btnMuteVoc, audioVoc.muted);
        updateVisualizerStates();
      });

      // Inicialización del traductor
      const apiEndpoint = "https://vork-st1k.onrender.com/api/translate";
      window.translator = new Vork({ endpoint: apiEndpoint, useCookies: true, batchSize: 500 });
      document.getElementById("btn-english").onclick = () => window.translator.translateToEnglish();
      document.getElementById("btn-restore").onclick = () => window.translator.restoreOriginal();
      document.getElementById("select-lang").onchange = (e) => window.translator.translatePage(e.target.value);
      document.getElementById("btn-translate-custom").onclick = () => {
        const val = document.getElementById("input-custom-lang").value.trim().toLowerCase();
        if (val) window.translator.translatePage(val);
      };
    });

})(window, document);
