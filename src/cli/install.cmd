@echo off
rem ==============================================================================
rem Vork CLI - Windows CMD Installer v1.0.3
rem Despliega el motor completo de Vork CLI consumiendo src/cli/src
rem ==============================================================================

setlocal enabledelayedexpansion

echo ========================================================
echo   Vork CLI v1.0.3 - Instalador Windows
echo   Motor de Agente IA Soberano y 9 Pilares Operacionales
echo ========================================================
echo.

set "SCRIPT_DIR=%~dp0"

rem 1. Si existe install.ps1 localmente en la misma carpeta, ejecutarlo directamente
if exist "%SCRIPT_DIR%install.ps1" (
    echo [INFO] Desplegando modulos locales desde %SCRIPT_DIR%src ...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*
    goto :done
)

rem 2. Si no es local, buscar PowerShell instalado para descarga remota
where powershell >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Desplegando modulos de Vork CLI con PowerShell...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex"
    goto :done
)

where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Desplegando modulos de Vork CLI con PowerShell Core...
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex"
    goto :done
)

echo [ERROR] Se requiere PowerShell o PowerShell Core para desplegar Vork CLI.
exit /b 1

:done
echo.
endlocal
