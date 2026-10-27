<#
.SYNOPSIS
    Vork CLI - Modulo UI: Componentes interactivos responsive.

.DESCRIPTION
    Todos los selectores comparten el mismo motor de paneles:
    - Se ajustan al ancho y alto reales de la terminal.
    - Detectan redimensionado en caliente sin romper la pantalla.
    - Soportan flechas, Home/End, PageUp/PageDown, Enter, Esc y Ctrl+C.
    - Recortan texto con ANSI de forma segura para evitar saltos de linea.
#>

function Wait-VorkGoBack {
    param([string]$CmdName = "")

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $true } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    try {
        while ($true) {
            $metrics = Get-VorkConsoleMetrics
            $hint = "  ${LeadLight}enter/espacio${Reset} ${Lead}continuar  ·  ${Reset}${Coral}esc${Reset} ${Lead}volver${Reset}"
            Write-Host (Limit-VorkAnsiText -Text $hint -MaxWidth ([Math]::Max(10, $metrics.Width - 1)))

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) {
                try {
                    Write-Host "$ESC[1A$ESC[0J" -NoNewline
                } catch { }
                continue
            }

            $key = $wait.Key
            if (-not $key) { continue }
            if ($key.Key -in [ConsoleKey]::Escape, [ConsoleKey]::Enter, [ConsoleKey]::Spacebar) { break }
            if (Test-VorkCtrlC -Key $key) { break }
            try { Write-Host "$ESC[1A$ESC[0J" -NoNewline } catch { }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Read-VorkInput {
    param([string]$Prompt = "")

    if ([Console]::IsInputRedirected) {
        if ($Prompt) { Write-Host $Prompt -NoNewline }
        return [Console]::ReadLine()
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $true } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $buffer = [System.Text.StringBuilder]::new()
    $position = 0

    try {
        while ($true) {
            $metrics = Get-VorkConsoleMetrics
            $maxPromptWidth = [Math]::Max(8, $metrics.Width - 12)
            $promptText = Limit-VorkAnsiText -Text $Prompt -MaxWidth $maxPromptWidth
            $promptWidth = Get-VorkDisplayWidth $promptText
            $inputWidth = [Math]::Max(4, $metrics.Width - $promptWidth - 1)
            $view = Get-VorkTextWindow -Text $buffer.ToString() -Cursor $position -Width $inputWidth

            try {
                Write-Host "`r$ClrLine" -NoNewline
                Write-Host "$promptText$($view.Text)$ClrToEnd" -NoNewline
                $column = $promptWidth + $view.Cursor
                if ($column -ge $metrics.Width) { $column = $metrics.Width - 1 }
                if ($column -lt 0) { $column = 0 }
                Write-Host "`r$($CSI)${column}C" -NoNewline
            } catch { }

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }

            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) {
                try { Write-Host "`r$ClrLine" -NoNewline; Write-Host "" } catch { }
                return ""
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                try { Write-Host "`r$ClrLine" -NoNewline; Write-Host "" } catch { }
                return ""
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                try { Write-Host "" } catch { }
                return $buffer.ToString()
            }

            if ($key.Key -eq [ConsoleKey]::Backspace -or $key.KeyChar -eq [char]8) {
                if ($position -gt 0) {
                    [void]$buffer.Remove($position - 1, 1)
                    $position--
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                if ($position -lt $buffer.Length) {
                    [void]$buffer.Remove($position, 1)
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                if ($position -gt 0) { $position-- }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::RightArrow) {
                if ($position -lt $buffer.Length) { $position++ }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home -or (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::A))) {
                $position = 0
                continue
            }

            if ($key.Key -eq [ConsoleKey]::End -or (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::E))) {
                $position = $buffer.Length
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U)) {
                [void]$buffer.Clear()
                $position = 0
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::K)) {
                if ($position -lt $buffer.Length) {
                    [void]$buffer.Remove($position, $buffer.Length - $position)
                }
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::W)) {
                if ($position -gt 0) {
                    $text = $buffer.ToString()
                    $cut = $position
                    while ($cut -gt 0 -and [char]::IsWhiteSpace($text[$cut - 1])) { $cut-- }
                    while ($cut -gt 0 -and -not [char]::IsWhiteSpace($text[$cut - 1])) { $cut-- }
                    [void]$buffer.Remove($cut, $position - $cut)
                    $position = $cut
                }
                continue
            }

            $char = $key.KeyChar
            if (-not [char]::IsControl($char)) {
                [void]$buffer.Insert($position, $char)
                $position++
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Get-VorkItemValue {
    param($Item)
    if ($null -eq $Item) { return $null }
    if ($Item -is [hashtable]) {
        if ($Item.ContainsKey('Value')) { return $Item.Value }
        if ($Item.ContainsKey('Label')) { return $Item.Label }
    }
    return $Item
}

function Get-VorkItemSearchText {
    param($Item)
    if ($Item -is [hashtable] -and $Item.ContainsKey('Search') -and $Item.Search) { return [string]$Item.Search }
    if ($Item -is [hashtable] -and $Item.ContainsKey('Label')) { return (Get-VorkPlainText ([string]$Item.Label)) }
    return [string]$Item
}

function Get-VorkPickerVisibleRows {
    param(
        $Metrics,
        [int]$ItemCount,
        [int]$ExtraRows = 0
    )
    $available = [Math]::Max(1, $Metrics.Height - 5 - $ExtraRows)
    return [Math]::Max(1, [Math]::Min([Math]::Max(1, $ItemCount), $available))
}

function Write-VorkPickerFrame {
    param(
        $Panel,
        [string]$Title,
        [string]$Subtitle,
        [array]$Items,
        [int]$Selected,
        [int]$Top,
        [int]$Visible,
        [string]$Search,
        [string]$Footer,
        [switch]$ShowSearch
    )

    $row = 0
    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderTop -Title $Title -RightText $Subtitle -Width $Panel.Width)
    $row++

    if ($ShowSearch) {
        $searchText = if ($Search) { $Search } else { "escribe para filtrar" }
        $searchColor = if ($Search) { "${White}${Bold}$Search${Reset}" } else { "${LeadDark}$searchText${Reset}" }
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} ${LeadLight}Buscar:${Reset} $searchColor"
        $row++
    }

    for ($i = 0; $i -lt $Visible; $i++) {
        $itemIndex = $Top + $i
        if ($itemIndex -lt $Items.Count) {
            $item = $Items[$itemIndex]
            $isSelected = $itemIndex -eq $Selected
            $prefix = if ($isSelected) { "${Cyan}${Bold}$([char]0x25B8)${Reset} " } else { "  " }
            $badge = if ($item -is [hashtable] -and $item.ContainsKey('Badge') -and $item.Badge) { "$($item.Badge) " } else { "" }
            $label = if ($item -is [hashtable] -and $item.ContainsKey('Label')) { [string]$item.Label } else { [string]$item }
            $valueText = if ($item -is [hashtable] -and $item.ContainsKey('ValueText') -and $item.ValueText) { "  ${Cyan}$($item.ValueText)${Reset}" } else { "" }
            $description = if ($item -is [hashtable] -and $item.ContainsKey('Description') -and $item.Description) { "  ${LeadLight}$($item.Description)${Reset}" } else { "" }
            $labelText = if ($isSelected) { "${White}${Bold}$label${Reset}" } else { "${White}$label${Reset}" }
            Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} $prefix$badge$labelText$valueText$description"
        } else {
            Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        }
        $row++
    }

    $below = [Math]::Max(0, $Items.Count - ($Top + $Visible))
    $above = $Top
    $scrollText = ""
    if ($above -gt 0 -and $below -gt 0) {
        $scrollText = "$([char]0x2191) $above arriba  ·  $([char]0x2193) $below abajo"
    } elseif ($below -gt 0) {
        $scrollText = "$([char]0x2193) $below mas resultados"
    } elseif ($above -gt 0) {
        $scrollText = "$([char]0x2191) $above mas resultados"
    }
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} ${LeadDark}$scrollText${Reset}"
    $row++

    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderBottom -LeftText $Footer -Width $Panel.Width)
}

