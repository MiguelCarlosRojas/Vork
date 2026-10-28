<#
.SYNOPSIS
    Vork CLI - UI Toolkit responsive (ANSI, metricas de consola, paneles y teclado).

.DESCRIPTION
    Utilidades compartidas por todos los componentes visuales de Vork CLI.
    Centraliza el calculo de ancho/alto, el recorte seguro de texto con ANSI,
    la creacion de paneles que se adaptan a la terminal y la lectura de teclas
    con deteccion de redimensionado en caliente.
#>

$global:VorkAnsiPattern = [regex]::new(
    "$([char]27)\[[0-9;?]*[ -/]*[@-~]",
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

function Get-VorkPlainText {
    param([string]$Text)
    if (-not $Text) { return "" }
    return $global:VorkAnsiPattern.Replace($Text, "")
}

function Get-VorkCharWidth {
    param([char]$Char)
    $code = [int]$Char
    if ($code -eq 0) { return 0 }
    if (($code -ge 0x0300 -and $code -le 0x036F) -or
        ($code -ge 0x1AB0 -and $code -le 0x1AFF) -or
        ($code -ge 0x1DC0 -and $code -le 0x1DFF) -or
        ($code -ge 0x20D0 -and $code -le 0x20FF) -or
        ($code -ge 0xFE20 -and $code -le 0xFE2F)) { return 0 }
    if (($code -ge 0x1100 -and $code -le 0x115F) -or
        ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
        ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
        ($code -ge 0xF900 -and $code -le 0xFAFF) -or
        ($code -ge 0xFE30 -and $code -le 0xFE4F) -or
        ($code -ge 0xFF00 -and $code -le 0xFF60) -or
        ($code -ge 0xFFE0 -and $code -le 0xFFE6) -or
        ($code -ge 0x1F300 -and $code -le 0x1FAFF) -or
        ($code -ge 0x20000 -and $code -le 0x3FFFD)) { return 2 }
    if ($code -ge 0xD800 -and $code -le 0xDBFF) { return 2 }
    if ($code -ge 0xDC00 -and $code -le 0xDFFF) { return 0 }
    return 1
}

function Get-VorkDisplayWidth {
    param([string]$Text)
    if (-not $Text) { return 0 }
    $plain = Get-VorkPlainText $Text
    $width = 0
    foreach ($c in $plain.ToCharArray()) { $width += Get-VorkCharWidth $c }
    return $width
}

function Limit-VorkAnsiText {
    param(
        [string]$Text,
        [int]$MaxWidth,
        [string]$Ellipsis = [char]0x2026
    )

    if ($MaxWidth -le 0 -or -not $Text) { return "" }

    $builder = [System.Text.StringBuilder]::new()
    $visible = 0
    $index = 0
    $truncated = $false
    $hasAnsi = $false
    $length = $Text.Length

    while ($index -lt $length) {
        $ch = $Text[$index]

        if ($ch -eq $ESC -and ($index + 1) -lt $length -and $Text[$index + 1] -eq '[') {
            $end = $index + 2
            while ($end -lt $length -and -not ([int][char]$Text[$end] -ge 0x40 -and [int][char]$Text[$end] -le 0x7E)) {
                $end++
            }
            if ($end -lt $length) { $end++ }
            [void]$builder.Append($Text.Substring($index, $end - $index))
            $hasAnsi = $true
            $index = $end
            continue
        }

        $charWidth = Get-VorkCharWidth $ch
        if (($visible + $charWidth) -gt $MaxWidth) {
            $truncated = $true
            break
        }

        [void]$builder.Append($ch)
        $visible += $charWidth
        $index++
    }

    if ($truncated -and $Ellipsis) {
        $ellipsisWidth = Get-VorkDisplayWidth $Ellipsis
        if (($visible + $ellipsisWidth) -le $MaxWidth) {
            [void]$builder.Append($Ellipsis)
            $visible += $ellipsisWidth
        }
    }

    if ($hasAnsi) { [void]$builder.Append($Reset) }
    return $builder.ToString()
}

function Fit-VorkAnsiText {
    param(
        [string]$Text,
        [int]$Width
    )

    if ($Width -le 0) { return "" }
    $limited = Limit-VorkAnsiText -Text $Text -MaxWidth $Width -Ellipsis ""
    $padding = $Width - (Get-VorkDisplayWidth $limited)
    if ($padding -gt 0) { return $limited + ([string]::new(' ', $padding)) }
    return $limited
}

function Get-VorkConsoleMetrics {
    $width = 0
    $height = 0
    $bufferWidth = 0
    $bufferHeight = 0

    try {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $bufferWidth = [Console]::BufferWidth
        $bufferHeight = [Console]::BufferHeight
    } catch { }

    if ($width -le 0 -or $height -le 0) {
        try {
            $raw = $Host.UI.RawUI.WindowSize
            $width = $raw.Width
            $height = $raw.Height
        } catch {
            $width = 120
            $height = 32
        }
    }

    if ($width -le 0) { $width = 120 }
    if ($height -le 0) { $height = 32 }
    if ($bufferWidth -le 0) { $bufferWidth = $width }
    if ($bufferHeight -le 0) { $bufferHeight = 1000 }

    $interactive = $true
    try {
        $interactive = (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)
    } catch { }

    return [pscustomobject]@{
        Width        = [int]([Math]::Max(20, [Math]::Min($width, 400)))
        Height       = [int]([Math]::Max(8, [Math]::Min($height, 200)))
        BufferWidth  = [int]$bufferWidth
        BufferHeight = [int]$bufferHeight
        Interactive  = [bool]$interactive
    }
}

function Ensure-VorkRowsBelow {
    param([int]$Rows = 3)

    if ($Rows -le 0) {
        try { return [Console]::CursorTop } catch { return 0 }
    }

    try {
        $curTop = [Console]::CursorTop
        $winTop = [Console]::WindowTop
        $winHeight = [Console]::WindowHeight
        $bufHeight = [Console]::BufferHeight

        $availableInWindow = ($winTop + $winHeight) - $curTop
        $needed = [Math]::Max(0, $Rows - $availableInWindow)

        if ($needed -gt 0) {
            for ($i = 0; $i -lt $needed; $i++) {
                [Console]::WriteLine()
            }
            $targetTop = [Console]::CursorTop - $needed
            if ($targetTop -lt 0) { $targetTop = 0 }
            [Console]::SetCursorPosition(0, $targetTop)
            return $targetTop
        }

        return $curTop
    } catch {
        try { return [Console]::CursorTop } catch { return 0 }
    }
}

function New-VorkPanel {
    param([int]$Rows)

    $metrics = Get-VorkConsoleMetrics
    $safeRows = [Math]::Max(1, [Math]::Min($Rows, [Math]::Max(1, $metrics.Height - 1)))
    $top = Ensure-VorkRowsBelow -Rows $safeRows

    return [pscustomobject]@{
        Top          = [int]$top
        Rows         = [int]$safeRows
        Width        = [int]$metrics.Width
        Height       = [int]$metrics.Height
        BufferHeight = [int]$metrics.BufferHeight
    }
}

function Clear-VorkPanel {
    param($Panel)

    if (-not $Panel) { return }

    for ($i = 0; $i -lt $Panel.Rows; $i++) {
        $row = $Panel.Top + $i
        try {
            [Console]::SetCursorPosition(0, $row)
            Write-Host "$ClrLine$ClrToEnd" -NoNewline
        } catch { }
    }

    try { [Console]::SetCursorPosition(0, $Panel.Top) } catch { }
}

function Update-VorkPanel {
    param(
        $Panel,
        [int]$Rows
    )

    $metrics = Get-VorkConsoleMetrics
    $safeRows = [Math]::Max(1, [Math]::Min($Rows, [Math]::Max(1, $metrics.Height - 1)))

    if (-not $Panel) { return New-VorkPanel -Rows $safeRows }

    $sizeChanged = ($metrics.Width -ne $Panel.Width) -or
        ($metrics.Height -ne $Panel.Height) -or
        ($safeRows -ne $Panel.Rows)

    if ($sizeChanged) {
        $top = $Panel.Top
        Clear-VorkPanel -Panel $Panel

        # Reutiliza la misma fila superior cuando hay espacio suficiente.
        $canReuse = $false
        try {
            $windowTop = [Console]::WindowTop
            $windowHeight = [Console]::WindowHeight
            $available = ($windowTop + $windowHeight) - $top
            $canReuse = ($top -ge $windowTop) -and ($available -ge $safeRows)
        } catch { }

        if ($canReuse) {
            try {
                [Console]::SetCursorPosition(0, $top)
                return [pscustomobject]@{
                    Top          = [int]$top
                    Rows         = [int]$safeRows
                    Width        = [int]$metrics.Width
                    Height       = [int]$metrics.Height
                    BufferHeight = [int]$metrics.BufferHeight
                }
            } catch { }
        }

        return New-VorkPanel -Rows $safeRows
    }

    return $Panel
}

function Write-VorkPanelLine {
    param(
        $Panel,
        [int]$Index,
        [string]$Text
    )

    if (-not $Panel -or $Index -lt 0 -or $Index -ge $Panel.Rows) { return }

    $row = $Panel.Top + $Index
    $maxWidth = [Math]::Max(1, $Panel.Width - 1)
    $line = Limit-VorkAnsiText -Text $Text -MaxWidth $maxWidth

    try {
        if ($row -ge 0 -and $row -lt [Console]::BufferHeight) {
            [Console]::SetCursorPosition(0, $row)
            Write-Host "$line$ClrToEnd" -NoNewline
        }
    } catch { }
}

function Wait-VorkConsoleKey {
    param([int]$PollMilliseconds = 15)

    if ([Console]::IsInputRedirected) {
        return [pscustomobject]@{
            Key     = $null
            Resized = $false
            Metrics = (Get-VorkConsoleMetrics)
        }
    }

    $initial = Get-VorkConsoleMetrics

    while ($true) {
        $available = $false
        try { $available = [Console]::KeyAvailable } catch { }

        if ($available) {
            $key = [Console]::ReadKey($true)
            $now = Get-VorkConsoleMetrics
            $resized = ($now.Width -ne $initial.Width) -or ($now.Height -ne $initial.Height)
            return [pscustomobject]@{
                Key     = $key
                Resized = $resized
                Metrics = $now
            }
        }

        Start-Sleep -Milliseconds $PollMilliseconds

        $now = Get-VorkConsoleMetrics
        if (($now.Width -ne $initial.Width) -or ($now.Height -ne $initial.Height)) {
            return [pscustomobject]@{
                Key     = $null
                Resized = $true
                Metrics = $now
            }
        }
    }
}

function Test-VorkCtrlC {
    param($Key)
    if (-not $Key) { return $false }
    return (($Key.KeyChar -eq [char]3) -or
        (($Key.Key -eq [ConsoleKey]::C) -and (($Key.Modifiers -band [ConsoleModifiers]::Control) -ne 0)))
}

function Test-VorkCtrlKey {
    param(
        $Key,
        [ConsoleKey]$Letter
    )
    if (-not $Key) { return $false }
    return (($Key.Key -eq $Letter) -and (($Key.Modifiers -band [ConsoleModifiers]::Control) -ne 0))
}

function Get-VorkTextWindow {
    param(
        [string]$Text,
        [int]$Cursor,
        [int]$Width
    )

    if (-not $Text) { $Text = "" }
    if ($Width -lt 1) { $Width = 1 }
    if ($Cursor -lt 0) { $Cursor = 0 }
    if ($Cursor -gt $Text.Length) { $Cursor = $Text.Length }

    $len = $Text.Length

    if ($Width -lt 3) {
        $index = [Math]::Min($Cursor, [Math]::Max(0, $len - 1))
        $ch = if ($len -gt 0) { [string]$Text[$index] } else { "" }
        return [pscustomobject]@{
            Text   = $ch
            Cursor = 0
            Left   = $index
        }
    }

    # Anchos de pantalla acumulados para soportar caracteres CJK/emoji.
    $prefix = New-Object 'int[]' ($len + 1)
    for ($i = 0; $i -lt $len; $i++) {
        $prefix[$i + 1] = $prefix[$i] + (Get-VorkCharWidth $Text[$i])
    }

    $total = $prefix[$len]
    $cursorDisplay = $prefix[$Cursor]

    if ($total -le $Width) {
        return [pscustomobject]@{
            Text   = $Text
            Cursor = $cursorDisplay
            Left   = 0
        }
    }

    $contentBudget = [Math]::Max(1, $Width - 2)
    $leftBudget = [Math]::Max(0, [int]([Math]::Floor($contentBudget / 2)))

    # Retrocede desde el cursor mientras quepa en el presupuesto izquierdo.
    $left = $Cursor
    while ($left -gt 0 -and (($prefix[$Cursor] - $prefix[$left - 1]) -le $leftBudget)) {
        $left--
    }

    # Extiende hacia la derecha todo lo que permita el presupuesto total.
    $right = $Cursor
    while ($right -lt $len -and (($prefix[$right + 1] - $prefix[$left]) -le $contentBudget)) {
        $right++
    }

    $slice = if ($right -gt $left) { $Text.Substring($left, $right - $left) } else { "" }
    $hasLeft = $left -gt 0
    $hasRight = $right -lt $len
    $markLeft = if ($hasLeft) { [char]0x2039 } else { ' ' }
    $markRight = if ($hasRight) { [char]0x203A } else { ' ' }

    $display = [string]$markLeft + $slice + [string]$markRight
    $cursorOffset = 1 + ($prefix[$Cursor] - $prefix[$left])

    return [pscustomobject]@{
        Text   = $display
        Cursor = $cursorOffset
        Left   = $left
    }
}

function Get-VorkCursorBoundary {
    param(
        [string]$Text,
        [int]$Position,
        [int]$Direction
    )

    if (-not $Text) { return 0 }
    if ($Position -lt 0) { $Position = 0 }
    if ($Position -gt $Text.Length) { $Position = $Text.Length }

    # Limites de caracteres reales (soporta acentos combinados y emojis).
    $starts = [System.Globalization.StringInfo]::ParseCombiningCharacters($Text)

    if ($Direction -lt 0) {
        $boundary = 0
        foreach ($start in $starts) {
            if ($start -lt $Position) { $boundary = $start } else { break }
        }
        return [int]$boundary
    }

    foreach ($start in $starts) {
        if ($start -gt $Position) { return [int]$start }
    }

    return [int]$Text.Length
}

function Format-VorkBorderTop {
    param(
        [string]$Title = "",
        [string]$RightText = "",
        [int]$Width
    )

    $maxWidth = [Math]::Max(4, $Width - 1)
    if ($Title -eq $null) { $Title = "" }

    if ($maxWidth -lt 10) {
        $n = [Math]::Max(0, $maxWidth - 2)
        return "  ${Lead}$([string]::new([char]0x2500, $n))$Reset"
    }

    $title = $Title
    $right = $RightText

    # Ajusta el contenido para que el borde nunca exceda el ancho disponible.
    while ($true) {
        $leftLen = if ($title) { 6 + (Get-VorkDisplayWidth $title) } else { 3 }
        $rightLen = if ($right) { 4 + (Get-VorkDisplayWidth $right) } else { 1 }

        if (($leftLen + $rightLen) -le $maxWidth) { break }
        if ($right) { $right = ""; continue }

        if ($title) {
            $maxTitle = [Math]::Max(0, $maxWidth - 7)
            if ((Get-VorkDisplayWidth $title) -le $maxTitle) { break }
            $title = Limit-VorkAnsiText -Text $title -MaxWidth $maxTitle -Ellipsis ""
        }
        break
    }

    $leftLen = if ($title) { 6 + (Get-VorkDisplayWidth $title) } else { 3 }
    $rightLen = if ($right) { 4 + (Get-VorkDisplayWidth $right) } else { 1 }
    $fill = [Math]::Max(0, $maxWidth - $leftLen - $rightLen)

    $leftColored = if ($title) {
        "  ${Lead}$([char]0x256D)$([char]0x2500) ${White}${Bold}$title${Reset}${Lead} "
    } else {
        "  ${Lead}$([char]0x256D)"
    }
    $rightColored = if ($right) {
        " ${LeadLight}$right${Reset}${Lead} $([char]0x2500)$([char]0x256E)${Reset}"
    } else {
        "${Lead}$([char]0x256E)${Reset}"
    }

    $result = $leftColored + ("$Lead" + [string]::new([char]0x2500, $fill) + "$Reset") + $rightColored
    if ((Get-VorkDisplayWidth $result) -gt $maxWidth) {
        return (Limit-VorkAnsiText -Text $result -MaxWidth $maxWidth -Ellipsis "")
    }
    return $result
}

function Format-VorkBorderMiddle {
    param(
        [string]$RightText = "",
        [int]$Width
    )

    $maxWidth = [Math]::Max(4, $Width - 1)

    if ($maxWidth -lt 10) {
        $n = [Math]::Max(0, $maxWidth - 2)
        return "  ${Lead}$([string]::new([char]0x2500, $n))$Reset"
    }

    $right = $RightText
    while ($true) {
        $rightLen = if ($right) { 2 + (Get-VorkDisplayWidth $right) } else { 1 }
        if ((4 + $rightLen) -le $maxWidth) { break }
        if ($right) { $right = ""; continue }
        break
    }

    $rightLen = if ($right) { 2 + (Get-VorkDisplayWidth $right) } else { 1 }
    $fill = [Math]::Max(0, $maxWidth - 4 - $rightLen)

    $leftColored = "  ${Lead}$([char]0x251C)$([char]0x2500)${Reset}"
    $rightColored = if ($right) {
        " ${LeadLight}$right${Reset}${Lead}$([char]0x2524)${Reset}"
    } else {
        "${Lead}$([char]0x2524)${Reset}"
    }

    $result = $leftColored + ("$Lead" + [string]::new([char]0x2500, $fill) + "$Reset") + $rightColored
    if ((Get-VorkDisplayWidth $result) -gt $maxWidth) {
        return (Limit-VorkAnsiText -Text $result -MaxWidth $maxWidth -Ellipsis "")
    }
    return $result
}

function Format-VorkBorderBottom {
    param(
        [string]$LeftText = "",
        [string]$RightText = "",
        [int]$Width
    )

    $maxWidth = [Math]::Max(4, $Width - 1)

    if ($maxWidth -lt 10) {
        $n = [Math]::Max(0, $maxWidth - 2)
        return "  ${Lead}$([string]::new([char]0x2500, $n))$Reset"
    }

    $left = $LeftText
    $right = $RightText

    while ($true) {
        $leftLen = if ($left) { 6 + (Get-VorkDisplayWidth $left) } else { 3 }
        $rightLen = if ($right) { 4 + (Get-VorkDisplayWidth $right) } else { 1 }

        if (($leftLen + $rightLen) -le $maxWidth) { break }
        if ($right) { $right = ""; continue }

        $maxLeft = [Math]::Max(0, $maxWidth - 7)
        if ((Get-VorkDisplayWidth $left) -le $maxLeft) { break }
        $left = Limit-VorkAnsiText -Text $left -MaxWidth $maxLeft -Ellipsis ""
        break
    }

    $leftLen = if ($left) { 6 + (Get-VorkDisplayWidth $left) } else { 3 }
    $rightLen = if ($right) { 4 + (Get-VorkDisplayWidth $right) } else { 1 }
    $fill = [Math]::Max(0, $maxWidth - $leftLen - $rightLen)

    $leftColored = if ($left) {
        "  ${Lead}$([char]0x2570)$([char]0x2500) ${LeadLight}$left${Reset}${Lead} "
    } else {
        "  ${Lead}$([char]0x2570)"
    }
    $rightColored = if ($right) {
        " ${LeadLight}$right${Reset}${Lead} $([char]0x2500)$([char]0x256F)${Reset}"
    } else {
        "${Lead}$([char]0x256F)${Reset}"
    }

    $result = $leftColored + ("$Lead" + [string]::new([char]0x2500, $fill) + "$Reset") + $rightColored
    if ((Get-VorkDisplayWidth $result) -gt $maxWidth) {
        return (Limit-VorkAnsiText -Text $result -MaxWidth $maxWidth -Ellipsis "")
    }
    return $result
}

function Write-VorkWrappedText {
    param(
        [string]$Text,
        [int]$Width = 0,
        [string]$Indent = "  ",
        [string]$Color = ""
    )

    if (-not $Text) { return }

    $metrics = Get-VorkConsoleMetrics
    if ($Width -le 0) { $Width = [Math]::Max(20, $metrics.Width - (Get-VorkDisplayWidth $Indent) - 1) }

    $plain = Get-VorkPlainText $Text
    $words = @($plain -split '\s+' | Where-Object { $_ })
    if ($words.Count -eq 0) { return }

    $line = ""
    foreach ($word in $words) {
        $candidate = if ($line) { "$line $word" } else { $word }
        if ((Get-VorkDisplayWidth $candidate) -le $Width) {
            $line = $candidate
        } else {
            if ($line) { Write-Host "$Color$Indent$line$Reset" }
            if ((Get-VorkDisplayWidth $word) -gt $Width) {
                $remaining = $word
                while ((Get-VorkDisplayWidth $remaining) -gt $Width) {
                    Write-Host "$Color$Indent$($remaining.Substring(0, $Width))$Reset"
                    $remaining = $remaining.Substring($Width)
                }
                $line = $remaining
            } else {
                $line = $word
            }
        }
    }

    if ($line) { Write-Host "$Color$Indent$line$Reset" }
}

function Get-VorkWrappedLines {
    param(
        [string]$Text,
        [int]$Width,
        [int]$MaxLines = 3
    )

    $result = @()
    if (-not $Text -or $Width -le 0 -or $MaxLines -le 0) { return $result }

    $plain = Get-VorkPlainText $Text
    $words = @($plain -split '\s+' | Where-Object { $_ })
    if ($words.Count -eq 0) { return $result }

    $line = ""
    foreach ($word in $words) {
        $candidate = if ($line) { "$line $word" } else { $word }
        if ((Get-VorkDisplayWidth $candidate) -le $Width) {
            $line = $candidate
        } else {
            if ($line) {
                $result += $line
                if ($result.Count -ge $MaxLines) { return $result }
            }
            $line = $word
            while ((Get-VorkDisplayWidth $line) -gt $Width) {
                $result += $line.Substring(0, $Width)
                if ($result.Count -ge $MaxLines) { return $result }
                $line = $line.Substring($Width)
            }
        }
    }

    if ($line -and $result.Count -lt $MaxLines) { $result += $line }
    return $result
}

function Write-VorkSectionTitle {
    param(
        [string]$Title,
        [string]$RightText = ""
    )

    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)
    Write-Host ""
    Write-Host "  ${White}${Bold}$Title${Reset}" -NoNewline
    if ($RightText) {
        $plainTitle = Get-VorkDisplayWidth $Title
        $plainRight = Get-VorkDisplayWidth $RightText
        $pad = [Math]::Max(1, $width - 3 - $plainTitle - $plainRight)
        Write-Host (" " * $pad) -NoNewline
        Write-Host "${LeadLight}$RightText${Reset}" -NoNewline
    }
    Write-Host ""
    Write-Host "  ${Lead}$([string]::new([char]0x2500, [Math]::Max(10, $width - 3)))${Reset}"
}


