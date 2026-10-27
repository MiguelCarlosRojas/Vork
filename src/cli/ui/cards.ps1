<#
.SYNOPSIS
    Vork CLI - Modulo UI: Selectores Interactivos con Flechas (Up/Down) y Enter
#>

function Wait-VorkGoBack {
    param([string]$CmdName = "")

    if ([Console]::IsInputRedirected) { return }

    Write-Host ""
    Write-Host "  ${LeadLight}Keyboard: ${Cyan}${Bold}esc${Reset} ${LeadLight}Go Back  ${Cyan}${Bold}enter${Reset} ${LeadLight}Select${Reset}"

    # Limpiar buffer de teclado residual
    while ([Console]::KeyAvailable) {
        try { [void][Console]::ReadKey($true) } catch { break }
    }

    try {
        while ($true) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -in [ConsoleKey]::Escape, [ConsoleKey]::Enter, [ConsoleKey]::Spacebar) {
                break
            }
        }
    } catch { }
}

function Read-VorkInput {
    param(
        [string]$Prompt = ""
    )

    try { [Console]::TreatControlCAsInput = $false } catch { }
    try { [Console]::CursorVisible = $true } catch { }

    if ($Prompt) {
        Write-Host $Prompt -NoNewline
    }

    if ([Console]::IsInputRedirected) {
        return [Console]::ReadLine()
    }

    # Limpiar buffer de teclas residuales
    while ([Console]::KeyAvailable) {
        try { [void][Console]::ReadKey($true) } catch { break }
    }

    $buf = [System.Text.StringBuilder]::new()
    $pos = 0

    while ($true) {
        $k = [Console]::ReadKey($true)

        if ($k.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            return $buf.ToString()
        }

        # Ctrl+C o Escape para cancelar
        $isCtrlC = ($k.KeyChar -eq [char]3) -or ($k.Key -eq [ConsoleKey]::C -and ($k.Modifiers -band [ConsoleModifiers]::Control))
        if ($isCtrlC -or $k.Key -eq [ConsoleKey]::Escape) {
            Write-Host ""
            return ""
        }

        if ($k.Key -eq [ConsoleKey]::Backspace -or $k.KeyChar -eq [char]8) {
            if ($pos -gt 0) {
                $buf.Remove($pos - 1, 1) | Out-Null
                $pos--
                Write-Host "${CSI}1D" -NoNewline
                $tail = if ($pos -lt $buf.Length) { $buf.ToString().Substring($pos) } else { "" }
                Write-Host "$tail $ClrToEnd" -NoNewline
                $backCount = $tail.Length + 1
                if ($backCount -gt 0) {
                    Write-Host "${CSI}${backCount}D" -NoNewline
                }
            }
            continue
        }

        if ($k.Key -eq [ConsoleKey]::Delete) {
            if ($pos -lt $buf.Length) {
                $buf.Remove($pos, 1) | Out-Null
                $tail = if ($pos -lt $buf.Length) { $buf.ToString().Substring($pos) } else { "" }
                Write-Host "$tail $ClrToEnd" -NoNewline
                $backCount = $tail.Length + 1
                if ($backCount -gt 0) {
                    Write-Host "${CSI}${backCount}D" -NoNewline
                }
            }
            continue
        }

        if ($k.Key -eq [ConsoleKey]::LeftArrow) {
            if ($pos -gt 0) {
                $pos--
                Write-Host "${CSI}1D" -NoNewline
            }
            continue
        }

        if ($k.Key -eq [ConsoleKey]::RightArrow) {
            if ($pos -lt $buf.Length) {
                $pos++
                Write-Host "${CSI}1C" -NoNewline
            }
            continue
        }

        if ($k.Key -eq [ConsoleKey]::Home) {
            if ($pos -gt 0) {
                Write-Host "${CSI}${pos}D" -NoNewline
                $pos = 0
            }
            continue
        }

        if ($k.Key -eq [ConsoleKey]::End) {
            if ($pos -lt $buf.Length) {
                $fwd = $buf.Length - $pos
                Write-Host "${CSI}${fwd}C" -NoNewline
                $pos = $buf.Length
            }
            continue
        }

        $ch = $k.KeyChar
        if (-not [char]::IsControl($ch)) {
            if ($pos -eq $buf.Length) {
                $buf.Append($ch) | Out-Null
                $pos++
                Write-Host $ch -NoNewline
            } else {
                $buf.Insert($pos, $ch) | Out-Null
                $pos++
                $tail = $buf.ToString().Substring($pos)
                Write-Host "$ch$tail" -NoNewline
                $backCount = $tail.Length
                if ($backCount -gt 0) {
                    Write-Host "${CSI}${backCount}D" -NoNewline
                }
            }
        }
    }
}

function Select-InteractiveOption {
    param(
        [string]$PromptTitle,
        [array]$Options,
        [int]$DefaultIndex = 0
    )

    if (-not $Options -or $Options.Count -eq 0) { return $null }

    $sel = if ($DefaultIndex -ge 0 -and $DefaultIndex -lt $Options.Count) { $DefaultIndex } else { 0 }
    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    Write-Host ""
    Write-Host "  ${White}${Bold}$PromptTitle${Reset}"
    Write-Host ""

    # Garantizar líneas disponibles en buffer para evitar desajuste al desplazar
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host ""
    }
    $menuStartRow = try { [Console]::CursorTop - $Options.Count } catch { $startTop }

    # Función de dibujo de opciones
    $renderMenu = {
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $opt = $Options[$i]
            $label = if ($opt.Label) { $opt.Label } else { $opt.ToString() }
            try { [Console]::SetCursorPosition(2, $menuStartRow + $i) } catch { }

            if ($i -eq $sel) {
                Write-Host "${Cyan}${Bold}> ${White}${Bold}$label${Reset}    $ClrToEnd" -NoNewline
            } else {
                Write-Host "  ${LeadLight}$label${Reset}    $ClrToEnd" -NoNewline
            }
        }
    }

    & $renderMenu

    try {
        while ($true) {
            $k = [Console]::ReadKey($true)

            if ($k.Key -eq [ConsoleKey]::UpArrow) {
                $sel = if ($sel -gt 0) { $sel - 1 } else { $Options.Count - 1 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::DownArrow) {
                $sel = if ($sel -lt ($Options.Count - 1)) { $sel + 1 } else { 0 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::Enter) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Options.Count) } catch { }
                Write-Host ""
                $chosen = $Options[$sel]
                if ($chosen.Value) { return $chosen.Value } else { return $chosen.ToString() }
            }

            if ($k.Key -eq [ConsoleKey]::Escape) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Options.Count) } catch { }
                Write-Host ""
                $def = $Options[$DefaultIndex]
                if ($def.Value) { return $def.Value } else { return $def.ToString() }
            }

            # Selección numérica directa (1-9)
            $ch = [string]$k.KeyChar
            $numVal = -1
            if ([int]::TryParse($ch, [ref]$numVal) -and $numVal -ge 1 -and $numVal -le $Options.Count) {
                $sel = $numVal - 1
                & $renderMenu
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Options.Count) } catch { }
                Write-Host ""
                $chosen = $Options[$sel]
                if ($chosen.Value) { return $chosen.Value } else { return $chosen.ToString() }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}


