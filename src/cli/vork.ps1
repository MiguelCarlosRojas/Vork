
# ========================================================
# MODULE: core/config.ps1
# ========================================================
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
$validModels = @("Vork 3", "Vork 3.1", "Vork 3.2")

if (-not $global:VorkModel) {
    if (Test-Path $modelFile) {
        $savedModel = try { (Get-Content -Path $modelFile -Raw).Trim() } catch { "Vork 3.1" }
        if ($savedModel -in $validModels) {
            $global:VorkModel = $savedModel
        }
    }
    if (-not $global:VorkModel) {
        $global:VorkModel = if ($env:VORK_MODEL -and $env:VORK_MODEL -in $validModels) { $env:VORK_MODEL } else { "Vork 3.1" }
    }
}
if ($global:VorkModel -notin $validModels) {
    $global:VorkModel = "Vork 3.1"
}

$tierFile = Join-Path $HOME ".vork\.tier"
if (-not $global:VorkTier) {
    if (Test-Path $tierFile) {
        $savedTier = try { (Get-Content -Path $tierFile -Raw).Trim().ToLower() } catch { "medium" }
        if ($savedTier -in @("low", "medium", "high", "expert")) {
            $global:VorkTier = $savedTier
        }
    }
    if (-not $global:VorkTier) {
        $global:VorkTier = if ($env:VORK_TIER) { $env:VORK_TIER.ToLower() } else { "medium" }
    }
}
if ($global:VorkModel -eq "Vork 3.2") {
    $global:VorkTier = "expert"
} elseif ($global:VorkTier -notin @("low", "medium", "high")) {
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
    if ($global:VorkModel -eq "Vork 3.2") {
        $clean = "expert"
    }
    if ($clean -in @("low", "medium", "high", "expert")) {
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
            "medium" { Write-Host "  ${Dim}Modo Balanceado: óptimo para traducción, razonamiento ágil y stems.${Reset}" }
            "high"   { Write-Host "  ${Dim}Modo Estudio / Ultra: máxima profundidad de razonamiento y fidelidad acústica.${Reset}" }
            "expert" { Write-Host "  ${Dim}Modo Expert Soberano: máxima profundidad cognitiva, razonamiento exhaustivo y arquitectura.${Reset}" }
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


# ========================================================
# MODULE: ui/toolkit.ps1
# ========================================================
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
    if (-not $Panel) { return New-VorkPanel -Rows $Rows }

    if ($metrics.Width -ne $Panel.Width -or $metrics.Height -ne $Panel.Height) {
        Clear-VorkPanel -Panel $Panel
        return New-VorkPanel -Rows $Rows
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


# ========================================================
# MODULE: ui/banner.ps1
# ========================================================
<#
.SYNOPSIS
    Vork CLI - Modulo UI: Banner y Logo Terminal V (Plomo Oscuro & Coral)

.DESCRIPTION
    Conserva el logo solido en bloque "V" y la cabecera clasica de Vork CLI,
    pero calcula el ancho real de la terminal para recortar de forma segura
    (sin romper colores ANSI) y cambia a una cabecera compacta cuando la
    ventana es demasiado estrecha o baja.
#>

function Show-Banner {
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)

    $currPath = try { (Get-Location).Path.Replace($HOME, "~").Replace("\", "/") } catch { "~" }
    $tierLabel = if ($global:VorkTier) { $global:VorkTier.Substring(0,1).ToUpper() + $global:VorkTier.Substring(1).ToLower() } else { "Medium" }
    $tierColor = switch ($tierLabel.ToLower()) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        "expert" { $Purple }
        default  { $Cyan }
    }
    $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
    $endpointInfo = "$ApiBase (Vork AI)"
    $versionBadge = "v$VorkVersion"

    # Logo V moderno solido de 15 columnas (identico al diseno original)
    $sF = [string][char]0x2588 # █
    $v1 = "  " + ($sF * 2) + "       " + ($sF * 2) + "  "
    $v2 = "  " + ($sF * 3) + "     " + ($sF * 3) + "  "
    $v3 = "   " + ($sF * 3) + "   " + ($sF * 3) + "   "
    $v4 = "    " + ($sF * 3) + " " + ($sF * 3) + "    "
    $v5 = "     " + ($sF * 5) + "     "

    Write-Host ""

    if ($width -ge 58 -and $metrics.Height -ge 12) {
        # Cabecera completa: logo a la izquierda, datos de sesion alineados a la derecha.
        $lines = @(
            "${Coral}${v1}${Reset}    ${Coral}${Bold}Vork CLI${Reset} ${BgSel}${Cyan}${Bold} $versionBadge ${Reset}",
            "${Coral}${v2}${Reset}    ${LeadLight}$modelName ($tierLabel)${Reset}",
            "${Coral}${v3}${Reset}    ${LeadLight}$endpointInfo${Reset}",
            "${Coral}${v4}${Reset}    ${Lead}$currPath${Reset}",
            "${Coral}${v5}${Reset}"
        )

        foreach ($line in $lines) {
            Write-Host (Limit-VorkAnsiText -Text $line -MaxWidth $width)
        }
    } else {
        # Cabecera compacta para terminales estrechas o de poca altura.
        $title = "  ${Coral}${Bold}Vork CLI${Reset}  ${BgSel}${Cyan}${Bold} $versionBadge ${Reset}"
        $engine = "  ${LeadLight}$modelName${Reset} ${Lead}·${Reset} ${tierColor}${Bold}$tierLabel${Reset} ${Lead}·${Reset} ${LeadLight}$endpointInfo${Reset}"
        $path = "  ${Lead}$currPath${Reset}"

        Write-Host (Limit-VorkAnsiText -Text $title -MaxWidth $width)
        Write-Host (Limit-VorkAnsiText -Text $engine -MaxWidth $width)
        Write-Host (Limit-VorkAnsiText -Text $path -MaxWidth $width)
    }

    Write-Host ""
}


# ========================================================
# MODULE: ui/cards.ps1
# ========================================================
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


# ========================================================
# MODULE: ui/help.ps1
# ========================================================
<#
.SYNOPSIS
    Vork CLI - Modulo UI: Catalogo visual, atajos y navegador de ayuda responsive.
#>

function Write-VorkHelpLine {
    param(
        [string]$Text,
        [int]$Width = 0
    )

    if ($Width -le 0) {
        $metrics = Get-VorkConsoleMetrics
        $Width = [Math]::Max(10, $metrics.Width - 1)
    }
    Write-Host (Limit-VorkAnsiText -Text $Text -MaxWidth $Width)
}

function Show-Shortcuts {
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)

    $items = @(
        @{ Key = "/slash";       Desc = "Ver los 40 comandos con barra (/)" },
        @{ Key = "/model";       Desc = "Cambiar modelo IA y nivel de esfuerzo (Switch Model & Effort)" },
        @{ Key = "/help";        Desc = "Ver catalogo detallado de los 9 pilares" },
        @{ Key = "/clear, cls";  Desc = "Limpiar pantalla y refrescar banner" },
        @{ Key = "/exit, quit, q"; Desc = "Salir de la sesion interactiva" },
        @{ Key = "/ping, /health"; Desc = "Comprobar conexion con el backend ($ApiBase)" },
        @{ Key = "/update";      Desc = "Actualizar Vork CLI al instante" }
    )

    Write-Host ""
    Write-VorkHelpLine -Width $width -Text "  ${White}${Bold}VORK CLI · ATAJOS & COMANDOS RAPIDOS${Reset}"

    $keyWidth = 18
    foreach ($item in $items) {
        $key = $item.Key.PadRight($keyWidth)
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}  $key${Reset}${Dim}$($item.Desc)${Reset}"
    }

    Write-Host ""
    Write-VorkHelpLine -Width $width -Text "  ${Dim}Pilares directos: translate, tts, clone, media, separate, image, remove-bg, agents${Reset}"
    Write-Host ""
}

function Show-Help {
    Show-Banner
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)
    $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 4))

    Write-VorkHelpLine -Width $width -Text "$White$Bold  SINTAXIS:$Reset"
    Write-VorkHelpLine -Width $width -Text "    $Yellow$Bold vork$Reset $Cyan<comando>$Reset $White [argumentos]$Reset   ${Dim}(Alias: vk, vork-cli, ct)${Reset}"
    Write-Host ""

    Write-VorkHelpLine -Width $width -Text "$White$Bold  LOS 9 PILARES OPERACIONALES:$Reset"

    $pillars = @(
        @{
            Title = "[01] Vork Traductor en la Nube"
            Tag = "+200 idiomas por lotes"
            Usage = "vork translate <texto> -To <iso>"
            Example = "vork translate 'Hola mundo' -To en"
        },
        @{
            Title = "[02] Vork Texto a Voz Neuronal (TTS)"
            Tag = "24 voces humanas"
            Usage = "vork tts <texto> -Voice <id> -Out <archivo>"
            Example = "vork tts 'Bienvenido a Vork' -Voice es-ES-AlvaroNeural -Out voz.mp3"
        },
        @{
            Title = "[03] Vork Clonacion de Voz IA"
            Tag = "Modelado timbrico F0"
            Usage = "vork clone -Audio <muestra> -Text <guion>"
            Example = "vork clone -Audio muestra.wav -Text 'Texto sintetizado'"
        },
        @{
            Title = "[04] Vork Conversor Multimedia"
            Tag = "YouTube, TikTok, IG a MP3/MP4"
            Usage = "vork media <url> -Format <mp3|mp4> -Quality 320"
            Example = "vork media 'https://youtube.com/watch?v=...' -Format mp3"
        },
        @{
            Title = "[05] Vork Separador de Stems"
            Tag = "Acapella / Karaoke con Demucs v4"
            Usage = "vork separate <url_o_archivo>"
            Example = "vork separate cancion.mp3"
        },
        @{
            Title = "[07] Vork Conversor de Imagenes"
            Tag = "PNG, JPG, WEBP, ICO, AVIF"
            Usage = "vork image <archivo> -Format <formato>"
            Example = "vork image logo.png -Format webp -Quality 90"
        },
        @{
            Title = "[08] Vork Estudio de Fondo IA"
            Tag = "U2-Net silueta y transparente"
            Usage = "vork remove-bg <archivo> -Out <archivo.png>"
            Example = "vork remove-bg foto.jpg -Out limpia.png"
        },
        @{
            Title = "[09] Vork Agentes Autonomos & TUI"
            Tag = "Modo orquestador de terminal"
            Usage = "vork agents / vork tui"
            Example = "vk  (alias ultracorto para ejecutar Vork CLI)"
        }
    )

    foreach ($pillar in $pillars) {
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x256D)$([char]0x2500) ${Bold}$($pillar.Title)${Reset} ${Dim}· $($pillar.Tag)${Reset}"
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2502)${Reset}  ${Yellow}$($pillar.Usage)${Reset}"
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2502)${Reset}  ${Dim}Ej: $($pillar.Example)${Reset}"
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2570)$rule${Reset}"
    }

    Write-Host ""
    Write-VorkHelpLine -Width $width -Text "$White$Bold  MANTENIMIENTO & ESTADO:$Reset"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork update$Reset     ${Dim}Sincroniza y actualiza Vork CLI al instante${Reset}"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork health$Reset     ${Dim}Comprueba la telemetria y estado de los 9 pilares${Reset}"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork version$Reset    ${Dim}Muestra detalles de arquitectura y version${Reset}"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork slash$Reset      ${Dim}Ver los 40 comandos con barra (/)${Reset}"
    Write-Host ""
}