# ========================================================
# RENDERIZADOR AVANZADO DE RESPUESTAS VORK AI
# ========================================================

function Remove-VorkEmojis {
    param([string]$Text)
    if (-not $Text) { return "" }
    # Eliminar pares suplentes de emojis Unicode (U+10000 a U+10FFFF)
    $clean = [regex]::Replace($Text, '[\uD800-\uDBFF][\uDC00-\uDFFF]', '')
    # Eliminar selectores de variacion y simbolos miscelaneos emoji
    $clean = [regex]::Replace($clean, '[\uFE0E\uFE0F]|[\u2600-\u26FF\u2700-\u2702\u2705\u2708-\u270F\u2728\u274C\u2753-\u2757\u27B0\u27BF]', '')
    # Normalizar espacios dobles residuales
    $clean = [regex]::Replace($clean, '[ \t]{2,}', ' ')
    return $clean
}

function Format-VorkInlineText {
    param([string]$Text)
    if (-not $Text) { return "" }
    $res = $Text
    # Codigo en linea: `codigo`
    $res = [regex]::Replace($res, '`([^`]+)`', "$Yellow`$1$Reset")
    # Negrita: **texto**
    $res = [regex]::Replace($res, '\*\*([^*]+)\*\*', "$White$Bold`$1$Reset")
    # Cursiva: *texto*
    $res = [regex]::Replace($res, '(?<!\*)\*([^*]+)\*(?!\*)', "$Dim`$1$Reset")
    # Limpiar etiquetas HTML residuales
    $res = [regex]::Replace($res, '(?i)<br\s*/?>', ' ')
    $res = [regex]::Replace($res, '(?i)</?li>', ' ')
    $res = [regex]::Replace($res, '(?i)</?ul>', '')
    return $res
}

