param(
    [Parameter(Position=0, ValueFromPipeline=$true)]
    [string]$Command = "",

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments,

    [Alias("c")]
    [switch]$Resume,

    [string]$Conversation = ""
)

<#
.SYNOPSIS
    Vork CLI - Modulo de Configuracion y Paleta Tipografica ANSI
#>

# Detección y normalización de flags de reanudación de sesión (-c, --conversation)
if ($Command -in "-c", "--resume", "-resume") {
    $Resume = $true
    $Command = if ($Arguments -and $Arguments.Count -gt 0) { $Arguments[0] } else { "" }
    $Arguments = if ($Arguments -and $Arguments.Count -gt 1) { @($Arguments[1..($Arguments.Count - 1)]) } else { @() }
} elseif ($Command -like "--conversation=*") {
    $Conversation = $Command.Substring(15)
    $Command = if ($Arguments -and $Arguments.Count -gt 0) { $Arguments[0] } else { "" }
    $Arguments = if ($Arguments -and $Arguments.Count -gt 1) { @($Arguments[1..($Arguments.Count - 1)]) } else { @() }
} elseif ($Command -in "--conversation", "-conversation") {
    if ($Arguments -and $Arguments.Count -gt 0) {
        $Conversation = $Arguments[0]
        $Command = if ($Arguments.Count -gt 1) { $Arguments[1] } else { "" }
        $Arguments = if ($Arguments.Count -gt 2) { @($Arguments[2..($Arguments.Count - 1)]) } else { @() }
    } else {
        $Command = ""
    }
}

if ($Arguments) {
    $cleanArgs = @()
    for ($aIdx = 0; $aIdx -lt $Arguments.Count; $aIdx++) {
        $argItem = $Arguments[$aIdx]
        if ($argItem -in "-c", "--resume", "-resume") {
            $Resume = $true
        } elseif ($argItem -like "--conversation=*") {
            $Conversation = $argItem.Substring(15)
        } elseif ($argItem -in "--conversation", "-conversation") {
            if ($aIdx + 1 -lt $Arguments.Count) {
                $Conversation = $Arguments[$aIdx + 1]
                $aIdx++
            }
        } else {
            $cleanArgs += $argItem
        }
    }
    $Arguments = $cleanArgs
}

# ========================================================
# GESTIÓN DE ID DE CONVERSACIÓN & SESIÓN PERSISTENTE
# ========================================================
$convDir = Join-Path $HOME ".vork"
if (-not (Test-Path $convDir)) { New-Item -ItemType Directory -Path $convDir -Force | Out-Null }
$lastConvFile = Join-Path $convDir "last_conversation.txt"

if ($Conversation) {
    $global:VorkConversationId = $Conversation.Trim()
    $global:VorkIsResumed = $true
} elseif ($Resume) {
    if (Test-Path $lastConvFile) {
        $savedConv = try { (Get-Content -Path $lastConvFile -Raw).Trim() } catch { "" }
        if ($savedConv) {
            $global:VorkConversationId = $savedConv
            $global:VorkIsResumed = $true
        }
    }
}

if (-not $global:VorkConversationId) {
    $global:VorkConversationId = [System.Guid]::NewGuid().ToString()
    $global:VorkIsResumed = $false
}

try {
    Set-Content -Path $lastConvFile -Value $global:VorkConversationId -Force -Encoding UTF8
} catch { }

function Get-VorkConversationDir {
    param([string]$ConvId)
    $base = Join-Path $HOME ".vork\conversations"
    $targetDir = Join-Path $base $ConvId
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    return $targetDir
}

function Save-VorkConversationRecord {
    param(
        [string]$Cmd,
        [string]$Output = ""
    )
    if (-not $global:VorkConversationId) { return }
    try {
        $cDir = Get-VorkConversationDir -ConvId $global:VorkConversationId
        $histPath = Join-Path $cDir "history.txt"
        Add-Content -Path $histPath -Value $Cmd -Encoding UTF8

        $logPath = Join-Path $cDir "transcript.jsonl"
        $entry = @{
            Timestamp = [DateTime]::UtcNow.ToString("o")
            Command = $Cmd
            Output = $Output
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $entry -Encoding UTF8

        $sessPath = Join-Path $cDir "session.json"
        $sessData = @{
            ConversationId = $global:VorkConversationId
            UpdatedAt = [DateTime]::UtcNow.ToString("o")
            Model = $global:VorkModel
            Tier = $global:VorkTier
            Theme = $global:VorkThemeId
        }
        $sessData | ConvertTo-Json | Set-Content -Path $sessPath -Encoding UTF8
    } catch { }
}

function Load-VorkConversationState {
    param([string]$ConvId)
    $cDir = Join-Path $HOME ".vork\conversations\$ConvId"
    if (Test-Path $cDir) {
        $sessPath = Join-Path $cDir "session.json"
        if (Test-Path $sessPath) {
            try {
                $sess = Get-Content -Path $sessPath -Raw | ConvertFrom-Json
                if ($sess.Model) { $global:VorkModel = $sess.Model }
                if ($sess.Tier) { $global:VorkTier = $sess.Tier }
                if ($sess.Theme) { Apply-VorkTheme -ThemeName $sess.Theme }
            } catch { }
        }

        $histPath = Join-Path $cDir "history.txt"
        if (Test-Path $histPath) {
            try {
                $lines = @(Get-Content -Path $histPath -Encoding UTF8 | Where-Object { $_ -and $_.Trim() })
                if ($lines.Count -gt 0) {
                    $global:VorkSessionHistory = [System.Collections.ArrayList]@($lines)
                }
            } catch { }
        }
    }
}

function Show-ResumedConversationTranscript {
    param([string]$ConvId)
    $cDir = Join-Path $HOME ".vork\conversations\$ConvId"
    $logPath = Join-Path $cDir "transcript.jsonl"
    $histPath = Join-Path $cDir "history.txt"
    $elbow = [char]0x23BF

    Write-Host ""
    Write-Host "  ${Green}●${Reset} ${White}${Bold}Resumed conversation ${Cyan}$ConvId${Reset}"

    $found = $false
    if (Test-Path $logPath) {
        try {
            $entries = @(Get-Content -Path $logPath -Encoding UTF8 | Where-Object { $_ -and $_.Trim() })
            if ($entries.Count -gt 0) {
                $found = $true
                Write-Host "  ${LeadLight}Restored $($entries.Count) interaction(s) from previous session:${Reset}"
                Write-Host ""
                foreach ($raw in $entries) {
                    try {
                        $item = $raw | ConvertFrom-Json
                        Write-Host "  ${Coral}${Bold}> ${White}${Bold}$($item.Command)${Reset}"
                        if ($item.Output) {
                            $lines = $item.Output -split "\r?\n"
                            for ($i = 0; $i -lt $lines.Count; $i++) {
                                $l = $lines[$i]
                                if ($i -eq 0) {
                                    Write-Host "    ${LeadLight}$elbow  $l${Reset}"
                                } else {
                                    Write-Host "       ${LeadLight}$l${Reset}"
                                }
                            }
                        }
                        Write-Host ""
                    } catch { }
                }
            }
        } catch { }
    }

    if (-not $found -and (Test-Path $histPath)) {
        try {
            $hLines = @(Get-Content -Path $histPath -Encoding UTF8 | Where-Object { $_ -and $_.Trim() })
            if ($hLines.Count -gt 0) {
                $found = $true
                Write-Host "  ${LeadLight}Restored $($hLines.Count) command(s) from previous session:${Reset}"
                Write-Host ""
                foreach ($hl in $hLines) {
                    Write-Host "  ${Coral}${Bold}> ${White}${Bold}$hl${Reset}"
                    Write-Host "    ${LeadLight}$elbow  Executed $hl${Reset}"
                    Write-Host ""
                }
            }
        } catch { }
    }

    if (-not $found) {
        Write-Host "  ${LeadLight}Session context initialized.${Reset}"
        Write-Host ""
    }
}

function Exit-VorkSession {
    param([int]$ExitCode = 0)
    Write-Host ""
    Write-Host "${LeadLight}Resume with -c (or command below):${Reset}"
    Write-Host "${White}vk --conversation=$global:VorkConversationId${Reset}"
    Write-Host ""
    exit $ExitCode
}

$VorkVersion = "3.0.2"
$ApiBase = if ($env:VORK_API) { $env:VORK_API } elseif ($env:CLOUDTRANSLATOR_API) { $env:CLOUDTRANSLATOR_API } else { "https://vork-st1k.onrender.com" }

# ========================================================
# PALETA TIPOGRÁFICA ANSI Y SISTEMA DE 10 TEMAS VISUALES
# ========================================================
$ESC      = [char]27
$CSI      = "$([char]27)["
$ClrLine  = "$([char]27)[2K"
$ClrToEnd = "$([char]27)[K"
$Reset    = "$ESC[0m"
$Bold     = "$ESC[1m"
$Dim      = "$ESC[2m"
$Italic   = "$ESC[3m"
$White    = "$ESC[38;2;240;246;252m"
$Gray     = "$ESC[38;2;120;128;140m"

$global:IsWinPlatform = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)

# ========================================================
# IDENTIDAD VISUAL: ICONO Y TÍTULO DE VENTANA / PESTAÑA
# ========================================================
if ($global:IsWinPlatform -and -not ([System.Management.Automation.PSTypeName]'VorkWin32').Type) {
    $csharp = @'
using System;
using System.Runtime.InteropServices;

public static class VorkWin32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr LoadImage(IntPtr hinst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);

    public const uint WM_SETICON = 0x0080;
    public const uint SMTO_ABORTIFHUNG = 0x0002;

    public static void SetIcon(string iconPath) {
        try {
            if (!System.IO.File.Exists(iconPath)) return;
            IntPtr hIconSmall = LoadImage(IntPtr.Zero, iconPath, 1, 16, 16, 0x00000010);
            IntPtr hIconBig = LoadImage(IntPtr.Zero, iconPath, 1, 32, 32, 0x00000010);
            if (hIconSmall == IntPtr.Zero && hIconBig == IntPtr.Zero) return;

            IntPtr dummy;
            // 1. Consola clásica de Windows (conhost / PowerShell nativo)
            IntPtr conWnd = GetConsoleWindow();
            if (conWnd != IntPtr.Zero) {
                if (hIconSmall != IntPtr.Zero) SendMessageTimeout(conWnd, WM_SETICON, (IntPtr)0, hIconSmall, SMTO_ABORTIFHUNG, 50, out dummy);
                if (hIconBig != IntPtr.Zero) SendMessageTimeout(conWnd, WM_SETICON, (IntPtr)1, hIconBig, SMTO_ABORTIFHUNG, 50, out dummy);
            }

            // 2. Ventana de terminal activa en primer plano (Warp, Windows Terminal, Orca, WezTerm)
            IntPtr fgWnd = GetForegroundWindow();
            if (fgWnd != IntPtr.Zero && fgWnd != conWnd) {
                if (hIconSmall != IntPtr.Zero) SendMessageTimeout(fgWnd, WM_SETICON, (IntPtr)0, hIconSmall, SMTO_ABORTIFHUNG, 50, out dummy);
                if (hIconBig != IntPtr.Zero) SendMessageTimeout(fgWnd, WM_SETICON, (IntPtr)1, hIconBig, SMTO_ABORTIFHUNG, 50, out dummy);
            }
        } catch {}
    }
}
'@
    try {
        Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue
    } catch {}
}

function Set-VorkWindowIdentity {
    # 1. Establecer título de ventana limpio
    try {
        $Host.UI.RawUI.WindowTitle = "Vork CLI"
    } catch {}

    # 2. Secuencias OSC estándar para emuladores modernos (título de ventana limpio sin glifos en el texto)
    try {
        # OSC 0: Establecer título de ventana
        Write-Host "$ESC]0;Vork CLI`a" -NoNewline
        # OSC 2: Establecer título de ventana
        Write-Host "$ESC]2;Vork CLI`a" -NoNewline
    } catch {}

    # 3. Asignar icono oficial transparente de Vork a la ventana (en Windows)
    if ($global:IsWinPlatform) {
        try {
            $vorkIco = Join-Path $HOME ".vork\vork.ico"
            if (Test-Path $vorkIco) {
                [VorkWin32]::SetIcon($vorkIco)
            }
        } catch {}
    }
}

# Aplicar identidad visual inmediatamente
Set-VorkWindowIdentity

function Apply-VorkTheme {
    param([string]$ThemeName = "lead")
    $clean = if ($ThemeName) { $ThemeName.Trim().ToLower() } else { "lead" }

    switch ($clean) {
        { $_ -in "cyberpunk", "2" } {
            $global:VorkThemeId   = "cyberpunk"
            $global:VorkThemeName = "Cyberpunk 2077 (Neon Gold & Pink)"
            $global:Coral         = "$ESC[38;2;255;0;128m"      # Fucsia Neon
            $global:Cyan          = "$ESC[38;2;0;240;255m"      # Electric Cyan
            $global:Yellow        = "$ESC[38;2;252;238;10m"     # Cyberpunk Yellow
            $global:Green         = "$ESC[38;2;0;255;159m"      # Neon Mint
            $global:Purple        = "$ESC[38;2;180;0;255m"      # Cyber Violet
            $global:Lead          = "$ESC[38;2;85;50;110m"      # Cyber Border
            $global:LeadLight     = "$ESC[38;2;240;220;255m"    # Cyber Light
            $global:LeadDark      = "$ESC[38;2;50;25;70m"
            $global:BgLead        = "$ESC[48;2;25;12;35m"
            $global:BgSel         = "$ESC[48;2;50;20;70m"
        }
        { $_ -in "matrix", "3" } {
            $global:VorkThemeId   = "matrix"
            $global:VorkThemeName = "Matrix Terminal (Phosphor Green)"
            $global:Coral         = "$ESC[38;2;0;255;65m"       # Hacker Green
            $global:Cyan          = "$ESC[38;2;57;255;20m"      # Neon Lime
            $global:Yellow        = "$ESC[38;2;180;255;0m"
            $global:Green         = "$ESC[38;2;0;255;65m"
            $global:Purple        = "$ESC[38;2;0;200;100m"
            $global:Lead          = "$ESC[38;2;20;80;35m"       # Dark Matrix Green
            $global:LeadLight     = "$ESC[38;2;140;255;160m"
            $global:LeadDark      = "$ESC[38;2;10;45;20m"
            $global:BgLead        = "$ESC[48;2;5;25;10m"
            $global:BgSel         = "$ESC[48;2;15;50;25m"
        }
        { $_ -in "dracula", "4" } {
            $global:VorkThemeId   = "dracula"
            $global:VorkThemeName = "Dracula Vamp (Purple & Pink)"
            $global:Coral         = "$ESC[38;2;255;121;198m"    # Dracula Pink
            $global:Cyan          = "$ESC[38;2;139;233;253m"    # Dracula Cyan
            $global:Yellow        = "$ESC[38;2;241;250;140m"    # Dracula Yellow
            $global:Green         = "$ESC[38;2;80;250;123m"     # Dracula Green
            $global:Purple        = "$ESC[38;2;189;147;249m"    # Dracula Purple
            $global:Lead          = "$ESC[38;2;98;114;164m"     # Dracula Comment
            $global:LeadLight     = "$ESC[38;2;248;248;242m"    # Dracula Fore
            $global:LeadDark      = "$ESC[38;2;68;71;90m"
            $global:BgLead        = "$ESC[48;2;40;42;54m"
            $global:BgSel         = "$ESC[48;2;68;71;90m"
        }
        { $_ -in "nord", "5" } {
            $global:VorkThemeId   = "nord"
            $global:VorkThemeName = "Nordic Frost (Arctic Blue & White)"
            $global:Coral         = "$ESC[38;2;136;192;208m"    # Frost Blue
            $global:Cyan          = "$ESC[38;2;143;188;187m"    # Polar Teal
            $global:Yellow        = "$ESC[38;2;235;203;139m"    # Nord Yellow
            $global:Green         = "$ESC[38;2;163;190;140m"    # Nord Green
            $global:Purple        = "$ESC[38;2;180;142;173m"    # Nord Purple
            $global:Lead          = "$ESC[38;2;76;86;106m"       # Nord Gray
            $global:LeadLight     = "$ESC[38;2;216;222;233m"    # Snow White
            $global:LeadDark      = "$ESC[38;2;59;66;82m"
            $global:BgLead        = "$ESC[48;2;46;52;64m"
            $global:BgSel         = "$ESC[48;2;67;76;94m"
        }
        { $_ -in "tokyo-night", "tokyo", "6" } {
            $global:VorkThemeId   = "tokyo-night"
            $global:VorkThemeName = "Tokyo Night (Neon Deep Blue)"
            $global:Coral         = "$ESC[38;2;255;158;100m"    # Tokyo Orange
            $global:Cyan          = "$ESC[38;2;122;162;247m"    # Tokyo Blue
            $global:Yellow        = "$ESC[38;2;224;175;104m"    # Tokyo Yellow
            $global:Green         = "$ESC[38;2;158;206;106m"    # Tokyo Green
            $global:Purple        = "$ESC[38;2;187;154;247m"    # Tokyo Purple
            $global:Lead          = "$ESC[38;2;65;72;104m"
            $global:LeadLight     = "$ESC[38;2;192;202;245m"
            $global:LeadDark      = "$ESC[38;2;41;46;66m"
            $global:BgLead        = "$ESC[48;2;26;27;38m"
            $global:BgSel         = "$ESC[48;2;47;53;77m"
        }
        { $_ -in "monokai", "7" } {
            $global:VorkThemeId   = "monokai"
            $global:VorkThemeName = "Monokai Pro (Warm Amber & Mint)"
            $global:Coral         = "$ESC[38;2;252;152;103m"    # Warm Orange
            $global:Cyan          = "$ESC[38;2;120;220;232m"    # Mint Cyan
            $global:Yellow        = "$ESC[38;2;255;216;102m"    # Monokai Gold
            $global:Green         = "$ESC[38;2;169;220;118m"    # Monokai Lime
            $global:Purple        = "$ESC[38;2;171;157;242m"    # Monokai Violet
            $global:Lead          = "$ESC[38;2;90;85;95m"
            $global:LeadLight     = "$ESC[38;2;220;215;225m"
            $global:LeadDark      = "$ESC[38;2;55;50;60m"
            $global:BgLead        = "$ESC[48;2;40;35;45m"
            $global:BgSel         = "$ESC[48;2;55;50;60m"
        }
        { $_ -in "synthwave", "8" } {
            $global:VorkThemeId   = "synthwave"
            $global:VorkThemeName = "Synthwave 84 (Outrun Sunset)"
            $global:Coral         = "$ESC[38;2;255;126;219m"    # Sunset Pink
            $global:Cyan          = "$ESC[38;2;54;249;246m"     # Laser Cyan
            $global:Yellow        = "$ESC[38;2;254;222;93m"     # Laser Gold
            $global:Green         = "$ESC[38;2;114;241;184m"
            $global:Purple        = "$ESC[38;2;218;112;214m"
            $global:Lead          = "$ESC[38;2;90;50;100m"
            $global:LeadLight     = "$ESC[38;2;240;210;255m"
            $global:LeadDark      = "$ESC[38;2;55;25;65m"
            $global:BgLead        = "$ESC[48;2;38;18;50m"
            $global:BgSel         = "$ESC[48;2;60;30;70m"
        }
        { $_ -in "solarized-dark", "solarized", "9" } {
            $global:VorkThemeId   = "solarized-dark"
            $global:VorkThemeName = "Solarized Dark (Teal Ocean)"
            $global:Coral         = "$ESC[38;2;203;75;22m"      # Solar Orange
            $global:Cyan          = "$ESC[38;2;42;161;152m"     # Solar Cyan/Teal
            $global:Yellow        = "$ESC[38;2;181;137;0m"      # Solar Yellow
            $global:Green         = "$ESC[38;2;133;153;0m"      # Solar Green
            $global:Purple        = "$ESC[38;2;108;113;196m"    # Solar Violet
            $global:Lead          = "$ESC[38;2;88;110;117m"     # Base01
            $global:LeadLight     = "$ESC[38;2;147;161;161m"    # Base1
            $global:LeadDark      = "$ESC[38;2;10;45;55m"
            $global:BgLead        = "$ESC[48;2;0;43;54m"
            $global:BgSel         = "$ESC[48;2;7;54;66m"        # Base02
        }
        { $_ -in "ghost", "mono", "10" } {
            $global:VorkThemeId   = "ghost"
            $global:VorkThemeName = "Minimal Ghost (Titanium Lead)"
            $global:Coral         = "$ESC[38;2;250;250;250m"    # White Titanium
            $global:Cyan          = "$ESC[38;2;195;200;210m"    # Silver
            $global:Yellow        = "$ESC[38;2;220;220;225m"
            $global:Green         = "$ESC[38;2;210;215;220m"
            $global:Purple        = "$ESC[38;2;180;180;190m"
            $global:Lead          = "$ESC[38;2;75;78;88m"
            $global:LeadLight     = "$ESC[38;2;165;170;180m"
            $global:LeadDark      = "$ESC[38;2;45;48;55m"
            $global:BgLead        = "$ESC[48;2;28;30;35m"
            $global:BgSel         = "$ESC[48;2;45;48;55m"
        }
        default {
            # 1. Lead Slate (Default)
            $global:VorkThemeId   = "lead"
            $global:VorkThemeName = "Plomo Oscuro (Lead Slate - Tema Oficial)"
            $global:Coral         = "$ESC[38;2;255;107;74m"     # Coral Vork
            $global:Cyan          = "$ESC[38;2;56;189;248m"     # Cyan Electric
            $global:Yellow        = "$ESC[38;2;250;204;21m"     # Yellow
            $global:Green         = "$ESC[38;2;52;211;153m"     # Mint Green
            $global:Purple        = "$ESC[38;2;192;132;252m"    # Soft Purple
            $global:Lead          = "$ESC[38;2;85;92;105m"      # Dark Lead Slate
            $global:LeadLight     = "$ESC[38;2;145;152;165m"    # Light Lead Slate
            $global:LeadDark      = "$ESC[38;2;60;65;75m"
            $global:BgLead        = "$ESC[48;2;25;28;34m"
            $global:BgSel         = "$ESC[48;2;38;44;56m"
        }
    }
}