function Invoke-VorkPicker {
    param(
        [string]$Title,
        [string]$Subtitle = "",
        [array]$Items,
        [int]$DefaultIndex = 0,
        [string]$Footer = "flechas mover  ·  enter seleccionar  ·  esc cancelar",
        [switch]$Searchable,
        [switch]$NumericSelect
    )

    if (-not $Items -or $Items.Count -eq 0) { return $null }

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        $fallback = if ($DefaultIndex -ge 0 -and $DefaultIndex -lt $Items.Count) { $Items[$DefaultIndex] } else { $Items[0] }
        return (Get-VorkItemValue $fallback)
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $query = ""
    $selected = [Math]::Max(0, [Math]::Min($DefaultIndex, $Items.Count - 1))
    $top = 0
    $panel = $null
    $searchRows = if ($Searchable) { 1 } else { 0 }

    try {
        while ($true) {
            $filtered = if ($Searchable -and $query) {
                @($Items | Where-Object { (Get-VorkItemSearchText $_).ToLower().Contains($query.ToLower()) })
            } else {
                @($Items)
            }

            if ($filtered.Count -eq 0) {
                $selected = 0
                $top = 0
            } else {
                if ($selected -ge $filtered.Count) { $selected = $filtered.Count - 1 }
                if ($selected -lt 0) { $selected = 0 }
            }

            $metrics = Get-VorkConsoleMetrics
            $visible = Get-VorkPickerVisibleRows -Metrics $metrics -ItemCount ([Math]::Max(1, $filtered.Count)) -ExtraRows $searchRows
            $panelRows = $visible + 3 + $searchRows
            $panel = Update-VorkPanel -Panel $panel -Rows $panelRows

            if ($filtered.Count -gt 0) {
                if ($selected -lt $top) { $top = $selected }
                if ($selected -ge ($top + $visible)) { $top = $selected - $visible + 1 }
                if ($top -lt 0) { $top = 0 }
                $maxTop = [Math]::Max(0, $filtered.Count - $visible)
                if ($top -gt $maxTop) { $top = $maxTop }
            }

            $displayItems = if ($filtered.Count -eq 0) {
                @(@{ Label = "Sin coincidencias"; Description = "prueba con otra busqueda"; Value = $null })
            } else {
                $filtered
            }

            Write-VorkPickerFrame -Panel $panel -Title $Title -Subtitle $Subtitle -Items $displayItems -Selected $selected -Top $top -Visible $visible -Search $query -Footer $Footer -ShowSearch:$Searchable

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }

            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) {
                Clear-VorkPanel -Panel $panel
                return $null
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($Searchable -and $query) {
                    $query = ""
                    $selected = 0
                    $top = 0
                    continue
                }
                Clear-VorkPanel -Panel $panel
                return $null
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                if ($filtered.Count -gt 0) {
                    Clear-VorkPanel -Panel $panel
                    return (Get-VorkItemValue $filtered[$selected])
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($filtered.Count -gt 0) {
                    $selected = if ($selected -gt 0) { $selected - 1 } else { $filtered.Count - 1 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($filtered.Count -gt 0) {
                    $selected = if ($selected -lt ($filtered.Count - 1)) { $selected + 1 } else { 0 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::PageUp) {
                if ($filtered.Count -gt 0) {
                    $selected = [Math]::Max(0, $selected - $visible)
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::PageDown) {
                if ($filtered.Count -gt 0) {
                    $selected = [Math]::Min($filtered.Count - 1, $selected + $visible)
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home) {
                $selected = 0
                continue
            }

            if ($key.Key -eq [ConsoleKey]::End) {
                if ($filtered.Count -gt 0) { $selected = $filtered.Count - 1 }
                continue
            }

            if ($Searchable -and $key.Key -eq [ConsoleKey]::Backspace) {
                if ($query.Length -gt 0) {
                    $query = $query.Substring(0, $query.Length - 1)
                    $selected = 0
                    $top = 0
                }
                continue
            }

            if ($Searchable -and (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U))) {
                $query = ""
                $selected = 0
                $top = 0
                continue
            }

            $char = [string]$key.KeyChar
            if ($NumericSelect -and $char -match '^[1-9]$' -and $filtered.Count -gt 0) {
                $numericIndex = [int]$char - 1
                if ($numericIndex -lt $filtered.Count) {
                    Clear-VorkPanel -Panel $panel
                    return (Get-VorkItemValue $filtered[$numericIndex])
                }
            }

            if ($Searchable -and -not [char]::IsControl($key.KeyChar)) {
                $query += [string]$key.KeyChar
                $selected = 0
                $top = 0
                continue
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Select-InteractiveOption {
    param(
        [string]$PromptTitle,
        [array]$Options,
        [int]$DefaultIndex = 0
    )

    if (-not $Options -or $Options.Count -eq 0) { return $null }

    $items = @()
    foreach ($option in $Options) {
        if ($option -is [hashtable]) {
            $label = if ($option.ContainsKey('Label') -and $option.Label) { [string]$option.Label } else { [string]$option }
            $value = if ($option.ContainsKey('Value')) { $option.Value } else { $label }
            $description = if ($option.ContainsKey('Description')) { [string]$option.Description } else { "" }
            $items += @{ Label = $label; Value = $value; Description = $description; Search = (Get-VorkPlainText $label) }
        } else {
            $label = [string]$option
            $items += @{ Label = $label; Value = $option; Description = ""; Search = $label }
        }
    }

    return (Invoke-VorkPicker -Title $PromptTitle -Subtitle "Vork CLI" -Items $items -DefaultIndex $DefaultIndex -NumericSelect -Footer "flechas mover  ·  1-9 elegir  ·  enter seleccionar  ·  esc cancelar")
}

function Write-VorkMediaFormatFrame {
    param(
        $Panel,
        [int]$SelectedFormat,
        [int]$Mp3Index,
        [int]$Mp4Index,
        [array]$Mp3Qualities,
        [array]$Mp4Qualities
    )

    $row = 0
    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderTop -Title "Formato y calidad de salida" -RightText "Vork Media" -Width $Panel.Width)
    $row++

    $mp3 = $Mp3Qualities[$Mp3Index]
    $mp4 = $Mp4Qualities[$Mp4Index]

    $rows = @(
        @{ Index = 0; Label = "MP3"; Quality = $mp3.Id; Desc = $mp3.Desc },
        @{ Index = 1; Label = "MP4"; Quality = $mp4.Id; Desc = $mp4.Desc },
        @{ Index = 2; Label = "WAV"; Quality = "lossless"; Desc = "Audio PCM sin compresion" }
    )

    foreach ($item in $rows) {
        $isSelected = $item.Index -eq $SelectedFormat
        $prefix = if ($isSelected) { "${Cyan}${Bold}$([char]0x25B8)${Reset} " } else { "  " }
        $number = "[$($item.Index + 1)]"
        $quality = if ($isSelected) {
            "${Yellow}${Bold}$([char]0x2039) $($item.Quality) $([char]0x203A)${Reset}"
        } else {
            "${LeadLight}$($item.Quality)${Reset}"
        }
        $label = if ($isSelected) { "${White}${Bold}$($item.Label)${Reset}" } else { "${White}$($item.Label)${Reset}" }
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} $prefix${Cyan}$number${Reset}  $label  $quality  ${LeadLight}· $($item.Desc)${Reset}"
        $row++
    }

    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderBottom -LeftText "flechas formato  ·  izquierda/derecha calidad  ·  enter confirmar  ·  esc cancelar" -Width $Panel.Width)
}

function Select-InteractiveMediaFormat {
    param(
        [string]$PromptTitle = "Selecciona el formato y calidad de salida:",
        [string]$DefaultFormat = "mp4",
        [string]$DefaultMp4Quality = "720p",
        [string]$DefaultMp3Quality = "320k"
    )

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        return @{ Format = $DefaultFormat; Quality = if ($DefaultFormat -eq "mp3") { $DefaultMp3Quality } elseif ($DefaultFormat -eq "wav") { "lossless" } else { $DefaultMp4Quality } }
    }

    $mp4Qualities = @(
        @{ Id = "1080p60HD"; Desc = "Full HD 60fps" },
        @{ Id = "1080pHD";   Desc = "Full HD 1080p" },
        @{ Id = "720p60";    Desc = "HD 60fps" },
        @{ Id = "720p";      Desc = "HD 720p" },
        @{ Id = "480p";      Desc = "SD 480p" },
        @{ Id = "360p";      Desc = "Movil 360p" },
        @{ Id = "240p";      Desc = "Ahorro 240p" },
        @{ Id = "140p";      Desc = "Ultra ligero 140p" }
    )
    $mp3Qualities = @(
        @{ Id = "320k"; Desc = "Maxima fidelidad" },
        @{ Id = "256k"; Desc = "Alta fidelidad" },
        @{ Id = "192k"; Desc = "Balanceado" },
        @{ Id = "128k"; Desc = "Estandar" },
        @{ Id = "96k";  Desc = "Ahorro" },
        @{ Id = "64k";  Desc = "Minimo" }
    )

    $selectedFormat = if ($DefaultFormat -eq "mp3") { 0 } elseif ($DefaultFormat -eq "wav") { 2 } else { 1 }
    $mp4Index = 3
    for ($i = 0; $i -lt $mp4Qualities.Count; $i++) {
        if ($mp4Qualities[$i].Id -eq $DefaultMp4Quality) { $mp4Index = $i; break }
    }
    $mp3Index = 0
    for ($i = 0; $i -lt $mp3Qualities.Count; $i++) {
        if ($mp3Qualities[$i].Id -eq $DefaultMp3Quality) { $mp3Index = $i; break }
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $panel = $null
    try {
        while ($true) {
            $panel = Update-VorkPanel -Panel $panel -Rows 5
            Write-VorkMediaFormatFrame -Panel $panel -SelectedFormat $selectedFormat -Mp3Index $mp3Index -Mp4Index $mp4Index -Mp3Qualities $mp3Qualities -Mp4Qualities $mp4Qualities

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }
            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) { Clear-VorkPanel -Panel $panel; return $null }

            if ($key.Key -eq [ConsoleKey]::Escape) { Clear-VorkPanel -Panel $panel; return $null }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                $selectedFormat = if ($selectedFormat -gt 0) { $selectedFormat - 1 } else { 2 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                $selectedFormat = if ($selectedFormat -lt 2) { $selectedFormat + 1 } else { 0 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                if ($selectedFormat -eq 0) {
                    $mp3Index = if ($mp3Index -gt 0) { $mp3Index - 1 } else { $mp3Qualities.Count - 1 }
                } elseif ($selectedFormat -eq 1) {
                    $mp4Index = if ($mp4Index -gt 0) { $mp4Index - 1 } else { $mp4Qualities.Count - 1 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::RightArrow) {
                if ($selectedFormat -eq 0) {
                    $mp3Index = if ($mp3Index -lt ($mp3Qualities.Count - 1)) { $mp3Index + 1 } else { 0 }
                } elseif ($selectedFormat -eq 1) {
                    $mp4Index = if ($mp4Index -lt ($mp4Qualities.Count - 1)) { $mp4Index + 1 } else { 0 }
                }
                continue
            }

            $char = [string]$key.KeyChar
            if ($char -eq '1') { $selectedFormat = 0; continue }
            if ($char -eq '2') { $selectedFormat = 1; continue }
            if ($char -eq '3') { $selectedFormat = 2; continue }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                Clear-VorkPanel -Panel $panel
                if ($selectedFormat -eq 0) { return @{ Format = 'mp3'; Quality = $mp3Qualities[$mp3Index].Id } }
                if ($selectedFormat -eq 1) { return @{ Format = 'mp4'; Quality = $mp4Qualities[$mp4Index].Id } }
                return @{ Format = 'wav'; Quality = 'lossless' }
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Write-VorkTTSFrame {
    param(
        $Panel,
        [array]$Catalog,
        [array]$VoiceIndices,
        [int]$SelectedLanguage,
        [int]$Top,
        [int]$Visible
    )

    $row = 0
    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderTop -Title "Idioma y voz neuronal" -RightText "Vork TTS" -Width $Panel.Width)
    $row++

    for ($i = 0; $i -lt $Visible; $i++) {
        $index = $Top + $i
        if ($index -lt $Catalog.Count) {
            $language = $Catalog[$index]
            $voiceIndex = $VoiceIndices[$index]
            if ($voiceIndex -ge $language.Voices.Count) { $voiceIndex = 0 }
            $voice = $language.Voices[$voiceIndex]
            $isSelected = $index -eq $SelectedLanguage
            $prefix = if ($isSelected) { "${Cyan}${Bold}$([char]0x25B8)${Reset} " } else { "  " }
            $number = if (($index + 1) -lt 10) { "[$($index + 1)]" } else { "[$($index + 1)]" }
            $languageName = $language.Name
            $voiceText = if ($isSelected) {
                "${Yellow}${Bold}$([char]0x2039) $($voice.Name) $([char]0x203A)${Reset}"
            } else {
                "${LeadLight}$($voice.Name)${Reset}"
            }
            $meta = if ($isSelected) { "  ${LeadLight}· $($voice.Country) · $($voice.Gender)${Reset}" } else { "" }
            $label = if ($isSelected) { "${White}${Bold}$languageName${Reset}" } else { "${White}$languageName${Reset}" }
            Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} $prefix${Cyan}$number${Reset} $label  $voiceText$meta"
        } else {
            Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        }
        $row++
    }

    $below = [Math]::Max(0, $Catalog.Count - ($Top + $Visible))
    $above = $Top
    $scrollText = if ($below -gt 0 -and $above -gt 0) { "$([char]0x2191) $above  ·  $([char]0x2193) $below" } elseif ($below -gt 0) { "$([char]0x2193) $below idiomas mas" } elseif ($above -gt 0) { "$([char]0x2191) $above idiomas mas" } else { "" }
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} ${LeadDark}$scrollText${Reset}"
    $row++

    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderBottom -LeftText "flechas idioma  ·  izquierda/derecha voz  ·  enter confirmar  ·  esc cancelar" -Width $Panel.Width)
}

function Select-InteractiveTTSVoice {
    param(
        [string]$PromptTitle = "Selecciona el idioma y la voz neuronal:",
        [string]$DefaultLang = "Español",
        [string]$DefaultVoiceId = "es-ES-alvaro"
    )

    $catalog = @(
        @{ Name = "Español"; Voices = @(
            @{ Id = "es-ES-alvaro"; Edge = "es-ES-AlvaroNeural"; Name = "Alvaro"; Country = "España"; Gender = "Masculina"; Desc = "Sobria y madura" },
            @{ Id = "es-ES-sofia";  Edge = "es-ES-ElviraNeural"; Name = "Sofia";  Country = "España"; Gender = "Femenina";  Desc = "Castellano claro" },
            @{ Id = "es-MX-mateo";  Edge = "es-MX-JorgeNeural";  Name = "Mateo";  Country = "Mexico"; Gender = "Masculina"; Desc = "Calida para audiolibros" },
            @{ Id = "es-MX-dalia";  Edge = "es-MX-DaliaNeural";  Name = "Dalia";  Country = "Mexico"; Gender = "Femenina";  Desc = "Diccion moderna" },
            @{ Id = "es-PE-diego";  Edge = "es-PE-AlexNeural";   Name = "Diego";  Country = "Peru"; Gender = "Masculina"; Desc = "Articulacion precisa" },
            @{ Id = "es-PE-camila"; Edge = "es-PE-CamilaNeural"; Name = "Camila"; Country = "Peru"; Gender = "Femenina";  Desc = "Entonacion neutra" },
            @{ Id = "es-AR-lucia";  Edge = "es-AR-ElenaNeural";  Name = "Lucia";  Country = "Argentina"; Gender = "Femenina"; Desc = "Cadencia rioplatense" },
            @{ Id = "es-AR-tomas";  Edge = "es-AR-TomasNeural";  Name = "Tomas";  Country = "Argentina"; Gender = "Masculina"; Desc = "Ritmo natural" },
            @{ Id = "es-CO-gonzalo"; Edge = "es-CO-GonzaloNeural"; Name = "Gonzalo"; Country = "Colombia"; Gender = "Masculina"; Desc = "Pronunciacion cristalina" },
            @{ Id = "es-CO-salome"; Edge = "es-CO-SalomeNeural"; Name = "Salome"; Country = "Colombia"; Gender = "Femenina"; Desc = "Timbre dulce" },
            @{ Id = "es-US-paloma"; Edge = "es-US-PalomaNeural"; Name = "Paloma"; Country = "Latinoamerica"; Gender = "Femenina"; Desc = "Neutral" },
            @{ Id = "es-US-alonso"; Edge = "es-US-AlonsoNeural"; Name = "Alonso"; Country = "Latinoamerica"; Gender = "Masculina"; Desc = "Institucional" }
        )},
        @{ Name = "English"; Voices = @(
            @{ Id = "en-US-emma"; Edge = "en-US-JennyNeural"; Name = "Emma"; Country = "United States"; Gender = "Femenina"; Desc = "Clear narration" },
            @{ Id = "en-US-liam"; Edge = "en-US-GuyNeural"; Name = "Liam"; Country = "United States"; Gender = "Masculina"; Desc = "Natural inflection" },
            @{ Id = "en-GB-james"; Edge = "en-GB-RyanNeural"; Name = "James"; Country = "United Kingdom"; Gender = "Masculina"; Desc = "BBC British tone" },
            @{ Id = "en-GB-sonia"; Edge = "en-GB-SoniaNeural"; Name = "Sonia"; Country = "United Kingdom"; Gender = "Femenina"; Desc = "Soothing timbre" },
            @{ Id = "en-AU-olivia"; Edge = "en-AU-NatashaNeural"; Name = "Olivia"; Country = "Australia"; Gender = "Femenina"; Desc = "Bright voice" }
        )},
        @{ Name = "Français"; Voices = @(
            @{ Id = "fr-FR-chloe"; Edge = "fr-FR-DeniseNeural"; Name = "Chloe"; Country = "France"; Gender = "Femenina"; Desc = "Fluide et naturelle" },
            @{ Id = "fr-FR-henri"; Edge = "fr-FR-HenriNeural"; Name = "Henri"; Country = "France"; Gender = "Masculina"; Desc = "Diction soignee" }
        )},
        @{ Name = "Deutsch"; Voices = @(
            @{ Id = "de-DE-hanna"; Edge = "de-DE-KatjaNeural"; Name = "Hanna"; Country = "Deutschland"; Gender = "Femenina"; Desc = "Klare Aussprache" },
            @{ Id = "de-DE-lukas"; Edge = "de-DE-ConradNeural"; Name = "Lukas"; Country = "Deutschland"; Gender = "Masculina"; Desc = "Kraftig und formell" }
        )},
        @{ Name = "Italiano"; Voices = @(
            @{ Id = "it-IT-giulia"; Edge = "it-IT-ElsaNeural"; Name = "Giulia"; Country = "Italia"; Gender = "Femenina"; Desc = "Calda e melodica" },
            @{ Id = "it-IT-marco"; Edge = "it-IT-DiegoNeural"; Name = "Marco"; Country = "Italia"; Gender = "Masculina"; Desc = "Timbro profondo" }
        )},
        @{ Name = "Português"; Voices = @(
            @{ Id = "pt-BR-isabella"; Edge = "pt-BR-FranciscaNeural"; Name = "Isabella"; Country = "Brasil"; Gender = "Femenina"; Desc = "Calorosa e vibrante" },
            @{ Id = "pt-BR-antonio"; Edge = "pt-BR-AntonioNeural"; Name = "Antonio"; Country = "Brasil"; Gender = "Masculina"; Desc = "Grave e marcante" }
        )},
        @{ Name = "日本語"; Voices = @(
            @{ Id = "ja-JP-sakura"; Edge = "ja-JP-NanamiNeural"; Name = "Sakura"; Country = "Japon"; Gender = "Femenina"; Desc = "Natural studio voice" },
            @{ Id = "ja-JP-kenji"; Edge = "ja-JP-KeitaNeural"; Name = "Kenji"; Country = "Japon"; Gender = "Masculina"; Desc = "Deep calm voice" }
        )},
        @{ Name = "中文"; Voices = @(
            @{ Id = "zh-CN-liwei"; Edge = "zh-CN-XiaoxiaoNeural"; Name = "Li Wei"; Country = "China"; Gender = "Femenina"; Desc = "Mandarin natural" },
            @{ Id = "zh-CN-yunxi"; Edge = "zh-CN-YunxiNeural"; Name = "Yun Xi"; Country = "China"; Gender = "Masculina"; Desc = "News broadcast" }
        )},
        @{ Name = "Русский"; Voices = @(
            @{ Id = "ru-RU-anastasia"; Edge = "ru-RU-SvetlanaNeural"; Name = "Anastasia"; Country = "Rusia"; Gender = "Femenina"; Desc = "Velvet timbre" },
            @{ Id = "ru-RU-dmitry"; Edge = "ru-RU-DmitryNeural"; Name = "Dmitry"; Country = "Rusia"; Gender = "Masculina"; Desc = "Clear male voice" }
        )},
        @{ Name = "한국어"; Voices = @(
            @{ Id = "ko-KR-minji"; Edge = "ko-KR-SunHiNeural"; Name = "Min-Ji"; Country = "Corea del Sur"; Gender = "Femenina"; Desc = "Clear standard voice" },
            @{ Id = "ko-KR-injoon"; Edge = "ko-KR-InJoonNeural"; Name = "In-Joon"; Country = "Corea del Sur"; Gender = "Masculina"; Desc = "Soft and trustworthy" }
        )},
        @{ Name = "العربية"; Voices = @(
            @{ Id = "ar-XA-omar"; Edge = "ar-SA-HamedNeural"; Name = "Omar"; Country = "Mundo Arabe"; Gender = "Masculina"; Desc = "Formal and clear" },
            @{ Id = "ar-XA-zariyah"; Edge = "ar-SA-ZariyahNeural"; Name = "Zariyah"; Country = "Mundo Arabe"; Gender = "Femenina"; Desc = "Warm and clear" }
        )}
    )

    $selectedLanguage = 0
    for ($i = 0; $i -lt $catalog.Count; $i++) {
        if ($catalog[$i].Name -eq $DefaultLang) { $selectedLanguage = $i; break }
    }

    $voiceIndices = @()
    for ($i = 0; $i -lt $catalog.Count; $i++) {
        $voiceIndex = 0
        for ($v = 0; $v -lt $catalog[$i].Voices.Count; $v++) {
            if ($catalog[$i].Voices[$v].Id -eq $DefaultVoiceId) { $voiceIndex = $v; break }
        }
        $voiceIndices += $voiceIndex
    }

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        $fallbackLang = $catalog[$selectedLanguage]
        $fallbackVoice = $fallbackLang.Voices[$voiceIndices[$selectedLanguage]]
        return @{ Language = $fallbackLang.Name; Id = $fallbackVoice.Id; EdgeVoice = $fallbackVoice.Edge; Name = $fallbackVoice.Name; Country = $fallbackVoice.Country; Gender = $fallbackVoice.Gender; Desc = $fallbackVoice.Desc }
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $top = 0
    $panel = $null
    try {
        while ($true) {
            $metrics = Get-VorkConsoleMetrics
            $visible = [Math]::Max(1, [Math]::Min($catalog.Count, $metrics.Height - 6))
            $panelRows = $visible + 3
            $panel = Update-VorkPanel -Panel $panel -Rows $panelRows

            if ($selectedLanguage -lt $top) { $top = $selectedLanguage }
            if ($selectedLanguage -ge ($top + $visible)) { $top = $selectedLanguage - $visible + 1 }
            if ($top -lt 0) { $top = 0 }
            $maxTop = [Math]::Max(0, $catalog.Count - $visible)
            if ($top -gt $maxTop) { $top = $maxTop }

            Write-VorkTTSFrame -Panel $panel -Catalog $catalog -VoiceIndices $voiceIndices -SelectedLanguage $selectedLanguage -Top $top -Visible $visible

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }
            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) { Clear-VorkPanel -Panel $panel; return $null }
            if ($key.Key -eq [ConsoleKey]::Escape) { Clear-VorkPanel -Panel $panel; return $null }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                $selectedLanguage = if ($selectedLanguage -gt 0) { $selectedLanguage - 1 } else { $catalog.Count - 1 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                $selectedLanguage = if ($selectedLanguage -lt ($catalog.Count - 1)) { $selectedLanguage + 1 } else { 0 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                $count = $catalog[$selectedLanguage].Voices.Count
                $voiceIndices[$selectedLanguage] = if ($voiceIndices[$selectedLanguage] -gt 0) { $voiceIndices[$selectedLanguage] - 1 } else { $count - 1 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::RightArrow) {
                $count = $catalog[$selectedLanguage].Voices.Count
                $voiceIndices[$selectedLanguage] = if ($voiceIndices[$selectedLanguage] -lt ($count - 1)) { $voiceIndices[$selectedLanguage] + 1 } else { 0 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home) { $selectedLanguage = 0; continue }
            if ($key.Key -eq [ConsoleKey]::End) { $selectedLanguage = $catalog.Count - 1; continue }

            $char = [string]$key.KeyChar
            if ($char -match '^[1-9]$') {
                $numericIndex = [int]$char - 1
                if ($numericIndex -lt $catalog.Count) { $selectedLanguage = $numericIndex }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                Clear-VorkPanel -Panel $panel
                $chosenLanguage = $catalog[$selectedLanguage]
                $chosenVoice = $chosenLanguage.Voices[$voiceIndices[$selectedLanguage]]
                return @{
                    Language  = $chosenLanguage.Name
                    Id        = $chosenVoice.Id
                    EdgeVoice = $chosenVoice.Edge
                    Name      = $chosenVoice.Name
                    Country   = $chosenVoice.Country
                    Gender    = $chosenVoice.Gender
                    Desc      = $chosenVoice.Desc
                }
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Select-InteractiveTheme {
    param(
        [array]$Themes,
        [string]$ActiveThemeId
    )

    if (-not $Themes -or $Themes.Count -eq 0) { return $null }

    $items = @()
    $defaultIndex = 0
    for ($i = 0; $i -lt $Themes.Count; $i++) {
        $theme = $Themes[$i]
        if ($theme.Id -eq $ActiveThemeId) { $defaultIndex = $i }
        $badge = if ($theme.Id -eq $ActiveThemeId) { "$($CSI)42;30;1m ACTIVO $Reset" } else { "" }
        $label = "$($theme.Dot) $($theme.Name)"
        $description = if ($theme.Acentos) { [string]$theme.Acentos } else { "" }
        $items += @{ Label = $label; Value = $theme.Id; Badge = $badge; Description = $description; Search = (Get-VorkPlainText "$($theme.Name) $description") }
    }

    return (Invoke-VorkPicker -Title "Temas visuales de Vork CLI" -Subtitle "$($Themes.Count) temas" -Items $items -DefaultIndex $defaultIndex -NumericSelect -Footer "flechas mover  ·  1-9 elegir  ·  enter aplicar  ·  esc cancelar")
}

function Write-VorkPermissionsFrame {
    param(
        $Panel,
        [array]$Keys,
        $PermsHash,
        [int]$Selected,
        [int]$Top,
        [int]$Visible
    )

    $row = 0
    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderTop -Title "Permisos y sandbox" -RightText "Vork CLI" -Width $Panel.Width)
    $row++

    for ($i = 0; $i -lt $Visible; $i++) {
        $index = $Top + $i
        if ($index -lt $Keys.Count) {
            $key = $Keys[$index]
            $item = $PermsHash[$key]
            $isSelected = $index -eq $Selected
            $prefix = if ($isSelected) { "${Cyan}${Bold}$([char]0x25B8)${Reset} " } else { "  " }
            $badge = if ($item.Enabled) { "$($CSI)42;30;1m PERMITIDO $Reset" } else { "$($CSI)41;97;1m DENEGADO  $Reset" }
            $label = if ($isSelected) { "${White}${Bold}$($item.Name)${Reset}" } else { "${White}$($item.Name)${Reset}" }
            $description = if ($item.Desc) { "  ${LeadLight}$($item.Desc)${Reset}" } else { "" }
            Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} $prefix$badge $label$description"
        } elseif ($index -eq $Keys.Count) {
            $isSelected = $index -eq $Selected
            $prefix = if ($isSelected) { "${Cyan}${Bold}$([char]0x25B8)${Reset} " } else { "  " }
            Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} $prefix${Green}${Bold}Guardar y volver${Reset}"
        } else {
            Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        }
        $row++
    }

    $below = [Math]::Max(0, ($Keys.Count + 1) - ($Top + $Visible))
    $above = $Top
    $scrollText = if ($below -gt 0 -and $above -gt 0) { "$([char]0x2191) $above  ·  $([char]0x2193) $below" } elseif ($below -gt 0) { "$([char]0x2193) $below mas" } elseif ($above -gt 0) { "$([char]0x2191) $above mas" } else { "" }
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} ${LeadDark}$scrollText${Reset}"
    $row++

    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderBottom -LeftText "flechas mover  ·  enter/espacio alternar  ·  esc salir" -Width $Panel.Width)
}

function Select-InteractivePermissions {
    param([hashtable]$PermsHash)

    if (-not $PermsHash -or $PermsHash.Count -eq 0) { return $PermsHash }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $PermsHash }

    $keys = @($PermsHash.Keys | Sort-Object)
    $totalItems = $keys.Count + 1
    $selected = 0
    $top = 0
    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $panel = $null
    try {
        while ($true) {
            $metrics = Get-VorkConsoleMetrics
            $visible = [Math]::Max(1, [Math]::Min($totalItems, $metrics.Height - 6))
            $panelRows = $visible + 3
            $panel = Update-VorkPanel -Panel $panel -Rows $panelRows

            if ($selected -lt $top) { $top = $selected }
            if ($selected -ge ($top + $visible)) { $top = $selected - $visible + 1 }
            if ($top -lt 0) { $top = 0 }
            $maxTop = [Math]::Max(0, $totalItems - $visible)
            if ($top -gt $maxTop) { $top = $maxTop }

            Write-VorkPermissionsFrame -Panel $panel -Keys $keys -PermsHash $PermsHash -Selected $selected -Top $top -Visible $visible

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }
            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) { Clear-VorkPanel -Panel $panel; return $PermsHash }
            if ($key.Key -eq [ConsoleKey]::Escape) { Clear-VorkPanel -Panel $panel; return $PermsHash }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                $selected = if ($selected -gt 0) { $selected - 1 } else { $totalItems - 1 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                $selected = if ($selected -lt ($totalItems - 1)) { $selected + 1 } else { 0 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home) { $selected = 0; continue }
            if ($key.Key -eq [ConsoleKey]::End) { $selected = $totalItems - 1; continue }

            if ($key.Key -eq [ConsoleKey]::Enter -or $key.Key -eq [ConsoleKey]::Spacebar) {
                if ($selected -eq $keys.Count) {
                    Clear-VorkPanel -Panel $panel
                    return $PermsHash
                }
                $selectedKey = $keys[$selected]
                $PermsHash[$selectedKey].Enabled = -not $PermsHash[$selectedKey].Enabled
                Save-VorkPermissions -PermsHash $PermsHash
                continue
            }

            $char = [string]$key.KeyChar
            if ($char -match '^[1-9]$') {
                $numericIndex = [int]$char - 1
                if ($numericIndex -lt $keys.Count) {
                    $selected = $numericIndex
                    $selectedKey = $keys[$selected]
                    $PermsHash[$selectedKey].Enabled = -not $PermsHash[$selectedKey].Enabled
                    Save-VorkPermissions -PermsHash $PermsHash
                }
                continue
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Write-VorkModelFrame {
    param(
        $Panel,
        [int]$SelectedIndex,
        [array]$FilteredModels,
        [string]$ActiveModelId,
        [int]$EffortIndex,
        [string]$SearchQuery
    )

    $row = 0
    # Line 0: Switch Model
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "${White}${Bold}Switch Model${Reset}"
    $row++

    # Line 1: Blank
    Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
    $row++

    # Line 2: Search input
    $searchDisplay = if ($SearchQuery) { "${White}${Bold}$SearchQuery${Reset}" } else { "" }
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${White}Search:${Reset} $searchDisplay"
    $row++

    # Line 3: Underline
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "          ${LeadDark}────────────────────${Reset}"
    $row++

    # Line 4: Blank
    Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
    $row++

    # Lines 5..7: Model items (up to 3 or filtered count)
    for ($i = 0; $i -lt 3; $i++) {
        if ($i -lt $FilteredModels.Count) {
            $m = $FilteredModels[$i]
            $isFocused = ($i -eq $SelectedIndex)
            $isCurrent = ($m.Id -eq $ActiveModelId)

            $cursor = if ($isFocused) { "${Cyan}${Bold}>${Reset} " } else { "  " }
            $nameStr = $m.Name.PadRight(28)
            $nameColored = if ($isFocused) { "${White}${Bold}$nameStr${Reset}" } else { "${White}$nameStr${Reset}" }
            $tag = if ($isCurrent) { "${LeadDark}(current)${Reset}" } else { "" }

            Write-VorkPanelLine -Panel $Panel -Index $row -Text "$cursor$nameColored$tag"
        } else {
            Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        }
        $row++
    }

    # Line 8: Blank
    Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
    $row++

    # Lines 9..11: Effort Track & Description
    $focusedModel = if ($FilteredModels.Count -gt 0 -and $SelectedIndex -lt $FilteredModels.Count) { $FilteredModels[$SelectedIndex] } else { $null }

    if ($focusedModel -and $focusedModel.SupportsEffort) {
        $triL = [char]0x25C2 # ◂
        $triR = [char]0x25B8 # ▸
        $bar = [string][char]0x2501 * 14 # ━━━━━━━━━━━━━━

        $cLow = if ($EffortIndex -eq 0) { "${Green}${Bold}$([char]0x25C9)${Reset}" } else { "${LeadDark}$([char]0x25CF)${Reset}" }
        $cMed = if ($EffortIndex -eq 1) { "${Yellow}${Bold}$([char]0x25C9)${Reset}" } else { "${LeadDark}$([char]0x25CF)${Reset}" }
        $cHig = if ($EffortIndex -eq 2) { "${Coral}${Bold}$([char]0x25C9)${Reset}" } else { "${LeadDark}$([char]0x25CF)${Reset}" }

        $lblLow = if ($EffortIndex -eq 0) { "${White}${Bold}low${Reset}" } else { "${LeadDark}low${Reset}" }
        $lblMed = if ($EffortIndex -eq 1) { "${White}${Bold}medium${Reset}" } else { "${LeadDark}medium${Reset}" }
        $lblHig = if ($EffortIndex -eq 2) { "${White}${Bold}high${Reset}" } else { "${LeadDark}high${Reset}" }

        $desc = switch ($EffortIndex) {
            0 { "Fastest response for lightweight tasks and quick queries" }
            1 { "Optimal balance of speed and analytical depth" }
            2 { "Deepest reasoning for complex problems -- slower but strongest" }
        }

        Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${White}Effort${Reset}  ${LeadDark}$triL${Reset}        $cLow${LeadDark}$bar${Reset}$cMed${LeadDark}$bar${Reset}$cHig        ${LeadDark}$triR${Reset}"
        $row++
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "                  $lblLow          $lblMed          $lblHig"
        $row++
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "            ${LeadLight}$desc${Reset}"
        $row++
    } elseif ($focusedModel -and -not $focusedModel.SupportsEffort) {
        $triL = [char]0x25C2
        $triR = [char]0x25B8
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${White}Effort${Reset}  ${LeadDark}$triL${Reset}                                                     ${Purple}${Bold}[EXPERT]${Reset}        ${LeadDark}$triR${Reset}"
        $row++
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "                                                                ${Purple}${Bold}expert (bloqueado)${Reset}"
        $row++
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "            ${LeadLight}Deepest reasoning & sovereign architecture -- locked at Expert${Reset}"
        $row++
    } else {
        Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        $row++
        Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        $row++
        Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        $row++
    }

    # Line 12: Blank
    Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
    $row++

    # Line 13: Keyboard line
    $upDown = "$([char]0x2191)/$([char]0x2193)"
    $leftRight = "$([char]0x2190)/$([char]0x2192)"
    if ($focusedModel -and $focusedModel.SupportsEffort) {
        $kbText = "${LeadDark}Keyboard: ${White}${Bold}$upDown${Reset} ${LeadLight}Navigate${Reset}  ${White}${Bold}$leftRight${Reset} ${LeadLight}Effort${Reset}  ${White}${Bold}enter${Reset} ${LeadLight}Select${Reset}  ${White}${Bold}esc${Reset} ${LeadLight}Go Back${Reset}"
    } else {
        $kbText = "${LeadDark}Keyboard: ${White}${Bold}$upDown${Reset} ${LeadLight}Navigate${Reset}  ${White}${Bold}enter${Reset} ${LeadLight}Select${Reset}  ${White}${Bold}esc${Reset} ${LeadLight}Go Back${Reset}"
    }
    Write-VorkPanelLine -Panel $Panel -Index $row -Text $kbText
    $row++

    # Line 14: Blank
    Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
    $row++

    # Line 15: Right-aligned status
    $activeModelDisp = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3.1" }
    $activeTierDisp = if ($activeModelDisp -eq "Vork 3.2") { "expert" } elseif ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
    $tierColor = switch ($activeTierDisp) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        "expert" { $Purple }
        default  { $Cyan }
    }
    $rawStatus = "$activeModelDisp · $activeTierDisp"
    $rawWidth = Get-VorkDisplayWidth $rawStatus
    $pad = [Math]::Max(0, $Panel.Width - $rawWidth - 2)
    $statusLine = ([string]::new(' ', $pad)) + "${LeadLight}$activeModelDisp${Reset} ${Lead}·${Reset} ${tierColor}$activeTierDisp${Reset}"
    Write-VorkPanelLine -Panel $Panel -Index $row -Text $statusLine
}

function Show-InteractiveModelSwitcher {
    $catalog = @(
        @{ Id = "Vork 3";   Name = "Vork 3";                  SupportsEffort = $true },
        @{ Id = "Vork 3.1"; Name = "Vork 3.1";                SupportsEffort = $true },
        @{ Id = "Vork 3.2"; Name = "Vork 3.2 (Expert Edition)"; SupportsEffort = $false }
    )
    $efforts = @("low", "medium", "high")

    $currModel = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3.1" }
    $selectedIndex = 0
    for ($i = 0; $i -lt $catalog.Count; $i++) {
        if ($catalog[$i].Id -eq $currModel) {
            $selectedIndex = $i
            break
        }
    }

    $currTier = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
    $effortIndex = [Array]::IndexOf($efforts, $currTier)
    if ($effortIndex -lt 0) { $effortIndex = 1 }

    $searchQuery = ""

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        $eff = if ($currModel -eq "Vork 3.2") { "expert" } else { $efforts[$effortIndex] }
        return @{ Action = "selected"; Model = $currModel; Tier = $eff }
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $panel = $null
    try {
        while ($true) {
            $filtered = @($catalog | Where-Object {
                -not $searchQuery -or
                $_.Name.ToLower().Contains($searchQuery.ToLower()) -or
                $_.Id.ToLower().Contains($searchQuery.ToLower())
            })

            if ($filtered.Count -eq 0) {
                $selectedIndex = 0
            } elseif ($selectedIndex -ge $filtered.Count) {
                $selectedIndex = $filtered.Count - 1
            } elseif ($selectedIndex -lt 0) {
                $selectedIndex = 0
            }

            $panel = Update-VorkPanel -Panel $panel -Rows 16
            Write-VorkModelFrame -Panel $panel -SelectedIndex $selectedIndex -FilteredModels $filtered -ActiveModelId $global:VorkModel -EffortIndex $effortIndex -SearchQuery $searchQuery

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }
            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) {
                Clear-VorkPanel -Panel $panel
                return @{ Action = "exited" }
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($searchQuery) {
                    $searchQuery = ""
                    $selectedIndex = 0
                    continue
                }
                Clear-VorkPanel -Panel $panel
                return @{ Action = "exited" }
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($filtered.Count -gt 0) {
                    $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $filtered.Count - 1 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($filtered.Count -gt 0) {
                    $selectedIndex = if ($selectedIndex -lt ($filtered.Count - 1)) { $selectedIndex + 1 } else { 0 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                if ($filtered.Count -gt 0 -and $filtered[$selectedIndex].SupportsEffort) {
                    $effortIndex = if ($effortIndex -gt 0) { $effortIndex - 1 } else { $efforts.Count - 1 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::RightArrow) {
                if ($filtered.Count -gt 0 -and $filtered[$selectedIndex].SupportsEffort) {
                    $effortIndex = if ($effortIndex -lt ($efforts.Count - 1)) { $effortIndex + 1 } else { 0 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                if ($filtered.Count -gt 0) {
                    $chosenModel = $filtered[$selectedIndex]
                    $chosenEffort = if ($chosenModel.SupportsEffort) { $efforts[$effortIndex] } else { "expert" }

                    $global:VorkModel = $chosenModel.Id
                    $global:VorkTier = $chosenEffort

                    try {
                        $vorkDir = Join-Path $HOME ".vork"
                        if (-not (Test-Path $vorkDir)) { New-Item -ItemType Directory -Path $vorkDir -Force | Out-Null }
                        Set-Content -Path (Join-Path $vorkDir ".model") -Value $chosenModel.Id -Force -Encoding UTF8
                        Set-Content -Path (Join-Path $vorkDir ".tier") -Value $chosenEffort -Force -Encoding UTF8
                    } catch { }

                    Clear-VorkPanel -Panel $panel
                    return @{ Action = "selected"; Model = $chosenModel.Id; Tier = $chosenEffort }
                }
                Clear-VorkPanel -Panel $panel
                return @{ Action = "exited" }
            }

            if ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($searchQuery.Length -gt 0) {
                    $searchQuery = $searchQuery.Substring(0, $searchQuery.Length - 1)
                    $selectedIndex = 0
                }
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U)) {
                $searchQuery = ""
                $selectedIndex = 0
                continue
            }

            if (-not [char]::IsControl($key.KeyChar)) {
                $searchQuery += [string]$key.KeyChar
                $selectedIndex = 0
                continue
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Write-VorkSettingsFrame {
    param(
        $Panel,
        $SettingsData,
        [array]$FilteredKeys,
        [int]$Selected,
        [int]$Top,
        [int]$Visible,
        [string]$Search
    )

    $row = 0
    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderTop -Title "Configuracion" -RightText "Vork CLI" -Width $Panel.Width)
    $row++

    $searchText = if ($Search) { "${White}${Bold}$Search${Reset}" } else { "${LeadDark}escribe para filtrar${Reset}" }
    Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} ${LeadLight}Buscar:${Reset} $searchText"
    $row++

    for ($i = 0; $i -lt $Visible; $i++) {
        $index = $Top + $i
        if ($index -lt $FilteredKeys.Count) {
            $key = $FilteredKeys[$index]
            $item = $SettingsData[$key]
            $isSelected = $index -eq $Selected
            $prefix = if ($isSelected) { "${Cyan}${Bold}$([char]0x25B8)${Reset} " } else { "  " }
            $label = if ($isSelected) { "${White}${Bold}$($item.Label)${Reset}" } else { "${White}$($item.Label)${Reset}" }
            $value = if ($isSelected) { "${Cyan}${Bold}$($item.Value)${Reset}" } else { "${LeadLight}$($item.Value)${Reset}" }
            Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} $prefix$label  $value"
        } else {
            Write-VorkPanelLine -Panel $Panel -Index $row -Text ""
        }
        $row++
    }

    $description = ""
    if ($FilteredKeys.Count -gt 0 -and $Selected -lt $FilteredKeys.Count) {
        $description = [string]$SettingsData[$FilteredKeys[$Selected]].Desc
    }
    $descriptionLines = Get-VorkWrappedLines -Text $description -Width ([Math]::Max(10, $Panel.Width - 8)) -MaxLines 2
    for ($d = 0; $d -lt 2; $d++) {
        $line = if ($d -lt $descriptionLines.Count) { $descriptionLines[$d] } else { "" }
        Write-VorkPanelLine -Panel $Panel -Index $row -Text "  ${Lead}$([char]0x2502)${Reset} ${LeadLight}$line${Reset}"
        $row++
    }

    Write-VorkPanelLine -Panel $Panel -Index $row -Text (Format-VorkBorderBottom -LeftText "flechas mover/cambiar  ·  enter siguiente  ·  esc limpiar/salir" -Width $Panel.Width)
}

function Show-InteractiveSettings {
    $settingsFile = Join-Path $HOME ".vork\settings.json"
    $savedSettings = @{}
    if (Test-Path $settingsFile) {
        try {
            $rawJson = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            foreach ($property in $rawJson.PSObject.Properties) {
                $savedSettings[$property.Name] = $property.Value
            }
        } catch { }
    }

    $settingsData = [ordered]@{
        "agent_mode"            = @{ Label = "Agent Mode"; Options = @("default", "accept-edits", "auto", "plan"); Value = if ($savedSettings["agent_mode"]) { $savedSettings["agent_mode"] } else { "default" }; Desc = "Comportamiento del agente: default, accept-edits, auto o plan." }
        "animation_speed"       = @{ Label = "Animation Speed"; Options = @("medium", "fast", "off"); Value = if ($savedSettings["animation_speed"]) { $savedSettings["animation_speed"] } else { "medium" }; Desc = "Velocidad de animaciones, spinners y barras de progreso." }
        "artifact_review"       = @{ Label = "Artifact Review"; Options = @("asks for review", "always-approve", "off"); Value = if ($savedSettings["artifact_review"]) { $savedSettings["artifact_review"] } else { "asks for review" }; Desc = "Confirma artefactos, diffs y planes antes de ejecutarlos." }
        "color_scheme"          = @{ Label = "Color Scheme"; Options = @("dark", "light", "system"); Value = if ($savedSettings["color_scheme"]) { $savedSettings["color_scheme"] } else { "dark" }; Desc = "Paleta de color de la terminal: dark, light o system." }
        "conv_grouping"         = @{ Label = "Conversation Grouping"; Options = @("none", "project", "date"); Value = if ($savedSettings["conv_grouping"]) { $savedSettings["conv_grouping"] } else { "none" }; Desc = "Agrupacion del historial de conversaciones." }
        "copy_on_select"        = @{ Label = "Copy on Select"; Options = @("on", "off"); Value = if ($savedSettings["copy_on_select"]) { $savedSettings["copy_on_select"] } else { "on" }; Desc = "Copia automaticamente el texto seleccionado al portapapeles." }
        "editor"                = @{ Label = "Editor"; Options = @("auto ($EDITOR)", "code", "vim", "nano", "notepad"); Value = if ($savedSettings["editor"]) { $savedSettings["editor"] } else { "auto ($EDITOR)" }; Desc = "Editor externo para abrir archivos, configuraciones y diffs." }
        "editor_mode"           = @{ Label = "Editor Mode"; Options = @("default", "vim", "emacs"); Value = if ($savedSettings["editor_mode"]) { $savedSettings["editor_mode"] } else { "default" }; Desc = "Atajos de edicion del prompt y de los campos de texto." }
        "enable_telemetry"      = @{ Label = "Enable Telemetry"; Options = @("on", "off"); Value = if ($savedSettings["enable_telemetry"]) { $savedSettings["enable_telemetry"] } else { "on" }; Desc = "Envia metricas anonimas para diagnosticar los pilares." }
        "non_workspace"         = @{ Label = "Non-Workspace Access"; Options = @("off", "on"); Value = if ($savedSettings["non_workspace"]) { $savedSettings["non_workspace"] } else { "off" }; Desc = "Permite inspeccionar archivos fuera del proyecto actual." }
        "notifications"         = @{ Label = "Notifications"; Options = @("on", "off"); Value = if ($savedSettings["notifications"]) { $savedSettings["notifications"] } else { "on" }; Desc = "Notificaciones y avisos al terminar tareas en segundo plano." }
        "queued_messages"       = @{ Label = "Queued Messages"; Options = @("Queue", "Discard", "Prompt"); Value = if ($savedSettings["queued_messages"]) { $savedSettings["queued_messages"] } else { "Queue" }; Desc = "Que hacer con mensajes nuevos mientras corre una tarea." }
        "rendering_mode"        = @{ Label = "Rendering Mode"; Options = @("native terminal (inline)", "fullscreen alternate-screen"); Value = if ($savedSettings["rendering_mode"]) { $savedSettings["rendering_mode"] } else { "native terminal (inline)" }; Desc = "Modo de renderizado de la interfaz." }
        "sandbox_mode"          = @{ Label = "Sandbox Mode"; Options = @("off", "on"); Value = if ($savedSettings["sandbox_mode"]) { $savedSettings["sandbox_mode"] } else { "off" }; Desc = "Restringe comandos y escritura a un directorio temporal." }
        "seasonal_themes"       = @{ Label = "Seasonal Themes"; Options = @("off", "on"); Value = if ($savedSettings["seasonal_themes"]) { $savedSettings["seasonal_themes"] } else { "off" }; Desc = "Activa temas festivos segun la fecha del calendario." }
        "show_active_tasks"     = @{ Label = "Show Active Tasks"; Options = @("on", "off"); Value = if ($savedSettings["show_active_tasks"]) { $savedSettings["show_active_tasks"] } else { "on" }; Desc = "Muestra tareas activas en segundo plano." }
        "show_feedback_survey"  = @{ Label = "Show Feedback Survey"; Options = @("on", "off"); Value = if ($savedSettings["show_feedback_survey"]) { $savedSettings["show_feedback_survey"] } else { "on" }; Desc = "Muestra encuestas de opinion ocasionales." }
        "show_tips"             = @{ Label = "Show Tips"; Options = @("on", "off"); Value = if ($savedSettings["show_tips"]) { $savedSettings["show_tips"] } else { "on" }; Desc = "Muestra atajos y consejos bajo el prompt." }
        "tool_permission"       = @{ Label = "Tool Permission"; Options = @("always-proceed (overridden by dangerously-skip-permissions)", "ask-each", "deny-unsafe"); Value = if ($savedSettings["tool_permission"]) { $savedSettings["tool_permission"] } else { "always-proceed (overridden by dangerously-skip-permissions)" }; Desc = "Politica de ejecucion de herramientas del agente." }
        "use_ai_credits"        = @{ Label = "Use AI Credits"; Options = @("off", "on"); Value = if ($savedSettings["use_ai_credits"]) { $savedSettings["use_ai_credits"] } else { "off" }; Desc = "Usa creditos para modelos premium y Demucs v4." }
        "verbosity"             = @{ Label = "Verbosity"; Options = @("medium", "quiet", "verbose"); Value = if ($savedSettings["verbosity"]) { $savedSettings["verbosity"] } else { "medium" }; Desc = "Nivel de detalle de logs y diagnosticos." }
    }

    $keys = @($settingsData.Keys)
    $selected = 0
    $top = 0
    $query = ""

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        return @{ Action = "exited" }
    }

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    $saveAll = {
        try {
            $vorkDir = Join-Path $HOME ".vork"
            if (-not (Test-Path $vorkDir)) { New-Item -ItemType Directory -Path $vorkDir -Force | Out-Null }
            $toExport = @{}
            foreach ($key in $settingsData.Keys) { $toExport[$key] = $settingsData[$key].Value }
            $toExport | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8
        } catch { }
    }

    $panel = $null
    try {
        while ($true) {
            $filteredKeys = @($keys | Where-Object {
                -not $query -or
                $settingsData[$_].Label.ToLower().Contains($query.ToLower()) -or
                $settingsData[$_].Value.ToLower().Contains($query.ToLower())
            })

            if ($filteredKeys.Count -eq 0) {
                $selected = 0
                $top = 0
            } else {
                if ($selected -ge $filteredKeys.Count) { $selected = $filteredKeys.Count - 1 }
                if ($selected -lt 0) { $selected = 0 }
            }

            $metrics = Get-VorkConsoleMetrics
            $visible = [Math]::Max(1, [Math]::Min([Math]::Max(1, $filteredKeys.Count), $metrics.Height - 9))
            $panelRows = $visible + 5
            $panel = Update-VorkPanel -Panel $panel -Rows $panelRows

            if ($filteredKeys.Count -gt 0) {
                if ($selected -lt $top) { $top = $selected }
                if ($selected -ge ($top + $visible)) { $top = $selected - $visible + 1 }
                if ($top -lt 0) { $top = 0 }
                $maxTop = [Math]::Max(0, $filteredKeys.Count - $visible)
                if ($top -gt $maxTop) { $top = $maxTop }
            }

            Write-VorkSettingsFrame -Panel $panel -SettingsData $settingsData -FilteredKeys $filteredKeys -Selected $selected -Top $top -Visible $visible -Search $query

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) { continue }
            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) { Clear-VorkPanel -Panel $panel; return @{ Action = "exited" } }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($query) {
                    $query = ""
                    $selected = 0
                    $top = 0
                    continue
                }
                Clear-VorkPanel -Panel $panel
                return @{ Action = "exited" }
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($filteredKeys.Count -gt 0) { $selected = if ($selected -gt 0) { $selected - 1 } else { $filteredKeys.Count - 1 } }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($filteredKeys.Count -gt 0) { $selected = if ($selected -lt ($filteredKeys.Count - 1)) { $selected + 1 } else { 0 } }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home) { $selected = 0; continue }
            if ($key.Key -eq [ConsoleKey]::End) { if ($filteredKeys.Count -gt 0) { $selected = $filteredKeys.Count - 1 }; continue }

            if ($filteredKeys.Count -gt 0 -and ($key.Key -eq [ConsoleKey]::LeftArrow -or $key.Key -eq [ConsoleKey]::RightArrow -or $key.Key -eq [ConsoleKey]::Spacebar)) {
                $activeKey = $filteredKeys[$selected]
                $options = @($settingsData[$activeKey].Options)
                $currentValue = [string]$settingsData[$activeKey].Value
                $currentIndex = [Array]::IndexOf($options, $currentValue)
                if ($currentIndex -lt 0) { $currentIndex = 0 }
                $direction = if ($key.Key -eq [ConsoleKey]::LeftArrow) { -1 } else { 1 }
                $nextIndex = $currentIndex + $direction
                if ($nextIndex -ge $options.Count) { $nextIndex = 0 }
                if ($nextIndex -lt 0) { $nextIndex = $options.Count - 1 }
                $settingsData[$activeKey].Value = $options[$nextIndex]
                & $saveAll
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                if ($filteredKeys.Count -gt 0) {
                    $selected = if ($selected -lt ($filteredKeys.Count - 1)) { $selected + 1 } else { 0 }
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($query.Length -gt 0) {
                    $query = $query.Substring(0, $query.Length - 1)
                    $selected = 0
                    $top = 0
                }
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U)) {
                $query = ""
                $selected = 0
                $top = 0
                continue
            }

            if (-not [char]::IsControl($key.KeyChar)) {
                $query += [string]$key.KeyChar
                $selected = 0
                $top = 0
                continue
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}
