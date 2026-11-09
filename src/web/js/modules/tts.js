/**
 * tts.js
 * Lógica modular del front-end para tts.html
 */

(function (window, document) {
  "use strict";

document.addEventListener("DOMContentLoaded", () => {
      const apiEndpoint = "https://vork-st1k.onrender.com/api/translate";
      window.translator = new Vork({ endpoint: apiEndpoint, useCookies: true, batchSize: 500 });
      document.getElementById("btn-english").onclick = () => window.translator.translateToEnglish();
      document.getElementById("btn-restore").onclick = () => window.translator.restoreOriginal();
      document.getElementById("select-lang").onchange = (e) => window.translator.translatePage(e.target.value);
      document.getElementById("btn-translate-custom").onclick = () => {
        const val = document.getElementById("input-custom-lang").value.trim().toLowerCase();
        if (val) window.translator.translatePage(val);
      };

      // ==========================================
      // LÓGICA DE SÍNTESIS VOCAL (BACKEND NEURAL)
      // ==========================================
      const ttsInput = document.getElementById("tts-input-text");
      const ttsCharCount = document.getElementById("tts-char-count");
      const ttsLang = document.getElementById("tts-lang-select");
      const ttsVoice = document.getElementById("tts-voice-select");
      const ttsRate = document.getElementById("tts-rate-slider");
      const ttsRateVal = document.getElementById("tts-rate-val");
      const ttsPitch = document.getElementById("tts-pitch-slider");
      const ttsPitchVal = document.getElementById("tts-pitch-val");
      const ttsBtnPlay = document.getElementById("tts-btn-play");
      const ttsBtnPause = document.getElementById("tts-btn-pause");
      const ttsBtnStop = document.getElementById("tts-btn-stop");
      const ttsBtnDownload = document.getElementById("tts-btn-download");
      const ttsBtnCopyStream = document.getElementById("tts-btn-copy-stream");
      const ttsStatusLabel = document.getElementById("tts-status-label");
      const ttsTimeLabel = document.getElementById("tts-time-label");
      const ttsBars = document.getElementById("tts-bars-container");
      const audioPlayer = document.getElementById("backend-audio-player");
      const catalogGrid = document.getElementById("voices-cards-grid");

      let backendVoices = [];
      let lastGeneratedAudio = null;
      let playStartTime = 0;
      let timerInterval = null;
      let isStoppingPlayback = false;

      function updateCharCount() {
        if (ttsInput && ttsCharCount) {
          ttsCharCount.textContent = `${ttsInput.value.length} caracteres`;
        }
      }
      if (ttsInput) ttsInput.addEventListener("input", updateCharCount);

      function stopCurrentPlayback() {
        if (audioPlayer) {
          isStoppingPlayback = true;
          audioPlayer.pause();
          audioPlayer.currentTime = 0;
          setStatus("DETENIDO", false);
          stopTimer();
          setTTSPlaybackLock(false);
        }
      }

      function setTTSPlaybackLock(isLocked) {
        const lockableElements = [
          ttsInput,
          ttsLang,
          ttsVoice,
          ttsRate,
          ttsPitch,
          ttsBtnPlay,
          ttsBtnDownload,
          ttsBtnCopyStream
        ];

        lockableElements.forEach(el => {
          if (el) {
            el.disabled = isLocked;
            el.style.pointerEvents = isLocked ? "none" : "auto";
            el.style.opacity = isLocked ? "0.6" : "1";
          }
        });

        if (ttsInput) {
          ttsInput.readOnly = isLocked;
          ttsInput.style.cursor = isLocked ? "not-allowed" : "text";
        }

        document.querySelectorAll(".btn-select-voice, .btn-sample-play, .btn-filter-voice").forEach(btn => {
          btn.disabled = isLocked;
          btn.style.pointerEvents = isLocked ? "none" : "auto";
          btn.style.opacity = isLocked ? "0.6" : "1";
        });

        // Asegurar que Pausar y Detener SIEMPRE estén activos para interactuar durante la reproducción
        if (ttsBtnPause) {
          ttsBtnPause.disabled = false;
          ttsBtnPause.style.pointerEvents = "auto";
          ttsBtnPause.style.opacity = "1";
          ttsBtnPause.style.cursor = "pointer";
        }
        if (ttsBtnStop) {
          ttsBtnStop.disabled = false;
          ttsBtnStop.style.pointerEvents = "auto";
          ttsBtnStop.style.opacity = "1";
          ttsBtnStop.style.cursor = "pointer";
        }
      }

      if (ttsRate) {
        ttsRate.addEventListener("input", (e) => {
          ttsRateVal.textContent = parseFloat(e.target.value).toFixed(1) + "x";
          stopCurrentPlayback();
        });
      }

      if (ttsPitch) {
        ttsPitch.addEventListener("input", (e) => {
          ttsPitchVal.textContent = parseFloat(e.target.value).toFixed(1);
          stopCurrentPlayback();
        });
      }

      function setStatus(text, isPlaying = false) {
        if (ttsStatusLabel) {
          ttsStatusLabel.textContent = text;
          if (isPlaying) {
            ttsStatusLabel.className = "eq-status-badge active";
            if (ttsBars) ttsBars.classList.add("animating");
          } else {
            ttsStatusLabel.className = "eq-status-badge";
            if (ttsBars) ttsBars.classList.remove("animating");
          }
        }
      }

      function startTimer() {
        playStartTime = Date.now();
        if (timerInterval) clearInterval(timerInterval);
        timerInterval = setInterval(() => {
          const elapsed = Math.floor((Date.now() - playStartTime) / 1000);
          const m = String(Math.floor(elapsed / 60)).padStart(2, "0");
          const s = String(elapsed % 60).padStart(2, "0");
          if (ttsTimeLabel) ttsTimeLabel.textContent = `${m}:${s}`;
        }, 500);
      }

      function stopTimer() {
        if (timerInterval) clearInterval(timerInterval);
        if (ttsTimeLabel) ttsTimeLabel.textContent = "00:00";
      }

      // Cargar Catálogo de 24 Voces desde el Backend
      async function loadVoicesCatalog() {
        try {
          const res = await fetch("/api/tts/voices");
          const data = await res.json();
          if (data && data.voices) {
            backendVoices = data.voices;
            renderVoiceSelector();
            renderVoiceCatalogCards("all");
          }
        } catch (err) {
          console.warn("Error al cargar catálogo de voces:", err);
        }
      }

      function renderVoiceSelector() {
        if (!ttsVoice) return;
        ttsVoice.innerHTML = "";

        const groups = {};
        backendVoices.forEach(v => {
          const langKey = v.country ? v.country.split(" ")[0] : v.lang;
          if (!groups[langKey]) groups[langKey] = [];
          groups[langKey].push(v);
        });

        Object.keys(groups).forEach(grp => {
          const optGroup = document.createElement("optgroup");
          optGroup.label = grp;
          groups[grp].forEach(v => {
            const opt = document.createElement("option");
            opt.value = v.id;
            opt.textContent = `${v.name} (${v.gender === "femenina" ? "Femenina" : "Masculina"} - ${v.style}) - ${v.country}`;
            optGroup.appendChild(opt);
          });
          ttsVoice.appendChild(optGroup);
        });
      }

      function renderVoiceCatalogCards(filter = "all") {
        if (!catalogGrid) return;
        catalogGrid.innerHTML = "";

        const filtered = filter === "all" ? backendVoices : backendVoices.filter(v => v.lang === filter);
        filtered.forEach(v => {
          const card = document.createElement("div");
          card.className = "tech-card";
          card.style.padding = "20px";
          card.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
              <div>
                <span class="tech-card-tag" style="margin-bottom: 4px;">${v.country}</span>
                <h3 style="font-size: 1.1rem; margin: 0; color: #fff;">${v.name}</h3>
              </div>
              <span class="badge" style="background: rgba(56, 189, 248, 0.15); color: var(--primary); font-size: 0.7rem; padding: 3px 8px; border-radius: 99px;">
                ${v.gender === "femenina" ? "Femenina" : "Masculina"}
              </span>
            </div>
            <p style="font-size: 0.82rem; color: var(--text-secondary); margin-bottom: 12px; line-height: 1.5;">${v.description}</p>
            <div style="margin-top: auto; display: flex; gap: 8px;">
              <button class="btn btn-outline btn-sample-play" data-voice="${v.id}" data-text="${encodeURIComponent(v.sampleText)}" style="flex: 1; padding: 7px 10px; font-size: 0.75rem;">
                <svg class="icon" viewBox="0 0 24 24"><polygon points="5 3 19 12 5 21 5 3"/></svg>
                Muestra
              </button>
              <button class="btn btn-primary btn-select-voice" data-voice="${v.id}" style="flex: 1; padding: 7px 10px; font-size: 0.75rem;">
                Usar Voz
              </button>
            </div>
          `;
          catalogGrid.appendChild(card);
        });

        // Eventos de botones en tarjetas
        document.querySelectorAll(".btn-select-voice").forEach(b => {
          b.addEventListener("click", (e) => {
            stopCurrentPlayback();
            const vId = e.currentTarget.getAttribute("data-voice");
            if (ttsVoice) ttsVoice.value = vId;
            const foundVoice = backendVoices.find(v => v.id === vId);
            if (foundVoice && ttsLang) {
              const matchedOpt = Array.from(ttsLang.options).find(o => o.value.startsWith(foundVoice.lang));
              if (matchedOpt) ttsLang.value = matchedOpt.value;
            }
            document.querySelector(".studio-wrapper").scrollIntoView({ behavior: "smooth" });
          });
        });

        document.querySelectorAll(".btn-sample-play").forEach(b => {
          b.addEventListener("click", async (e) => {
            stopCurrentPlayback();
            const vId = e.currentTarget.getAttribute("data-voice");
            const sampleTxt = decodeURIComponent(e.currentTarget.getAttribute("data-text"));
            e.currentTarget.disabled = true;
            try {
              const res = await fetch("/api/tts", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ text: sampleTxt, voiceId: vId })
              });
              const d = await res.json();
              if (d.audioBase64) {
                audioPlayer.src = d.audioBase64;
                await audioPlayer.play();
                setStatus(`REPRODUCIENDO (${vId})`, true);
                startTimer();
              }
            } catch (err) {}
            setTimeout(() => { e.currentTarget.disabled = false; }, 1000);
          });
        });
      }

      // Sincronización bidireccional entre selector de idioma y selector de voz
      if (ttsLang) {
        ttsLang.addEventListener("change", () => {
          stopCurrentPlayback();
          const lCode = ttsLang.value.slice(0, 2);
          const firstMatching = backendVoices.find(v => v.lang === lCode);
          if (firstMatching && ttsVoice) {
            ttsVoice.value = firstMatching.id;
          }
        });
      }

      if (ttsVoice) {
        ttsVoice.addEventListener("change", () => {
          stopCurrentPlayback();
          const vObj = backendVoices.find(v => v.id === ttsVoice.value);
          if (vObj && ttsLang) {
            const matchedOpt = Array.from(ttsLang.options).find(o => o.value.startsWith(vObj.lang));
            if (matchedOpt) ttsLang.value = matchedOpt.value;
          }
        });
      }

      // Filtros de categoría de voz
      document.querySelectorAll(".btn-filter-voice").forEach(btn => {
        btn.addEventListener("click", (e) => {
          document.querySelectorAll(".btn-filter-voice").forEach(b => {
            b.className = "btn btn-outline btn-filter-voice";
          });
          e.currentTarget.className = "btn btn-primary btn-filter-voice active";
          renderVoiceCatalogCards(e.currentTarget.getAttribute("data-filter"));
        });
      });

      // Eventos del Audio Player HTML5 con bloqueo automático
      audioPlayer.addEventListener("play", () => {
        isStoppingPlayback = false;
        setStatus("REPRODUCIENDO", true);
        startTimer();
        setTTSPlaybackLock(true);
      });
      audioPlayer.addEventListener("pause", () => {
        if (isStoppingPlayback) {
          isStoppingPlayback = false;
          setStatus("DETENIDO", false);
          stopTimer();
          setTTSPlaybackLock(false);
          return;
        }
        setStatus("PAUSADO", false);
        if (timerInterval) clearInterval(timerInterval);
        setTTSPlaybackLock(false);
      });
      audioPlayer.addEventListener("ended", () => {
        setStatus("COMPLETADO", false);
        stopTimer();
        setTTSPlaybackLock(false);
      });
      audioPlayer.addEventListener("error", () => {
        setStatus("ERROR", false);
        stopTimer();
        setTTSPlaybackLock(false);
      });

      // Caché local en memoria del cliente para respuestas en 0ms
      const ttsClientCache = new Map();

      // Botón Reproducir / Generar con Backend 100% Real
      if (ttsBtnPlay) {
        ttsBtnPlay.addEventListener("click", async () => {
          const text = (ttsInput.value || "").trim();
          if (!text) {
            alert("Escribe un texto para generar locución.");
            return;
          }

          if (audioPlayer.paused && audioPlayer.src && audioPlayer.currentTime > 0) {
            audioPlayer.play();
            return;
          }

          const selectedVoiceId = ttsVoice.value;
          const rateVal = parseFloat(ttsRate.value) || 1.0;
          const pitchVal = parseFloat(ttsPitch.value) || 1.0;
          const clientCacheKey = `${selectedVoiceId}:${rateVal}:${pitchVal}:${text}`;

          // Si ya lo tenemos en memoria, reproducir al instante en 0ms sin consumir red
          if (ttsClientCache.has(clientCacheKey)) {
            const cached = ttsClientCache.get(clientCacheKey);
            lastGeneratedAudio = cached;
            audioPlayer.src = cached.streamUrl || cached.audioBase64;
            await audioPlayer.play();
            setStatus("REPRODUCIENDO (0ms CACHÉ)", true);
            return;
          }

          setTTSPlaybackLock(true);
          ttsBtnPlay.innerHTML = `<span class="spinner" style="display:inline-block; margin-right:8px;"></span> Sintetizando...`;
          setStatus("SINTETIZANDO EN BACKEND...", true);

          try {
            const resp = await fetch("/api/tts", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                text,
                voiceId: selectedVoiceId,
                rate: rateVal,
                pitch: pitchVal
              })
            });

            const data = await resp.json();
            if (data.status === "success" && (data.streamUrl || data.audioBase64)) {
              lastGeneratedAudio = data;
              ttsClientCache.set(clientCacheKey, data);
              // Usar streamUrl para inicio de reproducción inmediato por HTTP 206 en redes lentas
              audioPlayer.src = data.streamUrl || data.audioBase64;
              await audioPlayer.play();
              setStatus("REPRODUCIENDO", true);
            } else {
              throw new Error(data.error || "No se pudo generar la síntesis vocal");
            }
          } catch (err) {
            alert("Error al sintetizar voz: " + err.message);
            setStatus("ERROR", false);
            setTTSPlaybackLock(false);
          } finally {
            ttsBtnPlay.innerHTML = `<svg class="icon" viewBox="0 0 24 24"><polygon points="5 3 19 12 5 21 5 3"/></svg> Reproducir`;
          }
        });
      }

      if (ttsBtnPause) {
        ttsBtnPause.addEventListener("click", () => {
          if (!audioPlayer.paused) {
            audioPlayer.pause();
            setTTSPlaybackLock(false);
          }
        });
      }

      if (ttsBtnStop) {
        ttsBtnStop.addEventListener("click", () => {
          stopCurrentPlayback();
        });
      }

      // Descarga Real del Archivo de Audio
      if (ttsBtnDownload) {
        ttsBtnDownload.addEventListener("click", async () => {
          const text = (ttsInput.value || "").trim();
          if (!text) {
            alert("Escribe un texto antes de descargar el audio.");
            return;
          }

          ttsBtnDownload.disabled = true;
          const origDownloadHtml = ttsBtnDownload.innerHTML;
          ttsBtnDownload.innerHTML = `<span class="spinner" style="display:inline-block;width:14px;height:14px;margin-right:6px;"></span> Descargando...`;

          try {
            let audioData = lastGeneratedAudio;
            if (!audioData || audioData.text !== text) {
              const resp = await fetch("/api/tts", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  text,
                  voiceId: ttsVoice.value,
                  lang: ttsLang.value.slice(0, 2),
                  rate: parseFloat(ttsRate.value) || 1.0,
                  pitch: parseFloat(ttsPitch.value) || 1.0
                })
              });
              audioData = await resp.json();
              if (audioData.status === "success") {
                lastGeneratedAudio = audioData;
              }
            }

            if (audioData && audioData.audioBase64) {
              const byteCharacters = atob(audioData.audioBase64.split(",")[1]);
              const byteNumbers = new Array(byteCharacters.length);
              for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
              }
              const byteArray = new Uint8Array(byteNumbers);
              const ext = audioData.format || "mp3";
              const mime = audioData.mimeType || "audio/mpeg";
              const blob = new Blob([byteArray], { type: mime });
              const url = URL.createObjectURL(blob);

              const a = document.createElement("a");
              a.href = url;
              a.download = `voz-tts-vork-${Date.now()}.${ext}`;
              document.body.appendChild(a);
              a.click();
              document.body.removeChild(a);
              setTimeout(() => URL.revokeObjectURL(url), 2000);

              ttsBtnDownload.innerHTML = `<svg class="icon" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg> ¡Descargado!`;
              setTimeout(() => {
                ttsBtnDownload.innerHTML = origDownloadHtml;
                ttsBtnDownload.disabled = false;
              }, 2000);
            } else {
              throw new Error("No se pudo obtener el buffer de audio");
            }
          } catch (e) {
            alert("Error al descargar audio: " + e.message);
            ttsBtnDownload.disabled = false;
            ttsBtnDownload.innerHTML = origDownloadHtml;
          }
        });
      }

      // Copiar Enlace Directo
      if (ttsBtnCopyStream) {
        ttsBtnCopyStream.onclick = async () => {
          const text = (ttsInput.value || "").trim();
          if (!text) {
            alert("Escribe un texto antes de copiar el enlace directo.");
            return;
          }

          let audioData = lastGeneratedAudio;
          if (!audioData || audioData.text !== text) {
            try {
              const resp = await fetch("/api/tts", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  text,
                  voiceId: ttsVoice.value,
                  lang: ttsLang.value.slice(0, 2),
                  rate: parseFloat(ttsRate.value) || 1.0,
                  pitch: parseFloat(ttsPitch.value) || 1.0
                })
              });
              audioData = await resp.json();
              if (audioData.status === "success") {
                lastGeneratedAudio = audioData;
              }
            } catch (e) {
              alert("Error al obtener enlace: " + e.message);
              return;
            }
          }

          const targetUrl = (audioData && audioData.downloadUrl) ? audioData.downloadUrl : (audioData && audioData.streamUrl ? audioData.streamUrl : null);
          if (targetUrl) {
            const downloadFull = targetUrl.startsWith("http") ? targetUrl : window.location.origin + targetUrl;
            navigator.clipboard.writeText(downloadFull);
            const origHtml = ttsBtnCopyStream.innerHTML;
            const origBg = ttsBtnCopyStream.style.background;
            const origColor = ttsBtnCopyStream.style.color;
            const origBorder = ttsBtnCopyStream.style.borderColor;
            ttsBtnCopyStream.classList.add("btn-copied");
            ttsBtnCopyStream.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Copiado!</span>`;
            ttsBtnCopyStream.style.background = "var(--primary)";
            ttsBtnCopyStream.style.color = "#000000";
            ttsBtnCopyStream.style.borderColor = "var(--primary)";
            ttsBtnCopyStream.style.fontWeight = "700";
            setTimeout(() => {
              ttsBtnCopyStream.classList.remove("btn-copied");
              ttsBtnCopyStream.innerHTML = origHtml;
              ttsBtnCopyStream.style.background = origBg;
              ttsBtnCopyStream.style.color = origColor;
              ttsBtnCopyStream.style.borderColor = origBorder;
              ttsBtnCopyStream.style.fontWeight = "";
            }, 2000);
          } else {
            alert("No se pudo obtener el enlace directo.");
          }
        };
      }

      // Cargar voces al inicio
      loadVoicesCatalog();
    });

})(window, document);