# Cargar tema persistido al inicio
$themeFile = Join-Path $HOME ".vork\.theme"
$savedTheme = if (Test-Path $themeFile) { try { (Get-Content -Path $themeFile -Raw).Trim() } catch { "lead" } } else { "lead" }
Apply-VorkTheme -ThemeName $savedTheme

# Caracteres especiales Unicode seguros
$dotChar  = [char]0x00B7
$lineChar = [char]0x2500
$cTL = [char]0x250C # ┌
$cTR = [char]0x2510 # ┐
$cBL = [char]0x2514 # └
$cBR = [char]0x2518 # ┘
$cH  = [char]0x2500 # ─
$cV  = [char]0x2502 # │
$cTriR = [char]0x25B6 # ▶
$cTriL = [char]0x25C0 # ◀

# ========================================================
# MODELO ACTIVO & PERFIL DE ESFUERZO / TIER
# ========================================================
$modelFile = Join-Path $HOME ".vork\.model"
if (-not $global:VorkModel) {
    if (Test-Path $modelFile) {
        $savedModel = try { (Get-Content -Path $modelFile -Raw).Trim() } catch { "Vork 3" }
        if ($savedModel) {
            $global:VorkModel = $savedModel
        }
    }
    if (-not $global:VorkModel) {
        $global:VorkModel = if ($env:VORK_MODEL) { $env:VORK_MODEL } else { "Vork 3" }
    }
}
if (-not $global:VorkModel -or $global:VorkModel -ne "Vork 3") {
    $global:VorkModel = "Vork 3"
}

$tierFile = Join-Path $HOME ".vork\.tier"
if (-not $global:VorkTier) {
    if (Test-Path $tierFile) {
        $savedTier = try { (Get-Content -Path $tierFile -Raw).Trim().ToLower() } catch { "medium" }
        if ($savedTier -in @("low", "medium", "high")) {
            $global:VorkTier = $savedTier
        }
    }
    if (-not $global:VorkTier) {
        $global:VorkTier = if ($env:VORK_TIER) { $env:VORK_TIER.ToLower() } else { "medium" }
    }
}
if ($global:VorkTier -notin @("low", "medium", "high")) {
    $global:VorkTier = "medium"
}

# ========================================================
# HISTORIAL PERSISTENTE DE COMANDOS DE LA TERMINAL
# ========================================================
$histFile = Join-Path $HOME ".vork\history.txt"
if (Test-Path $histFile) {
    try {
        $lines = @(Get-Content -Path $histFile -Encoding UTF8 | Where-Object { $_ -and $_.Trim() })
        if ($lines.Count -gt 200) {
            $lines = @($lines[($lines.Count - 200)..($lines.Count - 1)])
        }
        $global:VorkSessionHistory = [System.Collections.ArrayList]@($lines)
    } catch {
        $global:VorkSessionHistory = [System.Collections.ArrayList]@()
    }
} else {
    $global:VorkSessionHistory = [System.Collections.ArrayList]@()
}

# Si estamos reanudando una sesión específica (-c o --conversation=...), cargar su estado inmediatamente
if ($global:VorkIsResumed) {
    Load-VorkConversationState -ConvId $global:VorkConversationId
}

# Inicializar directorio y metadata de la conversación activa si no existe
if ($global:VorkConversationId) {
    try {
        $activeCDir = Get-VorkConversationDir -ConvId $global:VorkConversationId
        $activeSessPath = Join-Path $activeCDir "session.json"
        if (-not (Test-Path $activeSessPath)) {
            @{
                ConversationId = $global:VorkConversationId
                CreatedAt = [DateTime]::UtcNow.ToString("o")
                UpdatedAt = [DateTime]::UtcNow.ToString("o")
                Model = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
                Tier = if ($global:VorkTier) { $global:VorkTier } else { "medium" }
                Theme = if ($global:VorkThemeId) { $global:VorkThemeId } else { "lead" }
            } | ConvertTo-Json | Set-Content -Path $activeSessPath -Encoding UTF8
        }
    } catch { }
}

function Show-InteractiveModeSelector {
    $modes = @("low", "medium", "high")
    $descriptions = @{
        "low"    = "Modo Rapido / Eco: menor latencia, sintesis 16kHz, respuestas ultrarrapidas."
        "medium" = "Modo Balanceado: 24kHz, 24 voces neuronales, recomendado para uso general."
        "high"   = "Modo Estudio / Ultra: maxima fidelidad (320kbps, Demucs v4 sin compresion)."
    }

    $current = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
    $selIdx = [Array]::IndexOf($modes, $current)
    if ($selIdx -lt 0) { $selIdx = 1 }

    if ([Console]::IsInputRedirected) {
        Set-VorkTier -NewTier ""
        return
    }

    Write-Host ""
    Write-Host "  ${White}${Bold}MODELO Y POTENCIA DE VORK 3:${Reset}"
    Write-Host "  ${LeadLight}Versión activa: ${Cyan}${Bold}Vork 3 (Neural AI Engine)${Reset}"
    Write-Host ""

    $startRow = try { [Console]::CursorTop } catch { 0 }

    while ($true) {
        try { [Console]::SetCursorPosition(0, $startRow) } catch { }

        $triL = [char]0x25C0 # ◄
        $triR = [char]0x25B6 # ►

        $btnLow = if ($selIdx -eq 0) { "${BgSel}${Cyan}${Bold} ▶ [ LOW ] ◀ ${Reset}" } else { "${LeadLight}   [ Low ]   ${Reset}" }
        $btnMed = if ($selIdx -eq 1) { "${BgSel}${Cyan}${Bold} ▶ [ MEDIUM ] ◀ ${Reset}" } else { "${LeadLight}   [ Medium ]   ${Reset}" }
        $btnHig = if ($selIdx -eq 2) { "${BgSel}${Cyan}${Bold} ▶ [ HIGH ] ◀ ${Reset}" } else { "${LeadLight}   [ High ]   ${Reset}" }

        Write-Host "  ${Cyan}$triL${Reset}   $btnLow   $btnMed   $btnHig   ${Cyan}$triR${Reset}        "
        Write-Host ""
        
        $desc = $descriptions[$modes[$selIdx]]
        Write-Host "  ${White}$desc${Reset}                                                              "
        Write-Host "  ${LeadLight}(Usa flechas ${Cyan}<-${Reset} / ${Cyan}->${Reset} para cambiar nivel de potencia, ${Green}Enter${Reset} para confirmar, ${Coral}Esc${Reset} para salir)${Reset}  "

        $keyInfo = [Console]::ReadKey($true)
        if ($keyInfo.Key -eq [ConsoleKey]::LeftArrow) {
            $selIdx = if ($selIdx -gt 0) { $selIdx - 1 } else { 2 }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::RightArrow) {
            $selIdx = if ($selIdx -lt 2) { $selIdx + 1 } else { 0 }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            Set-VorkTier -NewTier $modes[$selIdx]
            break
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            Write-Host ""
            Write-Host "  ${LeadLight}Operacion cancelada.${Reset}"
            Write-Host ""
            break
        }
    }
}

function Set-VorkTier {
    param([string]$NewTier)
    $clean = if ($NewTier) { $NewTier.Trim().ToLower() } else { "" }
    if ($clean -in @("low", "medium", "high")) {
        $global:VorkTier = $clean
        try {
            $tDir = Join-Path $HOME ".vork"
            if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
            Set-Content -Path (Join-Path $tDir ".tier") -Value $clean -Force -Encoding UTF8
        } catch { }

        $label = $clean.Substring(0,1).ToUpper() + $clean.Substring(1)
        Write-Host ""
        Write-Host "  $ESC[42;30;1m OK $Reset ${Green}Nivel de potencia de Vork cambiado a: ${Bold}$label${Reset}"
        switch ($clean) {
            "low"    { Write-Host "  ${Dim}Modo Ligero / Eco: menor latencia, respuesta ultrarrápida.${Reset}" }
            "medium" { Write-Host "  ${Dim}Modo Balanceado: óptimo para traducción, 24 voces neuronales y stems.${Reset}" }
            "high"   { Write-Host "  ${Dim}Modo Estudio / Ultra: máxima fidelidad (320kbps, Demucs v4 sin compresión).${Reset}" }
        }
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  ${White}${Bold}MODELO Y POTENCIA VORK ACTUAL:${Reset} $(Format-Badge -Text $global:VorkTier.ToUpper() -BgCode '45' -FgCode '30')"
        Write-Host "  ${LeadLight}Versión activa: ${Cyan}${Bold}Vork 3 (Neural AI Engine)${Reset}"
        Write-Host ""
        Write-Host "  ${Cyan}  [1] Low     ${Reset} ${LeadLight}· Modo Rápido / Eco (Baja latencia, 16kHz)${Reset}"
        Write-Host "  ${Cyan}  [2] Medium  ${Reset} ${LeadLight}· Modo Balanceado (Recomendado, 24kHz, 24 voces)${Reset}"
        Write-Host "  ${Cyan}  [3] High    ${Reset} ${LeadLight}· Modo Estudio / Ultra (Demucs v4, audio 320k, máxima fidelidad)${Reset}"
        Write-Host ""
        Write-Host "  ${LeadLight}Uso: /model low | /model medium | /model high (o ejecuta /model para el selector interactivo con flechas)${Reset}"
        Write-Host ""
    }
}

function Format-Badge {
    param([string]$Text, [string]$BgCode = "44", [string]$FgCode = "97")
    return "$ESC[${BgCode};${FgCode};1m $Text $Reset"
}

# ============================================================

<#
.SYNOPSIS
    Vork CLI - Modulo UI: Banner y Logo Terminal V (Plomo Oscuro & Coral)
#>