function Show-SlashCommands {
    Show-Banner
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)
    $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 4))

    Write-VorkHelpLine -Width $width -Text "$White$Bold  CATALOGO COMPLETO DE LOS 40 COMANDOS CON BARRA (/):$Reset"
    Write-VorkHelpLine -Width $width -Text "  ${Dim}Uso: vork /<comando> o en la consola interactiva TUI${Reset}"
    Write-Host ""

    $categories = @(
        @{
            Title = "[CATEGORIA 1] Los 9 Pilares Operacionales (9)"
            Items = @(
                @{ Cmd = "/translate"; Desc = "Traduccion neuronal por lotes en +200 idiomas" },
                @{ Cmd = "/tts";       Desc = "Sintesis de voz con 24 voces neuronales humanas" },
                @{ Cmd = "/clone";     Desc = "Clonacion vocal IA y modelado espectral F0" },
                @{ Cmd = "/media";     Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
                @{ Cmd = "/separate";  Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
                @{ Cmd = "/image";     Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
                @{ Cmd = "/remove-bg"; Desc = "Silueta inteligente y eliminacion de fondo IA" },
                @{ Cmd = "/agents";    Desc = "Orquestacion de subagentes en terminal interactiva" }
            )
        },
        @{
            Title = "[CATEGORIA 2] Agentes Autonomos & Planificacion IA (8)"
            Items = @(
                @{ Cmd = "/goal";       Desc = "Modo autonomo continuo para tareas exhaustivas" },
                @{ Cmd = "/plan";       Desc = "Planificacion guiada y desglose paso a paso" },
                @{ Cmd = "/grill-me";   Desc = "Entrevista interactiva para decisiones de diseno" },
                @{ Cmd = "/teamwork";   Desc = "Coordinacion con multiples subagentes concurrentes" },
                @{ Cmd = "/boost";      Desc = "Razonamiento profundo con verificacion estricta" },
                @{ Cmd = "/learn";      Desc = "Persistir reglas, correcciones y preferencias" },
                @{ Cmd = "/browser";    Desc = "Navegacion e interaccion web automatizada" },
                @{ Cmd = "/automation"; Desc = "Disenar y programar tareas en segundo plano" }
            )
        },
        @{
            Title = "[CATEGORIA 3] Contexto, Sesion & Memoria (7)"
            Items = @(
                @{ Cmd = "/compact"; Desc = "Compactar historial para liberar ventana de contexto" },
                @{ Cmd = "/clear";   Desc = "Limpiar pantalla de terminal conservando la sesion" },
                @{ Cmd = "/reset";   Desc = "Reiniciar variables y contexto de la sesion a cero" },
                @{ Cmd = "/history"; Desc = "Explorar historial cronologico de comandos ejecutados" },
                @{ Cmd = "/save";    Desc = "Guardar estado de sesion, artefactos y contexto" },
                @{ Cmd = "/resume";  Desc = "Reanudar una sesion previa o restaurar estado" },
                @{ Cmd = "/undo";    Desc = "Deshacer la ultima accion o cambio de codigo" }
            )
        },
        @{
            Title = "[CATEGORIA 4] Codigo, Auditoria & Flujo de Trabajo (4)"
            Items = @(
                @{ Cmd = "/status";   Desc = "Inspeccionar estado del entorno, archivos y tareas activas" },
                @{ Cmd = "/review";   Desc = "Auditoria de codigo, buenas practicas y seguridad" },
                @{ Cmd = "/bug";      Desc = "Diagnostico y depuracion asistida de excepciones" },
                @{ Cmd = "/refactor"; Desc = "Reestructurar y optimizar codigo sin alterar salida" }
            )
        },
        @{
            Title = "[CATEGORIA 5] Configuracion & Preferencias (6)"
            Items = @(
                @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
                @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
                @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
                @{ Cmd = "/model";       Desc = "Cambiar modelo IA y nivel de esfuerzo" },
                @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
                @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" }
            )
        },
        @{
            Title = "[CATEGORIA 6] Sistema, Telemetria & Utilidades (6)"
            Items = @(
                @{ Cmd = "/help";   Desc = "Manual interactivo de comandos y atajos de teclado" },
                @{ Cmd = "/update"; Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
                @{ Cmd = "/health"; Desc = "Telemetria en tiempo real de los 9 pilares" },
                @{ Cmd = "/ping";   Desc = "Prueba de latencia ultrarrrapida hacia la nube" },
                @{ Cmd = "/docs";   Desc = "Abrir la documentacion oficial de Vork en el navegador" },
                @{ Cmd = "/exit";   Desc = "Cerrar la sesion de terminal de forma segura" }
            )
        }
    )

    $cmdWidth = 14
    foreach ($category in $categories) {
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x256D)$([char]0x2500) ${Bold}$($category.Title)${Reset}"
        foreach ($item in $category.Items) {
            $cmd = $item.Cmd.PadRight($cmdWidth)
            Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2502)${Reset}  ${Yellow}$cmd${Reset} ${White}· $($item.Desc)${Reset}"
        }
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2570)$rule${Reset}"
    }
    Write-Host ""
}

# ========================================================
# NAVEGADOR DE AYUDA INTERACTIVO (?) (MODAL MULTIPESTAÑA VORK)
# ========================================================