function Render-VorkTable {
    param(
        [string[]]$TableLines,
        [int]$MaxWidth = 100
    )
    if (-not $TableLines -or $TableLines.Count -lt 2) { return }

    $rows = [System.Collections.Generic.List[string[]]]::new()
    foreach ($line in $TableLines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
        if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
        # Omitir fila separadora Markdown (|---|---|)
        if ($trimmed -match '^[\s\-:\|]+$') { continue }
        $rawCells = $trimmed -split '\|'
        $cellList = [System.Collections.Generic.List[string]]::new()
        foreach ($c in $rawCells) {
            $cleanedCell = [regex]::Replace($c.Trim(), '(?i)<br\s*/?>', "`n")
            $cellList.Add($cleanedCell)
        }
        $rows.Add($cellList.ToArray())
    }
    if ($rows.Count -eq 0) { return }

    # Calcular numero maximo de columnas
    $colCount = 0
    foreach ($r in $rows) {
        if ($r.Length -gt $colCount) { $colCount = $r.Length }
    }
    if ($colCount -eq 0) { return }

    # Rellenar celdas faltantes
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $r = $rows[$i]
        if ($r.Length -lt $colCount) {
            $newR = [System.Collections.Generic.List[string]]::new($r)
            while ($newR.Count -lt $colCount) { $newR.Add("") }
            $rows[$i] = $newR.ToArray()
        }
    }

    # Espacio para bordes verticales: '  │ ' + ' │ ' * (colCount-1) + ' │'
    $borderSpaces = 4 + 3 * ($colCount - 1)
    $availWidth = [Math]::Max(20, $MaxWidth - $borderSpaces)

    # Ancho deseado por columna segun texto plano
    $colMaxWidths = New-Object 'int[]' $colCount
    for ($c = 0; $c -lt $colCount; $c++) {
        $maxLen = 6
        foreach ($r in $rows) {
            $subLines = $r[$c] -split "`n"
            foreach ($sl in $subLines) {
                $cleanCell = [regex]::Replace($sl, '\*\*([^*]+)\*\*', '$1')
                $cleanCell = [regex]::Replace($cleanCell, '`([^`]+)`', '$1')
                $w = Get-VorkDisplayWidth (Get-VorkPlainText $cleanCell.Trim())
                if ($w -gt $maxLen) { $maxLen = $w }
            }
        }
        $colMaxWidths[$c] = $maxLen
    }

    $totalDesired = 0
    for ($c = 0; $c -lt $colCount; $c++) { $totalDesired += $colMaxWidths[$c] }

    $colWidths = New-Object 'int[]' $colCount
    if ($totalDesired -le $availWidth) {
        for ($c = 0; $c -lt $colCount; $c++) { $colWidths[$c] = $colMaxWidths[$c] }
    } else {
        $minCol = 8
        for ($c = 0; $c -lt $colCount; $c++) {
            $w = [Math]::Max($minCol, [int][Math]::Floor(($colMaxWidths[$c] / [double]$totalDesired) * $availWidth))
            $colWidths[$c] = $w
        }
    }

    # Bordes de tabla Unicode
    $topBorder = "  $Lead$([char]0x250C)"
    $midBorder = "  $Lead$([char]0x251C)"
    $botBorder = "  $Lead$([char]0x2514)"
    for ($c = 0; $c -lt $colCount; $c++) {
        $seg = [string]::new([char]0x2500, $colWidths[$c] + 2)
        $topBorder += $seg + $(if ($c -lt $colCount - 1) { [char]0x252C } else { [char]0x2510 })
        $midBorder += $seg + $(if ($c -lt $colCount - 1) { [char]0x253C } else { [char]0x2524 })
        $botBorder += $seg + $(if ($c -lt $colCount - 1) { [char]0x2534 } else { [char]0x2518 })
    }
    $topBorder += "$Reset"
    $midBorder += "$Reset"
    $botBorder += "$Reset"

    Write-Host $topBorder

    for ($rIdx = 0; $rIdx -lt $rows.Count; $rIdx++) {
        $row = $rows[$rIdx]
        $isHeader = ($rIdx -eq 0)

        $wrappedCells = [System.Collections.Generic.List[string[]]]::new()
        $maxCellLines = 1
        for ($c = 0; $c -lt $colCount; $c++) {
            $rawCell = $row[$c]
            $subLines = $rawCell -split "`n"
            $cellLines = [System.Collections.Generic.List[string]]::new()
            foreach ($sl in $subLines) {
                $trimmedSl = $sl.Trim()
                if (-not $trimmedSl) { continue }
                $cleanCell = [regex]::Replace($trimmedSl, '\*\*([^*]+)\*\*', '$1')
                $wrapped = @(Get-VorkWrappedLines -Text $cleanCell -Width $colWidths[$c] -MaxLines 10)
                if ($wrapped -and $wrapped.Count -gt 0) {
                    foreach ($w in $wrapped) { $cellLines.Add($w) }
                } else {
                    $cellLines.Add("")
                }
            }
            if ($cellLines.Count -eq 0) { $cellLines.Add("") }
            if ($cellLines.Count -gt $maxCellLines) { $maxCellLines = $cellLines.Count }
            $wrappedCells.Add($cellLines.ToArray())
        }

        for ($lineIdx = 0; $lineIdx -lt $maxCellLines; $lineIdx++) {
            $outLine = "  $Lead$([char]0x2502)$Reset"
            for ($c = 0; $c -lt $colCount; $c++) {
                $cellText = if ($lineIdx -lt $wrappedCells[$c].Length) { $wrappedCells[$c][$lineIdx] } else { "" }
                $formattedCell = if ($isHeader) {
                    "$White$Bold$cellText$Reset"
                } else {
                    Format-VorkInlineText -Text $cellText
                }
                $plainW = Get-VorkDisplayWidth (Get-VorkPlainText $formattedCell)
                $pad = [Math]::Max(0, $colWidths[$c] - $plainW)
                $outLine += " " + $formattedCell + ([string]::new(' ', $pad)) + " $Lead$([char]0x2502)$Reset"
            }
            Write-Host $outLine
        }

        if ($isHeader) {
            Write-Host $midBorder
        }
    }

    Write-Host $botBorder
}