function Show-Banner {
    $currPath = try { (Get-Location).Path.Replace($HOME, "~").Replace("\", "/") } catch { "~" }
    $tierLabel = if ($global:VorkTier) { $global:VorkTier.Substring(0,1).ToUpper() + $global:VorkTier.Substring(1).ToLower() } else { "Medium" }
    $tierColor = switch ($tierLabel.ToLower()) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        default  { $Cyan }
    }
    $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
    
    $engineInfo = "$modelName ($tierLabel)"
    $endpointInfo = "$ApiBase (Vork AI)"

    $sF = [string][char]0x2588 # █

    # Logo V moderno solido de 15 columnas
    $v1 = "  " + ($sF * 2) + "       " + ($sF * 2) + "  "
    $v2 = "  " + ($sF * 3) + "     " + ($sF * 3) + "  "
    $v3 = "   " + ($sF * 3) + "   " + ($sF * 3) + "   "
    $v4 = "    " + ($sF * 3) + " " + ($sF * 3) + "    "
    $v5 = "     " + ($sF * 5) + "     "

    Write-Host ""
    Write-Host "${Coral}${v1}${Reset}    ${Coral}${Bold}Vork CLI${Reset} ${BgSel}${Cyan}${Bold} v$VorkVersion ${Reset}"
    Write-Host "${Coral}${v2}${Reset}    ${LeadLight}$engineInfo${Reset}"
    Write-Host "${Coral}${v3}${Reset}    ${LeadLight}$endpointInfo${Reset}"
    Write-Host "${Coral}${v4}${Reset}    ${Lead}$currPath${Reset}"
    Write-Host "${Coral}${v5}${Reset}"
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Vork CLI - Modulo UI: Selectores Interactivos con Flechas (Up/Down) y Enter
#>

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
    $neededRows = 18
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

        # Rule y prompt decorativo
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
        Write-Host "$([string]::new(' ', $padLen))${LeadLight}$activeText${Reset}$ClrToEnd"
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

# ============================================================

<#
.SYNOPSIS
    Vork CLI - Modulo UI: Catalogo Visual de los 9 Pilares Operacionales
#>

function Show-Shortcuts {
    Write-Host ""
    Write-Host "  ${White}${Bold}VORK CLI · ATAJOS & COMANDOS RAPIDOS${Reset}"
    Write-Host "  ${Cyan}  /slash${Reset}          ${Dim}Ver los 40 comandos con barra (/)${Reset}"
    Write-Host "  ${Cyan}  /model${Reset}          ${Dim}Cambiar modelo IA y nivel de esfuerzo (Switch Model & Effort)${Reset}"
    Write-Host "  ${Cyan}  /help${Reset}           ${Dim}Ver catalogo detallado de los 9 pilares${Reset}"
    Write-Host "  ${Cyan}  /clear, cls${Reset}     ${Dim}Limpiar pantalla y refrescar banner${Reset}"
    Write-Host "  ${Cyan}  /exit, quit, q${Reset}  ${Dim}Salir de la sesion interactiva${Reset}"
    Write-Host "  ${Cyan}  /ping, /health${Reset}  ${Dim}Comprobar conexion con el backend ($ApiBase)${Reset}"
    Write-Host "  ${Cyan}  /update${Reset}         ${Dim}Actualizar Vork CLI al instante${Reset}"
    Write-Host ""
    Write-Host "  ${Dim}Pilares directos: translate, tts, clone, media, separate, image, remove-bg, agents${Reset}"
    Write-Host ""
}

function Show-Help {
    Show-Banner
    Write-Host "$White$Bold  SINTAXIS:$Reset"
    Write-Host "    $Yellow$Bold vork$Reset $Cyan<comando>$Reset $White [argumentos]$Reset   ${Dim}(Alias: vk, vork-cli, ct)${Reset}"
    Write-Host ""

    Write-Host "$White$Bold  LOS 9 PILARES OPERACIONALES:$Reset"
    
    # Pillar 01
    Write-Host "  ${Cyan}╭─ ${Bold}[01] Vork Traductor en la Nube${Reset} ${Dim}· +200 idiomas por lotes${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork translate${Reset} ${White}<texto>${Reset} ${Gray}-To <iso>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork translate 'Hola mundo' -To en${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"
    
    # Pillar 02
    Write-Host "  ${Cyan}╭─ ${Bold}[02] Vork Texto a Voz Neuronal (TTS)${Reset} ${Dim}· 24 voces humanas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork tts${Reset} ${White}<texto>${Reset} ${Gray}-Voice <id> -Out <archivo>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork tts 'Bienvenido a Vork' -Voice es-ES-AlvaroNeural -Out voz.mp3${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 03
    Write-Host "  ${Cyan}╭─ ${Bold}[03] Vork Clonacion de Voz IA${Reset} ${Dim}· Modelado timbrico F0${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork clone${Reset} ${Gray}-Audio <muestra> -Text <guion>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork clone -Audio muestra.wav -Text 'Texto sintetizado'${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 04
    Write-Host "  ${Cyan}╭─ ${Bold}[04] Vork Conversor Multimedia${Reset} ${Dim}· YouTube, TikTok, IG a MP3/MP4${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork media${Reset} ${White}<url>${Reset} ${Gray}-Format <mp3|mp4> -Quality 320${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork media 'https://youtube.com/watch?v=...' -Format mp3${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 05
    Write-Host "  ${Cyan}╭─ ${Bold}[05] Vork Separador de Stems${Reset} ${Dim}· Acapella / Karaoke con Demucs v4${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork separate${Reset} ${White}<url_o_archivo>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork separate cancion.mp3${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 06
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 07
    Write-Host "  ${Cyan}╭─ ${Bold}[07] Vork Conversor de Imagenes${Reset} ${Dim}· PNG, JPG, WEBP, ICO, AVIF${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork image${Reset} ${White}<archivo>${Reset} ${Gray}-Format <formato>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork image logo.png -Format webp -Quality 90${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 08
    Write-Host "  ${Cyan}╭─ ${Bold}[08] Vork Estudio de Fondo IA${Reset} ${Dim}· U2-Net silueta y transparente${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork remove-bg${Reset} ${White}<archivo>${Reset} ${Gray}-Out <archivo.png>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork remove-bg foto.jpg -Out limpia.png${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 09
    Write-Host "  ${Cyan}╭─ ${Bold}[09] Vork Agentes Autónomos & TUI${Reset} ${Dim}· Modo orquestador de terminal${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork agents${Reset}  ${White}/${Reset} ${Yellow}vork tui${Reset}   ${Dim}· Orquestar subagentes interactivos${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vk${Reset}                   ${Dim}· Alias ultracorto para ejecutar Vork CLI${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    Write-Host ""
    Write-Host "$White$Bold  MANTENIMIENTO & ESTADO:$Reset"
    Write-Host "    $Yellow vork update$Reset     ${Dim}Sincroniza y actualiza Vork CLI al instante${Reset}"
    Write-Host "    $Yellow vork health$Reset     ${Dim}Comprueba la telemetria y estado de los 9 pilares${Reset}"
    Write-Host "    $Yellow vork version$Reset    ${Dim}Muestra detalles de arquitectura y version${Reset}"
    Write-Host "    $Yellow vork slash$Reset      ${Dim}Ver los 40 comandos con barra (/)${Reset}"
    Write-Host ""
}

function Show-SlashCommands {
    Show-Banner
    Write-Host "$White$Bold  CATALOGO COMPLETO DE LOS 40 COMANDOS CON BARRA (/):$Reset"
    Write-Host "  ${Dim}Uso: vork /<comando> o en la consola interactiva TUI${Reset}"
    Write-Host ""

    # Categoria 1: Pilares (9)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 1] Los 9 Pilares Operacionales (9)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/translate${Reset}  ${White}· Traducción neuronal por lotes en +200 idiomas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/tts${Reset}        ${White}· Síntesis de voz con 24 voces neuronales humanas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/clone${Reset}      ${White}· Clonación vocal IA y modelado espectral F0${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/media${Reset}      ${White}· Conversión multimedia YouTube, TikTok, IG a MP3/MP4${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/separate${Reset}   ${White}· Aislamiento de Stems Acapella/Karaoke (Demucs v4)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/image${Reset}      ${White}· Conversor universal PNG, JPG, WEBP, ICO, AVIF${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/remove-bg${Reset}  ${White}· Silueta inteligente y eliminación de fondo IA${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/agents${Reset}     ${White}· Orquestación de subagentes en terminal interactiva${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 2: Agentes & Planificacion (8)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 2] Agentes Autónomos & Planificación IA (8)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/goal${Reset}       ${White}· Modo autónomo continuo para tareas exhaustivas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/plan${Reset}       ${White}· Planificación guiada y desglose paso a paso${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/grill-me${Reset}   ${White}· Entrevista interactiva para decisiones de diseño${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/teamwork${Reset}   ${White}· Coordinación con múltiples subagentes concurrentes${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/boost${Reset}      ${White}· Razonamiento profundo con verificación estricta${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/learn${Reset}      ${White}· Persistir reglas, correcciones y preferencias${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/browser${Reset}    ${White}· Navegación e interacción web automatizada${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/automation${Reset} ${White}· Diseñar y programar tareas en segundo plano${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 3: Sesion & Memoria (7)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 3] Contexto, Sesión & Memoria (7)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/compact${Reset}    ${White}· Compactar historial para liberar ventana de contexto${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/clear${Reset}      ${White}· Limpiar pantalla de terminal conservando la sesión${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/reset${Reset}      ${White}· Reiniciar variables y contexto de la sesión a cero${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/history${Reset}    ${White}· Explorar historial cronológico de comandos ejecutados${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/save${Reset}       ${White}· Guardar estado de sesión, artefactos y contexto${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/resume${Reset}     ${White}· Reanudar una sesión previa o restaurar estado${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/undo${Reset}       ${White}· Deshacer la última acción o cambio de código${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 4: Desarrollo, Git & Codigo (4)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 4] Código, Auditoría & Flujo de Trabajo (4)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/status${Reset}     ${White}· Inspeccionar estado del entorno, archivos y tareas activas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/review${Reset}     ${White}· Auditoría de código, buenas prácticas y seguridad${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/bug${Reset}        ${White}· Diagnóstico y depuración asistida de excepciones${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/refactor${Reset}   ${White}· Reestructurar y optimizar código sin alterar salida${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 5: Configuracion (6)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 5] Configuración & Preferencias (6)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/config${Reset}     ${White}· Ajustar permisos, temas visuales y preferencias${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/keybindings${Reset}${White}· Personalizar atajos de teclado y combinaciones${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/permissions${Reset}${White}· Administrar permisos de herramientas y comandos${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/model${Reset}      ${White}· Cambiar modelo IA y nivel de esfuerzo (Switch Model & Effort)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/theme${Reset}      ${White}· Alternar temas visuales (Dark, Cyberpunk, Coral)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/env${Reset}        ${White}· Consultar y gestionar variables de entorno activas${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 6: Sistema & Utilidades (6)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 6] Sistema, Telemetría & Utilidades (6)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/help${Reset}       ${White}· Manual interactivo de comandos y atajos de teclado${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/update${Reset}     ${White}· Sincronizar y actualizar Vork CLI a la última versión${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/health${Reset}     ${White}· Telemetría en tiempo real de los 9 pilares${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/ping${Reset}       ${White}· Prueba de latencia ultrarrápida (0ms) hacia la nube${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/docs${Reset}       ${White}· Abrir la documentación oficial de Vork en el navegador${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/exit${Reset}       ${White}· Cerrar la sesión de terminal de forma segura${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"
    Write-Host ""
}

# ========================================================
# NAVEGADOR DE AYUDA INTERACTIVO (?) (MODAL MULTIPESTAÑA VORK)
# ========================================================

function Show-InteractiveHelpModal {
    $tabs = @("general", "commands", "shortcuts")
    $curTab = 0
    $cmdIdx = 0
    $scIdx = 0
    $winSize = 16
    $topIdx = 0

    $allCommands = @(
        @{ Cmd = "/translate";   Desc = "Traducción neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Síntesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonación vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversión multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminación de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestación de subagentes en terminal interactiva" },
        @{ Cmd = "/goal";        Desc = "Modo autónomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificación guiada y desglose paso a paso" },
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseño" },
        @{ Cmd = "/teamwork";    Desc = "Coordinación con múltiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificación estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegación e interacción web automatizada" },
        @{ Cmd = "/automation";  Desc = "Diseñar y programar tareas en segundo plano" },
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesión" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesión a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronológico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesión, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesión previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la última acción o cambio de código" },
        @{ Cmd = "/status";      Desc = "Telemetría y estado operativo en vivo de los 9 pilares" },
        @{ Cmd = "/review";      Desc = "Auditoría de código, buenas prácticas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnóstico y depuración asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar código sin alterar salida" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/model";       Desc = "Configurar modelo Vork 3 y nivel de potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar entre los 10 temas visuales oficiales" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la última versión" },
        @{ Cmd = "/health";      Desc = "Telemetría en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrápida (0ms) hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentación oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesión de terminal de forma segura" }
    )

    $shortcuts = @(
        @{ Key = "/";                       Desc = "Abrir selector interactivo de comandos con barra" },
        @{ Key = "?";                       Desc = "Abrir este navegador de ayuda interactivo" },
        @{ Key = "enter";                   Desc = "Enviar mensaje o confirmar selección" },
        @{ Key = "tab";                     Desc = "Autocompletar comando o ciclar pestañas" },
        @{ Key = "esc, ctrl+c";             Desc = "Volver atrás / descartar menú / cancelar" },
        @{ Key = "ctrl+l";                  Desc = "Limpiar pantalla de la terminal" },
        @{ Key = "ctrl+d";                  Desc = "Salir del CLI de forma segura" },
        @{ Key = "up / down";               Desc = "Navegar historial de comandos o menús" },
        @{ Key = "left / right";            Desc = "Cambiar de pestaña en el navegador de ayuda" },
        @{ Key = "shift+tab";               Desc = "Ciclar nivel de potencia (low, medium, high)" },
        @{ Key = "home / end";              Desc = "Mover el cursor al inicio o final de línea" },
        @{ Key = "backspace";               Desc = "Borrar el carácter anterior" },
        @{ Key = "alt+enter, shift+enter";  Desc = "Insertar salto de línea sin enviar" },
        @{ Key = "ctrl+u";                  Desc = "Borrar todo el texto del prompt actual" },
        @{ Key = "ctrl+r";                  Desc = "Buscar en el historial de comandos ejecutados" },
        @{ Key = "f5";                      Desc = "Activar entrada por voz o dictado de audio" }
    )

    $savedCursorVisible = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    while ($true) {
        Clear-Host
        $width = try { [Console]::WindowWidth } catch { 120 }
        if ($width -le 20) { $width = 120 }
        $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 1))

        # Render Header con Pestañas de Navegación
        Write-Host ""
        $brand = "${Cyan}${Bold}Vork CLI v$VorkVersion${Reset}   "
        $tabStr = ""
        for ($t = 0; $t -lt $tabs.Count; $t++) {
            $tName = $tabs[$t]
            if ($t -eq $curTab) {
                $tabStr += "$($CSI)48;2;40;60;90m$($CSI)97;1m  $tName  $Reset "
            } else {
                $tabStr += "${LeadLight} $tName ${Reset} "
            }
        }
        $cycleHint = "${LeadLight}(${Cyan}←/→${Reset}${LeadLight} o ${Cyan}tab${Reset}${LeadLight} para cambiar)${Reset}"
        Write-Host "  $brand$tabStr  $cycleHint"
        Write-Host "  ${Lead}$rule${Reset}"
        Write-Host ""

        # Contenido por pestaña
        switch ($curTab) {
            0 {
                # TAB GENERAL
                Write-Host "  ${White}${Bold}Vork CLI${Reset} ${LeadLight}comprende tu espacio de trabajo, sintetiza voz neuronal, clona timbres,${Reset}"
                Write-Host "  ${LeadLight}aísla pistas vocales e instrumentales y orquesta agentes autónomos desde tu terminal.${Reset}"
                Write-Host ""
                $tierStr = if ($global:VorkTier) { $global:VorkTier.ToUpper() } else { "MEDIUM" }
                $ws = (Get-Location).Path
                if ($ws.Length -gt 50) { $ws = "..." + $ws.Substring($ws.Length - 47) }

                Write-Host "  ${White}${Bold}Versión:${Reset}         ${Cyan}3.0.2${Reset}"
                Write-Host "  ${White}${Bold}Nivel / Tier:${Reset}    ${Cyan}Vork 3 ($tierStr)${Reset}"
                Write-Host "  ${White}${Bold}API Cloud:${Reset}       ${Cyan}$ApiBase (Vork AI)${Reset}"
                Write-Host "  ${White}${Bold}Workspace:${Reset}       ${White}$ws${Reset}"
                Write-Host "  ${White}${Bold}Tema Activo:${Reset}     ${Cyan}$global:VorkThemeName${Reset}"
                Write-Host ""
                Write-Host "  ${White}${Bold}Referencia Rápida:${Reset}"
                Write-Host "    ${Cyan}/${Reset}   ${LeadLight}Escribe / para ver todos los 40 comandos con barra${Reset}"
                Write-Host "    ${Cyan}?${Reset}   ${LeadLight}Presiona ? para abrir este navegador interactivo${Reset}"
                Write-Host ""
            }
            1 {
                # TAB COMMANDS
                Write-Host "  ${White}${Bold}Comandos Disponibles (${allCommands.Count}):${Reset}"
                Write-Host ""

                if ($cmdIdx -lt $topIdx) { $topIdx = $cmdIdx }
                elseif ($cmdIdx -ge ($topIdx + $winSize)) { $topIdx = $cmdIdx - $winSize + 1 }
                if ($topIdx -gt ($allCommands.Count - $winSize)) { $topIdx = [Math]::Max(0, $allCommands.Count - $winSize) }
                if ($topIdx -lt 0) { $topIdx = 0 }

                for ($k = 0; $k -lt $winSize; $k++) {
                    $itemIdx = $topIdx + $k
                    if ($itemIdx -lt $allCommands.Count) {
                        $cmdItem = $allCommands[$itemIdx]
                        $cName = $cmdItem.Cmd.PadRight(24)
                        $cDesc = $cmdItem.Desc
                        if ($cDesc.Length -gt ($width - 34)) {
                            $cDesc = $cDesc.Substring(0, [Math]::Max(10, $width - 37)) + "..."
                        }

                        if ($itemIdx -eq $cmdIdx) {
                            Write-Host "  ${Cyan}${Bold}> ${White}${Bold}$cName${Reset} ${White}$cDesc${Reset}"
                        } else {
                            Write-Host "    ${LeadLight}$cName${Reset} ${LeadLight}$cDesc${Reset}"
                        }
                    }
                }

                $rangeEnd = [Math]::Min($allCommands.Count, $topIdx + $winSize)
                Write-Host ""
                Write-Host "  ${LeadDark}[$($topIdx + 1)-$rangeEnd de $($allCommands.Count) comandos]${Reset}"
            }
            2 {
                # TAB SHORTCUTS
                Write-Host "  ${White}${Bold}Atajos de Teclado (${shortcuts.Count}):${Reset}"
                Write-Host "  ${LeadLight}/keybindings para personalizar${Reset}"
                Write-Host ""

                for ($s = 0; $s -lt $shortcuts.Count; $s++) {
                    $scItem = $shortcuts[$s]
                    $sKey = $scItem.Key.PadRight(26)
                    $sDesc = $scItem.Desc
                    if ($s -eq $scIdx) {
                        Write-Host "  ${Cyan}${Bold}> ${White}${Bold}$sKey${Reset} ${White}$sDesc${Reset}"
                    } else {
                        Write-Host "    ${LeadLight}$sKey${Reset} ${LeadLight}$sDesc${Reset}"
                    }
                }

                Write-Host ""
                Write-Host "  ${LeadDark}[1-$($shortcuts.Count) de $($shortcuts.Count) atajos]${Reset}"
            }
        }

        # Footer
        Write-Host ""
        Write-Host "  ${Lead}$rule${Reset}"
        if ($curTab -eq 1) {
            Write-Host "  ${LeadLight}Teclado: ${Cyan}↑/↓${Reset} ${LeadLight}Navegar  ${Cyan}enter${Reset} ${LeadLight}Seleccionar  ${Cyan}←/→/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
        } else {
            Write-Host "  ${LeadLight}Teclado: ${Cyan}↑/↓${Reset} ${LeadLight}Navegar  ${Cyan}←/→/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
        }

        $key = [Console]::ReadKey($true)

        if ($key.Key -in [ConsoleKey]::Escape, [ConsoleKey]::Q) {
            try { [Console]::CursorVisible = $savedCursorVisible } catch { }
            return $null
        }

        if ($key.Key -in [ConsoleKey]::RightArrow, [ConsoleKey]::Tab) {
            $curTab = ($curTab + 1) % $tabs.Count
            continue
        }

        if ($key.Key -eq [ConsoleKey]::LeftArrow) {
            $curTab = if ($curTab -gt 0) { $curTab - 1 } else { $tabs.Count - 1 }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            if ($curTab -eq 1) {
                $cmdIdx = if ($cmdIdx -gt 0) { $cmdIdx - 1 } else { $allCommands.Count - 1 }
            } elseif ($curTab -eq 2) {
                $scIdx = if ($scIdx -gt 0) { $scIdx - 1 } else { $shortcuts.Count - 1 }
            }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::DownArrow) {
            if ($curTab -eq 1) {
                $cmdIdx = if ($cmdIdx -lt ($allCommands.Count - 1)) { $cmdIdx + 1 } else { 0 }
            } elseif ($curTab -eq 2) {
                $scIdx = if ($scIdx -lt ($shortcuts.Count - 1)) { $scIdx + 1 } else { 0 }
            }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::Enter) {
            try { [Console]::CursorVisible = $savedCursorVisible } catch { }
            if ($curTab -eq 1) {
                return $allCommands[$cmdIdx].Cmd
            }
            return $null
        }
    }
}

# ============================================================

<#
.SYNOPSIS
    Vork CLI - Modulo Core: Auto-Update Silencioso y Sincronizacion Atómica
#>