function Select-InteractiveMediaFormat {
    param(
        [string]$PromptTitle = "Selecciona el formato y calidad de salida:",
        [string]$DefaultFormat = "mp4",
        [string]$DefaultMp4Quality = "720p",
        [string]$DefaultMp3Quality = "320k"
    )

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    # Catálogo de calidades multimedia soportadas
    $mp4Qualities = @(
        @{ Id = "1080p60HD"; Desc = "Video Full HD 60fps" },
        @{ Id = "1080pHD";   Desc = "Video Full HD 1080p" },
        @{ Id = "720p60";     Desc = "Video HD 60fps" },
        @{ Id = "720p";       Desc = "Video HD 720p" },
        @{ Id = "480p";       Desc = "Video SD 480p" },
        @{ Id = "360p";       Desc = "Video Móvil 360p" },
        @{ Id = "240p";       Desc = "Video Ahorro 240p" },
        @{ Id = "140p";       Desc = "Video Ultra Ligero 140p" }
    )

    $mp3Qualities = @(
        @{ Id = "320k"; Desc = "Audio MP3 Máxima Fidelidad 320 kbps" },
        @{ Id = "256k"; Desc = "Audio MP3 Alta Fidelidad 256 kbps" },
        @{ Id = "192k"; Desc = "Audio MP3 Balanceado 192 kbps" },
        @{ Id = "128k"; Desc = "Audio MP3 Estándar 128 kbps" },
        @{ Id = "96k";  Desc = "Audio MP3 Ahorro 96 kbps" },
        @{ Id = "64k";  Desc = "Audio MP3 Mínimo 64 kbps" }
    )

    # 0 -> mp3, 1 -> mp4, 2 -> wav
    $selFormat = if ($DefaultFormat -eq "mp3") { 0 } elseif ($DefaultFormat -eq "wav") { 2 } else { 1 }

    $mp4Idx = 3 # 720p por defecto
    for ($i = 0; $i -lt $mp4Qualities.Count; $i++) {
        if ($mp4Qualities[$i].Id -eq $DefaultMp4Quality) {
            $mp4Idx = $i
            break
        }
    }

    $mp3Idx = 0 # 320k por defecto
    for ($i = 0; $i -lt $mp3Qualities.Count; $i++) {
        if ($mp3Qualities[$i].Id -eq $DefaultMp3Quality) {
            $mp3Idx = $i
            break
        }
    }

    Write-Host ""
    Write-Host "  ${White}${Bold}$PromptTitle${Reset}"
    Write-Host ""

    # Espacio para 3 opciones + 1 línea de separación + 1 línea de atajos
    $totalMenuRows = 5
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt $totalMenuRows; $i++) {
        Write-Host ""
    }
    $menuStartRow = try { [Console]::CursorTop - $totalMenuRows } catch { $startTop }

    $renderMenu = {
        $curMp3 = $mp3Qualities[$mp3Idx]
        $curMp4 = $mp4Qualities[$mp4Idx]

        # Fila 0: MP3
        try { [Console]::SetCursorPosition(2, $menuStartRow + 0) } catch { }
        if ($selFormat -eq 0) {
            Write-Host "${Cyan}${Bold}> [1] mp3  ${Yellow}◂ $($curMp3.Id) ▸${Reset} ${LeadLight}($($curMp3.Desc))${Reset}    $ClrToEnd" -NoNewline
        } else {
            Write-Host "  ${LeadLight}[1] mp3  ($($curMp3.Id))${Reset}    $ClrToEnd" -NoNewline
        }

        # Fila 1: MP4
        try { [Console]::SetCursorPosition(2, $menuStartRow + 1) } catch { }
        if ($selFormat -eq 1) {
            Write-Host "${Cyan}${Bold}> [2] mp4  ${Yellow}◂ $($curMp4.Id) ▸${Reset} ${LeadLight}($($curMp4.Desc))${Reset}    $ClrToEnd" -NoNewline
        } else {
            Write-Host "  ${LeadLight}[2] mp4  ($($curMp4.Id))${Reset}    $ClrToEnd" -NoNewline
        }

        # Fila 2: WAV
        try { [Console]::SetCursorPosition(2, $menuStartRow + 2) } catch { }
        if ($selFormat -eq 2) {
            Write-Host "${Cyan}${Bold}> [3] wav  ${Yellow}◂ lossless ▸${Reset} ${LeadLight}(Audio PCM sin compresión)${Reset}    $ClrToEnd" -NoNewline
        } else {
            Write-Host "  ${LeadLight}[3] wav  (Audio PCM sin compresión)${Reset}    $ClrToEnd" -NoNewline
        }

        # Fila 3: Espaciado
        try { [Console]::SetCursorPosition(2, $menuStartRow + 3) } catch { }
        Write-Host "$ClrToEnd" -NoNewline

        # Fila 4: Atajos de teclado
        try { [Console]::SetCursorPosition(2, $menuStartRow + 4) } catch { }
        Write-Host "${LeadLight}↑/↓ Navegar  ·  ←/→ Cambiar calidad  ·  enter Confirmar  ·  esc Cancelar${Reset}$ClrToEnd" -NoNewline
    }

    & $renderMenu

    try {
        while ($true) {
            $k = [Console]::ReadKey($true)

            if ($k.Key -eq [ConsoleKey]::UpArrow) {
                $selFormat = if ($selFormat -gt 0) { $selFormat - 1 } else { 2 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::DownArrow) {
                $selFormat = if ($selFormat -lt 2) { $selFormat + 1 } else { 0 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::LeftArrow) {
                if ($selFormat -eq 0) {
                    $mp3Idx = if ($mp3Idx -gt 0) { $mp3Idx - 1 } else { $mp3Qualities.Count - 1 }
                } elseif ($selFormat -eq 1) {
                    $mp4Idx = if ($mp4Idx -gt 0) { $mp4Idx - 1 } else { $mp4Qualities.Count - 1 }
                }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::RightArrow) {
                if ($selFormat -eq 0) {
                    $mp3Idx = if ($mp3Idx -lt ($mp3Qualities.Count - 1)) { $mp3Idx + 1 } else { 0 }
                } elseif ($selFormat -eq 1) {
                    $mp4Idx = if ($mp4Idx -lt ($mp4Qualities.Count - 1)) { $mp4Idx + 1 } else { 0 }
                }
                & $renderMenu
                continue
            }

            $ch = [string]$k.KeyChar
            if ($ch -eq '1') {
                $selFormat = 0
                & $renderMenu
                continue
            } elseif ($ch -eq '2') {
                $selFormat = 1
                & $renderMenu
                continue
            } elseif ($ch -eq '3') {
                $selFormat = 2
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::Enter) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $totalMenuRows) } catch { }
                Write-Host ""

                if ($selFormat -eq 0) {
                    return @{ Format = 'mp3'; Quality = $mp3Qualities[$mp3Idx].Id }
                } elseif ($selFormat -eq 1) {
                    return @{ Format = 'mp4'; Quality = $mp4Qualities[$mp4Idx].Id }
                } else {
                    return @{ Format = 'wav'; Quality = 'lossless' }
                }
            }

            $isCtrlC = ($k.KeyChar -eq [char]3) -or ($k.Key -eq [ConsoleKey]::C -and ($k.Modifiers -band [ConsoleModifiers]::Control))
            if ($k.Key -eq [ConsoleKey]::Escape -or $isCtrlC) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $totalMenuRows) } catch { }
                Write-Host ""
                return $null
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}