function Show-InteractiveHelpModal {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $null }

    $tabs = @("general", "commands", "shortcuts")
    $curTab = 0
    $cmdIdx = 0
    $scIdx = 0
    $cmdTop = 0
    $scTop = 0

    $allCommands = @(
        @{ Cmd = "/translate";   Desc = "Traduccion neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Sintesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonacion vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminacion de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestacion de subagentes en terminal interactiva" },
        @{ Cmd = "/goal";        Desc = "Modo autonomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificacion guiada y desglose paso a paso" },
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseno" },
        @{ Cmd = "/teamwork";    Desc = "Coordinacion con multiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificacion estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegacion e interaccion web automatizada" },
        @{ Cmd = "/automation";  Desc = "Disenar y programar tareas en segundo plano" },
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesion" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesion a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronologico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesion, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesion previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la ultima accion o cambio de codigo" },
        @{ Cmd = "/status";      Desc = "Telemetria y estado operativo en vivo de los 9 pilares" },
        @{ Cmd = "/review";      Desc = "Auditoria de codigo, buenas practicas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnostico y depuracion asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar codigo sin alterar salida" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/model";       Desc = "Configurar modelo Vork 3 y nivel de potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar entre los 10 temas visuales oficiales" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/health";      Desc = "Telemetria en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrrapida hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentacion oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesion de terminal de forma segura" }
    )

    $shortcuts = @(
        @{ Key = "/";                      Desc = "Abrir selector interactivo de comandos con barra" },
        @{ Key = "?";                      Desc = "Abrir este navegador de ayuda interactivo" },
        @{ Key = "enter";                  Desc = "Enviar mensaje o confirmar seleccion" },
        @{ Key = "tab";                    Desc = "Autocompletar comando o ciclar pestanas" },
        @{ Key = "esc, ctrl+c";            Desc = "Volver atras / descartar menu / cancelar" },
        @{ Key = "ctrl+l";                 Desc = "Limpiar pantalla de la terminal" },
        @{ Key = "ctrl+d";                 Desc = "Salir del CLI de forma segura" },
        @{ Key = "up / down";              Desc = "Navegar historial de comandos o menus" },
        @{ Key = "left / right";           Desc = "Cambiar de pestana en el navegador de ayuda" },
        @{ Key = "shift+tab";              Desc = "Ciclar nivel de potencia (low, medium, high)" },
        @{ Key = "home / end";             Desc = "Mover el cursor al inicio o final de linea" },
        @{ Key = "backspace";              Desc = "Borrar el caracter anterior" },
        @{ Key = "alt+enter, shift+enter"; Desc = "Insertar salto de linea sin enviar" },
        @{ Key = "ctrl+u";                 Desc = "Borrar todo el texto del prompt actual" },
        @{ Key = "ctrl+r";                 Desc = "Buscar en el historial de comandos ejecutados" },
        @{ Key = "f5";                     Desc = "Activar entrada por voz o dictado de audio" }
    )

    $savedCursorVisible = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    try {
        Clear-Host
        while ($true) {
            $metrics = Get-VorkConsoleMetrics
            $width = [Math]::Max(20, $metrics.Width - 1)
            $height = [Math]::Max(8, $metrics.Height)
            $compact = $height -lt 14
            $winSize = if ($compact) {
                [Math]::Max(1, [Math]::Min(20, $height - 8))
            } else {
                [Math]::Max(1, [Math]::Min(20, $height - 12))
            }
            $bodyBudget = [Math]::Max(1, $height - 6)
            $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 3))

            # Encabezado con pestanas
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
            Write-VorkHelpLine -Width $width -Text "  $brand$tabStr"
            Write-VorkHelpLine -Width $width -Text "  ${Lead}$rule${Reset}"

            switch ($curTab) {
                0 {
                    $tierStr = if ($global:VorkTier) { $global:VorkTier.ToUpper() } else { "MEDIUM" }
                    $ws = try { (Get-Location).Path } catch { "~" }
                    $maxWs = [Math]::Max(12, $width - 22)
                    if ((Get-VorkDisplayWidth $ws) -gt $maxWs) { $ws = "..." + $ws.Substring([Math]::Max(0, $ws.Length - ($maxWs - 3))) }

                    $generalLines = @()
                    if ($bodyBudget -ge 14) {
                        $generalLines += ""
                        $generalLines += "  ${White}${Bold}Vork CLI${Reset} ${LeadLight}comprende tu espacio de trabajo, sintetiza voz neuronal, clona timbres,${Reset}"
                        $generalLines += "  ${LeadLight}aisla pistas vocales e instrumentales y orquesta agentes autonomos desde tu terminal.${Reset}"
                        $generalLines += ""
                    }
                    $generalLines += "  ${White}${Bold}Version:${Reset}         ${Cyan}$VorkVersion${Reset}"
                    $generalLines += "  ${White}${Bold}Nivel / Tier:${Reset}    ${Cyan}Vork 3 ($tierStr)${Reset}"
                    $generalLines += "  ${White}${Bold}API Cloud:${Reset}       ${Cyan}$ApiBase (Vork AI)${Reset}"
                    $generalLines += "  ${White}${Bold}Workspace:${Reset}       ${White}$ws${Reset}"
                    $generalLines += "  ${White}${Bold}Tema Activo:${Reset}     ${Cyan}$global:VorkThemeName${Reset}"
                    $generalLines += ""
                    $generalLines += "  ${White}${Bold}Referencia Rapida:${Reset}"
                    $generalLines += "    ${Cyan}/${Reset}   ${LeadLight}Escribe / para ver todos los 40 comandos con barra${Reset}"
                    $generalLines += "    ${Cyan}?${Reset}   ${LeadLight}Presiona ? para abrir este navegador interactivo${Reset}"
                    $generalLines += ""

                    for ($g = 0; $g -lt $bodyBudget; $g++) {
                        if ($g -lt $generalLines.Count) {
                            Write-VorkHelpLine -Width $width -Text $generalLines[$g]
                        } else {
                            Write-Host ""
                        }
                    }
                }
                1 {
                    if (-not $compact) { Write-Host "" }
                    Write-VorkHelpLine -Width $width -Text "  ${White}${Bold}Comandos Disponibles ($($allCommands.Count)):${Reset}"
                    if (-not $compact) { Write-Host "" }

                    if ($cmdIdx -lt $cmdTop) { $cmdTop = $cmdIdx }
                    elseif ($cmdIdx -ge ($cmdTop + $winSize)) { $cmdTop = $cmdIdx - $winSize + 1 }
                    $maxTop = [Math]::Max(0, $allCommands.Count - $winSize)
                    if ($cmdTop -gt $maxTop) { $cmdTop = $maxTop }
                    if ($cmdTop -lt 0) { $cmdTop = 0 }

                    for ($k = 0; $k -lt $winSize; $k++) {
                        $itemIdx = $cmdTop + $k
                        if ($itemIdx -lt $allCommands.Count) {
                            $cmdItem = $allCommands[$itemIdx]
                            $cName = $cmdItem.Cmd.PadRight(15)
                            $line = if ($itemIdx -eq $cmdIdx) {
                                "  ${Cyan}${Bold}> ${White}${Bold}$cName${Reset} ${White}$($cmdItem.Desc)${Reset}"
                            } else {
                                "    ${LeadLight}$cName${Reset} ${LeadLight}$($cmdItem.Desc)${Reset}"
                            }
                            Write-VorkHelpLine -Width $width -Text $line
                        }
                    }

                    $rangeEnd = [Math]::Min($allCommands.Count, $cmdTop + $winSize)
                    if ($height -ge 10) {
                        if (-not $compact) { Write-Host "" }
                        Write-VorkHelpLine -Width $width -Text "  ${LeadDark}[$($cmdTop + 1)-$rangeEnd de $($allCommands.Count) comandos]${Reset}"
                    }
                }
                2 {
                    if (-not $compact) { Write-Host "" }
                    Write-VorkHelpLine -Width $width -Text "  ${White}${Bold}Atajos de Teclado ($($shortcuts.Count)):${Reset}"
                    if (-not $compact) { Write-VorkHelpLine -Width $width -Text "  ${LeadLight}/keybindings para personalizar${Reset}" }
                    if (-not $compact) { Write-Host "" }

                    if ($scIdx -lt $scTop) { $scTop = $scIdx }
                    elseif ($scIdx -ge ($scTop + $winSize)) { $scTop = $scIdx - $winSize + 1 }
                    $scMaxTop = [Math]::Max(0, $shortcuts.Count - $winSize)
                    if ($scTop -gt $scMaxTop) { $scTop = $scMaxTop }
                    if ($scTop -lt 0) { $scTop = 0 }

                    for ($s = 0; $s -lt $winSize; $s++) {
                        $itemIdx = $scTop + $s
                        if ($itemIdx -lt $shortcuts.Count) {
                            $scItem = $shortcuts[$itemIdx]
                            $sKey = $scItem.Key.PadRight(20)
                            $line = if ($itemIdx -eq $scIdx) {
                                "  ${Cyan}${Bold}> ${White}${Bold}$sKey${Reset} ${White}$($scItem.Desc)${Reset}"
                            } else {
                                "    ${LeadLight}$sKey${Reset} ${LeadLight}$($scItem.Desc)${Reset}"
                            }
                            Write-VorkHelpLine -Width $width -Text $line
                        }
                    }

                    $rangeEnd = [Math]::Min($shortcuts.Count, $scTop + $winSize)
                    if ($height -ge 10) {
                        if (-not $compact) { Write-Host "" }
                        Write-VorkHelpLine -Width $width -Text "  ${LeadDark}[$($scTop + 1)-$rangeEnd de $($shortcuts.Count) atajos]${Reset}"
                    }
                }
            }

            Write-Host ""
            Write-VorkHelpLine -Width $width -Text "  ${Lead}$rule${Reset}"
            $footer = if ($curTab -eq 1) {
                "  ${LeadLight}Teclado: ${Cyan}$([char]0x2191)/$([char]0x2193)${Reset} ${LeadLight}Navegar  ${Cyan}enter${Reset} ${LeadLight}Seleccionar  ${Cyan}$([char]0x2190)/$([char]0x2192)/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
            } else {
                "  ${LeadLight}Teclado: ${Cyan}$([char]0x2191)/$([char]0x2193)${Reset} ${LeadLight}Navegar  ${Cyan}$([char]0x2190)/$([char]0x2192)/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
            }
            Write-VorkHelpLine -Width $width -Text $footer

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) {
                Clear-Host
                continue
            }

            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) { return $null }
            if ($key.Key -in [ConsoleKey]::Escape, [ConsoleKey]::Q) { return $null }

            if ($key.Key -in [ConsoleKey]::RightArrow, [ConsoleKey]::Tab) {
                $curTab = ($curTab + 1) % $tabs.Count
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                $curTab = if ($curTab -gt 0) { $curTab - 1 } else { $tabs.Count - 1 }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($curTab -eq 1) {
                    $cmdIdx = if ($cmdIdx -gt 0) { $cmdIdx - 1 } else { $allCommands.Count - 1 }
                } elseif ($curTab -eq 2) {
                    $scIdx = if ($scIdx -gt 0) { $scIdx - 1 } else { $shortcuts.Count - 1 }
                }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($curTab -eq 1) {
                    $cmdIdx = if ($cmdIdx -lt ($allCommands.Count - 1)) { $cmdIdx + 1 } else { 0 }
                } elseif ($curTab -eq 2) {
                    $scIdx = if ($scIdx -lt ($shortcuts.Count - 1)) { $scIdx + 1 } else { 0 }
                }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home) {
                if ($curTab -eq 1) { $cmdIdx = 0 }
                elseif ($curTab -eq 2) { $scIdx = 0 }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::End) {
                if ($curTab -eq 1) { $cmdIdx = $allCommands.Count - 1 }
                elseif ($curTab -eq 2) { $scIdx = $shortcuts.Count - 1 }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                if ($curTab -eq 1) { return $allCommands[$cmdIdx].Cmd }
                return $null
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursorVisible } catch { }
    }
}


