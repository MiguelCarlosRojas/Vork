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
    param([int]$Rows)

    if ($Rows -le 0) {
        try { return [Console]::CursorTop } catch { return 0 }
    }

    try {
        $windowTop = [Console]::WindowTop
        $windowHeight = [Console]::WindowHeight
        $current = [Console]::CursorTop
        $bottom = $windowTop + $windowHeight
        $available = $bottom - $current

        if ($available -lt $Rows) {
            $needed = $Rows - $available
            for ($i = 0; $i -lt $needed; $i++) { [Console]::WriteLine() }
            $newTop = [Console]::CursorTop - $needed
            if ($newTop -lt $windowTop) { $newTop = $windowTop }
            [Console]::SetCursorPosition(0, $newTop)
        }

        return [Console]::CursorTop
    } catch {
        return 0
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
        [Console]::SetCursorPosition(0, $row)
        Write-Host "$line$ClrToEnd" -NoNewline
    } catch { }
}

function Wait-VorkConsoleKey {
    param([int]$PollMilliseconds = 75)

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

function Format-VorkBorderTop {
    param(
        [string]$Title,
        [string]$RightText = "",
        [int]$Width
    )

    $maxWidth = [Math]::Max(4, $Width - 1)
    if (-not $Title) { $Title = "Vork" }

    if ($maxWidth -lt 10) {
        $n = [Math]::Max(0, $maxWidth - 2)
        return "  ${Lead}$([string]::new([char]0x2500, $n))$Reset"
    }

    $title = $Title
    $right = $RightText

    # Ajusta el contenido para que el borde nunca exceda el ancho disponible.
    while ($true) {
        $leftLen = 6 + (Get-VorkDisplayWidth $title)
        $rightLen = if ($right) { 4 + (Get-VorkDisplayWidth $right) } else { 1 }

        if (($leftLen + $rightLen) -le $maxWidth) { break }
        if ($right) { $right = ""; continue }

        $maxTitle = [Math]::Max(0, $maxWidth - 7)
        if ((Get-VorkDisplayWidth $title) -le $maxTitle) { break }
        $title = Limit-VorkAnsiText -Text $title -MaxWidth $maxTitle -Ellipsis ""
        break
    }

    $leftLen = 6 + (Get-VorkDisplayWidth $title)
    $rightLen = if ($right) { 4 + (Get-VorkDisplayWidth $right) } else { 1 }
    $fill = [Math]::Max(0, $maxWidth - $leftLen - $rightLen)

    $leftColored = "  ${Lead}$([char]0x256D)$([char]0x2500) ${White}${Bold}$title${Reset}${Lead} "
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