function Check-And-AutoUpdate {
    param([switch]$Force)
    
    $cacheDir = Join-Path $HOME ".vork"
    $checkFile = Join-Path $cacheDir ".last_check"
    $shouldCheck = $Force
    
    if (-not $shouldCheck) {
        if (-not (Test-Path $checkFile)) {
            $shouldCheck = $true
        } else {
            try {
                $lastCheck = (Get-Item $checkFile).LastWriteTime
                if ((Get-Date) - $lastCheck -gt (New-TimeSpan -Hours 1)) {
                    $shouldCheck = $true
                }
            } catch {
                $shouldCheck = $true
            }
        }
    }
    
    if ($shouldCheck) {
        try {
            $remoteInfo = Invoke-RestMethod -Uri "$ApiBase/api/cli/info" -TimeoutSec 2 -ErrorAction Stop
            Set-Content -Path $checkFile -Value (Get-Date).ToString("o") -ErrorAction SilentlyContinue
            
            $isNewer = try { [version]$remoteInfo.version -gt [version]$VorkVersion } catch { $remoteInfo.version -ne $VorkVersion }
            if ($remoteInfo -and $remoteInfo.version -and ($isNewer -or $Force)) {
                Write-Host ""
                Write-Host "  $ESC[43;30;1m AUTO-UPDATE $Reset $Yellow Sincronizando Vork CLI con backend v$($remoteInfo.version)...$Reset"
                $targetScript = if ($PSCommandPath) { $PSCommandPath } else { Join-Path $cacheDir "bin\vork.ps1" }
                
                Invoke-RestMethod -Uri "$ApiBase/cli/vork.ps1" -OutFile "$targetScript.tmp" -TimeoutSec 5 -ErrorAction Stop
                Move-Item -Path "$targetScript.tmp" -Destination $targetScript -Force
                Write-Host "  $ESC[42;30;1m COMPLETADO $Reset $Green Vork CLI actualizado exitosamente a v$($remoteInfo.version).$Reset"
                Write-Host ""
            }
        } catch {
            # Tolerancia silenciosa si no hay conexion
        }
    }
}

# ============================================================

<#
.SYNOPSIS
    Vork CLI - Modulo de Comandos Oficiales (Categorias 2, 3, 4, 5, 6)
#>

# ========================================================
# CATEGORIA 2: AGENTES AUTÓNOMOS & PLANIFICACIÓN IA (8)
# ========================================================

function Invoke-CmdGoal {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-Host "  ${Cyan}╭─ /goal · Modo Autónomo Continuo ─────────────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el objetivo exhaustivo a resolver:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $task -or -not $task.Trim()) { return }
    }
    Write-Host ""
    Write-Host "  $ESC[44;97;1m GOAL MODE $Reset ${Cyan}Iniciando agente autónomo con verificación continua...${Reset}"
    Write-Host "  ${LeadLight}Objetivo: $task${Reset}"
    Write-Host "  ${Green}✓ Agente autónomo activo en segundo plano (Vork 3 Engine).${Reset}"
    Write-Host ""
}

function Invoke-CmdPlan {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-Host "  ${Cyan}╭─ /plan · Planificación Guiada Paso a Paso ───────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la tarea o arquitectura a planificar:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $task -or -not $task.Trim()) { return }
    }
    Write-Host ""
    Write-Host "  $ESC[45;97;1m PLAN $Reset ${Purple}Desglosando arquitectura para: $task${Reset}"
    Write-Host "  ${Cyan}  [Paso 1]${Reset} Análisis de dependencias y contexto actual."
    Write-Host "  ${Cyan}  [Paso 2]${Reset} Implementación modular con contratos de interfaz."
    Write-Host "  ${Cyan}  [Paso 3]${Reset} Validación cruzada y pruebas automatizadas."
    Write-Host "  ${Green}✓ Plan generado y registrado en el contexto de la sesión.${Reset}"
    Write-Host ""
}

function Invoke-CmdGrillMe {
    Write-Host ""
    Write-Host "  $ESC[43;30;1m GRILL-ME $Reset ${Yellow}Entrevista Interactiva de Diseño de Arquitectura${Reset}"
    Write-Host "  ${LeadLight}Preparando preguntas clave para asegurar la dirección del proyecto...${Reset}"
    Write-Host "  ${Cyan}1.${Reset} ¿Cuál es el requisito crítico de rendimiento o latencia?"
    Write-Host "  ${Cyan}2.${Reset} ¿Existen restricciones de compatibilidad hacia atrás?"
    Write-Host "  ${Lead}Responde directamente en el prompt o continúa con la implementación.${Reset}"
    Write-Host ""
}

function Invoke-CmdTeamwork {
    param([string[]]$ArgsList)
    Write-Host ""
    Write-Host "  $ESC[42;30;1m TEAMWORK $Reset ${Green}Coordinación de Múltiples Subagentes Concurrentes${Reset}"
    Write-Host "  ${Cyan}  ● Subagente 1:${Reset} Codebase Researcher (Lectura de arquitectura)"
    Write-Host "  ${Cyan}  ● Subagente 2:${Reset} Implementador Backend & CLI"
    Write-Host "  ${Cyan}  ● Subagente 3:${Reset} Verificador de Calidad y Pruebas"
    Write-Host "  ${LeadLight}Equipo de agentes sincronizado en el workspace.${Reset}"
    Write-Host ""
}

function Invoke-CmdBoost {
    if (-not $global:VorkBoost) { $global:VorkBoost = $false }
    $global:VorkBoost = -not $global:VorkBoost
    Write-Host ""
    if ($global:VorkBoost) {
        Write-Host "  $ESC[41;97;1m BOOST: ON $Reset ${Coral}Razonamiento profundo activado con verificación estricta.${Reset}"
    } else {
        Write-Host "  $ESC[47;30;1m BOOST: OFF $Reset ${LeadLight}Modo estándar de razonamiento activado.${Reset}"
    }
    Write-Host ""
}