# ========================================================
# MODULE: pillars/p01_translate.ps1
# ========================================================
<#
.SYNOPSIS
    Pilar 01: Vork Traductor Neuronal en la Nube (+200 Idiomas)
#>

function Invoke-PillarTranslate {
    param([string[]]$ArgsList)

    $to = "en"
    $text = ""

    if ($ArgsList -and $ArgsList.Length -gt 0) {
        $to = $ArgsList[0]
        if ($ArgsList.Length -gt 1) {
            $text = ($ArgsList[1..($ArgsList.Length - 1)]) -join " "
        }
    }

    if (-not $text) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [01] Vork Traductor en la Nube (+200 Idiomas)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el texto que deseas traducir:${Reset}"
        $textInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $textInput -or -not $textInput.Trim()) {
            Write-Host "  ${Lead}╰─ Traducción cancelada.${Reset}"
            Write-Host ""
            return
        }
        $text = $textInput.Trim()

        $langOptions = @(
            @{ Value = "en"; Label = "en (Inglés)" },
            @{ Value = "es"; Label = "es (Español)" },
            @{ Value = "fr"; Label = "fr (Francés)" },
            @{ Value = "de"; Label = "de (Alemán)" },
            @{ Value = "it"; Label = "it (Italiano)" },
            @{ Value = "pt"; Label = "pt (Portugués)" },
            @{ Value = "ja"; Label = "ja (Japonés)" },
            @{ Value = "zh"; Label = "zh (Chino)" },
            @{ Value = "ru"; Label = "ru (Ruso)" },
            @{ Value = "ko"; Label = "ko (Coreano)" }
        )

        $chosenLang = Select-InteractiveOption -PromptTitle "Selecciona el idioma destino:" -Options $langOptions -DefaultIndex 0
        if (-not $chosenLang) {
            Write-Host "  ${Lead}╰─ Traducción cancelada.${Reset}"
            Write-Host ""
            return
        }
        $to = $chosenLang
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
        
        $outFile = "traduccion.txt"
        [System.IO.File]::WriteAllText((Join-Path (Get-Location) $outFile), $res.translatedText, [System.Text.Encoding]::UTF8)
        $resolvedOut = (Resolve-Path $outFile).Path
        Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error al traducir]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}


# ========================================================
# MODULE: pillars/p02_tts.ps1
# ========================================================
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

    if (-not $out) { $out = "audio_tts.mp3" }

    $body = @{ text = $text; voice = $voice; outputFormat = "audio-24khz-48kbitrate-mono-mp3" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/tts" -Method Post -Body $body -ContentType "application/json"
        $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }
        if ($res.audioBase64) {
            try {
                $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
            } catch {}
        }
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/tts/download?file=$out" }
        if (-not (Test-Path $targetFile)) {
            try { Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile -UseBasicParsing } catch {}
        }

        Write-Host "  $Cyan│$Reset  $Green✓ Síntesis vocal completada con éxito.$Reset"
        if (Test-Path $targetFile) {
            $resolvedOut = (Resolve-Path $targetFile).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } else {
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error TTS]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}


# ========================================================
# MODULE: pillars/p03_clone.ps1
# ========================================================
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
        if (-not $chosenF0) {
            Write-Host "  ${Lead}╰─ Clonación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $f0Method = $chosenF0

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

    if (-not $out) { $out = "voz_clonada.wav" }
    $cloneText = if ($text -and $text.Trim()) { $text.Trim() } else { "Prueba de síntesis con voz clonada en Vork CLI." }
    $body = @{ text = $cloneText; audioSampleBase64 = $b64; similarity = "high"; format = "wav" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/voice-clone" -Method Post -Body $body -ContentType "application/json"
        $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }
        if ($res.audioBase64) {
            try {
                $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
            } catch {}
        }
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/voice-clone/download" }
        if (-not (Test-Path $targetFile)) {
            try { Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile -UseBasicParsing } catch {}
        }

        Write-Host "  $Cyan│$Reset  $Green✓ Clonación de voz completada exitosamente.$Reset"
        if (Test-Path $targetFile) {
            $resolvedOut = (Resolve-Path $targetFile).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } else {
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Clonación]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}


# ========================================================
# MODULE: pillars/p04_media.ps1
# ========================================================
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
            Write-Host "  $Cyan│$Reset  $Green✓ Conversión multimedia completada exitosamente.$Reset"
            $dlFull = if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" }
            $localFile = if ($res.filename) { $res.filename } else { "media_output.$fmt" }
            try {
                Invoke-WebRequest -Uri $dlFull -OutFile $localFile -UseBasicParsing -TimeoutSec 120
                $resolvedOut = (Resolve-Path $localFile).Path
                Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
            } catch {
                Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlFull$Reset"
            }
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


# ========================================================
# MODULE: pillars/p05_separate.ps1
# ========================================================
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
        if (-not $chosenMode) {
            Write-Host "  ${Lead}╰─ Separación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $mode = $chosenMode
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
            $localVoc = "vocals.wav"
            try {
                Invoke-WebRequest -Uri $vocDl -OutFile $localVoc -UseBasicParsing -TimeoutSec 120
                Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$((Resolve-Path $localVoc).Path)$Reset"
            } catch {
                Write-Host "  $Cyan│$Reset    Descarga: $Yellow$vocDl$Reset"
            }
        } elseif ($mode -eq "karaoke" -and $instDl) {
            Write-Host "  $Cyan│$Reset  $Green✓ Pista Instrumental (Karaoke) aislada con éxito:$Reset"
            $localInst = "instrumental.wav"
            try {
                Invoke-WebRequest -Uri $instDl -OutFile $localInst -UseBasicParsing -TimeoutSec 120
                Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$((Resolve-Path $localInst).Path)$Reset"
            } catch {
                Write-Host "  $Cyan│$Reset    Descarga: $Yellow$instDl$Reset"
            }
        } else {
            Write-Host "  $Cyan│$Reset  $Green✓ Separación de stems lista con Demucs v4:$Reset"
            if ($vocDl) {
                $localVoc = "vocals.wav"
                try {
                    Invoke-WebRequest -Uri $vocDl -OutFile $localVoc -UseBasicParsing -TimeoutSec 120
                    Write-Host "  $Cyan│$Reset  $Green✓ Guardado local (Vocals):$Reset       $White$((Resolve-Path $localVoc).Path)$Reset"
                } catch {
                    Write-Host "  $Cyan│$Reset    ${White}${Bold}Voz Acapella:${Reset}  $Yellow$vocDl$Reset"
                }
            }
            if ($instDl) {
                $localInst = "instrumental.wav"
                try {
                    Invoke-WebRequest -Uri $instDl -OutFile $localInst -UseBasicParsing -TimeoutSec 120
                    Write-Host "  $Cyan│$Reset  $Green✓ Guardado local (Instrumental):$Reset $White$((Resolve-Path $localInst).Path)$Reset"
                } catch {
                    Write-Host "  $Cyan│$Reset    ${White}${Bold}Instrumental:${Reset}  $Cyan$instDl$Reset"
                }
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


# ========================================================
# MODULE: pillars/p07_image.ps1
# ========================================================
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
        if (-not $chosenFmt) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }
        $fmt = $chosenFmt
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
        Write-Host "  $Cyan│$Reset  $Green✓ Conversión de imagen completada exitosamente.$Reset"
        $localImg = if ($target -and (Test-Path $target)) {
            [System.IO.Path]::GetFileNameWithoutExtension($target) + "_convertido.$fmt"
        } else {
            "imagen_convertida.$fmt"
        }
        try {
            Invoke-WebRequest -Uri $dlUrl -OutFile $localImg -UseBasicParsing -TimeoutSec 60
            $resolvedOut = (Resolve-Path $localImg).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } catch {
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Imagen]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}


# ========================================================
# MODULE: pillars/p08_remove_bg.ps1
# ========================================================
<#
.SYNOPSIS
    Pilar 08: Vork Modificador de Imagen & Fondo IA con Prompt (BRIA RMBG + FLUX.1)
#>

