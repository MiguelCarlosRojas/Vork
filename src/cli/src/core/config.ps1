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
# IDENTIDAD DE DISPOSITIVO Y AISLAMIENTO DE USUARIO
# ========================================================
function Get-VorkDeviceIdentity {
    $dev = ""
    try {
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $dev = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.Trim() } else { "PC" }
        } elseif ($IsMacOS -or ($env:OSTYPE -like "*darwin*")) {
            $dev = (scutil --get ComputerName 2>$null)
            if (-not $dev) { $dev = (hostname -s 2>$null) }
        } else {
            $dev = if ($env:HOSTNAME) { $env:HOSTNAME.Trim() } else { (hostname 2>$null) }
        }
    } catch { }
    if (-not $dev) {
        $dev = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($env:HOSTNAME) { $env:HOSTNAME } else { "PC" }
    }
    $global:VorkDeviceName = $dev
    return $dev
}

$vorkBaseDir = Join-Path $HOME ".vork"
if (-not (Test-Path $vorkBaseDir)) { New-Item -ItemType Directory -Path $vorkBaseDir -Force | Out-Null }
$identityFile = Join-Path $vorkBaseDir "identity.json"
$global:VorkIdentity = $null

if (Test-Path $identityFile) {
    try {
        $global:VorkIdentity = Get-Content -Path $identityFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { }
}

$detectedDev = Get-VorkDeviceIdentity

if (-not $global:VorkIdentity -or -not $global:VorkIdentity.clientId) {
    $global:VorkIdentity = [pscustomobject]@{
        clientId       = [System.Guid]::NewGuid().ToString()
        installationId = [System.Guid]::NewGuid().ToString("N")
        deviceName     = $detectedDev
        username       = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { "User" }
        platform       = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { "windows" } else { "unix" }
        createdAt      = [DateTime]::UtcNow.ToString("o")
    }
    try {
        $global:VorkIdentity | ConvertTo-Json | Set-Content -Path $identityFile -Force -Encoding UTF8
    } catch { }
} else {
    # Actualizar dinámicamente si el usuario renombra su equipo
    if ($global:VorkIdentity.deviceName -ne $detectedDev) {
        $global:VorkIdentity.deviceName = $detectedDev
        try {
            $global:VorkIdentity | ConvertTo-Json | Set-Content -Path $identityFile -Force -Encoding UTF8
        } catch { }
    }
}

$global:VorkClientId = $global:VorkIdentity.clientId
$global:VorkDeviceName = $detectedDev

# ========================================================
# GESTIÓN DE ID DE CONVERSACIÓN & SESIÓN PERSISTENTE
# ========================================================
$convDir = $vorkBaseDir
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

$VorkVersion = "1.0.3"
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

    # ----------------------------------------------------
    # PALETA OSCURA DE ALTO CONTRASTE POR DEFECTO
    # ----------------------------------------------------
    $global:VorkIsLightMode = $false
    $global:White     = "$ESC[38;2;240;246;252m"
    $global:Gray      = "$ESC[38;2;120;128;140m"
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
# CATÁLOGO DE MODELOS & GESTIÓN DE ESFUERZO / POTENCIA
# ========================================================

function Get-VorkAvailableModels {
    $authFile = Join-Path $HOME ".vork\auth.json"
    $authData = @{}
    if (Test-Path $authFile) {
        try { $authData = Get-Content -Path $authFile -Raw | ConvertFrom-Json } catch { }
    }

    $models = @(
        # 1. Modo Automático (Rotación Inteligente)
        @{
            Id             = "auto"
            Name           = "Auto (Rotación Inteligente)"
            Provider       = "Vork Orchestrator"
            Badge          = "Recomendado"
            Power          = ""
            Desc           = "Elige automáticamente la mejor IA gratis según la tarea y rota si hay pausas"
            Ctx            = "Auto"
            SupportsEffort = $false
            IsVork         = $true
        },

        # 2. Perfiles Vork (únicos con niveles low / medium / high y expert)
        @{
            Id             = "Vork 3.2"
            Name           = "Vork 3.2 (Expert)"
            Provider       = "Vork Cloud IA"
            Badge          = "Expert"
            Power          = "Expert"
            Desc           = "Nivel expert de alta capacidad (superior a Vork 3 y Vork 3.1)"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $true
        },
        @{
            Id             = "Vork 3.1"
            Name           = "Vork 3.1"
            Provider       = "Vork Cloud IA"
            Badge          = "Avanzado"
            Power          = ""
            Desc           = "Modelo intermedio avanzado (superior a Vork 3, configurable en low/medium/high)"
            Ctx            = "64k"
            SupportsEffort = $true
            IsVork         = $true
        },
        @{
            Id             = "Vork 3"
            Name           = "Vork 3"
            Provider       = "Vork Cloud IA"
            Badge          = "Base"
            Power          = ""
            Desc           = "Modelo base ligero y ágil (configurable en low/medium/high)"
            Ctx            = "32k"
            SupportsEffort = $true
            IsVork         = $true
        },

        # 3. Modelos Soberanos Gratuitos con su propia potencia técnica
        # --- Google Gemini Series (Google AI Studio Free Tier) ---
        @{
            Id             = "google/gemini-2.0-flash"
            Name           = "Gemini 2.0 Flash"
            Provider       = if ($authData.gemini) { "Google AI Studio (Conectado)" } else { "Google AI Studio" }
            Badge          = if ($authData.gemini) { "Conectado" } else { "Flash" }
            Power          = "1M Multimodal"
            Desc           = "Multimodal nativo, visión y ventana de 1 millón de tokens"
            Ctx            = "1M"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "google/gemini-2.0-flash-lite"
            Name           = "Gemini 2.0 Flash-Lite"
            Provider       = if ($authData.gemini) { "Google AI Studio (Conectado)" } else { "Google AI Studio" }
            Badge          = if ($authData.gemini) { "Conectado" } else { "Lite" }
            Power          = "Flash-Lite"
            Desc           = "Inferencia ultrarrápida de baja latencia con 1M contexto y visión multimodal"
            Ctx            = "1M"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "google/gemini-2.0-flash-thinking-exp"
            Name           = "Gemini Flash Thinking"
            Provider       = if ($authData.gemini) { "Google AI Studio (Conectado)" } else { "Google AI Studio" }
            Badge          = if ($authData.gemini) { "Conectado" } else { "Thinking" }
            Power          = "Thinking 1M"
            Desc           = "Razonamiento reflexivo paso a paso y resolución matemática con visión"
            Ctx            = "1M"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "google/gemini-1.5-pro"
            Name           = "Gemini 1.5 Pro"
            Provider       = if ($authData.gemini) { "Google AI Studio (Conectado)" } else { "Google AI Studio" }
            Badge          = if ($authData.gemini) { "Conectado" } else { "Pro" }
            Power          = "2M Pro"
            Desc           = "Ventana colosal de 2 millones de tokens para análisis integral de repositorios"
            Ctx            = "2M"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- DeepSeek & Modelos de Razonamiento ---
        @{
            Id             = "deepseek/deepseek-r1-distill"
            Name           = "DeepSeek R1 Distill"
            Provider       = "Kilo Gateway"
            Badge          = "R1"
            Power          = "Razonamiento R1"
            Desc           = "Razonamiento matemático y lógica algorítmica compleja"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "deepseek/deepseek-r1-qwen-32b"
            Name           = "DeepSeek R1 Qwen 32B"
            Provider       = if ($authData.sambanova) { "SambaNova (Conectado)" } else { "Cloudflare / SambaNova" }
            Badge          = "R1 32B"
            Power          = "R1 Distill 32B"
            Desc           = "Lógica matemática y algorítmica destilada sobre base Qwen 2.5"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "qwen/qwq-32b"
            Name           = "Qwen QwQ 32B"
            Provider       = if ($authData.sambanova) { "SambaNova (Conectado)" } else { "Cloudflare / SambaNova" }
            Badge          = "QwQ"
            Power          = "Razonamiento QwQ"
            Desc           = "Modelo analítico avanzado con razonamiento profundo y planificación"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Meta Llama Series (Groq / Cerebras / Cloudflare) ---
        @{
            Id             = "meta-llama/llama-3.3-70b"
            Name           = "Llama 3.3 70B"
            Provider       = if ($authData.groq) { "Groq (Conectado)" } elseif ($authData.cerebras) { "Cerebras (Conectado)" } else { "Groq / Cerebras" }
            Badge          = if ($authData.groq -or $authData.cerebras) { "Conectado" } else { "Llama" }
            Power          = "70B Ultra"
            Desc           = "Velocidad extrema y multitarea (800+ tokens/seg)"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "meta-llama/llama-3.1-8b"
            Name           = "Llama 3.1 8B Instant"
            Provider       = if ($authData.cerebras) { "Cerebras (Conectado)" } elseif ($authData.groq) { "Groq (Conectado)" } else { "Groq / Cerebras" }
            Badge          = if ($authData.cerebras -or $authData.groq) { "Conectado" } else { "Turbo" }
            Power          = "8B Turbo"
            Desc           = "Inferencia a velocidad récord (hasta 2.100 tokens/s) para respuestas inmediatas"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "meta-llama/llama-3.2-11b-vision"
            Name           = "Llama 3.2 11B Vision"
            Provider       = if ($authData.groq) { "Groq (Conectado)" } else { "Groq / Cloudflare" }
            Badge          = "Visión"
            Power          = "11B Visión"
            Desc           = "Comprensión visual de código, interfaces gráficas y diagramas de arquitectura"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "meta-llama/llama-3.2-3b"
            Name           = "Llama 3.2 3B"
            Provider       = "Cloudflare / Groq"
            Badge          = "Edge"
            Power          = "3B Edge"
            Desc           = "Modelo ultraligero de inferencia instantánea sin fricción"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Qwen & Ingeniería de Software ---
        @{
            Id             = "qwen/qwen-2.5-coder-32b"
            Name           = "Qwen 2.5 Coder 32B"
            Provider       = if ($authData.sambanova) { "SambaNova (Conectado)" } else { "Hetzner / SambaNova" }
            Badge          = "Qwen"
            Power          = "32B Coder"
            Desc           = "Arquitectura de software y generación de pruebas unitarias"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Mistral AI Series (La Plateforme Experiment / Free) ---
        @{
            Id             = "mistralai/codestral-2501"
            Name           = "Codestral 2501"
            Provider       = if ($authData.mistral) { "Mistral AI (Conectado)" } else { "Mistral AI" }
            Badge          = if ($authData.mistral) { "Conectado" } else { "Code" }
            Power          = "Code 256k"
            Desc           = "Especialista en desarrollo de software, pruebas y refactor"
            Ctx            = "256k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "mistralai/mistral-small-latest"
            Name           = "Mistral Small 24B"
            Provider       = if ($authData.mistral) { "Mistral AI (Conectado)" } else { "Mistral AI" }
            Badge          = if ($authData.mistral) { "Conectado" } else { "Small" }
            Power          = "Small 24B"
            Desc           = "Razonamiento eficiente, fluidez multilingüe nativa y síntesis de ideas"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "mistralai/pixtral-12b"
            Name           = "Pixtral 12B Vision"
            Provider       = if ($authData.mistral) { "Mistral AI (Conectado)" } else { "Mistral AI" }
            Badge          = if ($authData.mistral) { "Conectado" } else { "Visión" }
            Power          = "12B Visión"
            Desc           = "Extracción visual de código, análisis de diagramas y comprensión gráfica"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- NVIDIA NIM & Soberanos ---
        @{
            Id             = "nvidia/nemotron-3-ultra-550b"
            Name           = "Nemotron 3 Ultra 550B"
            Provider       = "Kilo Gateway"
            Badge          = "Ultra"
            Power          = "550B Ultra"
            Desc           = "Razonamiento profundo, código y soberanía de datos"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "nvidia/llama-3.1-nemotron-70b-instruct"
            Name           = "Nemotron 70B Instruct"
            Provider       = if ($authData.nvidia) { "NVIDIA NIM (Conectado)" } else { "NVIDIA NIM" }
            Badge          = if ($authData.nvidia) { "Conectado" } else { "NIM" }
            Power          = "70B NIM"
            Desc           = "Aceleración por hardware NVIDIA para desarrollo y generación de código"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Z.ai BigModel Flash Series ---
        @{
            Id             = "zhipu/glm-4.7-flash"
            Name           = "GLM 4.7 Flash"
            Provider       = if ($authData.zai) { "Z.ai (Conectado)" } else { "Z.ai" }
            Badge          = if ($authData.zai) { "Conectado" } else { "Free" }
            Power          = "Flash"
            Desc           = "Inferencia ultraligera sin coste para tareas rápidas"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "zhipu/glm-4.6v-flash"
            Name           = "GLM 4.6V Flash Visión"
            Provider       = if ($authData.zai) { "Z.ai (Conectado)" } else { "Z.ai" }
            Badge          = if ($authData.zai) { "Conectado" } else { "Visión" }
            Power          = "Flash Visión"
            Desc           = "Visión artificial ultraligera y reconocimiento visual OCR sin coste"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- OpenRouter Free Tier ---
        @{
            Id             = "openrouter/free"
            Name           = "OpenRouter Auto Free"
            Provider       = if ($authData.openrouter) { "OpenRouter (Conectado)" } else { "OpenRouter" }
            Badge          = if ($authData.openrouter) { "Conectado" } else { "Free" }
            Power          = "Multi-IA Free"
            Desc           = "Enrutador soberano que rota automáticamente entre todos los modelos :free"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "google/gemma-2-9b-it:free"
            Name           = "Google Gemma 2 9B"
            Provider       = "OpenRouter"
            Badge          = "Gemma"
            Power          = "9B Gemma"
            Desc           = "Modelo de arquitectura abierta optimizado por Google en cluster gratis"
            Ctx            = "8k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Pollinations (Abierto sin registro ni API key) ---
        @{
            Id             = "gpt-oss-20b"
            Name           = "GPT-OSS 20B"
            Provider       = "Pollinations"
            Badge          = "Free"
            Power          = "20B"
            Desc           = "Conversación abierta sin registro con límites por IP"
            Ctx            = "32k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "pollinations/gpt-4o-mini"
            Name           = "GPT-4o Mini Free"
            Provider       = "Pollinations"
            Badge          = "Free"
            Power          = "Mini Open"
            Desc           = "Acceso comunitario a GPT-4o Mini sin registro ni límites de cuenta"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Repositorios Open-Source: Microsoft Phi Family ---
        @{
            Id             = "microsoft/phi-4"
            Name           = "Phi-4 Reasoning"
            Provider       = "Hugging Face / Azure"
            Badge          = "Phi"
            Power          = "14B Reasoner"
            Desc           = "Modelo compacto líder en benchmarks matemáticos, lógica y código"
            Ctx            = "16k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "microsoft/phi-3.5-mini"
            Name           = "Phi-3.5 Mini"
            Provider       = "Hugging Face Serverless"
            Badge          = "Phi"
            Power          = "3.8B Mini"
            Desc           = "Ventana de 128k tokens y alta capacidad analítica en tamaño ultra ligero"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Repositorios Enterprise: Cohere Trial Free Tier ---
        @{
            Id             = "cohere/command-r-plus"
            Name           = "Command R+"
            Provider       = if ($authData.cohere) { "Cohere (Conectado)" } else { "Cohere API" }
            Badge          = if ($authData.cohere) { "Conectado" } else { "Cohere" }
            Power          = "Enterprise RAG"
            Desc           = "Especializado en recuperación RAG, llamadas a herramientas y síntesis formal"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "cohere/command-r7b"
            Name           = "Command R7B"
            Provider       = if ($authData.cohere) { "Cohere (Conectado)" } else { "Cohere API" }
            Badge          = if ($authData.cohere) { "Conectado" } else { "7B" }
            Power          = "7B MultiLing"
            Desc           = "Motor multilingüe optimizado para flujos de trabajo rápidos y 23 idiomas"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "cohere/aya-expanse-32b"
            Name           = "Aya Expanse 32B"
            Provider       = if ($authData.cohere) { "Cohere (Conectado)" } else { "Cohere For AI" }
            Badge          = "Aya"
            Power          = "32B Global"
            Desc           = "Poderoso modelo multilingüe global entrenado en +70 lenguas del mundo"
            Ctx            = "8k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Repositorios y Clusters de Inferencia: SiliconFlow & DeepSeek Frontier ---
        @{
            Id             = "deepseek/deepseek-v3"
            Name           = "DeepSeek V3 671B"
            Provider       = if ($authData.siliconflow) { "SiliconFlow (Conectado)" } else { "SiliconFlow / Samba" }
            Badge          = "V3 MoE"
            Power          = "671B MoE"
            Desc           = "Arquitectura Mixture-of-Experts de 671B parámetros líder en generación de software"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "deepseek/deepseek-r1-distill-qwen-7b"
            Name           = "DeepSeek R1 Distill 7B"
            Provider       = if ($authData.siliconflow) { "SiliconFlow (Conectado)" } else { "SiliconFlow" }
            Badge          = "R1 7B"
            Power          = "R1 Distill 7B"
            Desc           = "Inferencia de razonamiento R1 ultra veloz optimizada para baja latencia"
            Ctx            = "32k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "qwen/qwen-2.5-7b"
            Name           = "Qwen 2.5 7B Instruct"
            Provider       = if ($authData.siliconflow) { "SiliconFlow (Conectado)" } else { "SiliconFlow / Hetzner" }
            Badge          = "7B"
            Power          = "7B Instruct"
            Desc           = "Inferencia instantánea con soporte multilingüe y resolución directa de dudas"
            Ctx            = "32k"
            SupportsEffort = $false
            IsVork         = $false
        },

        # --- Repositorios Open Weights Clásicos & Nano ---
        @{
            Id             = "mistralai/mistral-7b-v0.3"
            Name           = "Mistral 7B v0.3"
            Provider       = if ($authData.huggingface) { "Hugging Face (Conectado)" } else { "Hugging Face Serverless" }
            Badge          = "7B Open"
            Power          = "7B Open"
            Desc           = "El referente open-source de Mistral con soporte de llamada a funciones nativo"
            Ctx            = "32k"
            SupportsEffort = $false
            IsVork         = $false
        },
        @{
            Id             = "meta-llama/llama-3.2-1b"
            Name           = "Llama 3.2 1B Nano"
            Provider       = "Cloudflare / Hugging Face"
            Badge          = "1B Nano"
            Power          = "1B Nano"
            Desc           = "El modelo Llama más ligero y rápido jamás creado para asistencia inmediata"
            Ctx            = "128k"
            SupportsEffort = $false
            IsVork         = $false
        }
    )

    return $models
}

function Get-VorkActiveModelInfo {
    $models = Get-VorkAvailableModels
    $targetId = if ($global:VorkPinnedModel) { $global:VorkPinnedModel } elseif ($global:VorkModel) { $global:VorkModel } else { "auto" }

    $found = $models | Where-Object { $_.Id -eq $targetId -or $_.Name -eq $targetId } | Select-Object -First 1
    if (-not $found) {
        $isV = ($targetId -like "Vork*")
        $found = @{
            Id             = $targetId
            Name           = $targetId
            Provider       = "IA Externa"
            Badge          = ""
            Power          = ""
            Desc           = "Modelo configurado por el usuario"
            Ctx            = ""
            SupportsEffort = $false
            IsVork         = $isV
        }
    }
    return $found
}

# ========================================================
# MODELO ACTIVO & PERFIL DE ESFUERZO / POTENCIA
# ========================================================
$pinnedFile = Join-Path $HOME ".vork\.pinned_model"
if (Test-Path $pinnedFile) {
    $savedPinned = try { (Get-Content -Path $pinnedFile -Raw).Trim() } catch { "" }
    if ($savedPinned -and $savedPinned -ne "auto") {
        $global:VorkPinnedModel = $savedPinned
    }
}

$modelFile = Join-Path $HOME ".vork\.model"
if (-not $global:VorkModel) {
    if ($global:VorkPinnedModel) {
        $global:VorkModel = $global:VorkPinnedModel
    } elseif (Test-Path $modelFile) {
        $savedModel = try { (Get-Content -Path $modelFile -Raw).Trim() } catch { "Vork 3.1" }
        if ($savedModel -and $savedModel -ne "auto") {
            $global:VorkModel = $savedModel
        }
    }
    if (-not $global:VorkModel) {
        $global:VorkModel = if ($env:VORK_MODEL) { $env:VORK_MODEL } else { "Vork 3.1" }
    }
}

$activeInfo = Get-VorkActiveModelInfo
if ($activeInfo -and $activeInfo.Name) {
    $global:VorkModel = $activeInfo.Name
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

if ($activeInfo -and $activeInfo.IsVork) {
    if ($global:VorkModel -eq "Vork 3.2 (Expert)" -or $global:VorkModel -eq "Vork 3.2") {
        $global:VorkTier = "expert"
    } elseif ($global:VorkTier -notin @("low", "medium", "high")) {
        $global:VorkTier = if ($global:VorkModel -eq "Vork 3") { "low" } else { "medium" }
    }
} else {
    # Los modelos externos no usan tiers de Vork (se elimina el tier)
    $global:VorkTier = ""
}

# ========================================================
# MODO DE PERMISOS DEL AGENTE (programar, planear, profe) & YOLO
# ========================================================
$settingsFile = Join-Path $HOME ".vork\settings.json"
if (-not $global:VorkAgentMode -or $global:VorkYolo -eq $null) {
    if (Test-Path $settingsFile) {
        try {
            $savedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            if ($savedSettings.agent_mode -in @("programar", "planear", "profe")) {
                $global:VorkAgentMode = [string]$savedSettings.agent_mode
            }
            if ($savedSettings.auto_approve -eq "on") {
                $global:VorkYolo = $true
            }
        } catch { }
    }
    if (-not $global:VorkAgentMode) {
        $global:VorkAgentMode = "programar"
    }
    if ($global:VorkYolo -eq $null) {
        $global:VorkYolo = $false
    }
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