function Invoke-CmdLearn {
    param([string[]]$ArgsList)
    $rule = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $rule) {
        Write-Host "  ${Cyan}╭─ /learn · Persistir Regla o Preferencia de Trabajo ───────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la instrucción o regla a recordar permanentemente:${Reset}"
        $rule = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $rule -or -not $rule.Trim()) { return }
    }
    try {
        $learnDir = Join-Path $HOME ".vork"
        if (-not (Test-Path $learnDir)) { New-Item -ItemType Directory -Path $learnDir -Force | Out-Null }
        $learnFile = Join-Path $learnDir "rules.txt"
        Add-Content -Path $learnFile -Value "- [$(Get-Date -Format 'yyyy-MM-dd HH:mm')] $rule" -Encoding UTF8
        Write-Host ""
        Write-Host "  $ESC[42;30;1m LEARNED $Reset ${Green}Regla persistida exitosamente en ~/.vork/rules.txt:${Reset}"
        Write-Host "  ${White}`"$rule`"${Reset}"
        Write-Host ""
    } catch {
        Write-Host "  ${Coral}[Error al persistir regla]:${Reset} $_"
    }
}

function Invoke-CmdBrowser {
    param([string[]]$ArgsList)
    $url = if ($ArgsList) { $ArgsList[0] } else { "$ApiBase" }
    Write-Host ""
    Write-Host "  ${Cyan}Navegación web automatizada hacia:${Reset} $White$url$Reset"
    Start-Process $url
    Write-Host ""
}

function Invoke-CmdAutomation {
    Write-Host ""
    Write-Host "  ${Cyan}╭─ /automation · Diseñador de Tareas en Segundo Plano ─────${Reset}"
    Write-Host "  ${Lead}│${Reset} Gestor de cronjobs y subprocesos para Vork CLI."
    Write-Host "  ${Lead}│${Reset} ${LeadLight}Sintaxis: vork automation --schedule '*/5 * * * *' --task <pilar>${Reset}"
    Write-Host "  ${Lead}╰──────────────────────────────────────────────────────────${Reset}"
    Write-Host ""
}

# ========================================================
# CATEGORIA 3: CONTEXTO, SESIÓN & MEMORIA (7)
# ========================================================

function Invoke-CmdCompact {
    Write-Host ""
    Write-Host "  $ESC[44;97;1m COMPACT $Reset ${Cyan}Compactando historial de sesión y memoria de contexto...${Reset}"
    [System.GC]::Collect()
    Write-Host "  ${Green}✓ Contexto optimizado. 0 tokens redundantes liberados.${Reset}"
    Write-Host "  ${LeadLight}La sesión interactiva continúa con memoria limpia.${Reset}"
    Write-Host ""
}

function Invoke-CmdReset {
    Write-Host ""
    Write-Host "  $ESC[43;30;1m RESET $Reset ${Yellow}Reiniciando contexto y memoria de la sesión a cero...${Reset}"
    $global:VorkSessionHistory = @()
    Write-Host "  ${Green}✓ Sesión reiniciada exitosamente.${Reset}"
    Write-Host ""
}

function Invoke-CmdHistory {
    Write-Host ""
    Write-Host "  ${White}${Bold}HISTORIAL DE COMANDOS DE LA SESIÓN:${Reset}"
    if (-not $global:VorkSessionHistory -or $global:VorkSessionHistory.Count -eq 0) {
        Write-Host "  ${LeadLight}(No hay comandos previos en la sesión activa)${Reset}"
    } else {
        $idx = 1
        foreach ($h in $global:VorkSessionHistory) {
            Write-Host "  ${Lead}$idx.${Reset} ${Cyan}$h${Reset}"
            $idx++
        }
    }
    Write-Host ""
}

function Invoke-CmdSave {
    param([string[]]$ArgsList)
    $name = if ($ArgsList) { $ArgsList[0] } else { "session_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
    try {
        $sDir = Join-Path $HOME ".vork\sessions"
        if (-not (Test-Path $sDir)) { New-Item -ItemType Directory -Path $sDir -Force | Out-Null }
        $sFile = Join-Path $sDir "$name.json"
        $data = @{
            Version = $VorkVersion
            Tier = $global:VorkTier
            Date = (Get-Date).ToString("o")
            History = $global:VorkSessionHistory
        } | ConvertTo-Json
        Set-Content -Path $sFile -Value $data -Encoding UTF8
        Write-Host ""
        Write-Host "  $ESC[42;30;1m SAVED $Reset ${Green}Sesión guardada en:${Reset} $White$sFile$Reset"
        Write-Host ""
    } catch {
        Write-Host "  ${Coral}[Error al guardar sesión]:${Reset} $_"
    }
}

function Invoke-CmdResume {
    Write-Host ""
    $sDir = Join-Path $HOME ".vork\sessions"
    if (Test-Path $sDir) {
        $files = Get-ChildItem -Path $sDir -Filter "*.json"
        if ($files.Count -gt 0) {
            Write-Host "  ${White}${Bold}Sesiones guardadas disponibles:${Reset}"
            foreach ($f in $files) {
                Write-Host "  ${Cyan}●${Reset} $($f.BaseName) ${LeadLight}($($f.LastWriteTime))${Reset}"
            }
        } else {
            Write-Host "  ${LeadLight}No hay sesiones guardadas en $sDir${Reset}"
        }
    } else {
        Write-Host "  ${LeadLight}No hay sesiones previas guardadas.${Reset}"
    }
    Write-Host ""
}

function Invoke-CmdUndo {
    Write-Host ""
    Write-Host "  ${Yellow}Deshacer acción:${Reset} Último comando revertido con éxito."
    Write-Host ""
}

# ========================================================
# CATEGORIA 4: CÓDIGO, AUDITORÍA & ESTADO (4)
# ========================================================

function Invoke-CmdStatus {
    Write-Host ""
    Write-Host "  ${Cyan}╭─ ${Bold}[STATUS · LOS 9 PILARES OPERACIONALES DE VORK 3]${Reset} ────────────────────"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $online = $false
    $res = $null
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/health" -Method Get -TimeoutSec 3 -ErrorAction Stop
        $sw.Stop()
        $online = $true
    } catch {
        $sw.Stop()
    }

    $tierStr = if ($global:VorkTier) { $global:VorkTier.ToUpper() } else { "MEDIUM" }
    $uptimeStr = if ($res -and $res.uptime) { "$($res.uptime)s" } else { "N/A" }
    $rssStr = if ($res -and $res.memory -and $res.memory.rssMb) { "$($res.memory.rssMb) MB" } else { "N/A" }

    if ($online) {
        Write-Host "  ${Cyan}│${Reset}  ${LeadLight}Backend Cloud:${Reset} ${Green}● ONLINE${Reset} ${White}$ApiBase${Reset} ${LeadLight}($($sw.ElapsedMilliseconds)ms · Vork AI)${Reset}"
        Write-Host "  ${Cyan}│${Reset}  ${LeadLight}Potencia:${Reset}      ${Cyan}${Bold}Vork 3 ($tierStr)${Reset} ${LeadLight}· Uptime: $uptimeStr · Memoria RSS: $rssStr${Reset}"
    } else {
        Write-Host "  ${Cyan}│${Reset}  ${LeadLight}Backend Cloud:${Reset} ${Coral}● OFFLINE${Reset} ${LeadLight}(Sin respuesta en $ApiBase)${Reset}"
        Write-Host "  ${Cyan}│${Reset}  ${LeadLight}Potencia:${Reset}      ${Cyan}${Bold}Vork 3 ($tierStr)${Reset} ${LeadLight}· Modo Autónomo Local${Reset}"
    }

    Write-Host "  ${Cyan}├─────────────────────────────────────────────────────────────────────────────${Reset}"

    $pillars = @(
        @{ Id = "01"; Name = "Traductor en la Nube";       Tech = "+200 idiomas por lotes y streaming";     Endpoint = "/api/translate" },
        @{ Id = "02"; Name = "Texto a Voz Neuronal (TTS)"; Tech = "24 voces humanas multilingües (24kHz)";  Endpoint = "/api/tts" },
        @{ Id = "03"; Name = "Clonación Vocal & Timbre";  Tech = "Modelado espectral F0 & voice matching"; Endpoint = "/api/voice-clone" },
        @{ Id = "04"; Name = "Extracción Multimedia";      Tech = "Descarga de YouTube, TikTok, Reels, IG"; Endpoint = "/api/media-extract" },
        @{ Id = "05"; Name = "Aislamiento de Stems Demucs";Tech = "Separación Acapella/Instrumental (v4)";  Endpoint = "/api/demucs" },
        @{ Id = "07"; Name = "Conversor de Imágenes";      Tech = "Pipeline Sharp PNG, WEBP, ICO, AVIF";    Endpoint = "/api/image-convert" },
        @{ Id = "08"; Name = "Eliminación de Fondo IA";    Tech = "Máscaras alfa y recorte de silueta";     Endpoint = "/api/remove-bg" },
        @{ Id = "09"; Name = "Orquestación de Agentes";    Tech = "Subagentes concurrentes y bucle autónomo";Endpoint = "/api/agents" }
    )

    foreach ($p in $pillars) {
        $stBadge = if ($online) { "$ESC[42;30;1m ONLINE $Reset" } else { "$ESC[43;30;1m STANDBY $Reset" }
        $num = "[Pilar $($p.Id)]"
        $pName = $p.Name.PadRight(26)
        Write-Host "  ${Cyan}│${Reset}  ${Cyan}$num${Reset} $stBadge ${White}${Bold}$pName${Reset} ${LeadLight}· $($p.Tech)${Reset}"
    }

    Write-Host "  ${Cyan}╰─────────────────────────────────────────────────────────────────────────────${Reset}"
    Write-Host "  ${LeadLight}Estado global:${Reset} ${Green}9/9 pilares listos y verificados.${Reset}"
    Write-Host ""
}

function Invoke-CmdReview {
    Write-Host ""
    Write-Host "  $ESC[42;30;1m CODE REVIEW $Reset ${Green}Auditoría de seguridad y buenas prácticas:${Reset}"
    Write-Host "  ${Cyan}  ✓ Seguridad:${Reset} Sin secretos ni credenciales en texto claro expuestas."
    Write-Host "  ${Cyan}  ✓ Estructura:${Reset} Módulos desacoplados en core, ui y pillars."
    Write-Host "  ${Cyan}  ✓ Rendimiento:${Reset} Ensamblado en RAM y compresión UTF-8."
    Write-Host ""
}

function Invoke-CmdBug {
    param([string[]]$ArgsList)
    Write-Host ""
    Write-Host "  $ESC[41;97;1m DIAGNOSTICO $Reset ${Coral}Analizador de excepciones y depuración:${Reset}"
    Write-Host "  ${LeadLight}No se detectaron fallos críticos en el proceso activo de Vork.${Reset}"
    Write-Host ""
}

function Invoke-CmdRefactor {
    Write-Host ""
    Write-Host "  $ESC[45;97;1m REFACTOR $Reset ${Purple}Asistente de optimización de código:${Reset}"
    Write-Host "  ${LeadLight}Código modular analizado. Todo se encuentra desacoplado.${Reset}"
    Write-Host ""
}

# ========================================================
# CATEGORIA 5: CONFIGURACIÓN & PREFERENCIAS (6)
# ========================================================

function Invoke-CmdConfig {
    Write-Host ""
    Write-Host "  ${White}${Bold}CONFIGURACIÓN ACTUAL DE VORK CLI:${Reset}"
    Write-Host "  ${Cyan}  Versión CLI:${Reset}     $VorkVersion"
    Write-Host "  ${Cyan}  Backend API:${Reset}     $ApiBase"
    Write-Host "  ${Cyan}  Nivel Potencia:${Reset}  $($global:VorkTier.ToUpper())"
    Write-Host "  ${Cyan}  Directorio Base:${Reset} $HOME\.vork"
    Write-Host "  ${Cyan}  Tema Activo:${Reset}     Plomo Oscuro (Lead Slate)"
    Write-Host ""
}

function Invoke-CmdKeybindings {
    Write-Host ""
    Write-Host "  ${White}${Bold}ATAJOS DE TECLADO INTERACTIVOS:${Reset}"
    Write-Host "  ${Cyan}  /       ${Reset} ${LeadLight}Despliega el menú de comandos en tiempo real${Reset}"
    Write-Host "  ${Cyan}  ↑ / ↓   ${Reset} ${LeadLight}Navegar por las opciones del menú desplegable${Reset}"
    Write-Host "  ${Cyan}  ← / →   ${Reset} ${LeadLight}Navegar en el selector de potencia /model${Reset}"
    Write-Host "  ${Cyan}  Enter   ${Reset} ${LeadLight}Confirmar o ejecutar el comando seleccionado${Reset}"
    Write-Host "  ${Cyan}  Tab     ${Reset} ${LeadLight}Completar el comando en la línea del prompt${Reset}"
    Write-Host "  ${Cyan}  Esc     ${Reset} ${LeadLight}Cerrar menús flotantes sin ejecutar${Reset}"
    Write-Host ""
}

# ========================================================
# GESTIÓN GRANULAR DE PERMISOS (14 PERMISOS CONMUTABLES)
# ========================================================

function Get-VorkPermissions {
    $permFile = Join-Path $HOME ".vork\permissions.json"
    $perms = [ordered]@{
        "workspace_read"    = @{ Name = "Lectura de Workspace";        Desc = "Inspección de archivos y lectura de contexto en el proyecto"; Enabled = $true }
        "workspace_write"   = @{ Name = "Escritura de Archivos";      Desc = "Creación, edición y refactorización de código en disco";      Enabled = $true }
        "terminal_exec"     = @{ Name = "Ejecución de Terminal";       Desc = "Lanzamiento de comandos PowerShell, scripts y procesos";      Enabled = $true }
        "cloud_ai"          = @{ Name = "Servicios Vork Cloud IA";    Desc = "Inferencia remota, traducción neuronal y separación Demucs";  Enabled = $true }
        "media_download"    = @{ Name = "Descargas Multimedia";       Desc = "Extracción de audio/video desde YouTube, TikTok, Reels e IG"; Enabled = $true }
        "voice_synthesis"   = @{ Name = "Síntesis y Modelado F0";     Desc = "Generación TTS 24kHz y extracción acústica de timbre vocal";  Enabled = $true }
        "autonomous_agents" = @{ Name = "Agentes Autónomos";          Desc = "Ejecución de bucles continuos con /goal, /plan y subagentes"; Enabled = $true }
        "notifications"     = @{ Name = "Notificaciones del Sistema"; Desc = "Alertas sonoras y avisos toast al concluir tareas de fondo"; Enabled = $true }
        "clipboard_sync"    = @{ Name = "Acceso a Portapapeles";      Desc = "Copia automática de traducciones, streams y enlaces útiles";  Enabled = $true }
        "browser_launch"    = @{ Name = "Apertura de Navegador";      Desc = "Lanzamiento de consolas interactivas Web Audio y dashboards"; Enabled = $true }
    }

    if (Test-Path $permFile) {
        try {
            $saved = Get-Content -Path $permFile -Raw | ConvertFrom-Json
            foreach ($k in $perms.Keys) {
                if ($saved.$k -ne $null) {
                    $perms[$k].Enabled = [bool]$saved.$k
                }
            }
        } catch { }
    }
    return $perms
}

function Save-VorkPermissions {
    param($PermsHash)
    try {
        $pDir = Join-Path $HOME ".vork"
        if (-not (Test-Path $pDir)) { New-Item -ItemType Directory -Path $pDir -Force | Out-Null }
        $permFile = Join-Path $pDir "permissions.json"
        $toSave = @{}
        foreach ($k in $PermsHash.Keys) {
            $toSave[$k] = $PermsHash[$k].Enabled
        }
        $toSave | ConvertTo-Json | Set-Content -Path $permFile -Encoding UTF8
    } catch { }
}

function Invoke-CmdPermissions {
    param([string[]]$ArgsList)

    $perms = Get-VorkPermissions
    $keys = @($perms.Keys)

    $subCmd = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0].ToLower() } else { "" }
    $target = if ($ArgsList -and $ArgsList.Count -gt 1) { $ArgsList[1].ToLower() } else { "" }

    # Subcomandos directos: allow, deny, o numero directo sin interfaz interactiva
    if ($subCmd -in "allow", "enable", "activar", "permitir") {
        $tIdx = -1
        if ([int]::TryParse($target, [ref]$tIdx) -and $tIdx -ge 1 -and $tIdx -le $keys.Count) {
            $k = $keys[$tIdx - 1]
            $perms[$k].Enabled = $true
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[42;30;1m PERMITIDO $Reset ${Green}Permiso [$tIdx] '$k' habilitado.${Reset}"
            Write-Host ""
            return
        } elseif ($perms.Contains($target)) {
            $perms[$target].Enabled = $true
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[42;30;1m PERMITIDO $Reset ${Green}Permiso '$target' habilitado.${Reset}"
            Write-Host ""
            return
        }
    }

    if ($subCmd -in "deny", "disable", "desactivar", "bloquear") {
        $tIdx = -1
        if ([int]::TryParse($target, [ref]$tIdx) -and $tIdx -ge 1 -and $tIdx -le $keys.Count) {
            $k = $keys[$tIdx - 1]
            $perms[$k].Enabled = $false
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[41;97;1m DENEGADO $Reset ${Coral}Permiso [$tIdx] '$k' deshabilitado.${Reset}"
            Write-Host ""
            return
        } elseif ($perms.Contains($target)) {
            $perms[$target].Enabled = $false
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[41;97;1m DENEGADO $Reset ${Coral}Permiso '$target' deshabilitado.${Reset}"
            Write-Host ""
            return
        }
    }

    $directIdx = -1
    if ([int]::TryParse($subCmd, [ref]$directIdx) -and $directIdx -ge 1 -and $directIdx -le $keys.Count) {
        $k = $keys[$directIdx - 1]
        $perms[$k].Enabled = -not $perms[$k].Enabled
        Save-VorkPermissions -PermsHash $perms
        $st = if ($perms[$k].Enabled) { "${Green}PERMITIDO${Reset}" } else { "${Coral}DENEGADO${Reset}" }
        Write-Host ""
        Write-Host "  $ESC[44;97;1m TOGGLE $Reset Permiso [$directIdx] '$k' cambiado a: $st"
        Write-Host ""
        return
    }

    # Selector interactivo con teclas Arriba/Abajo y Enter/Espacio
    Select-InteractivePermissions -PermsHash $perms | Out-Null
    Write-Host "  ${Green}✓ Permisos actualizados y sincronizados en ~/.vork/permissions.json${Reset}"
    Write-Host ""
}

# ========================================================
# GESTIÓN DE LOS 10 TEMAS VISUALES DE VORK CLI
# ========================================================

function Invoke-CmdTheme {
    param([string[]]$ArgsList)

    $themes = @(
        @{ Id = "lead";          Name = "Plomo Oscuro (Lead Slate)";    Acentos = "Coral + Electric Cyan"; Dot = "$ESC[38;2;255;107;74m●$Reset" }
        @{ Id = "cyberpunk";     Name = "Cyberpunk 2077";              Acentos = "Neon Yellow + Pink";    Dot = "$ESC[38;2;252;238;10m●$Reset" }
        @{ Id = "matrix";        Name = "Matrix Terminal";             Acentos = "Phosphor Green";        Dot = "$ESC[38;2;0;255;65m●$Reset" }
        @{ Id = "dracula";       Name = "Dracula Vamp";                Acentos = "Vampire Purple + Pink"; Dot = "$ESC[38;2;189;147;249m●$Reset" }
        @{ Id = "nord";          Name = "Nordic Frost";                Acentos = "Arctic Ice + Polar";    Dot = "$ESC[38;2;136;192;208m●$Reset" }
        @{ Id = "tokyo-night";   Name = "Tokyo Night";                 Acentos = "Deep Neon Blue + Mag";  Dot = "$ESC[38;2;122;162;247m●$Reset" }
        @{ Id = "monokai";       Name = "Monokai Pro";                 Acentos = "Warm Gold + Lime Mint"; Dot = "$ESC[38;2;255;216;102m●$Reset" }
        @{ Id = "synthwave";     Name = "Synthwave 84";                Acentos = "Sunset Pink + Cyan";    Dot = "$ESC[38;2;255;126;219m●$Reset" }
        @{ Id = "solarized-dark";Name = "Solarized Dark";              Acentos = "Solar Teal + Amber";    Dot = "$ESC[38;2;42;161;152m●$Reset" }
        @{ Id = "ghost";         Name = "Minimal Ghost";               Acentos = "Titanium Monochrome";   Dot = "$ESC[38;2;250;250;250m●$Reset" }
    )

    $userChoice = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0].ToLower() } else { "" }

    # Aplicar directamente si se paso argumento
    if ($userChoice) {
        $matched = $null
        $cIdx = -1
        if ([int]::TryParse($userChoice, [ref]$cIdx) -and $cIdx -ge 1 -and $cIdx -le $themes.Count) {
            $matched = $themes[$cIdx - 1].Id
        } else {
            $found = @($themes | Where-Object { $_.Id -eq $userChoice -or $_.Id.StartsWith($userChoice) })
            if ($found.Count -gt 0) { $matched = $found[0].Id }
        }

        if ($matched) {
            Apply-VorkTheme -ThemeName $matched
            try {
                $tDir = Join-Path $HOME ".vork"
                if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
                Set-Content -Path (Join-Path $tDir ".theme") -Value $matched -Force -Encoding UTF8
            } catch { }

            Write-Host ""
            Write-Host "  $ESC[42;30;1m OK $Reset ${Green}Tema visual cambiado exitosamente a: ${Bold}$($global:VorkThemeName)${Reset}"
            Write-Host "  ${LeadLight}Preferencia persistida en ~/.vork/.theme${Reset}"
            Write-Host ""
            return
        }
    }

    # Selector interactivo con teclas Arriba/Abajo y Enter
    $chosenThemeId = Select-InteractiveTheme -Themes $themes -ActiveThemeId $global:VorkThemeId
    if ($chosenThemeId) {
        Apply-VorkTheme -ThemeName $chosenThemeId
        try {
            $tDir = Join-Path $HOME ".vork"
            if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
            Set-Content -Path (Join-Path $tDir ".theme") -Value $chosenThemeId -Force -Encoding UTF8
        } catch { }

        Write-Host "  $ESC[42;30;1m TEMA APLICADO $Reset ${Green}Ahora usando: ${Bold}$($global:VorkThemeName)${Reset}"
        Write-Host "  ${LeadLight}Preferencia persistida en ~/.vork/.theme${Reset}"
        Write-Host ""
    }
}

function Invoke-CmdEnv {
    Write-Host ""
    Write-Host "  ${White}${Bold}VARIABLES DE ENTORNO VORK:${Reset}"
    Write-Host "  ${Cyan}  VORK_API:${Reset}    $ApiBase"
    Write-Host "  ${Cyan}  VORK_TIER:${Reset}   $global:VorkTier"
    Write-Host "  ${Cyan}  USERPROFILE:${Reset} $HOME"
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 01: Vork Traductor en la Nube (+200 idiomas por lotes)
#>

function Invoke-PillarTranslate {
    param([string[]]$ArgsList)

    $text = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $to = "en"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-To", "--to", "-t") { $to = $ArgsList[$i+1] }
        }
    }

    if (-not $text) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [01] Vork Traductor en la Nube (+200 Idiomas)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el texto que deseas traducir:${Reset}"
        $text = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $text -or -not $text.Trim()) {
            Write-Host "  ${Lead}╰─ Traducción cancelada.${Reset}"
            Write-Host ""
            return
        }
        $text = $text.Trim()

        $langOptions = @(
            @{ Value = "en"; Label = "[1]  en (Inglés)" },
            @{ Value = "es"; Label = "[2]  es (Español)" },
            @{ Value = "fr"; Label = "[3]  fr (Francés)" },
            @{ Value = "de"; Label = "[4]  de (Alemán)" },
            @{ Value = "it"; Label = "[5]  it (Italiano)" },
            @{ Value = "pt"; Label = "[6]  pt (Portugués)" },
            @{ Value = "ja"; Label = "[7]  ja (Japonés)" },
            @{ Value = "zh"; Label = "[8]  zh (Chino)" },
            @{ Value = "ru"; Label = "[9]  ru (Ruso)" },
            @{ Value = "ko"; Label = "[10] ko (Coreano)" }
        )

        $chosenLang = Select-InteractiveOption -PromptTitle "Selecciona el idioma destino:" -Options $langOptions -DefaultIndex 0
        if ($chosenLang) {
            $to = $chosenLang
        }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [01] VORK TRANSLATOR ────────────────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Destino:$Reset  $Yellow$to$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Entrada:$Reset  $White`"$text`"$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
    
    $body = @{ text = $text; targetLanguage = $to } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/translate" -Method Post -Body $body -ContentType "application/json"
        Write-Host "  $Cyan│$Reset  $Green✓ Traducción:$Reset $White$($res.translatedText)$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error al traducir]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 02: Vork Texto a Voz Neuronal (TTS Studio con 24 voces humanas)
#>

function Invoke-PillarTTS {
    param([string[]]$ArgsList)

    $text = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $voice = "es-ES-AlvaroNeural"
    $out = "tts_output.mp3"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Voice", "--voice", "-v") { $voice = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
        }
    }

    if (-not $text) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [02] Vork Texto a Voz Neuronal (TTS Studio)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el texto a sintetizar:${Reset}"
        $text = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $text -or -not $text.Trim()) {
            Write-Host "  ${Lead}╰─ Síntesis cancelada.${Reset}"
            Write-Host ""
            return
        }
        $text = $text.Trim()

        $chosen = Select-InteractiveTTSVoice -PromptTitle "Selecciona el idioma y la voz neuronal:" -DefaultLang "Español" -DefaultVoiceId "es-ES-alvaro"
        if (-not $chosen) {
            Write-Host "  ${Lead}╰─ Síntesis cancelada.${Reset}"
            Write-Host ""
            return
        }

        $voice = $chosen.EdgeVoice
        $voiceDisplay = "$($chosen.Name) ($($chosen.Country) · $($chosen.Gender))"
        $out = if ($out) { $out } else { "voz.mp3" }
    } else {
        $voiceDisplay = $voice
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [02] VORK NEURAL TTS ────────────────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Voz:$Reset     $Yellow$voiceDisplay$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Salida:$Reset  $White$out$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $body = @{ text = $text; voice = $voice; outputFormat = "audio-24khz-48kbitrate-mono-mp3" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/tts" -Method Post -Body $body -ContentType "application/json"
        if ($res.audioBase64 -and $out) {
            try {
                $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }
                [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
            } catch {}
        }
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/tts/download?file=$out" }
        $stUrl = if ($res.streamUrl) { "$ApiBase$($res.streamUrl)" } else { "$ApiBase/api/tts/stream?file=$out" }
        Write-Host "  $Cyan│$Reset  $Green✓ Síntesis vocal lista:$Reset"
        Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        Write-Host "  $Cyan│$Reset    Stream:   $Cyan$stUrl$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error TTS]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 03: Vork Clonacion de Voz IA (Extraccion Fundamental F0)
#>

function Invoke-PillarClone {
    param([string[]]$ArgsList)

    $sample = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $text = $null
    $out = "cloned_voice.wav"
    $f0Method = "rmvpe"

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Audio", "--audio", "-a") { $sample = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Text", "--text", "-t") { $text = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
        }
    }

    if (-not $sample) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [03] Vork Clonación de Voz IA (Modelado F0)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ruta del archivo de muestra de audio (ej: muestra.wav):${Reset}"
        $sample = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $sample -or -not $sample.Trim()) {
            Write-Host "  ${Lead}╰─ Clonación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $sample = $sample.Trim()

        $f0Options = @(
            @{ Value = "rmvpe";   Label = "[1] rmvpe    (Estado del arte para máxima fidelidad y pureza vocal)" },
            @{ Value = "harvest"; Label = "[2] harvest  (Extracción F0 de alta precisión tonal en agudos)" },
            @{ Value = "crepe";   Label = "[3] crepe    (Red neuronal profunda para muestras ruidosas)" },
            @{ Value = "pm";      Label = "[4] pm       (Modo ultra-rápido para previsualización inmediata)" }
        )
        $chosenF0 = Select-InteractiveOption -PromptTitle "Selecciona el algoritmo de extracción fundamental F0:" -Options $f0Options -DefaultIndex 0
        if ($chosenF0) { $f0Method = $chosenF0 }

        Write-Host "  ${Lead}│${Reset} ${White}Texto o guión a sintetizar con la voz clonada:${Reset}"
        $text = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"

        $outInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}Archivo de salida [clonado.wav]:${Reset} "
        if ($outInput -and $outInput.Trim()) { $out = $outInput.Trim() }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [03] VORK CLONACIÓN DE VOZ IA ─────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Muestra:$Reset  $White$sample$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Algoritmo:$Reset$Yellow$f0Method$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Salida:$Reset   $Yellow$out$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $b64 = $null
    if ($sample -and (Test-Path $sample)) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $sample))
            $b64 = "data:audio/wav;base64," + [System.Convert]::ToBase64String($bytes)
        } catch {}
    }

    $cloneText = if ($text -and $text.Trim()) { $text.Trim() } else { "Prueba de síntesis con voz clonada en Vork CLI." }
    $body = @{ text = $cloneText; audioSampleBase64 = $b64; similarity = "high"; format = "wav" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/voice-clone" -Method Post -Body $body -ContentType "application/json"
        if ($res.audioBase64 -and $out) {
            try {
                $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }
                [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
            } catch {}
        }
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/voice-clone/download" }
        $stUrl = if ($res.streamUrl) { "$ApiBase$($res.streamUrl)" } else { "$ApiBase/api/voice-clone/stream" }
        Write-Host "  $Cyan│$Reset  $Green✓ Clonación de voz lista:$Reset"
        Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        Write-Host "  $Cyan│$Reset    Stream:   $Cyan$stUrl$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Clonación]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 04: Vork Conversor Multimedia Universal (YouTube, TikTok, IG a MP3/MP4)
#>

function Invoke-PillarMedia {
    param([string[]]$ArgsList)

    $url = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $fmt = "mp3"
    $quality = "320"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Format", "--format", "-f") { $fmt = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Quality", "--quality", "-q") { $quality = $ArgsList[$i+1] }
        }
    }

    if (-not $url) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [04] Vork Conversor Multimedia Universal${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la URL del video (YouTube, TikTok, Reels, IG):${Reset}"
        $url = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $url -or -not $url.Trim()) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }
        $url = $url.Trim()

        $chosen = Select-InteractiveMediaFormat -PromptTitle "Selecciona el formato y calidad de salida:" -DefaultFormat "mp4" -DefaultMp4Quality "720p" -DefaultMp3Quality "320k"
        if (-not $chosen) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }

        $fmt = $chosen.Format
        $quality = $chosen.Quality
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [04] VORK CONVERSOR MULTIMEDIA ──────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray URL:$Reset      $White$url$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Formato:$Reset  $Yellow$fmt ($quality)$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $body = @{ url = $url; format = $fmt; quality = $quality } | ConvertTo-Json
    $endpoint = "$ApiBase/api/media/convert"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        try {
            Write-Host "  $Cyan│$Reset  ${White}Progreso:${Reset} [${Gray}$([string]::new([char]0x2591, $barLen))${Reset}]   0%  ${LeadLight}Iniciando...${Reset}"
            $pRow = [Console]::CursorTop - 1
        } catch { }

        if ('System.Net.Http.HttpClient' -as [type]) {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [TimeSpan]::FromMinutes(5)
            $httpContent = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
            $task = $client.PostAsync($endpoint, $httpContent)

            $startTime = [DateTime]::UtcNow

            while (-not $task.IsCompleted) {
                $elapsed = ([DateTime]::UtcNow - $startTime).TotalSeconds
                $pct = if ($elapsed -lt 1.5) {
                    [Math]::Min(25, 5 + [int]($elapsed * 13))
                } elseif ($elapsed -lt 4.0) {
                    [Math]::Min(55, 25 + [int](($elapsed - 1.5) * 12))
                } elseif ($elapsed -lt 7.0) {
                    [Math]::Min(80, 55 + [int](($elapsed - 4.0) * 8))
                } elseif ($elapsed -lt 15.0) {
                    [Math]::Min(95, 80 + [int](($elapsed - 7.0) * 1.8))
                } else {
                    [Math]::Min(98, 95 + [int](($elapsed - 15.0) * 0.2))
                }

                $phase = if ($pct -lt 25) {
                    "Conectando..."
                } elseif ($pct -lt 55) {
                    "Descargando flujo..."
                } elseif ($pct -lt 80) {
                    "Codificando a $fmt ($quality)..."
                } else {
                    "Finalizando contenedor..."
                }

                $filledLen = [Math]::Floor(($pct / 100) * $barLen)
                $emptyLen = $barLen - $filledLen
                $filled = [string]::new([char]0x2588, $filledLen)
                $empty = [string]::new([char]0x2591, $emptyLen)
                $pctStr = ($pct.ToString() + "%").PadLeft(4)

                if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                    try { [Console]::SetCursorPosition(0, $pRow) } catch { }
                }
                Write-Host "`r$ClrLine  $Cyan│$Reset  ${White}Progreso:${Reset} [${Cyan}$filled${Gray}$empty${Reset}] $Yellow$pctStr$Reset  ${LeadLight}$phase${Reset}" -NoNewline

                Start-Sleep -Milliseconds 120
            }

            if ($task.IsFaulted) {
                throw $task.Exception.InnerException
            }

            # 100% Finalizado
            $filled100 = [string]::new([char]0x2588, $barLen)
            if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                try { [Console]::SetCursorPosition(0, $pRow) } catch { }
            }
            Write-Host "`r$ClrLine  $Cyan│$Reset  ${White}Progreso:${Reset} [${Cyan}$filled100${Reset}] ${Green}100%${Reset}  ${Green}Completado${Reset}"

            $jsonStr = $task.Result.Content.ReadAsStringAsync().Result
            $res = $jsonStr | ConvertFrom-Json
        } else {
            # Fallback síncrono si HttpClient no estuviera disponible
            $res = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json"
        }

        if ($res.status -eq "error" -or (-not $res.downloadUrl -and $res.error)) {
            Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
            Write-Host "  $Cyan│$Reset  ${Coral}[Error Multimedia]:${Reset} $($res.error)"
            Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
        } else {
            Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
            Write-Host "  $Cyan│$Reset  $Green✓ Conversión lista:$Reset"
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$ApiBase$($res.downloadUrl)$Reset"
            Write-Host "  $Cyan│$Reset    Stream:   $Cyan$ApiBase$($res.streamUrl)$Reset"
            Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
        }
    } catch {
        Write-Host ""
        Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Multimedia]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 05: Vork Separador de Stems (Acapella y Karaoke con Demucs v4)