function Write-VorkAIResponse {
    param(
        [string]$Answer,
        [string]$ActiveModel = "Vork 3.2",
        [string]$TierLabel = "Expert",
        [double]$ElapsedSec = 0
    )

    if (-not $Answer) { return }

    # 1. Filtro estricto anti-emojis
    $cleanAnswer = Remove-VorkEmojis -Text $Answer
    $metrics = Get-VorkConsoleMetrics
    $maxWidth = [Math]::Max(40, $metrics.Width - 4)

    $lines = $cleanAnswer -split '\r?\n'
    $inCodeBlock = $false
    $codeLang = ""
    $tableBuffer = [System.Collections.Generic.List[string]]::new()

    $i = 0
    while ($i -lt $lines.Length) {
        $line = $lines[$i]
        $trimmed = $line.Trim()

        # Inicio o Fin de Bloque de Codigo
        if ($trimmed -match '^`{3,}(.*)$') {
            if ($inCodeBlock) {
                # Cierre de bloque de codigo
                $boxWidth = [Math]::Min(76, $maxWidth - 4)
                $borderLen = [Math]::Max(4, $boxWidth - 2)
                Write-Host "  ${Lead}$([char]0x2570)$([string]::new([char]0x2500, $borderLen))${Reset}"
                Write-Host ""
                $inCodeBlock = $false
                $codeLang = ""
            } else {
                # Renderizar tabla pendiente si existiera
                if ($tableBuffer.Count -gt 0) {
                    Render-VorkTable -TableLines $tableBuffer.ToArray() -MaxWidth $maxWidth
                    $tableBuffer.Clear()
                    Write-Host ""
                }
                $codeLang = $Matches[1].Trim()
                if (-not $codeLang) { $codeLang = "código" }
                $langTag = "${Coral}${Bold}[$codeLang]${Reset}"
                $boxWidth = [Math]::Min(76, $maxWidth - 4)
                $borderLen = [Math]::Max(4, $boxWidth - 6 - (Get-VorkDisplayWidth $codeLang))
                Write-Host ""
                Write-Host "  ${Lead}$([char]0x256D)$([char]0x2500) $langTag ${Lead}$([string]::new([char]0x2500, $borderLen))${Reset}"
                $inCodeBlock = $true
            }
            $i++
            continue
        }

        if ($inCodeBlock) {
            $lineColor = if ($line.Trim().StartsWith("//") -or $line.Trim().StartsWith("#") -or $line.Trim().StartsWith("--")) { $LeadLight } else { $White }
            Write-Host "  ${Lead}$([char]0x2502)${Reset}  $lineColor$line${Reset}"
            $i++
            continue
        }

        # Deteccion de linea de tabla Markdown
        if ($trimmed.StartsWith('|') -and $trimmed.EndsWith('|')) {
            $tableBuffer.Add($line)
            $i++
            continue
        } else {
            if ($tableBuffer.Count -gt 0) {
                Render-VorkTable -TableLines $tableBuffer.ToArray() -MaxWidth $maxWidth
                $tableBuffer.Clear()
                Write-Host ""
            }
        }

        # Linea en blanco
        if (-not $trimmed) {
            Write-Host ""
            $i++
            continue
        }

        # Regla horizontal (---, ***, ___ )
        if ($trimmed -match '^(---|(\*\*\*)|___)$') {
            $ruleLen = [Math]::Min(50, $maxWidth - 4)
            Write-Host "  ${Lead}$([string]::new([char]0x2500, $ruleLen))${Reset}"
            Write-Host ""
            $i++
            continue
        }

        # Encabezados Markdown
        if ($trimmed.StartsWith('###')) {
            $hText = $trimmed.TrimStart('#').Trim()
            $hText = [regex]::Replace($hText, '^\*\*|\*\*$', '')
            $hFormatted = Format-VorkInlineText -Text $hText
            Write-Host ""
            Write-Host "  ${Cyan}${Bold}$([char]0x25B8) $hFormatted${Reset}"
            Write-Host ""
            $i++
            continue
        }
        if ($trimmed.StartsWith('##')) {
            $hText = $trimmed.TrimStart('#').Trim()
            $hText = [regex]::Replace($hText, '^\*\*|\*\*$', '')
            $hFormatted = Format-VorkInlineText -Text $hText
            Write-Host ""
            Write-Host "  ${White}${Bold}$hFormatted${Reset}"
            $ruleLen = [Math]::Min(40, (Get-VorkDisplayWidth (Get-VorkPlainText $hFormatted)) + 2)
            Write-Host "  ${Lead}$([string]::new([char]0x2500, $ruleLen))${Reset}"
            Write-Host ""
            $i++
            continue
        }
        if ($trimmed.StartsWith('#')) {
            $hText = $trimmed.TrimStart('#').Trim()
            $hText = [regex]::Replace($hText, '^\*\*|\*\*$', '')
            $hFormatted = Format-VorkInlineText -Text $hText
            Write-Host ""
            Write-Host "  ${Coral}${Bold}$hFormatted${Reset}"
            $ruleLen = [Math]::Min(50, (Get-VorkDisplayWidth (Get-VorkPlainText $hFormatted)) + 4)
            Write-Host "  ${Lead}$([string]::new([char]0x2500, $ruleLen))${Reset}"
            Write-Host ""
            $i++
            continue
        }

        # Bloque de cita (>)
        if ($trimmed.StartsWith('>')) {
            $qText = $trimmed.Substring(1).Trim()
            $qFormatted = Format-VorkInlineText -Text $qText
            Write-Host "  ${Lead}$([char]0x2502)${Reset} ${Cyan}$qFormatted${Reset}"
            $i++
            continue
        }

        # Elemento de lista no ordenada (- o *)
        if ($trimmed -match '^[-*]\s+(.*)$') {
            $itemText = $Matches[1]
            $isSub = $line.StartsWith('   ') -or $line.StartsWith("`t")
            $indent = if ($isSub) { "    " } else { "  " }
            $bullet = if ($isSub) { "${Lead}$([char]0x25AA)${Reset}" } else { "${Cyan}$([char]0x2022)${Reset}" }
            $formatted = Format-VorkInlineText -Text $itemText
            $contentWidth = [Math]::Max(20, $maxWidth - (Get-VorkDisplayWidth $indent) - 4)
            $wrapped = @(Get-VorkWrappedLines -Text $formatted -Width $contentWidth -MaxLines 10)
            if ($wrapped -and $wrapped.Count -gt 0) {
                Write-Host "$indent$bullet $($wrapped[0])"
                for ($wIdx = 1; $wIdx -lt $wrapped.Count; $wIdx++) {
                    Write-Host "$indent  $($wrapped[$wIdx])"
                }
            } else {
                Write-Host "$indent$bullet $formatted"
            }
            $i++
            continue
        }

        # Elemento de lista numerada (1. 2. etc.)
        if ($trimmed -match '^(\d+\.)\s+(.*)$') {
            $num = $Matches[1]
            $itemText = $Matches[2]
            $formatted = Format-VorkInlineText -Text $itemText
            $contentWidth = [Math]::Max(20, $maxWidth - (Get-VorkDisplayWidth $num) - 4)
            $wrapped = @(Get-VorkWrappedLines -Text $formatted -Width $contentWidth -MaxLines 10)
            if ($wrapped -and $wrapped.Count -gt 0) {
                Write-Host "  ${Cyan}$num${Reset} $($wrapped[0])"
                $hangingPad = [string]::new(' ', $num.Length + 1)
                for ($wIdx = 1; $wIdx -lt $wrapped.Count; $wIdx++) {
                    Write-Host "  $hangingPad$($wrapped[$wIdx])"
                }
            } else {
                Write-Host "  ${Cyan}$num${Reset} $formatted"
            }
            $i++
            continue
        }

        # Parrafo regular de texto con sangria uniforme de 2 espacios
        $formatted = Format-VorkInlineText -Text $trimmed
        $wrapped = @(Get-VorkWrappedLines -Text $formatted -Width ([Math]::Max(20, $maxWidth - 4)) -MaxLines 20)
        if ($wrapped -and $wrapped.Count -gt 0) {
            foreach ($wl in $wrapped) {
                Write-Host "  $wl"
            }
        } else {
            Write-Host "  $formatted"
        }
        $i++
    }

    # Renderizar cualquier tabla restante
    if ($tableBuffer.Count -gt 0) {
        Render-VorkTable -TableLines $tableBuffer.ToArray() -MaxWidth $maxWidth
        $tableBuffer.Clear()
        Write-Host ""
    }

    # Pie de respuesta con modelo, nivel y metadatos alineados
    Write-Host ""
    $elbowChar = [char]0x23BF
    $timeStr = if ($ElapsedSec -gt 0) { " ${Lead}$([char]0x00B7)${Reset} ${LeadLight}${ElapsedSec}s${Reset}" } else { "" }
    Write-Host "  ${LeadLight}$elbowChar  $ActiveModel · $TierLabel$timeStr${Reset}"
    Write-Host ""

    Send-VorkNotification -Title "Vork AI ($ActiveModel)" -Message "Respuesta completada en ${ElapsedSec}s."
}