function Select-InteractiveTTSVoice {
    param(
        [string]$PromptTitle = "Selecciona el idioma y la voz neuronal:",
        [string]$DefaultLang = "Español",
        [string]$DefaultVoiceId = "es-ES-alvaro"
    )

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    # Catálogo multilingüe con las 28+ voces neuronales de Vork TTS Studio
    $catalog = @(
        @{
            Name = "Español";
            Voices = @(
                @{ Id = "es-ES-alvaro"; Edge = "es-ES-AlvaroNeural"; Name = "Álvaro"; Country = "España"; Gender = "Masculina"; Desc = "Sobria y madura corporativa" },
                @{ Id = "es-ES-sofia";  Edge = "es-ES-ElviraNeural"; Name = "Sofía";  Country = "España"; Gender = "Femenina";  Desc = "Castellano impecable y claro" },
                @{ Id = "es-MX-mateo";  Edge = "es-MX-JorgeNeural";  Name = "Mateo";  Country = "México"; Gender = "Masculina"; Desc = "Cálida para audiolibros" },
                @{ Id = "es-MX-dalia";  Edge = "es-MX-DaliaNeural";  Name = "Dalia";  Country = "México"; Gender = "Femenina";  Desc = "Articulación y dicción moderna" },
                @{ Id = "es-PE-diego";  Edge = "es-PE-AlexNeural";   Name = "Diego";  Country = "Perú";   Gender = "Masculina"; Desc = "Andina con articulación precisa" },
                @{ Id = "es-PE-camila"; Edge = "es-PE-CamilaNeural"; Name = "Camila"; Country = "Perú";   Gender = "Femenina";  Desc = "Entonación neutra para tutoriales" },
                @{ Id = "es-AR-lucia";  Edge = "es-AR-ElenaNeural";  Name = "Lucía";  Country = "Argentina"; Gender = "Femenina";  Desc = "Cadencia suave rioplatense" },
                @{ Id = "es-AR-tomas";  Edge = "es-AR-TomasNeural";  Name = "Tomás";  Country = "Argentina"; Gender = "Masculina"; Desc = "Ritmo natural y timbre moderno" },
                @{ Id = "es-CO-gonzalo";Edge = "es-CO-GonzaloNeural";Name = "Gonzalo";Country = "Colombia";  Gender = "Masculina"; Desc = "Pronunciación cristalina" },
                @{ Id = "es-CO-salome"; Edge = "es-CO-SalomeNeural"; Name = "Salomé"; Country = "Colombia";  Gender = "Femenina";  Desc = "Timbre dulce y expresivo" },
                @{ Id = "es-US-paloma"; Edge = "es-US-PalomaNeural"; Name = "Paloma"; Country = "Latinoamérica Neutra"; Gender = "Femenina"; Desc = "Neutral para toda América Latina" },
                @{ Id = "es-US-alonso"; Edge = "es-US-AlonsoNeural"; Name = "Alonso"; Country = "Latinoamérica Neutra"; Gender = "Masculina"; Desc = "Institucional y sobria para noticias" }
            )
        },
        @{
            Name = "English";
            Voices = @(
                @{ Id = "en-US-emma";   Edge = "en-US-JennyNeural";  Name = "Emma";   Country = "United States"; Gender = "Femenina";  Desc = "Studio Neural clear narration" },
                @{ Id = "en-US-liam";   Edge = "en-US-GuyNeural";    Name = "Liam";   Country = "United States"; Gender = "Masculina"; Desc = "Engaging and natural inflection" },
                @{ Id = "en-GB-james";  Edge = "en-GB-RyanNeural";   Name = "James";  Country = "United Kingdom"; Gender = "Masculina"; Desc = "Distinguished BBC British tone" },
                @{ Id = "en-GB-sonia";  Edge = "en-GB-SoniaNeural";  Name = "Sonia";  Country = "United Kingdom"; Gender = "Femenina";  Desc = "Classical rhythm and soothing timbre" },
                @{ Id = "en-AU-olivia"; Edge = "en-AU-NatashaNeural";Name = "Olivia"; Country = "Australia"; Gender = "Femenina";  Desc = "Crisp Australian bright voice" }
            )
        },
        @{
            Name = "Français";
            Voices = @(
                @{ Id = "fr-FR-chloe";  Edge = "fr-FR-DeniseNeural"; Name = "Chloé";  Country = "France"; Gender = "Femenina";  Desc = "Parisienne fluide et naturelle" },
                @{ Id = "fr-FR-henri";  Edge = "fr-FR-HenriNeural";  Name = "Henri";  Country = "France"; Gender = "Masculina"; Desc = "Diction soignée et expressive" }
            )
        },
        @{
            Name = "Deutsch";
            Voices = @(
                @{ Id = "de-DE-hanna";  Edge = "de-DE-KatjaNeural";  Name = "Hanna";  Country = "Deutschland"; Gender = "Femenina";  Desc = "Klare deutsche Aussprache" },
                @{ Id = "de-DE-lukas";  Edge = "de-DE-ConradNeural"; Name = "Lukas";  Country = "Deutschland"; Gender = "Masculina"; Desc = "Kräftig für formelle Präsentationen" }
            )
        },
        @{
            Name = "Italiano";
            Voices = @(
                @{ Id = "it-IT-giulia"; Edge = "it-IT-ElsaNeural";   Name = "Giulia"; Country = "Italia"; Gender = "Femenina";  Desc = "Calda, espressiva e melodica" },
                @{ Id = "it-IT-marco";  Edge = "it-IT-DiegoNeural";  Name = "Marco";  Country = "Italia"; Gender = "Masculina"; Desc = "Timbro profondo ed elegante" }
            )
        },
        @{
            Name = "Português";
            Voices = @(
                @{ Id = "pt-BR-isabella"; Edge = "pt-BR-FranciscaNeural"; Name = "Isabella"; Country = "Brasil"; Gender = "Femenina";  Desc = "Voz brasileira calorosa e vibrante" },
                @{ Id = "pt-BR-antonio";  Edge = "pt-BR-AntonioNeural";   Name = "Antônio";  Country = "Brasil"; Gender = "Masculina"; Desc = "Grave e marcante para tutoriais" }
            )
        },
        @{
            Name = "日本語";
            Voices = @(
                @{ Id = "ja-JP-sakura"; Edge = "ja-JP-NanamiNeural"; Name = "さくら (Sakura)"; Country = "Japón"; Gender = "Femenina";  Desc = "スタジオ品質の自然な女性音声" },
                @{ Id = "ja-JP-kenji";  Edge = "ja-JP-KeitaNeural";  Name = "健二 (Kenji)";  Country = "Japón"; Gender = "Masculina"; Desc = "落ち着いた深みのある男性音声" }
            )
        },
        @{
            Name = "中文";
            Voices = @(
                @{ Id = "zh-CN-liwei";  Edge = "zh-CN-XiaoxiaoNeural"; Name = "李薇 (Li Wei)"; Country = "China"; Gender = "Femenina";  Desc = "标准普通话自然清晰女声" },
                @{ Id = "zh-CN-yunxi";  Edge = "zh-CN-YunxiNeural";    Name = "云希 (Yun Xi)"; Country = "China"; Gender = "Masculina"; Desc = "浑厚自然播报新闻专业男声" }
            )
        },
        @{
            Name = "Русский";
            Voices = @(
                @{ Id = "ru-RU-anastasia"; Edge = "ru-RU-SvetlanaNeural"; Name = "Анастасия (Anastasia)"; Country = "Rusia"; Gender = "Femenina";  Desc = "Бархатный тембр и артикуляция" },
                @{ Id = "ru-RU-dmitry";    Edge = "ru-RU-DmitryNeural";   Name = "Дмитрий (Dmitry)";     Country = "Rusia"; Gender = "Masculina"; Desc = "Четкий мужской голос" }
            )
        },
        @{
            Name = "한국어";
            Voices = @(
                @{ Id = "ko-KR-minji";   Edge = "ko-KR-SunHiNeural";  Name = "민지 (Min-Ji)";  Country = "Corea del Sur"; Gender = "Femenina";  Desc = "맑고 또렷한 표준어 여성 음성" },
                @{ Id = "ko-KR-injoon";  Edge = "ko-KR-InJoonNeural"; Name = "인준 (In-Joon)"; Country = "Corea del Sur"; Gender = "Masculina"; Desc = "부드럽고 신뢰감을 주는 남성" }
            )
        },
        @{
            Name = "العربية";
            Voices = @(
                @{ Id = "ar-XA-omar";    Edge = "ar-SA-HamedNeural";   Name = "عمر (Omar)";     Country = "Mundo Árabe"; Gender = "Masculina"; Desc = "صوت ذكوري جهوري فصيح ووقور" },
                @{ Id = "ar-XA-zariyah"; Edge = "ar-SA-ZariyahNeural"; Name = "زارية (Zariyah)"; Country = "Mundo Árabe"; Gender = "Femenina";  Desc = "صوت أنثوي عربي عذب وواضح" }
            )
        }
    )

    $selLang = 0
    for ($i = 0; $i -lt $catalog.Count; $i++) {
        if ($catalog[$i].Name -eq $DefaultLang) {
            $selLang = $i
            break
        }
    }

    # Inicializar índice de voz por cada idioma
    $voiceIndices = @(0) * $catalog.Count

    Write-Host ""
    Write-Host "  ${White}${Bold}$PromptTitle${Reset}"
    Write-Host ""

    # Espacio para las filas del catálogo + línea separadora + línea de atajos
    $totalMenuRows = $catalog.Count + 2
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt $totalMenuRows; $i++) {
        Write-Host ""
    }
    $menuStartRow = try { [Console]::CursorTop - $totalMenuRows } catch { $startTop }

    $renderMenu = {
        for ($i = 0; $i -lt $catalog.Count; $i++) {
            $lang = $catalog[$i]
            $vIdx = $voiceIndices[$i]
            $voice = $lang.Voices[$vIdx]
            $numStr = if (($i + 1) -lt 10) { "[$($i + 1)] " } else { "[$($i + 1)]" }
            $langPad = $lang.Name.PadRight(10)

            try { [Console]::SetCursorPosition(2, $menuStartRow + $i) } catch { }
            if ($i -eq $selLang) {
                Write-Host "${Cyan}${Bold}> $numStr $langPad ${Yellow}◂ $($voice.Name) ▸${Reset} ${LeadLight}($($voice.Country) · $($voice.Gender) · $($voice.Desc))${Reset}    $ClrToEnd" -NoNewline
            } else {
                Write-Host "  ${LeadLight}$numStr $langPad ($($voice.Name) · $($voice.Country))${Reset}    $ClrToEnd" -NoNewline
            }
        }

        # Separador
        try { [Console]::SetCursorPosition(2, $menuStartRow + $catalog.Count) } catch { }
        Write-Host "$ClrToEnd" -NoNewline

        # Barra de atajos
        try { [Console]::SetCursorPosition(2, $menuStartRow + $catalog.Count + 1) } catch { }
        Write-Host "${LeadLight}↑/↓ Idioma  ·  ←/→ Cambiar voz  ·  enter Confirmar  ·  esc Cancelar${Reset}$ClrToEnd" -NoNewline
    }

    & $renderMenu

    try {
        while ($true) {
            $k = [Console]::ReadKey($true)

            if ($k.Key -eq [ConsoleKey]::UpArrow) {
                $selLang = if ($selLang -gt 0) { $selLang - 1 } else { $catalog.Count - 1 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::DownArrow) {
                $selLang = if ($selLang -lt ($catalog.Count - 1)) { $selLang + 1 } else { 0 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::LeftArrow) {
                $curCount = $catalog[$selLang].Voices.Count
                $voiceIndices[$selLang] = if ($voiceIndices[$selLang] -gt 0) { $voiceIndices[$selLang] - 1 } else { $curCount - 1 }
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::RightArrow) {
                $curCount = $catalog[$selLang].Voices.Count
                $voiceIndices[$selLang] = if ($voiceIndices[$selLang] -lt ($curCount - 1)) { $voiceIndices[$selLang] + 1 } else { 0 }
                & $renderMenu
                continue
            }

            # Selección numérica directa (1-9)
            $ch = [string]$k.KeyChar
            $numVal = -1
            if ([int]::TryParse($ch, [ref]$numVal) -and $numVal -ge 1 -and $numVal -le $catalog.Count) {
                $selLang = $numVal - 1
                & $renderMenu
                continue
            }

            if ($k.Key -eq [ConsoleKey]::Enter) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $totalMenuRows) } catch { }
                Write-Host ""
                $chosenLang = $catalog[$selLang]
                $chosenVoice = $chosenLang.Voices[$voiceIndices[$selLang]]
                return @{
                    Language  = $chosenLang.Name
                    Id        = $chosenVoice.Id
                    EdgeVoice = $chosenVoice.Edge
                    Name      = $chosenVoice.Name
                    Country   = $chosenVoice.Country
                    Gender    = $chosenVoice.Gender
                    Desc      = $chosenVoice.Desc
                }
            }

            $isCtrlC = ($k.KeyChar -eq [char]3) -or ($k.Key -eq [ConsoleKey]::C -and ($k.Modifiers -band [ConsoleModifiers]::Control))
            if ($k.Key -eq [ConsoleKey]::Escape -or $isCtrlC) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $totalMenuRows) } catch { }
                Write-Host ""
                return $null
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Select-InteractiveTheme {
    param(
        [array]$Themes,
        [string]$ActiveThemeId
    )

    if (-not $Themes -or $Themes.Count -eq 0) { return $null }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    $activeIdx = 0
    for ($i = 0; $i -lt $Themes.Count; $i++) {
        if ($Themes[$i].Id -eq $ActiveThemeId) {
            $activeIdx = $i
            break
        }
    }
    $sel = $activeIdx

    Write-Host ""
    Write-Host "  ${White}${Bold}CATÁLOGO DE LOS 10 TEMAS VISUALES DE VORK CLI:${Reset}"
    $currName = if ($global:VorkThemeName) { $global:VorkThemeName } else { "Plomo Oscuro (Lead Slate - Tema Oficial)" }
    Write-Host "  ${LeadLight}Tema activo actualmente: ${Cyan}${Bold}$currName${Reset}"
    Write-Host ""

    # Pre-scroll para buffer estable
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt ($Themes.Count + 1); $i++) {
        Write-Host ""
    }
    $menuStartRow = try { [Console]::CursorTop - ($Themes.Count + 1) } catch { $startTop }

    $renderThemes = {
        for ($i = 0; $i -lt $Themes.Count; $i++) {
            $th = $Themes[$i]
            $num = if (($i + 1) -lt 10) { "[$($i + 1)] " } else { "[$($i + 1)]" }
            $isActive = ($th.Id -eq $global:VorkThemeId)
            $badge = if ($isActive) { "$($CSI)42;30;1m [ACTIVO] $Reset" } else { "         " }
            $namePad = $th.Name.PadRight(26)
            $lineContent = "${Cyan}$num${Reset} $badge $($th.Dot) ${White}${Bold}$namePad${Reset} ${LeadLight}· $($th.Acentos)${Reset}"

            try { [Console]::SetCursorPosition(2, $menuStartRow + $i) } catch { }

            if ($i -eq $sel) {
                Write-Host "${Cyan}${Bold}> ${Reset}$lineContent    $ClrToEnd" -NoNewline
            } else {
                Write-Host "  $lineContent    $ClrToEnd" -NoNewline
            }
        }
        try {
            [Console]::SetCursorPosition(2, $menuStartRow + $Themes.Count)
            Write-Host "  ${LeadDark}↑/↓ Navegar  Enter Seleccionar tema  Esc Cancelar${Reset}    $ClrToEnd" -NoNewline
        } catch { }
    }

    & $renderThemes

    try {
        while ($true) {
            $k = [Console]::ReadKey($true)

            if ($k.Key -eq [ConsoleKey]::UpArrow) {
                $sel = if ($sel -gt 0) { $sel - 1 } else { $Themes.Count - 1 }
                & $renderThemes
                continue
            }

            if ($k.Key -eq [ConsoleKey]::DownArrow) {
                $sel = if ($sel -lt ($Themes.Count - 1)) { $sel + 1 } else { 0 }
                & $renderThemes
                continue
            }

            if ($k.Key -eq [ConsoleKey]::Enter) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Themes.Count + 1) } catch { }
                Write-Host ""
                return $Themes[$sel].Id
            }

            if ($k.Key -eq [ConsoleKey]::Escape) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Themes.Count + 1) } catch { }
                Write-Host ""
                return $null
            }

            # Selección numérica directa (1-9, 0 para 10)
            $ch = [string]$k.KeyChar
            $numVal = -1
            if ($ch -eq '0' -and $Themes.Count -ge 10) {
                $sel = 9
                & $renderThemes
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Themes.Count + 1) } catch { }
                Write-Host ""
                return $Themes[$sel].Id
            } elseif ([int]::TryParse($ch, [ref]$numVal) -and $numVal -ge 1 -and $numVal -le $Themes.Count) {
                $sel = $numVal - 1
                & $renderThemes
                try { [Console]::SetCursorPosition(0, $menuStartRow + $Themes.Count + 1) } catch { }
                Write-Host ""
                return $Themes[$sel].Id
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Select-InteractivePermissions {
    param(
        [hashtable]$PermsHash
    )

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    $keys = @($PermsHash.Keys)
    $totalItems = $keys.Count + 1 # +1 para la opción de Guardar y Salir
    $sel = 0

    Write-Host ""
    Write-Host "  ${White}${Bold}PERMISOS DE SEGURIDAD Y SANDBOX · VORK CLI${Reset}"
    Write-Host "  ${LeadLight}Configuración persistente guardada en ~/.vork/permissions.json${Reset}"
    Write-Host ""

    # Pre-scroll para buffer estable
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt ($totalItems + 1); $i++) {
        Write-Host ""
    }
    $menuStartRow = try { [Console]::CursorTop - ($totalItems + 1) } catch { $startTop }

    $renderPerms = {
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $k = $keys[$i]
            $item = $PermsHash[$k]
            $num = if (($i + 1) -lt 10) { "[$($i + 1)] " } else { "[$($i + 1)]" }
            $statusBadge = if ($item.Enabled) {
                "$($CSI)42;30;1m [OK] PERMITIDO $Reset"
            } else {
                "$($CSI)41;97;1m [X] DENEGADO  $Reset"
            }
            $title = $item.Name.PadRight(28)
            $lineContent = "${Cyan}$num${Reset} $statusBadge  ${White}${Bold}$title${Reset} ${LeadLight}· $($item.Desc)${Reset}"

            try { [Console]::SetCursorPosition(2, $menuStartRow + $i) } catch { }

            if ($i -eq $sel) {
                Write-Host "${Cyan}${Bold}> ${Reset}$lineContent    $ClrToEnd" -NoNewline
            } else {
                Write-Host "  $lineContent    $ClrToEnd" -NoNewline
            }
        }

        # Opción final: Guardar y Salir
        $exitIdx = $keys.Count
        try { [Console]::SetCursorPosition(2, $menuStartRow + $exitIdx) } catch { }
        if ($sel -eq $exitIdx) {
            Write-Host ("${Cyan}${Bold}> ${Green}${Bold} " + "[✓] Guardar y Volver al Prompt${Reset}                                                      $ClrToEnd") -NoNewline
        } else {
            Write-Host ("  ${LeadLight} " + "[✓] Guardar y Volver al Prompt${Reset}                                                      $ClrToEnd") -NoNewline
        }

        # Footer con atajos de navegación
        try {
            [Console]::SetCursorPosition(2, $menuStartRow + $exitIdx + 1)
            Write-Host "  ${LeadDark}↑/↓ Navegar  Enter/Espacio Alternar permiso  Esc Salir${Reset}    $ClrToEnd" -NoNewline
        } catch { }
    }

    & $renderPerms

    try {
        while ($true) {
            $k = [Console]::ReadKey($true)

            if ($k.Key -eq [ConsoleKey]::UpArrow) {
                $sel = if ($sel -gt 0) { $sel - 1 } else { $totalItems - 1 }
                & $renderPerms
                continue
            }

            if ($k.Key -eq [ConsoleKey]::DownArrow) {
                $sel = if ($sel -lt ($totalItems - 1)) { $sel + 1 } else { 0 }
                & $renderPerms
                continue
            }

            # Enter o Espacio: si está sobre un permiso, alternarlo. Si está en [Guardar y Salir], salir.
            if ($k.Key -eq [ConsoleKey]::Enter -or $k.Key -eq [ConsoleKey]::Spacebar) {
                if ($sel -eq $keys.Count) {
                    try { [Console]::SetCursorPosition(0, $menuStartRow + $totalItems + 1) } catch { }
                    Write-Host ""
                    return $PermsHash
                } else {
                    $selectedKey = $keys[$sel]
                    $PermsHash[$selectedKey].Enabled = -not $PermsHash[$selectedKey].Enabled
                    Save-VorkPermissions -PermsHash $PermsHash
                    & $renderPerms
                    continue
                }
            }

            if ($k.Key -eq [ConsoleKey]::Escape) {
                try { [Console]::SetCursorPosition(0, $menuStartRow + $totalItems + 1) } catch { }
                Write-Host ""
                return $PermsHash
            }

            # Teclado numérico directo (1-9) para saltar y alternar directamente
            $ch = [string]$k.KeyChar
            $numVal = -1
            if ([int]::TryParse($ch, [ref]$numVal) -and $numVal -ge 1 -and $numVal -le $keys.Count) {
                $sel = $numVal - 1
                $selectedKey = $keys[$sel]
                $PermsHash[$selectedKey].Enabled = -not $PermsHash[$selectedKey].Enabled
                Save-VorkPermissions -PermsHash $PermsHash
                & $renderPerms
                continue
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Show-InteractiveModelSwitcher {
    $models = @(
        "Vork 3"
    )

    $efforts = @("low", "medium", "high")
    $effortDescs = @{
        "low"    = "Fast response times, streamlined reasoning"
        "medium" = "Balanced speed and reasoning quality for most tasks"
        "high"   = "Maximum reasoning depth for complex architectural and coding tasks"
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    $activeModel = "Vork 3"
    $activeTier = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }

    $selModelIdx = 0
    $effortIdx = [Array]::IndexOf($efforts, $activeTier)
    if ($effortIdx -lt 0) { $effortIdx = 1 }

    $searchBuf = ""
    $width = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
    if ($width -le 40 -or $width -gt 300) { $width = 120 }
    $ruleChar = [char]0x2500
    $rule = [string]::new($ruleChar, ($width - 1))

    # Pre-scroll buffer space for rock-solid stability
    $neededRows = 14
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt $neededRows; $i++) {
        Write-Host ""
    }
    $baseRow = try { [Console]::CursorTop - $neededRows } catch { $startTop }

    $renderAll = {
        # Filtrar modelos según $searchBuf
        $filtered = @($models | Where-Object { -not $searchBuf -or $_.ToLower().Contains($searchBuf.ToLower()) })
        $selModelIdx = 0

        $row = $baseRow

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${Coral}${Bold}> ${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${Lead}$rule${Reset}$ClrToEnd"
        $row++

        # Título
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${White}${Bold}Switch Model${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "$ClrToEnd"
        $row++

        # Search Box
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        $searchLabel = if ($searchBuf) { "  ${LeadLight}Search: ${White}${Bold}$searchBuf${Reset}" } else { "  ${LeadLight}Search:${Reset}" }
        Write-Host "$searchLabel$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "          ${Lead}────────────────────${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "$ClrToEnd"
        $row++

        if ($filtered.Count -gt 0) {
            # Único Modelo: Vork 3
            try { [Console]::SetCursorPosition(0, $row) } catch { }
            $mName = $filtered[0]
            $padName = $mName.PadRight(28)
            Write-Host "${Cyan}${Bold}> ${White}${Bold}$padName ${LeadLight}(current)${Reset}    $ClrToEnd"
            $row++

            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "$ClrToEnd"
            $row++

            # Slider de Effort
            # low:    ◂        ◉──────────────○──────────────○        ▸
            # medium: ◂        ●━━━━━━━━━━━━━━◉──────────────○        ▸
            # high:   ◂        ●━━━━━━━━━━━━━━●━━━━━━━━━━━━━━◉        ▸
            $triL = [char]0x25C2 # ◂
            $triR = [char]0x25B8 # ▸
            $dDot = [char]0x25CF # ●
            $cTar = [char]0x25C9 # ◉
            $cEmp = [char]0x25CB # ○
            $bHvy = [string]::new([char]0x2501, 14) # ━━━━━━
            $bThn = [string]::new([char]0x2500, 14) # ──────

            $currEffort = $efforts[$effortIdx]
            $effortColor = switch ($currEffort) {
                "low"    { $Green }
                "medium" { $Yellow }
                "high"   { $Coral }
                default  { $Cyan }
            }

            $sliderGraphic = ""
            $labelsGraphic = ""
            if ($effortIdx -eq 0) {
                $sliderGraphic = "${Green}${Bold}$cTar${Reset}${LeadDark}$bThn$cEmp$bThn$cEmp${Reset}"
                $labelsGraphic = "${Green}${Bold}low${Reset}          ${LeadLight}medium          high${Reset}"
            } elseif ($effortIdx -eq 1) {
                $sliderGraphic = "${Yellow}${Bold}$dDot$bHvy$cTar${Reset}${LeadDark}$bThn$cEmp${Reset}"
                $labelsGraphic = "${LeadLight}low          ${Yellow}${Bold}medium${Reset}          ${LeadLight}high${Reset}"
            } else {
                $sliderGraphic = "${Coral}${Bold}$dDot$bHvy$dDot$bHvy$cTar${Reset}"
                $labelsGraphic = "${LeadLight}low          medium          ${Coral}${Bold}high${Reset}"
            }

            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "  ${LeadLight}Effort  ${effortColor}$triL${Reset}        $sliderGraphic        ${effortColor}$triR${Reset}$ClrToEnd"
            $row++

            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "                  $labelsGraphic$ClrToEnd"
            $row++

            try { [Console]::SetCursorPosition(0, $row) } catch { }
            $effDesc = $effortDescs[$currEffort]
            Write-Host "            ${effortColor}$effDesc${Reset}$ClrToEnd"
            $row++

            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "$ClrToEnd"
            $row++

            # Footer con instrucciones normales
            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "${LeadLight}Keyboard: ${Cyan}↑/↓${Reset} ${LeadLight}Navigate  ${Cyan}←/→${Reset} ${LeadLight}Effort  ${Cyan}enter${Reset} ${LeadLight}Select  ${Cyan}esc${Reset} ${LeadLight}Go Back${Reset}$ClrToEnd"
            $row++
        } else {
            # Sin coincidencias
            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "  ${LeadLight}No models match `"$searchBuf`"${Reset}$ClrToEnd"
            $row++

            # Limpiar filas restantes
            for ($c = 0; $c -lt 5; $c++) {
                try { [Console]::SetCursorPosition(0, $row) } catch { }
                Write-Host "$ClrToEnd"
                $row++
            }

            # Footer esc Clear search
            try { [Console]::SetCursorPosition(0, $row) } catch { }
            Write-Host "${LeadLight}Keyboard: ${Cyan}esc${Reset} ${LeadLight}Clear search${Reset}$ClrToEnd"
            $row++
        }

        # Footer derecho con modelo y potencia actual
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        $activeText = "Vork 3 " + [char]0x00B7 + " $($efforts[$effortIdx])"
        $padLen = [Math]::Max(1, ($width - 1) - $activeText.Length)
        Write-Host "$([string]::new(' ', $padLen))${effortColor}$activeText${Reset}$ClrToEnd"
    }

    & $renderAll

    try {
        while ($true) {
            $filtered = @($models | Where-Object { -not $searchBuf -or $_.ToLower().Contains($searchBuf.ToLower()) })
            $k = [Console]::ReadKey($true)

            if ($filtered.Count -gt 0) {
                if ($k.Key -eq [ConsoleKey]::LeftArrow) {
                    $effortIdx = if ($effortIdx -gt 0) { $effortIdx - 1 } else { 0 }
                    & $renderAll
                    continue
                }

                if ($k.Key -eq [ConsoleKey]::RightArrow) {
                    $effortIdx = if ($effortIdx -lt 2) { $effortIdx + 1 } else { 2 }
                    & $renderAll
                    continue
                }

                if ($k.Key -eq [ConsoleKey]::Enter) {
                    $chosenModel = "Vork 3"
                    $chosenEffort = $efforts[$effortIdx]

                    $global:VorkModel = "Vork 3"
                    $global:VorkTier = $chosenEffort

                    try {
                        $vDir = Join-Path $HOME ".vork"
                        if (-not (Test-Path $vDir)) { New-Item -ItemType Directory -Path $vDir -Force | Out-Null }
                        Set-Content -Path (Join-Path $vDir ".model") -Value "Vork 3" -Force -Encoding UTF8
                        Set-Content -Path (Join-Path $vDir ".tier") -Value $chosenEffort -Force -Encoding UTF8
                    } catch { }

                    # Limpiar área del switcher
                    try {
                        for ($c = 0; $c -lt $neededRows; $c++) {
                            [Console]::SetCursorPosition(0, $baseRow + $c)
                            Write-Host ([string]::new(" ", $width - 1)) -NoNewline
                        }
                        [Console]::SetCursorPosition(0, $baseRow)
                    } catch { }

                    return @{ Action = "selected"; Model = "Vork 3"; Tier = $chosenEffort }
                }
            }

            if ($k.Key -eq [ConsoleKey]::Escape) {
                if ($searchBuf.Length -gt 0) {
                    $searchBuf = ""
                    & $renderAll
                    continue
                }

                # Limpiar área del switcher
                try {
                    for ($c = 0; $c -lt $neededRows; $c++) {
                        [Console]::SetCursorPosition(0, $baseRow + $c)
                        Write-Host ([string]::new(" ", $width - 1)) -NoNewline
                    }
                    [Console]::SetCursorPosition(0, $baseRow)
                } catch { }

                return @{ Action = "exited" }
            }

            if ($k.Key -eq [ConsoleKey]::Backspace) {
                if ($searchBuf.Length -gt 0) {
                    $searchBuf = $searchBuf.Substring(0, $searchBuf.Length - 1)
                    & $renderAll
                }
                continue
            }

            $ch = $k.KeyChar
            if (-not [char]::IsControl($ch)) {
                $searchBuf += $ch
                & $renderAll
                continue
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Show-InteractiveSettings {
    $settingsFile = Join-Path $HOME ".vork\settings.json"
    $savedSettings = @{}
    if (Test-Path $settingsFile) {
        try {
            $rawJson = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            foreach ($prop in $rawJson.PSObject.Properties) {
                $savedSettings[$prop.Name] = $prop.Value
            }
        } catch { }
    }

    $settingsData = [ordered]@{
        "agent_mode"           = @{
            Label = "Agent Mode"
            Options = @("default", "accept-edits", "auto", "plan")
            Value = if ($savedSettings["agent_mode"]) { $savedSettings["agent_mode"] } else { "default" }
            Desc = "'default': standard behavior. 'accept-edits': auto-approve file edits, prompt for commands. 'auto': auto-approve edits and safe commands, prompt on irreversible actions. 'plan': research and plan without making changes"
        }
        "animation_speed"      = @{
            Label = "Animation Speed"
            Options = @("medium", "fast", "off")
            Value = if ($savedSettings["animation_speed"]) { $savedSettings["animation_speed"] } else { "medium" }
            Desc = "Adjust UI animation and spinner speed across all interactive components and progress bars in the terminal."
        }
        "artifact_review"      = @{
            Label = "Artifact Review"
            Options = @("asks for review", "always-approve", "off")
            Value = if ($savedSettings["artifact_review"]) { $savedSettings["artifact_review"] } else { "asks for review" }
            Desc = "Determines whether generated artifacts, diffs, and execution plans require interactive confirmation before execution."
        }
        "color_scheme"         = @{
            Label = "Color Scheme"
            Options = @("dark", "light", "system")
            Value = if ($savedSettings["color_scheme"]) { $savedSettings["color_scheme"] } else { "dark" }
            Desc = "Sets terminal color palette mode. 'dark' enables high contrast slate/coral tones; 'light' optimizes for bright terminal backgrounds."
        }
        "conv_grouping"        = @{
            Label = "Conversation Picker Grouping"
            Options = @("none", "project", "date")
            Value = if ($savedSettings["conv_grouping"]) { $savedSettings["conv_grouping"] } else { "none" }
            Desc = "Grouping strategy for recent chat transcripts and session logs in the history browser."
        }
        "copy_on_select"       = @{
            Label = "Copy on Select"
            Options = @("on", "off")
            Value = if ($savedSettings["copy_on_select"]) { $savedSettings["copy_on_select"] } else { "on" }
            Desc = "Automatically copies selected text in interactive modals and responses straight into the system clipboard."
        }
        "editor"               = @{
            Label = "Editor"
            Options = @("auto ($EDITOR)", "code", "vim", "nano", "notepad")
            Value = if ($savedSettings["editor"]) { $savedSettings["editor"] } else { "auto ($EDITOR)" }
            Desc = "External text editor launched when opening code files, configs, or transcript diffs from Vork CLI."
        }
        "editor_mode"          = @{
            Label = "Editor Mode"
            Options = @("default", "vim", "emacs")
            Value = if ($savedSettings["editor_mode"]) { $savedSettings["editor_mode"] } else { "default" }
            Desc = "Keybindings mode for the interactive prompt and text input fields."
        }
        "enable_telemetry"     = @{
            Label = "Enable Telemetry"
            Options = @("on", "off")
            Value = if ($savedSettings["enable_telemetry"]) { $savedSettings["enable_telemetry"] } else { "on" }
            Desc = "Sends anonymous performance benchmarks and error traces to Vork Cloud to diagnose pillar connectivity."
        }
        "non_workspace"        = @{
            Label = "Non-Workspace Access"
            Options = @("off", "on")
            Value = if ($savedSettings["non_workspace"]) { $savedSettings["non_workspace"] } else { "off" }
            Desc = "Permits subagents and tools to inspect files outside the current project root directory when explicitly requested."
        }
        "notifications"        = @{
            Label = "Notifications"
            Options = @("on", "off")
            Value = if ($savedSettings["notifications"]) { $savedSettings["notifications"] } else { "on" }
            Desc = "Emits system toast notifications and audible chimes upon background job, Demucs stem, or /goal completion."
        }
        "queued_messages"      = @{
            Label = "Queued Messages"
            Options = @("Queue", "Discard", "Prompt")
            Value = if ($savedSettings["queued_messages"]) { $savedSettings["queued_messages"] } else { "Queue" }
            Desc = "Behavior when new commands or messages arrive while a long-running subagent task is currently running."
        }
        "rendering_mode"       = @{
            Label = "Rendering Mode"
            Options = @("native terminal (inline)", "fullscreen alternate-screen")
            Value = if ($savedSettings["rendering_mode"]) { $savedSettings["rendering_mode"] } else { "native terminal (inline)" }
            Desc = "Chooses between standard inline ANSI terminal rendering or switching to the terminal's alternate buffer screen."
        }
        "sandbox_mode"         = @{
            Label = "Sandbox Mode"
            Options = @("off", "on")
            Value = if ($savedSettings["sandbox_mode"]) { $savedSettings["sandbox_mode"] } else { "off" }
            Desc = "Restricts shell commands and file writing strictly to a sandboxed temporary directory."
        }
        "seasonal_themes"      = @{
            Label = "Seasonal Themes"
            Options = @("off", "on")
            Value = if ($savedSettings["seasonal_themes"]) { $savedSettings["seasonal_themes"] } else { "off" }
            Desc = "Enables temporary festive holiday themes and accent colors on matching calendar dates."
        }
        "show_active_tasks"    = @{
            Label = "Show Active Tasks"
            Options = @("on", "off")
            Value = if ($savedSettings["show_active_tasks"]) { $savedSettings["show_active_tasks"] } else { "on" }
            Desc = "Displays a real-time status indicator when background subagent jobs or audio processing tasks are active."
        }
        "show_feedback_survey" = @{
            Label = "Show Feedback Survey"
            Options = @("on", "off")
            Value = if ($savedSettings["show_feedback_survey"]) { $savedSettings["show_feedback_survey"] } else { "on" }
            Desc = "Prompts occasional one-click rating surveys after complex autonomous workflows conclude."
        }
        "show_tips"            = @{
            Label = "Show Tips"
            Options = @("on", "off")
            Value = if ($savedSettings["show_tips"]) { $savedSettings["show_tips"] } else { "on" }
            Desc = "Displays contextual shortcuts and keyboard hints beneath the prompt footer."
        }
        "tool_permission"      = @{
            Label = "Tool Permission"
            Options = @("always-proceed (overridden by dangerously-skip-permissions)", "ask-each", "deny-unsafe")
            Value = if ($savedSettings["tool_permission"]) { $savedSettings["tool_permission"] } else { "always-proceed (overridden by dangerously-skip-permissions)" }
            Desc = "Execution policy for agent tools. 'always-proceed' executes without pausing; 'ask-each' prompts before every tool call."
        }
        "use_ai_credits"       = @{
            Label = "Use AI Credits"
            Options = @("off", "on")
            Value = if ($savedSettings["use_ai_credits"]) { $savedSettings["use_ai_credits"] } else { "off" }
            Desc = "Toggles billing allocation for premium high-tier neural models and Demucs v4 studio separation."
        }
        "verbosity"            = @{
            Label = "Verbosity"
            Options = @("medium", "quiet", "verbose")
            Value = if ($savedSettings["verbosity"]) { $savedSettings["verbosity"] } else { "medium" }
            Desc = "Controls the depth of command outputs, subagent logs, and internal diagnostic traces displayed in the terminal."
        }
    }

    $keys = @($settingsData.Keys)
    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    $selIdx = 0
    $searchBuf = ""
    $width = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
    if ($width -le 40 -or $width -gt 300) { $width = 120 }
    $ruleChar = [char]0x2500
    $rule = [string]::new($ruleChar, ($width - 1))

    # Pre-scroll buffer space
    $neededRows = 34
    $startTop = try { [Console]::CursorTop } catch { 0 }
    for ($i = 0; $i -lt $neededRows; $i++) {
        Write-Host ""
    }
    $baseRow = try { [Console]::CursorTop - $neededRows } catch { $startTop }

    $saveAll = {
        try {
            $vDir = Join-Path $HOME ".vork"
            if (-not (Test-Path $vDir)) { New-Item -ItemType Directory -Path $vDir -Force | Out-Null }
            $toExport = @{}
            foreach ($k in $settingsData.Keys) {
                $toExport[$k] = $settingsData[$k].Value
            }
            $toExport | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8
        } catch { }
    }

    $renderAll = {
        # Filtrar configuraciones según searchBuf
        $filteredKeys = @($keys | Where-Object {
            -not $searchBuf -or
            $settingsData[$_].Label.ToLower().Contains($searchBuf.ToLower()) -or
            $settingsData[$_].Value.ToLower().Contains($searchBuf.ToLower())
        })
        if ($filteredKeys.Count -eq 0) { $filteredKeys = $keys }
        if ($selIdx -ge $filteredKeys.Count) { $selIdx = [Math]::Max(0, $filteredKeys.Count - 1) }

        $row = $baseRow

        # Header con rule y prompt
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${Lead}$rule${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${Coral}${Bold}> ${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${Lead}$rule${Reset}$ClrToEnd"
        $row++

        # Título
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${White}${Bold}Settings${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "$ClrToEnd"
        $row++

        # Search Box
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "  ${LeadLight}Search:${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        $searchDisplay = if ($searchBuf) { $searchBuf } else { " " }
        Write-Host "          ${White}${Bold}$searchDisplay${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "          ${Lead}────────────────────${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "$ClrToEnd"
        $row++

        # Lista de Configuraciones (21 renglones)
        for ($i = 0; $i -lt $filteredKeys.Count; $i++) {
            $k = $filteredKeys[$i]
            $item = $settingsData[$k]
            $lblPad = $item.Label.PadRight(29)
            $val = $item.Value

            try { [Console]::SetCursorPosition(0, $row) } catch { }
            if ($i -eq $selIdx) {
                Write-Host "${Cyan}${Bold}> ${White}${Bold}$lblPad${Reset} ${Cyan}${val}${Reset}    $ClrToEnd"
            } else {
                Write-Host "  ${White}$lblPad${Reset} ${LeadLight}${val}${Reset}    $ClrToEnd"
            }
            $row++
        }

        # Separador para descripción
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "$ClrToEnd"
        $row++

        # Descripción activa envuelta
        $activeKey = $filteredKeys[$selIdx]
        $desc = $settingsData[$activeKey].Desc

        # Envolver en 2 líneas si excede ancho
        $maxTextW = [Math]::Max(40, $width - 8)
        $descL1 = $desc
        $descL2 = ""
        if ($desc.Length -gt $maxTextW) {
            $splitPos = $desc.LastIndexOf(" ", $maxTextW)
            if ($splitPos -le 0) { $splitPos = $maxTextW }
            $descL1 = $desc.Substring(0, $splitPos)
            $descL2 = $desc.Substring($splitPos).Trim()
        }

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "  ${LeadLight}$descL1${Reset}$ClrToEnd"
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        if ($descL2) {
            Write-Host "  ${LeadLight}$descL2${Reset}$ClrToEnd"
        } else {
            Write-Host "$ClrToEnd"
        }
        $row++

        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "$ClrToEnd"
        $row++

        # Footer de navegación
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        Write-Host "${LeadLight}Keyboard: ${Cyan}↑/↓${Reset} ${LeadLight}Navigate  ${Cyan}←/→${Reset} ${LeadLight}Change  ${Cyan}enter${Reset} ${LeadLight}Select  ${Cyan}esc${Reset} ${LeadLight}Clear Search/Exit${Reset}$ClrToEnd"
        $row++

        # Footer derecho de modelo y potencia
        try { [Console]::SetCursorPosition(0, $row) } catch { }
        $activeModelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
        $activeTierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
        $activeFooterText = "$activeModelName " + [char]0x00B7 + " $activeTierName"
        $padLen = [Math]::Max(1, ($width - 1) - $activeFooterText.Length)
        Write-Host "$([string]::new(' ', $padLen))${LeadLight}$activeFooterText${Reset}$ClrToEnd"
    }

    & $renderAll

    try {
        while ($true) {
            $filteredKeys = @($keys | Where-Object {
                -not $searchBuf -or
                $settingsData[$_].Label.ToLower().Contains($searchBuf.ToLower()) -or
                $settingsData[$_].Value.ToLower().Contains($searchBuf.ToLower())
            })
            if ($filteredKeys.Count -eq 0) { $filteredKeys = $keys }

            $k = [Console]::ReadKey($true)

            if ($k.Key -eq [ConsoleKey]::UpArrow) {
                $selIdx = if ($selIdx -gt 0) { $selIdx - 1 } else { $filteredKeys.Count - 1 }
                & $renderAll
                continue
            }

            if ($k.Key -eq [ConsoleKey]::DownArrow) {
                $selIdx = if ($selIdx -lt ($filteredKeys.Count - 1)) { $selIdx + 1 } else { 0 }
                & $renderAll
                continue
            }

            # Cambiar valor hacia la izquierda (←)
            if ($k.Key -eq [ConsoleKey]::LeftArrow) {
                $activeK = $filteredKeys[$selIdx]
                $opts = $settingsData[$activeK].Options
                $cVal = $settingsData[$activeK].Value
                $curIdx = [Array]::IndexOf($opts, $cVal)
                if ($curIdx -lt 0) { $curIdx = 0 }
                $nextIdx = if ($curIdx -gt 0) { $curIdx - 1 } else { $opts.Count - 1 }
                $settingsData[$activeK].Value = $opts[$nextIdx]
                & $saveAll
                & $renderAll
                continue
            }

            # Cambiar valor hacia la derecha (→) o Enter
            if ($k.Key -eq [ConsoleKey]::RightArrow -or $k.Key -eq [ConsoleKey]::Enter) {
                $activeK = $filteredKeys[$selIdx]
                $opts = $settingsData[$activeK].Options
                $cVal = $settingsData[$activeK].Value
                $curIdx = [Array]::IndexOf($opts, $cVal)
                if ($curIdx -lt 0) { $curIdx = 0 }
                $nextIdx = if ($curIdx -lt ($opts.Count - 1)) { $curIdx + 1 } else { 0 }
                $settingsData[$activeK].Value = $opts[$nextIdx]
                & $saveAll
                & $renderAll
                continue
            }

            if ($k.Key -eq [ConsoleKey]::Escape) {
                if ($searchBuf.Length -gt 0) {
                    $searchBuf = ""
                    $selIdx = 0
                    & $renderAll
                    continue
                }

                # Limpiar área visual
                try {
                    for ($c = 0; $c -lt $neededRows; $c++) {
                        [Console]::SetCursorPosition(0, $baseRow + $c)
                        Write-Host ([string]::new(" ", $width - 1)) -NoNewline
                    }
                    [Console]::SetCursorPosition(0, $baseRow)
                } catch { }

                return @{ Action = "exited" }
            }

            if ($k.Key -eq [ConsoleKey]::Backspace) {
                if ($searchBuf.Length -gt 0) {
                    $searchBuf = $searchBuf.Substring(0, $searchBuf.Length - 1)
                    $selIdx = 0
                    & $renderAll
                }
                continue
            }

            $ch = $k.KeyChar
            if (-not [char]::IsControl($ch)) {
                $searchBuf += $ch
                $selIdx = 0
                & $renderAll
                continue
            }
        }
    } finally {
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}