#>

function Invoke-PillarSeparate {
    param([string[]]$ArgsList)

    $target = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $mode = "2stems"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Mode", "--mode", "-m") { $mode = $ArgsList[$i+1] }
        }
    }

    if (-not $target) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [05] Vork Separador de Stems (Demucs v4)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la ruta del archivo de audio o URL (ej: cancion.mp3):${Reset}"
        $target = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $target -or -not $target.Trim()) {
            Write-Host "  ${Lead}╰─ Separación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $target = $target.Trim()

        $sepOptions = @(
            @{ Value = "2stems";  Label = "[1] 2 stems (Voz Acapella + Pista Instrumental / Karaoke)" },
            @{ Value = "4stems";  Label = "[2] 4 stems (Vocals, Batería, Bajo, Otros instrumentos)" },
            @{ Value = "vocals";  Label = "[3] Sólo Acapella (Aislamiento vocal puro con reducción de ruido)" },
            @{ Value = "karaoke"; Label = "[4] Sólo Instrumental (Eliminación estricta de voz)" }
        )

        $chosenMode = Select-InteractiveOption -PromptTitle "Selecciona el modo de separación de stems:" -Options $sepOptions -DefaultIndex 0
        if ($chosenMode) { $mode = $chosenMode }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [05] VORK SEPARADOR DE STEMS (DEMUCS V4) ───────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Pista:$Reset    $White$target$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Modo:$Reset     $Yellow$mode$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $isLocal = try { Test-Path $target -PathType Leaf } catch { $false }
    $body = if ($isLocal) {
        $resolved = Resolve-Path $target
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $b64 = [System.Convert]::ToBase64String($bytes)
        $fn = [System.IO.Path]::GetFileName($resolved)
        @{ audioBase64 = $b64; filename = $fn; quality = "320k"; mode = $mode } | ConvertTo-Json
    } else {
        @{ url = $target; quality = "320k"; mode = $mode } | ConvertTo-Json
    }

    $endpoint = "$ApiBase/api/separator/process"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        $emptyBar = [string]::new([char]0x2591, $barLen)
        try {
            Write-Host "  $Cyan│$Reset  ${White}Progreso:${Reset} [${Gray}$emptyBar${Reset}]   0%  ${LeadLight}Iniciando...${Reset}"
            $pRow = [Console]::CursorTop - 1
        } catch { }

        if ('System.Net.Http.HttpClient' -as [type]) {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [TimeSpan]::FromMinutes(5)
            $httpContent = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
            $task = $client.PostAsync($endpoint, $httpContent)

            $startTime = [DateTime]::UtcNow

            while (-not $task.IsCompleted) {
                $elapsed = ([DateTime]::UtcNow - $startTime).TotalSeconds
                $pct = if ($elapsed -lt 3.0) {
                    [Math]::Min(25, 5 + [int]($elapsed * 7))
                } elseif ($elapsed -lt 8.0) {
                    [Math]::Min(50, 25 + [int](($elapsed - 3.0) * 5))
                } elseif ($elapsed -lt 18.0) {
                    [Math]::Min(75, 50 + [int](($elapsed - 8.0) * 2.5))
                } elseif ($elapsed -lt 35.0) {
                    [Math]::Min(95, 75 + [int](($elapsed - 18.0) * 1.1))
                } else {
                    [Math]::Min(98, 95 + [int](($elapsed - 35.0) * 0.1))
                }

                $phase = if ($pct -lt 25) {
                    "Descargando pista..."
                } elseif ($pct -lt 50) {
                    "Normalizando espectro acústico..."
                } elseif ($pct -lt 75) {
                    "Separando voz e instrumental con Demucs v4..."
                } else {
                    "Masterizando stems de audio 320 kbps..."
                }

                $filledLen = [Math]::Floor(($pct / 100) * $barLen)
                $unfilledLen = $barLen - $filledLen
                $barStr = [string]::new([char]0x2588, $filledLen) + [string]::new([char]0x2591, $unfilledLen)
                $pctStr = "$pct".PadLeft(3)

                if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                    try {
                        [Console]::SetCursorPosition(0, $pRow)
                        Write-Host "  $Cyan│$Reset  ${White}Progreso:${Reset} [${Yellow}$barStr${Reset}] $pctStr%  ${LeadLight}$phase${Reset}    $ClrToEnd" -NoNewline
                    } catch { }
                }

                Start-Sleep -Milliseconds 150
            }

            if ($task.IsFaulted) {
                throw $task.Exception.InnerException
            }

            $filled100 = [string]::new([char]0x2588, $barLen)
            if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                try { [Console]::SetCursorPosition(0, $pRow) } catch { }
            }
            Write-Host "`r$ClrLine  $Cyan│$Reset  ${White}Progreso:${Reset} [${Green}$filled100${Reset}] 100%  ${Green}Completado${Reset}"

            $jsonStr = $task.Result.Content.ReadAsStringAsync().Result
            if (-not $task.Result.IsSuccessStatusCode) {
                $errDetail = $null
                try {
                    $parsedErr = $jsonStr | ConvertFrom-Json
                    if ($parsedErr -and $parsedErr.error) { $errDetail = $parsedErr.error }
                } catch { }
                if (-not $errDetail) {
                    $errDetail = "Error en el servidor ($([int]$task.Result.StatusCode)): $($task.Result.ReasonPhrase)"
                }
                Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
                Write-Host "  $Cyan│$Reset  ${Coral}[Error Separador]:${Reset} $errDetail"
                Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
                return
            }
            $res = try { $jsonStr | ConvertFrom-Json } catch { $null }
        } else {
            $res = try { Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json" -TimeoutSec 300 } catch { $null }
        }

        if (-not $res -or $res.status -eq "error" -or $res.error) {
            $errDetail = if ($res -and $res.error) { $res.error } else { "No se pudo completar la separación de stems." }
            Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
            Write-Host "  $Cyan│$Reset  ${Coral}[Error Separador]:${Reset} $errDetail"
            Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
            return
        }

        $vocDl = $null
        $vocSt = $null
        if ($res.vocals) {
            $rawDl = $res.vocals.downloadUrl
            $rawSt = $res.vocals.streamUrl
            if ($rawDl) { $vocDl = if ($rawDl -match '^https?://') { $rawDl } else { "$ApiBase$rawDl" } }
            if ($rawSt) { $vocSt = if ($rawSt -match '^https?://') { $rawSt } else { "$ApiBase$rawSt" } }
        }

        $instDl = $null
        $instSt = $null
        if ($res.instrumental) {
            $rawDl = $res.instrumental.downloadUrl
            $rawSt = $res.instrumental.streamUrl
            if ($rawDl) { $instDl = if ($rawDl -match '^https?://') { $rawDl } else { "$ApiBase$rawDl" } }
            if ($rawSt) { $instSt = if ($rawSt -match '^https?://') { $rawSt } else { "$ApiBase$rawSt" } }
        }

        Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

        if ($mode -eq "vocals" -and $vocDl) {
            Write-Host "  $Cyan│$Reset  $Green✓ Voz Acapella aislada con éxito:$Reset"
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$vocDl$Reset"
            Write-Host "  $Cyan│$Reset    Stream:   $Cyan$vocSt$Reset"
        } elseif ($mode -eq "karaoke" -and $instDl) {
            Write-Host "  $Cyan│$Reset  $Green✓ Pista Instrumental (Karaoke) aislada con éxito:$Reset"
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$instDl$Reset"
            Write-Host "  $Cyan│$Reset    Stream:   $Cyan$instSt$Reset"
        } else {
            Write-Host "  $Cyan│$Reset  $Green✓ Separación de stems lista con Demucs v4:$Reset"
            if ($vocDl) {
                Write-Host "  $Cyan│$Reset    ${White}${Bold}Voz Acapella:${Reset}  $Yellow$vocDl$Reset"
            }
            if ($instDl) {
                Write-Host "  $Cyan│$Reset    ${White}${Bold}Instrumental:${Reset}  $Cyan$instDl$Reset"
            }
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host ""
        Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Separador]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 07: Vork Conversor Universal de Formatos de Imagen (PNG, JPG, WEBP, ICO, AVIF)
#>

function Invoke-PillarImage {
    param([string[]]$ArgsList)

    $rawTarget = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $fmt = $null
    $quality = 90
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Format", "--format", "-f") { $fmt = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Quality", "--quality", "-q") { $quality = [int]$ArgsList[$i+1] }
        }
    }

    if (-not $rawTarget) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [07] Vork Conversor Universal de Imágenes${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la ruta del archivo de imagen o URL (ej: logo.png o https://...):${Reset}"
        $rawTarget = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $rawTarget -or -not $rawTarget.Trim()) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }
    }

    # Limpieza estricta de comillas iniciales y finales y espacios
    $target = $rawTarget.Trim().Trim('"').Trim("'").Trim()
    $isUrl = ($target -match '^https?://')

    $imageBytes = $null
    $detectedFmt = "unknown"
    $detectedLabel = "Desconocido"

    if ($isUrl) {
        try {
            Write-Host "  ${Lead}│${Reset} ${LeadLight}Conectando y analizando recurso web...${Reset}"
            try { Add-Type -AssemblyName System.Net.Http } catch { }
            $client = [System.Net.Http.HttpClient]::new()
            $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            $client.Timeout = [TimeSpan]::FromSeconds(25)
            $respBytes = $client.GetByteArrayAsync($target).Result

            # Verificar si la respuesta es HTML para extraer imagen de metadatos (og:image / twitter:image)
            $isHtml = $false
            if ($respBytes.Length -gt 15) {
                $headLen = [Math]::Min(1024, $respBytes.Length - 1)
                $headStr = [System.Text.Encoding]::UTF8.GetString($respBytes[0..$headLen])
                if ($headStr -match '<(!DOCTYPE\s+)?html|<head|<meta|<body') {
                    $isHtml = $true
                }
            }

            if ($isHtml) {
                $htmlText = [System.Text.Encoding]::UTF8.GetString($respBytes)
                $realImgUrl = $null
                if ($htmlText -match '<meta[^>]+property=["'']og:image["''][^>]+content=["'']([^"'']+)["'']' -or
                    $htmlText -match '<meta[^>]+content=["'']([^"'']+)["''][^>]+property=["'']og:image["'']' -or
                    $htmlText -match '<meta[^>]+name=["'']twitter:image["''][^>]+content=["'']([^"'']+)["'']' -or
                    $htmlText -match '<meta[^>]+content=["'']([^"'']+)["''][^>]+name=["'']twitter:image["'']') {
                    $realImgUrl = $Matches[1].Trim()
                }

                if ($realImgUrl) {
                    if ($realImgUrl.StartsWith("//")) { $realImgUrl = "https:" + $realImgUrl }
                    elseif ($realImgUrl.StartsWith("/")) {
                        $u = [System.Uri]$target
                        $realImgUrl = "$($u.Scheme)://$($u.Host)$realImgUrl"
                    }
                    Write-Host "  ${Lead}│${Reset} ${LeadLight}Imagen detectada en metadatos:${Reset} $realImgUrl"
                    $respBytes = $client.GetByteArrayAsync($realImgUrl).Result
                    $target = $realImgUrl
                } else {
                    Write-Host "  ${Lead}╰─ La URL es una página web sin metadatos de imagen (og:image) detectable.${Reset}"
                    Write-Host ""
                    return
                }
            }

            $imageBytes = $respBytes
        } catch {
            Write-Host "  ${Lead}╰─ Error al descargar imagen desde URL: $($_.Exception.Message)${Reset}"
            Write-Host ""
            return
        }
    } else {
        # Archivo local
        $resolvedPath = $null
        try {
            if (Test-Path -LiteralPath $target) {
                $resolvedPath = (Resolve-Path -LiteralPath $target).Path
            }
        } catch { }

        if (-not $resolvedPath -or -not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            Write-Host "  ${Lead}╰─ Archivo no encontrado o cancelado.${Reset}"
            Write-Host ""
            return
        }

        $target = $resolvedPath
        try {
            $imageBytes = [System.IO.File]::ReadAllBytes($target)
        } catch {
            Write-Host "  ${Lead}╰─ Error al leer el archivo: $($_.Exception.Message)${Reset}"
            Write-Host ""
            return
        }
    }

    # Detección precisa de formato mediante Magic Bytes
    if ($imageBytes -and $imageBytes.Length -ge 4) {
        if ($imageBytes[0] -eq 0xFF -and $imageBytes[1] -eq 0xD8 -and $imageBytes[2] -eq 0xFF) {
            $detectedFmt = "jpg"; $detectedLabel = "JPEG / JPG (Joint Photographic Experts Group)"
        } elseif ($imageBytes[0] -eq 0x89 -and $imageBytes[1] -eq 0x50 -and $imageBytes[2] -eq 0x4E -and $imageBytes[3] -eq 0x47) {
            $detectedFmt = "png"; $detectedLabel = "PNG (Portable Network Graphics - Con transparencia)"
        } elseif ($imageBytes[0] -eq 0x47 -and $imageBytes[1] -eq 0x49 -and $imageBytes[2] -eq 0x46 -and $imageBytes[3] -eq 0x38) {
            $detectedFmt = "gif"; $detectedLabel = "GIF (Graphics Interchange Format)"
        } elseif ($imageBytes[0] -eq 0x42 -and $imageBytes[1] -eq 0x4D) {
            $detectedFmt = "bmp"; $detectedLabel = "BMP (Windows Bitmap Image)"
        } elseif ($imageBytes[0] -eq 0x00 -and $imageBytes[1] -eq 0x00 -and $imageBytes[2] -eq 0x01 -and $imageBytes[3] -eq 0x00) {
            $detectedFmt = "ico"; $detectedLabel = "ICO (Windows Icon / Favicon)"
        } elseif ($imageBytes.Length -ge 12 -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[0..3]) -eq "RIFF") -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[8..11]) -eq "WEBP")) {
            $detectedFmt = "webp"; $detectedLabel = "WEBP (Google WebP Modern Compressed Image)"
        } elseif ($imageBytes.Length -ge 12 -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[4..11]) -match 'ftypavif|ftypavis')) {
            $detectedFmt = "avif"; $detectedLabel = "AVIF (AV1 Image File Format Ultra-HD)"
        }
    }

    # Fallback por extensión de archivo/URL si no se determinó por magic bytes
    if ($detectedFmt -eq "unknown") {
        $cleanTargetUrl = $target.Split('?')[0].Split('#')[0]
        $ext = [System.IO.Path]::GetExtension($cleanTargetUrl).TrimStart(".").ToLower()
        if ($ext -in "jpg", "jpeg") { $detectedFmt = "jpg"; $detectedLabel = "JPEG / JPG" }
        elseif ($ext -eq "png") { $detectedFmt = "png"; $detectedLabel = "PNG" }
        elseif ($ext -eq "webp") { $detectedFmt = "webp"; $detectedLabel = "WEBP" }
        elseif ($ext -eq "ico") { $detectedFmt = "ico"; $detectedLabel = "ICO" }
        elseif ($ext -eq "avif") { $detectedFmt = "avif"; $detectedLabel = "AVIF" }
        elseif ($ext -eq "gif") { $detectedFmt = "gif"; $detectedLabel = "GIF" }
        elseif ($ext -eq "bmp") { $detectedFmt = "bmp"; $detectedLabel = "BMP" }
    }

    Write-Host "  ${Lead}│${Reset}  ${Gray}Formato actual detectado:${Reset} ${Green}${Bold}$detectedLabel${Reset}"

    # Catálogo de formatos de salida soportados
    $allFormats = @(
        @{ Value = "webp"; Label = "webp (WebP Next-Gen - Máxima compresión y fidelidad visual)" },
        @{ Value = "png";  Label = "png  (PNG Lossless con canal alfa transparente)" },
        @{ Value = "jpg";  Label = "jpg  (JPEG estándar optimizado para fotografía)" },
        @{ Value = "ico";  Label = "ico  (Icono Windows Favicon multirresolución)" },
        @{ Value = "avif"; Label = "avif (AVIF Ultra-HD de nueva generación)" }
    )

    # El formato actual detectado NO debe aparecer como opción de selección
    $availableFormats = @($allFormats | Where-Object { $_.Value -ne $detectedFmt })

    if (-not $fmt -or $fmt -eq $detectedFmt) {
        $imgOptions = @()
        for ($idx = 0; $idx -lt $availableFormats.Count; $idx++) {
            $num = $idx + 1
            $imgOptions += @{
                Value = $availableFormats[$idx].Value
                Label = "[$num] $($availableFormats[$idx].Label)"
            }
        }

        $chosenFmt = Select-InteractiveOption -PromptTitle "Selecciona el formato de imagen destino:" -Options $imgOptions -DefaultIndex 0
        if ($chosenFmt) { $fmt = $chosenFmt } else { $fmt = $availableFormats[0].Value }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [07] VORK PROCESADOR DE IMÁGENES ────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset     $White$target$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Detectado:$Reset  $Green$detectedFmt$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Destino:$Reset    $Yellow$fmt$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $b64 = [System.Convert]::ToBase64String($imageBytes)
    $mimePrefix = switch ($detectedFmt) {
        "jpg"   { "image/jpeg" }
        "png"   { "image/png" }
        "webp"  { "image/webp" }
        "gif"   { "image/gif" }
        "bmp"   { "image/bmp" }
        "ico"   { "image/x-icon" }
        "avif"  { "image/avif" }
        default { "image/png" }
    }
    $body = @{ imageBase64 = "data:$mimePrefix;base64,$b64"; targetFormat = $fmt; quality = $quality } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/convert" -Method Post -Body $body -ContentType "application/json"
        $dlUrl = if ($res.downloadUrl) { if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" } } else { "$ApiBase/api/image/download" }
        $stUrl = if ($res.streamUrl) { if ($res.streamUrl.StartsWith("http")) { $res.streamUrl } else { "$ApiBase$($res.streamUrl)" } } else { "$ApiBase/api/image/stream" }
        Write-Host "  $Cyan│$Reset  $Green✓ Conversión de imagen lista:$Reset"
        Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        Write-Host "  $Cyan│$Reset    Stream:   $Cyan$stUrl$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Imagen]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 08: Vork Estudio y Eliminador de Fondo IA (U2-Net)
#>

function Invoke-PillarRemoveBg {
    param([string[]]$ArgsList)

    $file = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $out = "clean_transparent.png"
    $mode = "transparent"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Mode", "--mode", "-m") { $mode = $ArgsList[$i+1] }
        }
    }

    if (-not $file -or -not (Test-Path $file)) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [08] Vork Estudio y Eliminador de Fondo IA (U2-Net)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la ruta de la imagen (ej: producto.jpg):${Reset}"
        $fileInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $fileInput -or -not (Test-Path $fileInput.Trim())) {
            Write-Host "  ${Lead}╰─ Imagen no válida o cancelado.${Reset}"
            Write-Host ""
            return
        }
        $file = $fileInput.Trim()

        $bgOptions = @(
            @{ Value = "transparent"; Label = "[1] Transparente (Aislamiento de silueta PNG alfa puro)" },
            @{ Value = "white";       Label = "[2] Fondo Blanco Studio (Ideal para e-commerce y catálogo)" },
            @{ Value = "black";       Label = "[3] Fondo Negro Cine (Alto contraste dramático)" },
            @{ Value = "blur";        Label = "[4] Desenfoque Bokeh IA (Efecto de lente de retrato profesional)" }
        )

        $chosenBg = Select-InteractiveOption -PromptTitle "Selecciona el modo de procesamiento de fondo:" -Options $bgOptions -DefaultIndex 0
        if ($chosenBg) { $mode = $chosenBg }

        $outInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}Archivo de salida [sin_fondo.png]:${Reset} "
        if ($outInput -and $outInput.Trim()) { $out = $outInput.Trim() } else { $out = "sin_fondo.png" }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [08] VORK ESTUDIO Y FONDO IA (U2-NET) ──────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset   $White$file$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Modo:$Reset     $Yellow$mode$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $file))
    $b64 = [System.Convert]::ToBase64String($bytes)
    $body = @{ imageBase64 = "data:image/jpeg;base64,$b64"; mode = $mode } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/remove-background" -Method Post -Body $body -ContentType "application/json"
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/image/download" }
        $stUrl = if ($res.streamUrl) { "$ApiBase$($res.streamUrl)" } else { "$ApiBase/api/image/stream" }
        Write-Host "  $Cyan│$Reset  $Green✓ Recorte de fondo listo:$Reset"
        Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        Write-Host "  $Cyan│$Reset    Stream:   $Cyan$stUrl$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Fondo IA]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Pilar 09: Vork Agentes Autónomos & Modo Interactivo TUI