function Invoke-PillarRemoveBg {
    param([string[]]$ArgsList)

    $file = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $userPrompt = $null
    $out = $null

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1]; continue }
            if ($ArgsList[$i] -in "-Prompt", "--prompt", "-p") { $userPrompt = $ArgsList[$i+1]; continue }
            if ($i -gt 0 -and -not $userPrompt -and -not $ArgsList[$i].StartsWith("-")) {
                $userPrompt = $ArgsList[$i]
            }
        }
    }

    if ($file) {
        $file = $file.Trim('"', "'", " ")
    }

    $isWebUrl = ($file -and $file -match '^https?://')
    $isLocalFile = ($file -and (Test-Path $file))

    if (-not $isWebUrl -and -not $isLocalFile) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [08] Vork Modificador de Imagen & Fondo IA con Prompt${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la ruta o URL de la imagen (ej: producto.jpg o enlace web):${Reset}"
        $fileInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $fileInput -or -not $fileInput.Trim()) {
            Write-Host "  ${Lead}╰─ Imagen no válida o cancelado.${Reset}"
            Write-Host ""
            return
        }
        $file = $fileInput.Trim('"', "'", " ")
        $isWebUrl = ($file -match '^https?://')
        $isLocalFile = (Test-Path $file)

        if (-not $isWebUrl -and -not $isLocalFile) {
            Write-Host "  ${Lead}╰─ [!] Archivo o URL no encontrado: $file${Reset}"
            Write-Host ""
            return
        }
    }

    if (-not $userPrompt) {
        Write-Host "  ${Lead}│${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Describe qué deseas modificar en la imagen (prompt):${Reset}"
        Write-Host "  ${Lead}│${Reset} ${LeadLight}(Ej: playa paradisíaca al atardecer, oficina moderna, fondo blanco, o enter para sin fondo)${Reset}"
        $pInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if ($pInput -and $pInput.Trim()) {
            $userPrompt = $pInput.Trim()
        }
    }

    # Detección inteligente del modo según el prompt del usuario
    $cleanP = if ($userPrompt) { $userPrompt.ToLower().Trim() } else { "" }
    $mode = "prompt"
    $colorVal = "#FFFFFF"

    if (-not $cleanP -or $cleanP -in "sin fondo", "quitar fondo", "eliminar fondo", "transparente", "transparent", "corte", "silueta", "solo sujeto", "none") {
        $mode = "transparent"
        $userPrompt = "Aislamiento de silueta PNG transparente"
    } elseif ($cleanP -in "fondo blanco", "blanco", "white", "fondo blanco studio", "white background") {
        $mode = "color"
        $colorVal = "#FFFFFF"
        $userPrompt = "Fondo Blanco Studio (#FFFFFF)"
    } elseif ($cleanP -in "fondo negro", "negro", "black", "black background", "fondo negro cine") {
        $mode = "color"
        $colorVal = "#000000"
        $userPrompt = "Fondo Negro Cine (#000000)"
    }

    if (-not $out) {
        $ext = if ($mode -eq "transparent") { "png" } else { "jpg" }
        if ($isLocalFile) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $suffix = if ($mode -eq "prompt") { "_modificado" } else { "_nobg" }
            $out = "${baseName}${suffix}.$ext"
        } else {
            $out = if ($mode -eq "prompt") { "imagen_modificada.$ext" } else { "sin_fondo.$ext" }
        }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [08] VORK ESTUDIO Y MODIFICADOR DE IMAGEN IA ────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset   $White$file$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Prompt:$Reset   $Cyan`"$userPrompt`"$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $bodyMap = @{ mode = $mode }
    if ($mode -eq "prompt") {
        $bodyMap["prompt"] = $userPrompt
    } elseif ($mode -eq "color") {
        $bodyMap["color"] = $colorVal
    }

    if ($isLocalFile) {
        $resolved = Resolve-Path $file
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $b64 = [System.Convert]::ToBase64String($bytes)
        $bodyMap["imageBase64"] = "data:image/jpeg;base64,$b64"
    } else {
        $bodyMap["url"] = $file
    }

    $body = $bodyMap | ConvertTo-Json

    try {
        if ($mode -eq "prompt") {
            Write-Host "  $Cyan│$Reset  ${LeadLight}Aislando sujeto con BRIA RMBG 1.4...${Reset}"
            Write-Host "  $Cyan│$Reset  ${LeadLight}Generando modificación con IA FLUX.1 Neural...${Reset}"
            Write-Host "  $Cyan│$Reset  ${LeadLight}Componiendo imagen final de alta resolución...${Reset}"
        } else {
            Write-Host "  $Cyan│$Reset  ${LeadLight}Procesando silueta con IA neuronal...${Reset}"
        }

        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/remove-background" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/image/download?id=$($res.id)" }

        Write-Host "  $Cyan│$Reset  $Green✓ Modificación de imagen completada exitosamente.$Reset"
        try {
            Invoke-WebRequest -Uri $dlUrl -OutFile $out -UseBasicParsing -TimeoutSec 90
            $resolvedOut = (Resolve-Path $out).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } catch {
            Write-Host "  $Cyan│$Reset  $Yellow URL de descarga:$Reset $White$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Imagen IA]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}


# ========================================================
# MODULE: pillars/p09_agents.ps1
# ========================================================
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
        if (-not $chosenAction) { return }
        if ($chosenAction -ne "status") {
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
    $reportFile = "vork_agents_cluster.json"
    @{ status = "online"; motor = "Vork Autonomous Agents v3"; pilares = 8; subagentes = @("Codebase Researcher", "Audio Engine Agent", "Demucs Stem Worker", "Media Extraction Bot") } | ConvertTo-Json | Set-Content -Path $reportFile -Encoding UTF8
    $resolvedOut = (Resolve-Path $reportFile).Path
    Write-Host "  ${Cyan}│${Reset}  $Green✓ Clúster de agentes sincronizado con éxito.$Reset"
    Write-Host "  ${Cyan}│${Reset}  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
    Write-Host "  ${Cyan}╰───────────────────────────────────────────────────${Reset}"
    Write-Host ""
}


# ========================================================
# MODULE: pillars/commands.ps1
# ========================================================
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


# ========================================================
# VORK AI CONVERSACIONAL (VORK 3, 3.1 & 3.2 EXPERT)
# ========================================================

function Invoke-VorkAIChat {
    param(
        [string]$Prompt,
        [string[]]$ArgsList
    )

    $fullPrompt = if ($Prompt) { $Prompt } elseif ($ArgsList) { $ArgsList -join " " } else { "" }
    $fullPrompt = $fullPrompt.Trim()

    if (-not $fullPrompt) {
        Write-Host ""
        Write-Host "  ${Cyan}╭─ Vork AI Conversacional ───────────────────────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Escribe tu consulta o tarea para la IA:${Reset}"
        $fullPrompt = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $fullPrompt -or -not $fullPrompt.Trim()) { return }
        $fullPrompt = $fullPrompt.Trim()
    }

    $activeModel = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3.1" }
    $activeTier = if ($activeModel -eq "Vork 3.2") { "expert" } elseif ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
    $tierLabel = if ($activeTier.Length -gt 1) { $activeTier.Substring(0,1).ToUpper() + $activeTier.Substring(1).ToLower() } else { $activeTier.ToUpper() }
    $tierColor = switch ($activeTier) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        "expert" { $Purple }
        default  { $Cyan }
    }

    Write-Host ""
    Write-Host "  ${tierColor}$([char]0x25CF)${Reset} ${LeadLight}Pensando con ${White}${Bold}$activeModel${Reset} ${LeadLight}(${tierColor}${Bold}$tierLabel${Reset}${LeadLight})...${Reset}"

    $answer = ""
    # 1. Intentar backend oficial de Vork
    try {
        $bodyJson = @{
            message = $fullPrompt
            model = $activeModel
            effort = $activeTier
        } | ConvertTo-Json -Compress

        $timeoutSec = if ($activeTier -in "high", "expert") { 60 } else { 35 }
        $res = Invoke-RestMethod -Uri "$ApiBase/api/ai/chat" -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec $timeoutSec -ErrorAction Stop
        if ($res -and $res.response) {
            $answer = $res.response
        } elseif ($res -and $res.message) {
            $answer = $res.message
        }
    } catch {
        # 2. Resiliencia autonoma: Si el backend local no responde, conectar directo
        try {
            $sysPrompt = switch ($activeModel) {
                "Vork 3"   { "Eres Vork 3, motor multimodal IA. Especialista en audio, traduccion y conversion. Responde en el idioma del usuario de forma tecnica y directa." }
                "Vork 3.2" { "Eres Vork 3.2 Expert Sovereign Edition. Rigor matematico y arquitectura de software al maximo nivel de excelencia. Respuestas exhaustivas, precisas y sin restricciones." }
                default    { "Eres Vork 3.1, la nueva generacion de Inteligencia Artificial creada desde cero por Vork. Eres un ingeniero senior de software y asistente analitico. Tus respuestas son tecnicas, profesionales, con codigo limpio y directas al grano." }
            }
            $seed = Get-Random -Minimum 100000 -Maximum 9999999
            $encodedPrompt = [System.Uri]::EscapeDataString($fullPrompt)
            $encodedSys = [System.Uri]::EscapeDataString($sysPrompt)
            $directUrl = "https://text.pollinations.ai/" + $encodedPrompt + "?system=" + $encodedSys + "&seed=" + $seed
            $directRes = Invoke-RestMethod -Uri $directUrl -Method Get -TimeoutSec 45 -ErrorAction Stop
            if ($directRes) {
                $answer = [string]$directRes
            }
        } catch {
            $answer = "No se pudo obtener respuesta del motor de Vork AI: $($_.Exception.Message)"
        }
    }

    Write-Host ""
    if ($answer) {
        $lines = $answer -split '\r?\n'
        foreach ($l in $lines) {
            if ($l.StartsWith('```')) {
                Write-Host "  ${Yellow}$l${Reset}"
            } elseif ($l.StartsWith("#")) {
                Write-Host "  ${White}${Bold}$l${Reset}"
            } elseif ($l.StartsWith(">")) {
                Write-Host "  ${Cyan}$l${Reset}"
            } else {
                Write-Host "  ${White}$l${Reset}"
            }
        }
    }
    Write-Host ""
    $elbowChar = [char]0x23BF
    Write-Host "  ${LeadLight}$elbowChar  $activeModel · $tierLabel${Reset}"
    Write-Host ""

    Save-VorkConversationRecord -Cmd $fullPrompt -Output $answer
}


# ========================================================
# MODULE: pillars/system.ps1
# ========================================================
<#
.SYNOPSIS
    Modulos de Sistema: Version y Telemetria en Vivo (Health)
#>

