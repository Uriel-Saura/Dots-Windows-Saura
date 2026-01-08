#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script para actualizar solo las configuraciones sin reinstalar aplicaciones
.DESCRIPTION
    Copia/crea enlaces simbólicos de los archivos de configuración a sus ubicaciones
#>

param(
    [switch]$Force  # Forzar sobrescritura
)

$ErrorActionPreference = "Continue"
$CONFIG_DIR = $PSScriptRoot
$USER_HOME = $env:USERPROFILE

function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "→ $args" -ForegroundColor Cyan }

function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-ConfigFile {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Description
    )
    
    $sourcePath = Join-Path $CONFIG_DIR $Source
    $targetPath = [System.Environment]::ExpandEnvironmentVariables($Target)
    
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "No encontrado: $sourcePath"
        return
    }
    
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    if (Test-Path $targetPath) {
        if ($Force) {
            Remove-Item $targetPath -Force -Recurse
        } else {
            Write-Warning "Ya existe: $Description (usa -Force para sobrescribir)"
            return
        }
    }
    
    try {
        if (Test-Administrator) {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force | Out-Null
            Write-Success "Enlace: $Description"
        } else {
            Copy-Item $sourcePath $targetPath -Force
            Write-Success "Copiado: $Description"
        }
    } catch {
        Copy-Item $sourcePath $targetPath -Force
        Write-Success "Copiado: $Description"
    }
}

Write-Host @"
╔════════════════════════════════════════════╗
║  Actualizador de Configuraciones          ║
╚════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

if (-not (Test-Administrator)) {
    Write-Warning "Sin permisos de admin - se copiarán archivos"
}

Write-Info "Actualizando configuraciones..."

# Windows Terminal
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path (Split-Path $wtSettings -Parent)) {
    Update-ConfigFile "WindowsTerminal\settings.json" $wtSettings "Windows Terminal"
}

# PowerShell Profile
$psProfile = $PROFILE.CurrentUserAllHosts
if (-not $psProfile) {
    $psProfile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}
Update-ConfigFile "WindowsTerminal\Microsoft.PowerShell_profile.ps1" $psProfile "PowerShell Profile"

# Oh My Posh
Update-ConfigFile "WindowsTerminal\pure.omp.json" "$env:USERPROFILE\.config\WindowsTerminal\pure.omp.json" "Oh My Posh"

# Fastfetch
Update-ConfigFile "fastfetch\config.jsonc" "$env:LOCALAPPDATA\fastfetch\config.jsonc" "Fastfetch config"
Update-ConfigFile "fastfetch\ascii.txt" "$env:LOCALAPPDATA\fastfetch\ascii.txt" "Fastfetch ASCII"

# YASB
$yasbDir = "$env:USERPROFILE\.yasb"
if (-not (Test-Path $yasbDir)) {
    New-Item -ItemType Directory -Path $yasbDir -Force | Out-Null
}
Update-ConfigFile "yasb\config.yaml" "$yasbDir\config.yaml" "YASB config"
Update-ConfigFile "yasb\styles.css" "$yasbDir\styles.css" "YASB styles"
Update-ConfigFile "yasb\update_colors.py" "$yasbDir\update_colors.py" "YASB updater"

# Firefox
$firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
if ($firefoxProfiles) {
    $defaultProfile = $firefoxProfiles | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1
    if ($defaultProfile) {
        $chromeDir = Join-Path $defaultProfile.FullName "chrome"
        if (-not (Test-Path $chromeDir)) {
            New-Item -ItemType Directory -Path $chromeDir -Force | Out-Null
        }
        Update-ConfigFile "firefox\userChrome.css" "$chromeDir\userChrome.css" "Firefox theme"
    }
}

# Flow Launcher
$flowThemes = "$env:APPDATA\FlowLauncher\Themes"
if (Test-Path $flowThemes) {
    Update-ConfigFile "FlowLaucnher\theme-wal.xaml" "$flowThemes\theme-wal.xaml" "Flow Launcher"
}

# Discord/Vencord
$vencordThemes = "$env:APPDATA\Vencord\themes"
if (Test-Path $vencordThemes) {
    Update-ConfigFile "Discord\midnight-paywall.theme.css" "$vencordThemes\midnight-paywall.theme.css" "Discord theme"
}

Write-Host ""
Write-Success "Configuraciones actualizadas"
Write-Info "Reinicia tus aplicaciones para ver los cambios"