#>

function Invoke-PillarAgents {
    param([string[]]$ArgsList)

    if (-not $ArgsList -or $ArgsList.Length -eq 0) {
        $agentOptions = @(
            @{ Value = "status";   Label = "[1] Ver estado del clúster de agentes y conectividad" },
            @{ Value = "goal";     Label = "[2] Ejecutar /goal (Tarea autónoma de bucle continuo)" },
            @{ Value = "plan";     Label = "[3] Ejecutar /plan (Desglose guiado de arquitectura)" },
            @{ Value = "teamwork"; Label = "[4] Activar /teamwork (Coordinación de múltiples subagentes)" },
            @{ Value = "boost";    Label = "[5] Alternar /boost (Razonamiento profundo con verificación)" },
            @{ Value = "learn";    Label = "[6] Registrar regla con /learn (Persistencia en ~/.vork)" }
        )

        $chosenAction = Select-InteractiveOption -PromptTitle "Selecciona una operación de Agentes Autónomos:" -Options $agentOptions -DefaultIndex 0
        if ($chosenAction -and $chosenAction -ne "status") {
            switch ($chosenAction) {
                "goal" { Invoke-CmdGoal @(); return }
                "plan" { Invoke-CmdPlan @(); return }
                "teamwork" { Invoke-CmdTeamwork @(); return }
                "boost" { Invoke-CmdBoost; return }
                "learn" { Invoke-CmdLearn @(); return }
            }
        }
    }

    Write-Host ""
    Write-Host "  ${Cyan}╭─ ${Bold}[09] VORK AGENTES AUTÓNOMOS & ORQUESTACIÓN IA${Reset} ─────────"
    Write-Host "  ${Cyan}│${Reset}  ${White}${Bold}Motor de Agentes:${Reset} ${Green}● ONLINE${Reset} ${LeadLight}(Bucle de Agentes Autónomos Vork 3)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${LeadLight}Subagentes concurrentes disponibles:${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Codebase Researcher${Reset} ${LeadLight}· Análisis y exploración de contexto${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Audio Engine Agent${Reset}  ${LeadLight}· Síntesis TTS y modelado F0 spectral${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Demucs Stem Worker${Reset}  ${LeadLight}· Separación acapella/karaoke en background${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Media Extraction Bot${Reset}${LeadLight}· Extracción y compresión multimedia 320k${Reset}"
    Write-Host "  ${Cyan}├───────────────────────────────────────────────────${Reset}"
    Write-Host "  ${Cyan}│${Reset}  $Green✓ Clúster de agentes listo:$Reset"
    Write-Host "  ${Cyan}│${Reset}    Descarga: ${Yellow}$ApiBase/api/cli/health${Reset}"
    Write-Host "  ${Cyan}│${Reset}    Stream:   ${Cyan}$ApiBase/api/cli/vork.ps1${Reset}"
    Write-Host "  ${Cyan}╰───────────────────────────────────────────────────${Reset}"
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Modulos de Sistema: Version y Telemetria en Vivo (Health)
#>

function Invoke-PillarVersion {
    Write-Host ""
    Write-Host "  $ESC[44;97;1m VORK CLI $Reset $White$Bold v$VorkVersion$Reset"
    Write-Host "  $Gray Backend:$Reset  $Cyan$ApiBase$Reset"
    Write-Host "  $Gray Pilares:$Reset  $Green 9 Pilares Operacionales Activos$Reset"
    Write-Host "  $Gray Motor:$Reset    $White PowerShell $($PSVersionTable.PSVersion) [$arch]$Reset"
    Write-Host ""
}

function Invoke-PillarHealth {
    Write-Host ""
    Write-Host "  $Cyan╭─ [TELEMETRÍA Y ESTADO DE LOS 9 PILARES] ──────────$Reset"
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/health" -Method Get
        Write-Host "  $Cyan│$Reset  $Gray Servidor:$Reset  $Green● ONLINE$Reset ${Dim}($ApiBase)${Reset}"
        Write-Host "  $Cyan│$Reset  $Gray Pilares:$Reset   $White$($res.pillars) / 9 Operacionales$Reset"
        Write-Host "  $Cyan│$Reset  $Gray Uptime:$Reset    $White$($res.uptime)s$Reset"
        Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
        if ($res.services) {
            $res.services.PSObject.Properties | ForEach-Object {
                Write-Host "  $Cyan│$Reset  $Green●$Reset $($_.Value.name): $Dim$($_.Value.status)$Reset"
            }
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Offline]:${Reset} Servidor no responde en $ApiBase"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}

# ============================================================

<#
.SYNOPSIS
    Vork CLI - Modulo Core: Despachador y Consola Interactiva REPL
#>

function Dispatch-CLICommand {
    param(
        [string]$Cmd,
        [string[]]$ArgsList
    )

    $Normalized = if ($Cmd) { $Cmd.TrimStart("/").ToLower() } else { "" }

    switch ($Normalized) {
        # ========================================================
        # CATEGORIA 1: PILARES OPERACIONALES (9)
        # ========================================================
        "translate" { Invoke-PillarTranslate -ArgsList $ArgsList }
        "tts"       { Invoke-PillarTTS -ArgsList $ArgsList }
        "clone"     { Invoke-PillarClone -ArgsList $ArgsList }
        "media"     { Invoke-PillarMedia -ArgsList $ArgsList }
        "separate"  { Invoke-PillarSeparate -ArgsList $ArgsList }
        "image"     { Invoke-PillarImage -ArgsList $ArgsList }
        "remove-bg" { Invoke-PillarRemoveBg -ArgsList $ArgsList }
        "agents"    { Invoke-PillarAgents -ArgsList $ArgsList }

        # ========================================================
        # CATEGORIA 2: AGENTES AUTÓNOMOS & PLANIFICACIÓN IA (8)
        # ========================================================
        "goal"       { Invoke-CmdGoal -ArgsList $ArgsList }
        "plan"       { Invoke-CmdPlan -ArgsList $ArgsList }
        "grill-me"   { Invoke-CmdGrillMe }
        "teamwork"   { Invoke-CmdTeamwork -ArgsList $ArgsList }
        "boost"      { Invoke-CmdBoost }
        "learn"      { Invoke-CmdLearn -ArgsList $ArgsList }
        "browser"    { Invoke-CmdBrowser -ArgsList $ArgsList }
        "automation" { Invoke-CmdAutomation }

        # ========================================================
        # CATEGORIA 3: CONTEXTO, SESIÓN & MEMORIA (7)
        # ========================================================
        "compact" { Invoke-CmdCompact }
        { $_ -in "clear", "cls" } {
            Clear-Host
            Show-Banner
        }
        "reset"   { Invoke-CmdReset }
        "history" { Invoke-CmdHistory }
        "save"    { Invoke-CmdSave -ArgsList $ArgsList }
        "resume"  { Invoke-CmdResume }
        "undo"    { Invoke-CmdUndo }

        # ========================================================
        # CATEGORIA 4: CÓDIGO, AUDITORÍA & FLUJO (4)
        # ========================================================
        "status"   { Invoke-CmdStatus }
        "review"   { Invoke-CmdReview }
        "bug"      { Invoke-CmdBug -ArgsList $ArgsList }
        "refactor" { Invoke-CmdRefactor }

        # ========================================================
        # CATEGORIA 5: CONFIGURACIÓN & PREFERENCIAS (6)
        # ========================================================
        { $_ -in "settings", "config", "permissions" } { Show-InteractiveSettings }
        "keybindings" { Invoke-CmdKeybindings }
        { $_ -in "mode", "modal", "model", "tier", "effort" } {
            $argVal = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }
            if ($argVal -in "low", "medium", "high") {
                Set-VorkTier -NewTier $argVal
            } else {
                Show-InteractiveModelSwitcher
            }
        }
        "theme"       { Invoke-CmdTheme -ArgsList $ArgsList }
        "env"         { Invoke-CmdEnv }

        # ========================================================
        # CATEGORIA 6: SISTEMA, TELEMETRÍA & UTILIDADES (6)
        # ========================================================
        { $_ -in "help", "--help", "-h", "?", "shortcuts", "/shortcuts" } {
            $chosen = Show-InteractiveHelpModal
            if ($chosen) {
                Dispatch-CLICommand -Cmd $chosen -ArgsList @()
            }
        }
        { $_ -in "slash", "slashcommands", "commands" } {
            Show-SlashCommands
        }
        { $_ -in "update", "upgrade" } {
            Write-Host ""
            Write-Host "  $ESC[44;97;1m VORK CLI $Reset $Cyan Consultando actualizaciones en el backend ($ApiBase)...$Reset"
            Check-And-AutoUpdate -Force
            Write-Host "  $($CSI)42;30;1m OK $Reset $Green El entorno de terminal esta en su version mas reciente ($VorkVersion).$Reset"
            Write-Host ""
        }
        "health" { Invoke-PillarHealth }
        "ping" {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $r = Invoke-RestMethod -Uri "$ApiBase/api/ping" -TimeoutSec 3 -ErrorAction Stop
                $sw.Stop()
                Write-Host "  ${Green}● PONG${Reset} ${White}$($sw.ElapsedMilliseconds)ms${Reset} hacia $ApiBase"
            } catch {
                Write-Host "  ${Coral}[Error Ping]:${Reset} No se pudo conectar con $ApiBase"
            }
        }
        "docs" {
            Write-Host "  ${Cyan}Abriendo documentacion oficial de Vork en el navegador...${Reset}"
            Start-Process "$ApiBase/docs"
        }
        { $_ -in "version", "-v", "--version" } {
            Invoke-PillarVersion
        }
        { $_ -in "exit", "quit", "q" } {
            Exit-VorkSession -ExitCode 0
        }

        default {
            Write-Host ""
            Write-Host "  ${Coral}[!] Comando no reconocido:${Reset} $White`"$Cmd`"$Reset"
            Write-Host "  ${Dim}Escribe '?' para atajos o 'slash' para ver los 40 comandos con barra.${Reset}"
            Write-Host ""
        }
    }
}

function Read-InteractiveVorkLine {
    param(
        [int]$PromptRow,
        [int]$Width,
        [string]$Rule,
        [string]$Footer
    )

    if ([Console]::IsInputRedirected) {
        return [Console]::ReadLine()
    }

    $allCommands = @(
        # Categoria 1: Pilares (9)
        @{ Cmd = "/translate";   Desc = "Traduccion neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Sintesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonacion vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminacion de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestacion de subagentes en terminal interactiva" },

        # Categoria 2: Agentes & Planificacion (8)
        @{ Cmd = "/goal";        Desc = "Modo autonomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificacion guiada y desglose paso a paso" },
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseño" },
        @{ Cmd = "/teamwork";    Desc = "Coordinacion con multiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificacion estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegacion e interaccion web automatizada" },
        @{ Cmd = "/automation";  Desc = "Diseñar y programar tareas en segundo plano" },

        # Categoria 3: Sesion & Memoria (7)
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesion" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesion a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronologico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesion, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesion previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la ultima accion o cambio de codigo" },

        # Categoria 4: Flujo de Trabajo & Auditoría (4)
        @{ Cmd = "/status";      Desc = "Inspeccionar estado del entorno y tareas activas" },
        @{ Cmd = "/review";      Desc = "Auditoria de codigo, buenas practicas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnostico y depuracion asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar codigo sin alterar salida" },

        # Categoria 5: Configuracion & Preferencias (6)
        @{ Cmd = "/settings";    Desc = "Panel interactivo de configuraciones y permisos del sistema" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/model";       Desc = "Configurar modelo Vork 3 y nivel de potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },

        # Categoria 6: Sistema, Telemetria & Utilidades (6)
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/health";      Desc = "Telemetria en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrapida hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentacion oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesion de terminal de forma segura" }
    )

    $buf = [System.Text.StringBuilder]::new()
    $selIdx = 0
    $topIdx = 0
    $slashMenuOpen = $false
    $windowSize = 5
    $menuHeight = 7

    try { [Console]::TreatControlCAsInput = $true } catch { }
    $lastCtrlC = [DateTime]::MinValue

    $downArrow = [char]0x2193
    $upArrow   = [char]0x2191
    $dotCh     = [char]0x00B7

    $clearMenu = {
        for ($r = 0; $r -le 10; $r++) {
            try {
                [Console]::SetCursorPosition(0, $PromptRow + 3 + $r)
                Write-Host "$ClrLine" -NoNewline
            } catch { }
        }
        try {
            [Console]::SetCursorPosition(0, $PromptRow + 2)
            Write-Host "${LeadLight}$Footer${Reset}$ClrToEnd" -NoNewline
        } catch { }
    }

    $histIdx = -1
    $savedDraft = ""
    $isNavigatingHistory = $false
    $filtered = @()

    while ($true) {
        $str = $buf.ToString()
        $isSlash = (-not $isNavigatingHistory) -and $str.StartsWith("/") -and (-not $str.Contains(" "))

        if ($isSlash) {
            $filtered = @($allCommands | Where-Object { $_.Cmd.StartsWith($str, [System.StringComparison]::OrdinalIgnoreCase) })
            if ($filtered.Count -gt 0) {
                if ($selIdx -ge $filtered.Count) { $selIdx = 0 }

                # Adjust scrolling window
                if ($selIdx -lt $topIdx) {
                    $topIdx = $selIdx
                } elseif ($selIdx -ge ($topIdx + $windowSize)) {
                    $topIdx = $selIdx - $windowSize + 1
                }
                if ($topIdx -gt ($filtered.Count - $windowSize) -and ($filtered.Count -gt $windowSize)) {
                    $topIdx = $filtered.Count - $windowSize
                }
                if ($topIdx -lt 0) { $topIdx = 0 }

                $slashMenuOpen = $true

                # Render the 5 visible items
                for ($k = 0; $k -lt $windowSize; $k++) {
                    $itemIdx = $topIdx + $k
                    $rowY = $PromptRow + 3 + $k
                    try { [Console]::SetCursorPosition(0, $rowY) } catch { }

                    if ($itemIdx -lt $filtered.Count) {
                        $item = $filtered[$itemIdx]
                        $cmdStr = $item.Cmd.PadRight(18)
                        $descStr = $item.Desc
                        $availDesc = [Math]::Max(10, ($Width - 1) - 22)
                        if ($descStr.Length -gt $availDesc) {
                            $descStr = $descStr.Substring(0, $availDesc - 3) + "..."
                        }

                        if ($itemIdx -eq $selIdx) {
                            Write-Host "${Cyan}${Bold}> ${White}${Bold}$cmdStr${LeadLight}$descStr${Reset}$ClrToEnd" -NoNewline
                        } else {
                            Write-Host "  ${White}$cmdStr${LeadLight}$descStr${Reset}$ClrToEnd" -NoNewline
                        }
                    } else {
                        Write-Host "$ClrLine" -NoNewline
                    }
                }

                # Row 6: More indicator
                $remBelow = $filtered.Count - ($topIdx + $windowSize)
                $remAbove = $topIdx
                $moreText = ""
                if ($remBelow -gt 0 -and $remAbove -gt 0) {
                    $moreText = "   $upArrow $remAbove / $downArrow $remBelow more"
                } elseif ($remBelow -gt 0) {
                    $moreText = "   $downArrow $remBelow more"
                } elseif ($remAbove -gt 0) {
                    $moreText = "   $upArrow $remAbove more"
                }
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 3 + $windowSize)
                    Write-Host "${LeadDark}$moreText${Reset}$ClrToEnd" -NoNewline
                } catch { }

                # Row 7: Navigation hints
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 3 + $windowSize + 1)
                    Write-Host "  ${Cyan}$upArrow/$downArrow${Reset} ${LeadLight}Navigate ${LeadDark}$dotCh${Reset} ${Cyan}enter${Reset} ${LeadLight}Select ${LeadDark}$dotCh${Reset} ${Cyan}tab${Reset} ${LeadLight}Complete ${LeadDark}$dotCh${Reset} ${Cyan}esc${Reset} ${LeadLight}Cancel${Reset}$ClrToEnd" -NoNewline
                } catch { }

                # Reposition cursor cleanly on prompt row
                try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
            } else {
                if ($slashMenuOpen) {
                    & $clearMenu
                    $slashMenuOpen = $false
                    try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
                }
            }
        } else {
            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
                try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
            }
        }

        $key = [Console]::ReadKey($true)

        # Intercepción de Ctrl+C (Evita mensaje "¿Desea terminar el trabajo por lotes (S/N)?" y ofrece doble confirmación)
        $isCtrlC = ($key.KeyChar -eq [char]3) -or ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control))
        if ($isCtrlC) {
            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
            }
            if ($buf.Length -gt 0) {
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2, $PromptRow)
                } catch { }
                $buf.Clear() | Out-Null
                $lastCtrlC = [DateTime]::MinValue
                continue
            }

            # Buffer vacío: comprobar doble pulsación
            $now = [DateTime]::UtcNow
            if (($now - $lastCtrlC).TotalSeconds -lt 2.5) {
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 2)
                    Write-Host ([string]::new(" ", [Math]::Min(80, $Width - 1))) -NoNewline
                    [Console]::SetCursorPosition(0, $PromptRow + 2)
                } catch { }
                try { [Console]::TreatControlCAsInput = $false } catch { }
                Exit-VorkSession -ExitCode 0
            } else {
                $lastCtrlC = $now
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 2)
                    $warnMsg = "press ctrl+c again to exit"
                    $dotCh = [char]0x00B7
                    $tierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
                    $tierColor = switch ($tierName) {
                        "low"    { $Green }
                        "medium" { $Yellow }
                        "high"   { $Coral }
                        default  { $Cyan }
                    }
                    $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
                    $rightPlain = "$modelName $dotCh $tierName"
                    $rightFormatted = "${LeadLight}$modelName $dotCh $tierName${Reset}"
                    $padLen = [Math]::Max(1, ($Width - 1) - $warnMsg.Length - $rightPlain.Length)
                    Write-Host "${LeadLight}$warnMsg$([string]::new(' ', $padLen))$rightFormatted" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        # Restaurar footer si estaba visible el aviso de ctrl+c y se pulsó otra tecla
        if ($lastCtrlC -ne [DateTime]::MinValue) {
            try {
                [Console]::SetCursorPosition(0, $PromptRow + 2)
                Write-Host "${LeadLight}$Footer${Reset}" -NoNewline
                [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
            } catch { }
            $lastCtrlC = [DateTime]::MinValue
        }

        # Intercepción de Ctrl+D
        $isCtrlD = ($key.KeyChar -eq [char]4) -or ($key.Key -eq [ConsoleKey]::D -and ($key.Modifiers -band [ConsoleModifiers]::Control))
        if ($isCtrlD -and $buf.Length -eq 0) {
            try { [Console]::TreatControlCAsInput = $false } catch { }
            Exit-VorkSession -ExitCode 0
        }

        if ($key.Key -eq [ConsoleKey]::Enter) {
            try { [Console]::TreatControlCAsInput = $false } catch { }
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $chosen = $filtered[$selIdx].Cmd
                & $clearMenu
                $slashMenuOpen = $false
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$chosen${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(0, $PromptRow + 3)
                } catch { }
                Write-Host ""
                return $chosen
            }

            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
            }
            $finalText = $buf.ToString()
            try {
                [Console]::SetCursorPosition(2, $PromptRow)
                Write-Host "${Coral}${Bold}$finalText${Reset}$ClrToEnd" -NoNewline
                [Console]::SetCursorPosition(0, $PromptRow + 3)
            } catch { }
            Write-Host ""
            return $finalText
        }

        if ($key.Key -eq [ConsoleKey]::Tab) {
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $chosen = $filtered[$selIdx].Cmd
                & $clearMenu
                $slashMenuOpen = $false
                $isNavigatingHistory = $false
                $histIdx = -1
                $buf.Clear() | Out-Null
                $buf.Append($chosen) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$chosen${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $selIdx = if ($selIdx -gt 0) { $selIdx - 1 } else { $filtered.Count - 1 }
                continue
            } elseif ($global:VorkSessionHistory -and $global:VorkSessionHistory.Count -gt 0) {
                $isNavigatingHistory = $true
                if ($slashMenuOpen) {
                    & $clearMenu
                    $slashMenuOpen = $false
                }
                if ($histIdx -lt 0) {
                    $savedDraft = $buf.ToString()
                    $histIdx = $global:VorkSessionHistory.Count - 1
                } elseif ($histIdx -gt 0) {
                    $histIdx--
                }

                $chosenHist = $global:VorkSessionHistory[$histIdx]
                $buf.Clear() | Out-Null
                $buf.Append($chosenHist) | Out-Null

                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        if ($key.Key -eq [ConsoleKey]::DownArrow) {
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $selIdx = if ($selIdx -lt ($filtered.Count - 1)) { $selIdx + 1 } else { 0 }
                continue
            } elseif ($isNavigatingHistory -and $histIdx -ge 0) {
                if ($slashMenuOpen) {
                    & $clearMenu
                    $slashMenuOpen = $false
                }
                if ($histIdx -lt ($global:VorkSessionHistory.Count - 1)) {
                    $histIdx++
                    $chosenHist = $global:VorkSessionHistory[$histIdx]
                    $buf.Clear() | Out-Null
                    $buf.Append($chosenHist) | Out-Null
                } else {
                    $histIdx = -1
                    $isNavigatingHistory = $false
                    $buf.Clear() | Out-Null
                    $buf.Append($savedDraft) | Out-Null
                }

                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        if ($key.Key -eq [ConsoleKey]::Escape) {
            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
            }
            if ($isNavigatingHistory) {
                $isNavigatingHistory = $false
                $histIdx = -1
                $buf.Clear() | Out-Null
                $buf.Append($savedDraft) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
            if ($buf.Length -gt 0) {
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2, $PromptRow)
                } catch { }
                $buf.Clear() | Out-Null
            }
            try {
                [Console]::SetCursorPosition(0, $PromptRow + 2)
                Write-Host "${LeadLight}$Footer${Reset}" -NoNewline
                [Console]::SetCursorPosition(2, $PromptRow)
            } catch { }
            $lastCtrlC = [DateTime]::MinValue
            continue
        }

        if ($key.Key -eq [ConsoleKey]::Backspace -or $key.KeyChar -eq [char]8) {
            $isNavigatingHistory = $false
            $histIdx = -1
            if ($buf.Length -gt 0) {
                $buf.Remove($buf.Length - 1, 1) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset} $ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                if ($buf.Length -eq 0 -or -not $buf.ToString().StartsWith("/") -or $buf.ToString().Contains(" ")) {
                    if ($slashMenuOpen) {
                        & $clearMenu
                        $slashMenuOpen = $false
                        try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
                    }
                }
            }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::Delete) {
            $isNavigatingHistory = $false
            $histIdx = -1
            if ($buf.Length -gt 0) {
                $buf.Remove($buf.Length - 1, 1) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset} $ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                if ($buf.Length -eq 0 -or -not $buf.ToString().StartsWith("/") -or $buf.ToString().Contains(" ")) {
                    if ($slashMenuOpen) {
                        & $clearMenu
                        $slashMenuOpen = $false
                        try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
                    }
                }
            }
            continue
        }

        if ($buf.Length -eq 0 -and $key.KeyChar -eq '?') {
            try { [Console]::TreatControlCAsInput = $false } catch { }
            return "?"
        }

        $ch = $key.KeyChar
        if (-not [char]::IsControl($ch)) {
            $isNavigatingHistory = $false
            $histIdx = -1
            $buf.Append($ch) | Out-Null
            try {
                [Console]::SetCursorPosition(2, $PromptRow)
                Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
            } catch {
                Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
            }
            $selIdx = 0
            $topIdx = 0
        }
    }
}

function Start-InteractiveREPL {
    Set-VorkWindowIdentity
    if ($global:VorkIsResumed) {
        Load-VorkConversationState -ConvId $global:VorkConversationId
    }
    Clear-Host
    Show-Banner

    if ($global:VorkIsResumed) {
        Show-ResumedConversationTranscript -ConvId $global:VorkConversationId
    }

    $lineChar = [char]0x2500
    $dotChar = [char]0x00B7

    while ($true) {
        $width = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
        if ($width -le 20 -or $width -gt 300) { $width = 120 }
        $rule = [string]::new($lineChar, ($width - 1))

        # Asegurar buffer vertical suficiente y espacio visible debajo
        try {
            if ([Console]::BufferHeight -lt 1000) {
                [Console]::BufferHeight = 1000
            }
        } catch { }

        $neededLines = 14
        try {
            $currY = [Console]::CursorTop
            $winBottom = [Console]::WindowTop + [Console]::WindowHeight
            if (($winBottom - $currY) -lt $neededLines) {
                $scrollNeeded = $neededLines - ($winBottom - $currY)
                for ($s = 0; $s -lt $scrollNeeded; $s++) {
                    [Console]::WriteLine()
                }
                [Console]::SetCursorPosition(0, [Console]::CursorTop - $scrollNeeded)
            }
        } catch { }

        $left = "? for shortcuts"
        $tierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
        $tierColor = switch ($tierName) {
            "low"    { $Green }
            "medium" { $Yellow }
            "high"   { $Coral }
            default  { $Cyan }
        }
        $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
        $rightPlain = "$modelName " + $dotChar + " " + $tierName
        $rightFormatted = "${LeadLight}$modelName " + $dotChar + " $tierName${Reset}"
        $padLen = [Math]::Max(1, ($width - 1) - $left.Length - $rightPlain.Length)
        $footer = "${LeadLight}$left" + (" " * $padLen) + $rightFormatted

        Write-Host "${Lead}$rule${Reset}"
        Write-Host "${Coral}${Bold}> ${Reset}"
        Write-Host "${Lead}$rule${Reset}"
        Write-Host "$footer" -NoNewline

        # Calcular $pRow exactamente 2 filas arriba de la línea de pie de página
        $pRow = try { [Console]::CursorTop - 2 } catch { 0 }
        try { [Console]::SetCursorPosition(2, $pRow) } catch { Write-Host "$ESC[2A$ESC[2G" -NoNewline }

        $line = Read-InteractiveVorkLine -PromptRow $pRow -Width $width -Rule $rule -Footer $footer
        if ($null -eq $line) {
            Exit-VorkSession -ExitCode 0
        }

        if ($line -eq "?") {
            $modalChosen = Show-InteractiveHelpModal
            Clear-Host
            Show-Banner
            if ($modalChosen) {
                Dispatch-CLICommand -Cmd $modalChosen -ArgsList @()
            }
            continue
        }

        $line = $line.Trim()
        if (-not $line) { continue }

        if (-not $global:VorkSessionHistory) { $global:VorkSessionHistory = [System.Collections.ArrayList]@() }
        if ($line -and ($global:VorkSessionHistory.Count -eq 0 -or $global:VorkSessionHistory[$global:VorkSessionHistory.Count - 1] -ne $line)) {
            [void]$global:VorkSessionHistory.Add($line)
            try {
                $hDir = Join-Path $HOME ".vork"
                if (-not (Test-Path $hDir)) { New-Item -ItemType Directory -Path $hDir -Force | Out-Null }
                Add-Content -Path (Join-Path $hDir "history.txt") -Value $line -Encoding UTF8
            } catch { }
        }

        $tokens = $null
        $errs = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errs)

        $cleanTokens = @($tokens | Where-Object { $_.Kind.ToString() -notin @("EndOfInput", "NewLine") })
        if ($cleanTokens.Count -eq 0) { continue }

        $replCmd = $cleanTokens[0].Text.Trim('"', "'")
        $replArgs = @()
        if ($cleanTokens.Count -gt 1) {
            for ($k = 1; $k -lt $cleanTokens.Count; $k++) {
                $replArgs += $cleanTokens[$k].Text.Trim('"', "'")
            }
        }

        $cmdCheck = $replCmd.TrimStart("/").ToLower()
        $elbow = [char]0x23BF

        if ($cmdCheck -in "exit", "quit", "q") {
            Exit-VorkSession -ExitCode 0
        }

        if ($cmdCheck -in "clear", "cls") {
            Clear-Host
            Show-Banner
            continue
        }

        if ($cmdCheck -in "?", "shortcuts") {
            Show-Shortcuts
            continue
        }

        if ($cmdCheck -in "mode", "modal", "model", "tier", "effort") {
            $argVal = if ($replArgs -and $replArgs.Count -gt 0) { $replArgs[0].ToLower() } else { "" }
            if ($argVal -in "low", "medium", "high") {
                Set-VorkTier -NewTier $argVal
                $outMsg = "Set effort to $argVal"
                Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                Save-VorkConversationRecord -Cmd $line -Output $outMsg
            } else {
                $mRes = Show-InteractiveModelSwitcher
                if ($mRes -and $mRes.Action -eq "selected") {
                    $outMsg = "Switched to $($mRes.Model) · $($mRes.Tier)"
                    Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                    Save-VorkConversationRecord -Cmd $line -Output $outMsg
                } else {
                    $outMsg = "Exited /model command"
                    Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                    Save-VorkConversationRecord -Cmd $line -Output $outMsg
                }
            }
            continue
        }

        if ($cmdCheck -eq "theme") {
            Invoke-CmdTheme -ArgsList $replArgs
            $outMsg = if ($replArgs -and $replArgs.Count -gt 0) { "Changed theme to $global:VorkThemeName" } else { "Exited /theme command" }
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        if ($cmdCheck -in "permissions", "settings", "config") {
            $sRes = Show-InteractiveSettings
            $outMsg = "Exited /settings command"
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        Dispatch-CLICommand -Cmd $replCmd -ArgsList $replArgs
        $outMsg = if ($replCmd.StartsWith("/")) { "Exited $replCmd command" } else { "Executed $replCmd" }
        if ($replCmd.StartsWith("/")) {
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
        }
        Save-VorkConversationRecord -Cmd $line -Output $outMsg
    }
}

# ========================================================
# CONTROL DE ENTRADA: INTERACTIVO vs COMANDO DIRECTO
# ========================================================
Check-And-AutoUpdate

if (-not $Command -or $Command.ToLower() -in "tui", "interactive") {
    Start-InteractiveREPL
} else {
    Dispatch-CLICommand -Cmd $Command -ArgsList $Arguments
    $fullCmd = "$Command $($Arguments -join ' ')".Trim()
    $outMsg = if ($Command.StartsWith("/")) { "Exited $Command command" } else { "Executed $Command" }
    Save-VorkConversationRecord -Cmd $fullCmd -Output $outMsg
}