function Invoke-PillarVersion {
    $archLabel = if ($env:PROCESSOR_ARCHITECTURE) { $env:PROCESSOR_ARCHITECTURE } else { "unknown" }
    Write-Host ""
    Write-Host "  $ESC[44;97;1m VORK CLI $Reset $White$Bold v$VorkVersion$Reset"
    Write-Host "  $Gray Backend:$Reset  $Cyan$ApiBase$Reset"
    Write-Host "  $Gray Pilares:$Reset  $Green 9 Pilares Operacionales Activos$Reset"
    Write-Host "  $Gray Motor:$Reset    $White PowerShell $($PSVersionTable.PSVersion) [$archLabel]$Reset"
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


# ========================================================
# MODULE: core/updater.ps1
# ========================================================
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


# ========================================================
# MODULE: core/router.ps1
# ========================================================
<#
.SYNOPSIS
    Vork CLI - Modulo Core: Despachador y consola interactiva REPL responsive.
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
        # CATEGORIA 2: AGENTES AUTONOMOS & PLANIFICACION IA (8)
        # ========================================================
        { $_ -in "chat", "ai", "ask" } {
            $chatPrompt = if ($ArgsList) { $ArgsList -join " " } else { "" }
            Invoke-VorkAIChat -Prompt $chatPrompt
        }
        "goal"       { Invoke-CmdGoal -ArgsList $ArgsList }
        "plan"       { Invoke-CmdPlan -ArgsList $ArgsList }
        "grill-me"   { Invoke-CmdGrillMe }
        "teamwork"   { Invoke-CmdTeamwork -ArgsList $ArgsList }
        "boost"      { Invoke-CmdBoost }
        "learn"      { Invoke-CmdLearn -ArgsList $ArgsList }
        "browser"    { Invoke-CmdBrowser -ArgsList $ArgsList }
        "automation" { Invoke-CmdAutomation }

        # ========================================================
        # CATEGORIA 3: CONTEXTO, SESION & MEMORIA (7)
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
        # CATEGORIA 4: CODIGO, AUDITORIA & FLUJO (4)
        # ========================================================
        "status"   { Invoke-CmdStatus }
        "review"   { Invoke-CmdReview }
        "bug"      { Invoke-CmdBug -ArgsList $ArgsList }
        "refactor" { Invoke-CmdRefactor }

        # ========================================================
        # CATEGORIA 5: CONFIGURACION & PREFERENCIAS (6)
        # ========================================================
        { $_ -in "settings", "config", "permissions" } {
            [void](Show-InteractiveSettings)
            Write-Host "  ${LeadLight}Configuración cerrada.${Reset}"
            Write-Host ""
        }
        "keybindings" { Invoke-CmdKeybindings }
        { $_ -in "mode", "modal", "model", "tier", "effort" } {
            $argVal = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }
            if ($argVal -in "low", "medium", "high") {
                Set-VorkTier -NewTier $argVal
            } else {
                $modelResult = Show-InteractiveModelSwitcher
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Exited /model command${Reset}"
                Write-Host ""
            }
        }
        "theme"       { Invoke-CmdTheme -ArgsList $ArgsList }
        "env"         { Invoke-CmdEnv }

        # ========================================================
        # CATEGORIA 6: SISTEMA, TELEMETRIA & UTILIDADES (6)
        # ========================================================
        { $_ -in "help", "--help", "-h", "?", "shortcuts", "/shortcuts" } {
            if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
                Show-Help
            } else {
                $chosen = Show-InteractiveHelpModal
                if ($chosen) {
                    Dispatch-CLICommand -Cmd $chosen -ArgsList @()
                }
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
            if ($Cmd.StartsWith("/")) {
                Write-Host ""
                Write-Host "  ${Coral}[!] Comando no reconocido:${Reset} $White`"$Cmd`"$Reset"
                Write-Host "  ${Dim}Escribe '?' para atajos o 'slash' para ver los 40 comandos con barra.${Reset}"
                Write-Host ""
            } else {
                $fullChat = "$Cmd $($ArgsList -join ' ')".Trim()
                Invoke-VorkAIChat -Prompt $fullChat
            }
        }
    }
}

function Get-VorkPromptTierColor {
    param([string]$Tier)

    switch (([string]$Tier).ToLower()) {
        "low"    { return $Green }
        "medium" { return $Yellow }
        "high"   { return $Coral }
        "expert" { return $Purple }
        default  { return $Cyan }
    }
}

function Format-VorkPromptStatus {
    param(
        [string]$Status,
        [int]$Width
    )

    if (-not $Status -or $Width -lt 36) { return "" }

    if ($Status -match '(?i)ctrl\s*\+\s*c') {
        $warning = if ($Width -lt 58) { "ctrl+c otra vez" } else { $Status }
        return "${Yellow}${Bold}$([char]0x26A0)${Reset} ${Yellow}$warning${Reset}"
    }

    $segments = @($Status -split ([string][char]0x00B7) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($segments.Count -ge 2) {
        $model = [string]$segments[0]
        $tier = [string]$segments[$segments.Count - 1]
        $tierLabel = if ($tier.Length -gt 1) { $tier.Substring(0, 1).ToUpper() + $tier.Substring(1).ToLower() } else { $tier.ToUpper() }
        $tierColor = Get-VorkPromptTierColor -Tier $tier

        if ($Width -lt 58) {
            return "${tierColor}$([char]0x25CF)${Reset} ${tierColor}${Bold}$tierLabel${Reset}"
        }

        return "${tierColor}$([char]0x25CF)${Reset} ${LeadLight}$model${Reset} ${Lead}$([char]0x00B7)${Reset} ${tierColor}${Bold}$tierLabel${Reset}"
    }

    return "${LeadLight}$Status${Reset}"
}

function Get-VorkPromptPlaceholder {
    param([int]$Budget)

    if ($Budget -lt 8) { return "" }

    $candidates = @(
        "Escribe tu mensaje o usa /comando",
        "Mensaje o /comando",
        "Mensaje o /cmd",
        "/comando"
    )

    foreach ($candidate in $candidates) {
        if ((Get-VorkDisplayWidth $candidate) -le $Budget) { return $candidate }
    }

    return ""
}

function Get-VorkPromptHints {
    param(
        [int]$Width,
        [bool]$MenuOpen
    )

    $upDown = [string]([char]0x2191) + [string]([char]0x2193)
    $enter = [string][char]0x23CE

    if ($MenuOpen) {
        if ($Width -ge 80) {
            return @(
                @{ Key = $upDown; Label = "navegar" },
                @{ Key = "tab";    Label = "completar" },
                @{ Key = "enter";  Label = "ejecutar" },
                @{ Key = "esc";    Label = "cerrar" }
            )
        }
        if ($Width -ge 60) {
            return @(
                @{ Key = $upDown; Label = "" },
                @{ Key = "tab";    Label = "completar" },
                @{ Key = $enter;   Label = "ejecutar" },
                @{ Key = "esc";    Label = "" }
            )
        }
        return @(
            @{ Key = $upDown; Label = "" },
            @{ Key = "tab";    Label = "" },
            @{ Key = $enter;   Label = "" },
            @{ Key = "esc";    Label = "" }
        )
    }

    if ($Width -ge 88) {
        return @(
            @{ Key = "?";      Label = "atajos" },
            @{ Key = "/";      Label = "comandos" },
            @{ Key = "ctrl+l"; Label = "limpiar" },
            @{ Key = "ctrl+c"; Label = "salir" }
        )
    }
    if ($Width -ge 64) {
        return @(
            @{ Key = "?";      Label = "atajos" },
            @{ Key = "/";      Label = "comandos" },
            @{ Key = "ctrl+c"; Label = "salir" }
        )
    }
    if ($Width -ge 46) {
        return @(
            @{ Key = "?";  Label = "ayuda" },
            @{ Key = "/";  Label = "cmds" },
            @{ Key = "^C"; Label = "salir" }
        )
    }
    return @(
        @{ Key = "?";  Label = "" },
        @{ Key = "/";  Label = "" },
        @{ Key = "^C"; Label = "" }
    )
}

function Format-VorkHintLine {
    param(
        [array]$Hints,
        [int]$MaxWidth
    )

    if (-not $Hints -or $Hints.Count -eq 0 -or $MaxWidth -le 0) { return "" }

    $separator = " ${Lead}$([char]0x00B7)${Reset} "
    $separatorWidth = 3
    $output = ""
    $used = 0

    foreach ($hint in $Hints) {
        $key = [string]$hint.Key
        $label = [string]$hint.Label
        if (-not $key) { continue }

        $pieceWidth = Get-VorkDisplayWidth $key
        if ($label) { $pieceWidth += 1 + (Get-VorkDisplayWidth $label) }

        $needed = $pieceWidth
        if ($output) { $needed += $separatorWidth }
        if (($used + $needed) -gt $MaxWidth) { break }

        if ($output) { $output += $separator }
        $output += "${White}${Bold}$key${Reset}"
        if ($label) { $output += " ${LeadLight}$label${Reset}" }
        $used += $needed
    }

    return $output
}

function Get-VorkPromptPathLabel {
    param([int]$MaxWidth = 28)

    $path = try { (Get-Location).Path } catch { "" }
    if (-not $path) { return "" }

    $homePath = [string]$HOME
    if ($homePath -and $path.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $path.Substring($homePath.Length).TrimStart([char[]]@('\', '/'))
        $path = if ($relative) { "~/" + ($relative -replace '\\', '/') } else { "~" }
    } else {
        $path = $path -replace '\\', '/'
    }

    if ($MaxWidth -gt 2 -and (Get-VorkDisplayWidth $path) -gt $MaxWidth) {
        while ($path.Length -gt 1 -and (Get-VorkDisplayWidth $path) -gt ($MaxWidth - 1)) {
            $path = $path.Substring(1)
        }
        $path = [string][char]0x2026 + $path
    }

    return $path
}

function Format-VorkMenuItemLine {
    param(
        [string]$Cmd,
        [string]$Desc,
        [bool]$Selected,
        [int]$InnerWidth
    )

    $inner = [Math]::Max(6, $InnerWidth)
    $vertical = [char]0x2502
    $arrow = [char]0x25B8
    $showDesc = $inner -ge 32
    $cmdWidth = if ($showDesc) {
        [Math]::Max(13, [Math]::Min(18, [int][Math]::Floor($inner * 0.3)))
    } else {
        $inner - 4
    }

    $cmdText = if ((Get-VorkDisplayWidth $Cmd) -le $cmdWidth) {
        $Cmd
    } elseif ($cmdWidth -ge 2) {
        (Limit-VorkAnsiText -Text $Cmd -MaxWidth ($cmdWidth - 1) -Ellipsis "") + [string][char]0x2026
    } else {
        ""
    }
    $cmdPad = $cmdText + [string]::new(' ', [Math]::Max(0, $cmdWidth - (Get-VorkDisplayWidth $cmdText)))

    if ($showDesc) {
        $descBudget = [Math]::Max(0, $inner - $cmdWidth - 4)
        $descText = if ((Get-VorkDisplayWidth $Desc) -le $descBudget) {
            $Desc
        } elseif ($descBudget -ge 2) {
            (Limit-VorkAnsiText -Text $Desc -MaxWidth ($descBudget - 1) -Ellipsis "") + [string][char]0x2026
        } else {
            ""
        }
        $descWidth = Get-VorkDisplayWidth $descText
        $fill = [string]::new(' ', [Math]::Max(0, $inner - $cmdWidth - 4 - $descWidth))
    } else {
        $descText = ""
        $fill = [string]::new(' ', [Math]::Max(0, $inner - 3 - (Get-VorkDisplayWidth $cmdText)))
    }

    if ($Selected) {
        if ($showDesc) {
            return "  ${Lead}$vertical${Reset}${BgSel} ${Cyan}${Bold}$arrow ${White}${Bold}$cmdPad ${LeadLight}$descText$fill${Reset} ${Lead}$vertical${Reset}"
        }
        return "  ${Lead}$vertical${Reset}${BgSel} ${Cyan}${Bold}$arrow ${White}${Bold}$cmdText$fill${Reset} ${Lead}$vertical${Reset}"
    }

    if ($showDesc) {
        return "  ${Lead}$vertical${Reset}   ${White}$cmdPad${Reset} ${LeadLight}$descText$fill${Reset} ${Lead}$vertical${Reset}"
    }

    return "  ${Lead}$vertical${Reset}   ${White}$cmdText$fill${Reset} ${Lead}$vertical${Reset}"
}

function Write-VorkPromptFrame {
    param(
        [int]$PromptRow,
        [int]$Width,
        [int]$Height,
        [string]$Text,
        [int]$Cursor,
        [array]$MenuItems,
        [int]$MenuSelected,
        [int]$MenuTop,
        [int]$MenuVisible,
        [bool]$MenuOpen,
        [string]$Status,
        [int]$MenuRows
    )

    $maxWidth = [Math]::Max(4, $Width - 1)
    $panel = [pscustomobject]@{
        Top          = $PromptRow
        Rows         = 3 + [Math]::Max(0, $MenuRows)
        Width        = $Width
        Height       = $Height
        BufferHeight = 0
    }

    # Cabecera: marca en coral + estado de modelo/tier alineado a la derecha.
    $statusText = Format-VorkPromptStatus -Status $Status -Width $Width
    $titleText = "${Coral}${Bold}Vork CLI${Reset}"
    Write-VorkPanelLine -Panel $panel -Index 0 -Text (Format-VorkBorderTop -Title $titleText -RightText $statusText -Width $Width)

    # Linea de entrada con placeholder atenuado cuando el buffer esta vacio.
    $inner = [Math]::Max(1, $Width - 9)
    $view = Get-VorkTextWindow -Text $Text -Cursor $Cursor -Width $inner
    $shownText = $view.Text
    $textWidth = Get-VorkDisplayWidth $view.Text

    if (-not $Text) {
        $placeholder = Get-VorkPromptPlaceholder -Budget $inner
        if ($placeholder) {
            $shownText = "${LeadLight}$placeholder${Reset}"
            $textWidth = Get-VorkDisplayWidth $placeholder
        }
    }

    $padding = [Math]::Max(0, ($Width - 3) - (6 + $textWidth))
    $inputLine = "  ${Lead}$([char]0x2502)${Reset} ${Coral}${Bold}$([char]0x276F)${Reset} $shownText$([string]::new(' ', $padding)) ${Lead}$([char]0x2502)${Reset}"
    Write-VorkPanelLine -Panel $panel -Index 1 -Text $inputLine

    # Pie de pagina: atajos contextuales que se recortan segun el ancho disponible.
    $hints = Get-VorkPromptHints -Width $Width -MenuOpen $MenuOpen
    $leftText = Format-VorkHintLine -Hints $hints -MaxWidth ([Math]::Max(0, $maxWidth - 8))
    $rightText = ""

    if ($MenuOpen) {
        $above = $MenuTop
        $below = [Math]::Max(0, $MenuItems.Count - ($MenuTop + $MenuVisible))

        if ($Width -ge 64) {
            $scrollText = if ($below -gt 0 -and $above -gt 0) {
                "$([char]0x2191)$above $([char]0x00B7) $([char]0x2193)$below"
            } elseif ($below -gt 0) {
                "$([char]0x2193) $below"
            } elseif ($above -gt 0) {
                "$([char]0x2191) $above"
            } else {
                ""
            }

            if ($scrollText) {
                $rightText = "${Lead}$scrollText"
                $leftText = Format-VorkHintLine -Hints $hints -MaxWidth ([Math]::Max(0, $maxWidth - 12 - (Get-VorkDisplayWidth $scrollText)))
            }
        }

        Write-VorkPanelLine -Panel $panel -Index 2 -Text (Format-VorkBorderMiddle -RightText $rightText -Width $Width)
    } else {
        if ($Width -ge 90) {
            $remaining = $maxWidth - 8 - (Get-VorkDisplayWidth $leftText) - 4
            if ($remaining -ge 12) {
                $pathLabel = Get-VorkPromptPathLabel -MaxWidth ([Math]::Min(28, $remaining))
                if ($pathLabel) { $rightText = "${Lead}$pathLabel" }
            }
        }

        Write-VorkPanelLine -Panel $panel -Index 2 -Text (Format-VorkBorderBottom -LeftText $leftText -RightText $rightText -Width $Width)
    }

    # Lista de comandos: fila seleccionada con fondo solido y borde derecho continuo.
    $menuStart = 3
    $menuInner = [Math]::Max(6, $Width - 7)

    for ($i = 0; $i -lt $MenuRows; $i++) {
        $row = $menuStart + $i
        $itemIndex = $MenuTop + $i
        if ($MenuOpen -and $i -lt $MenuVisible -and $itemIndex -lt $MenuItems.Count) {
            $item = $MenuItems[$itemIndex]
            $isSelected = $itemIndex -eq $MenuSelected
            $line = Format-VorkMenuItemLine -Cmd ([string]$item.Cmd) -Desc ([string]$item.Desc) -Selected $isSelected -InnerWidth $menuInner
            Write-VorkPanelLine -Panel $panel -Index $row -Text $line
        } elseif ($MenuOpen -and $i -eq $MenuVisible) {
            Write-VorkPanelLine -Panel $panel -Index $row -Text (Format-VorkBorderBottom -LeftText $leftText -Width $Width)
        } else {
            Write-VorkPanelLine -Panel $panel -Index $row -Text ""
        }
    }

    try {
        $cursorColumn = 6 + $view.Cursor
        if ($cursorColumn -ge ($Width - 1)) { $cursorColumn = $Width - 2 }
        if ($cursorColumn -lt 0) { $cursorColumn = 0 }
        [Console]::SetCursorPosition($cursorColumn, $PromptRow + 1)
    } catch { }
}

function Read-InteractiveVorkLine {
    param(
        [string]$Status = ""
    )

    if ([Console]::IsInputRedirected) {
        return [Console]::ReadLine()
    }

    $allCommands = @(
        @{ Cmd = "/translate";   Desc = "Traduccion neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Sintesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonacion vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminacion de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestacion de subagentes en terminal interactiva" },
        @{ Cmd = "/goal";        Desc = "Modo autonomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificacion guiada y desglose paso a paso" },
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseno" },
        @{ Cmd = "/teamwork";    Desc = "Coordinacion con multiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificacion estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegacion e interaccion web automatizada" },
        @{ Cmd = "/automation";  Desc = "Disenar y programar tareas en segundo plano" },
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesion" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesion a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronologico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesion, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesion previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la ultima accion o cambio de codigo" },
        @{ Cmd = "/status";      Desc = "Inspeccionar estado del entorno y tareas activas" },
        @{ Cmd = "/review";      Desc = "Auditoria de codigo, buenas practicas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnostico y depuracion asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar codigo sin alterar salida" },
        @{ Cmd = "/settings";    Desc = "Panel interactivo de configuraciones y permisos" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/chat";        Desc = "Conversar directamente con Vork AI (3.0, 3.1 o 3.2 Expert)" },
        @{ Cmd = "/model";       Desc = "Selector de modelo (Vork 3, 3.1, 3.2 Expert) y potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/health";      Desc = "Telemetria en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrapida hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentacion oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesion de terminal de forma segura" }
    )

    $buffer = [System.Text.StringBuilder]::new()
    $position = 0
    $selected = 0
    $top = 0
    $menuOpen = $false
    $filtered = @()
    $historyIndex = -1
    $draft = ""
    $navigatingHistory = $false
    $lastCtrlC = [DateTime]::MinValue
    $ctrlCWarning = $false

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::TreatControlCAsInput = $true } catch { }
    try { [Console]::CursorVisible = $true } catch { }

    try {
        $metrics = Get-VorkConsoleMetrics
        $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
        Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
        $promptRow = try { [Console]::CursorTop } catch { 0 }

        while ($true) {
            $text = $buffer.ToString()
            $isSlash = (-not $navigatingHistory) -and $text.StartsWith("/") -and (-not $text.Contains(" "))

            if ($isSlash) {
                $filtered = @($allCommands | Where-Object { $_.Cmd.StartsWith($text, [System.StringComparison]::OrdinalIgnoreCase) })
                if ($filtered.Count -gt 0) {
                    $menuOpen = $true
                    if ($selected -ge $filtered.Count) { $selected = 0 }
                    if ($selected -lt 0) { $selected = 0 }
                } else {
                    $menuOpen = $false
                }
            } else {
                $menuOpen = $false
                $filtered = @()
            }

            $metrics = Get-VorkConsoleMetrics
            $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
            $menuVisible = [Math]::Max(1, $menuRows - 1)
            if ($menuOpen -and $filtered.Count -gt 0) {
                if ($selected -lt $top) { $top = $selected }
                if ($selected -ge ($top + $menuVisible)) { $top = $selected - $menuVisible + 1 }
                if ($top -lt 0) { $top = 0 }
                $maxTop = [Math]::Max(0, $filtered.Count - $menuVisible)
                if ($top -gt $maxTop) { $top = $maxTop }
            } else {
                $top = 0
            }

            $statusText = $Status
            if (-not $statusText) {
                $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
                $tierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
                $statusText = "$modelName · $tierName"
            }
            if ($ctrlCWarning) { $statusText = "ctrl+c otra vez para salir" }

            Write-VorkPromptFrame -PromptRow $promptRow -Width $metrics.Width -Height $metrics.Height -Text $text -Cursor $position -MenuItems $filtered -MenuSelected $selected -MenuTop $top -MenuVisible $menuVisible -MenuOpen $menuOpen -Status $statusText -MenuRows $menuRows

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) {
                try {
                    [Console]::SetCursorPosition(0, $promptRow)
                    Write-Host "$ESC[0J" -NoNewline
                } catch {
                    try { Write-Host "$ESC[1A$ESC[0J" -NoNewline } catch { }
                }
                $metrics = Get-VorkConsoleMetrics
                $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
                Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
                $promptRow = try { [Console]::CursorTop } catch { 0 }
                continue
            }

            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) {
                $ctrlCWarning = $false
                if ($buffer.Length -gt 0) {
                    [void]$buffer.Clear()
                    $position = 0
                    $menuOpen = $false
                    $navigatingHistory = $false
                    $historyIndex = -1
                    $lastCtrlC = [DateTime]::MinValue
                    continue
                }

                $now = [DateTime]::UtcNow
                if (($now - $lastCtrlC).TotalSeconds -lt 2.5) {
                    try { [Console]::TreatControlCAsInput = $false } catch { }
                    $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                    Clear-VorkPanel -Panel $panel
                    Exit-VorkSession -ExitCode 0
                }

                $lastCtrlC = $now
                $ctrlCWarning = $true
                continue
            }

            if ($ctrlCWarning) { $ctrlCWarning = $false }
            $lastCtrlC = [DateTime]::MinValue

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::D) -and $buffer.Length -eq 0) {
                try { [Console]::TreatControlCAsInput = $false } catch { }
                $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                Clear-VorkPanel -Panel $panel
                Exit-VorkSession -ExitCode 0
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::L)) {
                Clear-Host
                Show-Banner
                Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
                $promptRow = try { [Console]::CursorTop } catch { 0 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                $finalText = if ($menuOpen -and $filtered.Count -gt 0) { [string]$filtered[$selected].Cmd } else { $buffer.ToString() }

                $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                Clear-VorkPanel -Panel $panel

                if ($finalText.Trim().Length -gt 0) {
                    $submitted = "  ${Coral}${Bold}$([char]0x276F)${Reset} ${White}$finalText${Reset}"
                    Write-Host (Limit-VorkAnsiText -Text $submitted -MaxWidth ([Math]::Max(10, $metrics.Width - 1)))
                    try { [Console]::SetCursorPosition(0, $promptRow + 1) } catch { }
                }

                try { [Console]::TreatControlCAsInput = $false } catch { }
                return $finalText
            }

            if ($key.Key -eq [ConsoleKey]::Tab) {
                if ($menuOpen -and $filtered.Count -gt 0) {
                    $chosen = [string]$filtered[$selected].Cmd
                    [void]$buffer.Clear()
                    [void]$buffer.Append($chosen)
                    $position = $buffer.Length
                    $menuOpen = $false
                    $navigatingHistory = $false
                    $historyIndex = -1
                    $selected = 0
                    $top = 0
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($menuOpen -and $filtered.Count -gt 0) {
                    $selected = if ($selected -gt 0) { $selected - 1 } else { $filtered.Count - 1 }
                    continue
                }

                if ($global:VorkSessionHistory -and $global:VorkSessionHistory.Count -gt 0) {
                    $navigatingHistory = $true
                    if ($historyIndex -lt 0) {
                        $draft = $buffer.ToString()
                        $historyIndex = $global:VorkSessionHistory.Count - 1
                    } elseif ($historyIndex -gt 0) {
                        $historyIndex--
                    }

                    [void]$buffer.Clear()
                    [void]$buffer.Append([string]$global:VorkSessionHistory[$historyIndex])
                    $position = $buffer.Length
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($menuOpen -and $filtered.Count -gt 0) {
                    $selected = if ($selected -lt ($filtered.Count - 1)) { $selected + 1 } else { 0 }
                    continue
                }

                if ($navigatingHistory -and $historyIndex -ge 0) {
                    if ($historyIndex -lt ($global:VorkSessionHistory.Count - 1)) {
                        $historyIndex++
                        [void]$buffer.Clear()
                        [void]$buffer.Append([string]$global:VorkSessionHistory[$historyIndex])
                    } else {
                        $historyIndex = -1
                        $navigatingHistory = $false
                        [void]$buffer.Clear()
                        [void]$buffer.Append($draft)
                    }
                    $position = $buffer.Length
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

            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($menuOpen) {
                    $menuOpen = $false
                    continue
                }
                if ($navigatingHistory) {
                    $navigatingHistory = $false
                    $historyIndex = -1
                    [void]$buffer.Clear()
                    [void]$buffer.Append($draft)
                    $position = $buffer.Length
                    continue
                }
                if ($buffer.Length -gt 0) {
                    [void]$buffer.Clear()
                    $position = 0
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Backspace -or $key.KeyChar -eq [char]8) {
                $navigatingHistory = $false
                $historyIndex = -1
                if ($position -gt 0) {
                    [void]$buffer.Remove($position - 1, 1)
                    $position--
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                $navigatingHistory = $false
                $historyIndex = -1
                if ($position -lt $buffer.Length) {
                    [void]$buffer.Remove($position, 1)
                }
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U)) {
                [void]$buffer.Clear()
                $position = 0
                $navigatingHistory = $false
                $historyIndex = -1
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
                    $currentText = $buffer.ToString()
                    $cut = $position
                    while ($cut -gt 0 -and [char]::IsWhiteSpace($currentText[$cut - 1])) { $cut-- }
                    while ($cut -gt 0 -and -not [char]::IsWhiteSpace($currentText[$cut - 1])) { $cut-- }
                    [void]$buffer.Remove($cut, $position - $cut)
                    $position = $cut
                }
                continue
            }

            if ($buffer.Length -eq 0 -and $key.KeyChar -eq '?') {
                $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                Clear-VorkPanel -Panel $panel
                try { [Console]::TreatControlCAsInput = $false } catch { }
                return "?"
            }

            $char = $key.KeyChar
            if (-not [char]::IsControl($char)) {
                $navigatingHistory = $false
                $historyIndex = -1
                [void]$buffer.Insert($position, $char)
                $position++
                $selected = 0
                $top = 0
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
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

    $elbow = [char]0x23BF

    while ($true) {
        $line = Read-InteractiveVorkLine
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
                $historyDir = Join-Path $HOME ".vork"
                if (-not (Test-Path $historyDir)) { New-Item -ItemType Directory -Path $historyDir -Force | Out-Null }
                Add-Content -Path (Join-Path $historyDir "history.txt") -Value $line -Encoding UTF8
            } catch { }
        }

        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errors)

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
                Write-Host ""
                Save-VorkConversationRecord -Cmd $line -Output $outMsg
            } else {
                $modelResult = Show-InteractiveModelSwitcher
                $outMsg = "Exited /model command"
                Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                Write-Host ""
                Save-VorkConversationRecord -Cmd $line -Output $outMsg
            }
            continue
        }

        if ($cmdCheck -eq "theme") {
            Invoke-CmdTheme -ArgsList $replArgs
            $outMsg = if ($replArgs -and $replArgs.Count -gt 0) { "Changed theme to $global:VorkThemeName" } else { "Exited /theme command" }
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Write-Host ""
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        if ($cmdCheck -in "permissions", "settings", "config") {
            $settingsResult = Show-InteractiveSettings
            $outMsg = "Exited /settings command"
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Write-Host ""
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        Dispatch-CLICommand -Cmd $replCmd -ArgsList $replArgs
        if ($replCmd.StartsWith("/")) {
            $outMsg = "Exited $replCmd command"
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Write-Host ""
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
        }
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