# ========================================================
# SISTEMA DE NOTIFICACIONES TOAST & SONORAS DE VORK
# ========================================================

function Test-VorkNotificationAllowed {
    # 1. Comprobar configuracion en settings.json
    try {
        $settingsFile = Join-Path $HOME ".vork\settings.json"
        if (Test-Path $settingsFile) {
            $settings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            if ($settings.notifications -ne $null) {
                $val = [string]$settings.notifications
                if ($val -in @("off", "disabled", "false", "0")) {
                    return $false
                }
            }
        }
    } catch { }

    # 2. Comprobar permiso en permissions.json
    try {
        $permFile = Join-Path $HOME ".vork\permissions.json"
        if (Test-Path $permFile) {
            $perms = Get-Content -Path $permFile -Raw | ConvertFrom-Json
            if ($perms.notifications -ne $null) {
                if ($perms.notifications -eq $false -or $perms.notifications -eq "false") {
                    return $false
                }
            }
        }
    } catch { }

    return $true
}

function Send-VorkNotification {
    param(
        [string]$Title = "Vork CLI",
        [string]$Message = "Tarea completada con éxito."
    )

    if (-not (Test-VorkNotificationAllowed)) {
        return
    }

    try {
        $scriptBlock = {
            param($t, $m)
            # 1. Alerta sonora suave
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }

            # 2. Toast Moderno Windows 10/11
            $shown = $false
            try {
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                $toastXml = [xml]$template.GetXml()
                $textNodes = $toastXml.GetElementsByTagName("text")
                if ($textNodes.Count -gt 0) { $textNodes.Item(0).AppendChild($toastXml.CreateTextNode($t)) | Out-Null }
                if ($textNodes.Count -gt 1) { $textNodes.Item(1).AppendChild($toastXml.CreateTextNode($m)) | Out-Null }

                $toastDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
                $toastDoc.LoadXml($toastXml.OuterXml)

                $toast = [Windows.UI.Notifications.ToastNotification]::new($toastDoc)
                $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Vork CLI")
                $notifier.Show($toast)
                $shown = $true
            } catch { }

            # 3. Fallback a NotifyIcon
            if (-not $shown) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                    $notify = New-Object System.Windows.Forms.NotifyIcon
                    $notify.Icon = [System.Drawing.SystemIcons]::Information
                    $notify.BalloonTipTitle = $t
                    $notify.BalloonTipText = $m
                    $notify.Visible = $true
                    $notify.ShowBalloonTip(3000)
                    Start-Sleep -Milliseconds 600
                    $notify.Dispose()
                } catch { }
            }
        }

        Start-Job -ScriptBlock $scriptBlock -ArgumentList $Title, $Message | Out-Null
    } catch {
        try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }
    }
}
