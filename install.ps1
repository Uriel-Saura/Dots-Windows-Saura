#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de instalación y configuración automática del entorno
.DESCRIPTION
    Instala todas las dependencias necesarias y configura enlaces simbólicos
    para los archivos de configuración en Windows.
.NOTES
    Requiere ejecutarse como Administrador para crear enlaces simbólicos
#>

#Requires -Version 5.1

param(
    [switch]$SkipInstall,      # Saltar instalación de aplicaciones
    [switch]$Force,            # Forzar sobrescritura de archivos existentes
    [switch]$CheckOnly,        # Solo verificar el estado actual
    [switch]$Uninstall         # Desinstalar todo
)

# Configuración
$ErrorActionPreference = "Continue"
$CONFIG_DIR = $PSScriptRoot
$USER_HOME = $env:USERPROFILE

# Colores para output
function Write-Step { Write-Host "→ $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Blue }

# Verificar si se ejecuta como administrador
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Verificar si una aplicación está instalada
function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Instalar Scoop si no está instalado
function Install-Scoop {
    if (-not (Test-CommandExists "scoop")) {
        Write-Step "Instalando Scoop package manager..."
        
        # Advertir si se ejecuta como admin
        if (Test-Administrator) {
            Write-Warning "Ejecutando como Administrador - Scoop puede fallar"
            Write-Info "Si falla, cierra este terminal y ejecuta sin privilegios admin"
        }
        
        try {
            # Instalar Scoop sin interacción
            irm get.scoop.sh -outfile 'install.ps1'
            .\install.ps1 -RunAsAdmin
            Remove-Item .\install.ps1
            Write-Success "Scoop instalado correctamente"
        } catch {
            Write-Warning "Error al instalar Scoop: $_"
            Write-Info "Continúa sin Scoop - usa Winget para instalar aplicaciones"
            return $false
        }
    } else {
        Write-Success "Scoop ya está instalado"
    }
    return $true
}

# Instalar Winget packages
function Install-WingetPackages {
    Write-Step "Verificando e instalando aplicaciones vía Winget..."
    
    if (-not (Test-CommandExists "winget")) {
        Write-Warning "Winget no está disponible en este sistema"
        Write-Info "Instala Winget desde Microsoft Store o continúa con Scoop"
        return
    }
    
    $wingetApps = @(
        @{Name="Git.Git"; Display="Git"},
        @{Name="Python.Python.3.12"; Display="Python 3.12"},
        @{Name="Mozilla.Firefox"; Display="Firefox"},
        @{Name="FlowLauncher.FlowLauncher"; Display="Flow Launcher"},
        @{Name="Obsidian.Obsidian"; Display="Obsidian"}
    )
    
    foreach ($app in $wingetApps) {
        Write-Step "Verificando $($app.Display)..."
        
        # Verificar si ya está instalado
        $installed = winget list --id $app.Name 2>&1 | Select-String $app.Name
        
        if (-not $installed) {
            Write-Info "→ Instalando $($app.Display) vía Winget..."
            
            try {
                $result = winget install -e --id $app.Name --silent --accept-package-agreements --accept-source-agreements 2>&1
                
                # Verificar el resultado
                if ($LASTEXITCODE -eq 0 -or $result -like "*Successfully installed*") {
                    Write-Success "$($app.Display) instalado correctamente"
                } else {
                    Write-Warning "$($app.Display) - Instalación completada con advertencias"
                }
            } catch {
                Write-Warning "Error al instalar $($app.Display): $_"
            }
        } else {
            Write-Success "$($app.Display) ya está instalado"
        }
    }
    
    Write-Success "Instalación vía Winget completada"
}

# Instalar aplicaciones vía Scoop
function Install-ScoopPackages {
    if (-not (Test-CommandExists "scoop")) {
        Write-Warning "Scoop no está instalado, saltando instalación de paquetes"
        return
    }
    
    Write-Step "Instalando paquetes vía Scoop..."
    
    # Agregar buckets necesarios
    $buckets = @("extras", "nerd-fonts")
    foreach ($bucket in $buckets) {
        $hasBucket = scoop bucket list | Select-String $bucket
        if (-not $hasBucket) {
            Write-Step "Agregando bucket '$bucket'..."
            scoop bucket add $bucket
        }
    }
    
    # Lista de aplicaciones a instalar
    $apps = @(
        "oh-my-posh",
        "fastfetch",
        "python",
        "git",
        "gsudo"
    )
    
    foreach ($app in $apps) {
        $installed = scoop list | Select-String "^$app "
        if (-not $installed) {
            Write-Step "Instalando $app..."
            scoop install $app
        } else {
            Write-Success "$app ya está instalado"
        }
    }
    
    # Instalar fuente Nerd Font
    Write-Step "Instalando FiraCode Nerd Font..."
    $fontInstalled = scoop list | Select-String "FiraCode-NF"
    if (-not $fontInstalled) {
        scoop install FiraCode-NF
    } else {
        Write-Success "FiraCode Nerd Font ya está instalada"
    }
}

# Instalar paquetes Python
function Install-PythonPackages {
    if (-not (Test-CommandExists "python")) {
        Write-Warning "Python no está instalado, saltando instalación de paquetes Python"
        return
    }
    
    Write-Step "Instalando paquetes Python..."
    
    $pythonPackages = @(
        "pywal",
        "pillow",
        "PyYAML"
    )
    
    foreach ($package in $pythonPackages) {
        Write-Step "Instalando $package..."
        python -m pip install --upgrade $package 2>&1 | Out-Null
    }
    
    Write-Success "Paquetes Python instalados"
}

# Crear enlace simbólico o copiar archivo
function New-ConfigLink {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Description
    )
    
    $sourcePath = Join-Path $CONFIG_DIR $Source
    $targetPath = [System.Environment]::ExpandEnvironmentVariables($Target)
    
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "Archivo fuente no existe: $sourcePath"
        return
    }
    
    # Crear directorio destino si no existe
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Info "Directorio creado: $targetDir"
    }
    
    # Si el destino ya existe
    if (Test-Path $targetPath) {
        if ($Force) {
            Remove-Item $targetPath -Force -Recurse
            Write-Info "Archivo existente eliminado: $targetPath"
        } else {
            Write-Warning "Ya existe: $targetPath (usa -Force para sobrescribir)"
            return
        }
    }
    
    # Intentar crear enlace simbólico
    try {
        if (Test-Administrator) {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force | Out-Null
            Write-Success "Link creado: $Description"
        } else {
            Copy-Item $sourcePath $targetPath -Force
            Write-Success "Copiado: $Description"
        }
    } catch {
        # Si falla, copiar el archivo
        Copy-Item $sourcePath $targetPath -Force
        Write-Success "Copiado (fallback): $Description"
    }
}

# Crear enlaces simbólicos para configuraciones
function New-ConfigLinks {
    Write-Step "Creando enlaces simbólicos/copiando configuraciones..."
    
    # Windows Terminal
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path (Split-Path $wtSettingsPath -Parent)) {
        New-ConfigLink "WindowsTerminal\settings.json" $wtSettingsPath "Windows Terminal settings"
    }
    
    # PowerShell Profile
    $psProfile = $PROFILE.CurrentUserAllHosts
    if (-not $psProfile) {
        $psProfile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    }
    New-ConfigLink "WindowsTerminal\Microsoft.PowerShell_profile.ps1" $psProfile "PowerShell Profile"
    
    # Oh My Posh theme
    New-ConfigLink "WindowsTerminal\pure.omp.json" "$env:USERPROFILE\.config\WindowsTerminal\pure.omp.json" "Oh My Posh theme"
    
    # Fastfetch
    New-ConfigLink "fastfetch\config.jsonc" "$env:LOCALAPPDATA\fastfetch\config.jsonc" "Fastfetch config"
    New-ConfigLink "fastfetch\ascii.txt" "$env:LOCALAPPDATA\fastfetch\ascii.txt" "Fastfetch ASCII art"
    
    # Firefox (solo si existe el perfil)
    $firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
    if ($firefoxProfiles) {
        $defaultProfile = $firefoxProfiles | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1
        if ($defaultProfile) {
            $chromeDir = Join-Path $defaultProfile.FullName "chrome"
            New-Item -ItemType Directory -Path $chromeDir -Force | Out-Null
            New-ConfigLink "firefox\userChrome.css" "$chromeDir\userChrome.css" "Firefox userChrome.css"
        }
    }
    
    # Flow Launcher theme
    $flowThemesDir = "$env:APPDATA\FlowLauncher\Themes"
    if (Test-Path $flowThemesDir) {
        New-ConfigLink "FlowLaucnher\theme-wal.xaml" "$flowThemesDir\theme-wal.xaml" "Flow Launcher theme"
    }
    
    # Discord/Vencord theme
    $vencordThemesDir = "$env:APPDATA\Vencord\themes"
    if (Test-Path $vencordThemesDir) {
        New-ConfigLink "Discord\midnight-paywall.theme.css" "$vencordThemesDir\midnight-paywall.theme.css" "Discord theme"
    }
    
    # Obsidian theme (requiere saber la ubicación del vault)
    Write-Info "Obsidian theme: Copia manualmente 'Obsidian\pywal.css' a tu vault/.obsidian/themes/"
    
    Write-Success "Enlaces de configuración completados"
}

# Instalar YASB (Yet Another Status Bar)
function Install-YASB {
    Write-Step "Configurando YASB..."
    
    if (-not (Test-CommandExists "python")) {
        Write-Warning "Python no instalado, saltando YASB"
        return
    }
    
    # Verificar si YASB está instalado
    $yasbInstalled = python -m pip list | Select-String "yasb"
    if (-not $yasbInstalled) {
        Write-Step "Instalando YASB..."
        python -m pip install yasb
    } else {
        Write-Success "YASB ya está instalado"
    }
    
    # Crear enlaces para config de YASB
    $yasbConfigDir = "$env:USERPROFILE\.yasb"
    if (-not (Test-Path $yasbConfigDir)) {
        New-Item -ItemType Directory -Path $yasbConfigDir -Force | Out-Null
    }
    
    New-ConfigLink "yasb\config.yaml" "$yasbConfigDir\config.yaml" "YASB config"
    New-ConfigLink "yasb\styles.css" "$yasbConfigDir\styles.css" "YASB styles"
    New-ConfigLink "yasb\update_colors.py" "$yasbConfigDir\update_colors.py" "YASB color updater"
}

# Configurar Git
function Set-GitConfig {
    if (-not (Test-CommandExists "git")) {
        Write-Warning "Git no instalado, saltando configuración"
        return
    }
    
    Write-Step "Configurando Git..."
    
    # Copiar config de jgit si existe
    if (Test-Path "$CONFIG_DIR\jgit\config") {
        $gitConfigDir = "$env:USERPROFILE\.jgit"
        New-Item -ItemType Directory -Path $gitConfigDir -Force | Out-Null
        Copy-Item "$CONFIG_DIR\jgit\config" "$gitConfigDir\config" -Force
        Write-Success "Configuración Git copiada"
    }
}

# Crear directorios necesarios
function New-RequiredDirectories {
    Write-Step "Creando directorios necesarios..."
    
    $dirs = @(
        "$env:USERPROFILE\.cache\wal",
        "$env:USERPROFILE\.config\wal\colorschemes\dark",
        "$env:USERPROFILE\.config\wal\colorschemes\light",
        "$env:USERPROFILE\.config\wal\templates"
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Info "Creado: $dir"
        }
    }
    
    Write-Success "Directorios creados"
}

# Verificar estado actual
function Show-Status {
    Write-Host "`n=== ESTADO DEL SISTEMA ===" -ForegroundColor Magenta
    
    $checks = @(
        @{Name="Scoop"; Command="scoop"},
        @{Name="Winget"; Command="winget"},
        @{Name="Python"; Command="python"},
        @{Name="Git"; Command="git"},
        @{Name="Oh My Posh"; Command="oh-my-posh"},
        @{Name="Fastfetch"; Command="fastfetch"},
        @{Name="Pywal"; Command="wal"},
        @{Name="YASB"; Command="yasb"}
    )
    
    foreach ($check in $checks) {
        $exists = Test-CommandExists $check.Command
        if ($exists) {
            Write-Host "  ✓ $($check.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($check.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== ARCHIVOS DE CONFIGURACIÓN ===" -ForegroundColor Magenta
    
    $configs = @(
        @{Name="Windows Terminal"; Path="$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"},
        @{Name="PowerShell Profile"; Path=$PROFILE.CurrentUserAllHosts},
        @{Name="Fastfetch Config"; Path="$env:LOCALAPPDATA\fastfetch\config.jsonc"},
        @{Name="YASB Config"; Path="$env:USERPROFILE\.yasb\config.yaml"}
    )
    
    foreach ($config in $configs) {
        if ($config.Path -and (Test-Path $config.Path)) {
            Write-Host "  ✓ $($config.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($config.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

# Desinstalar todo
function Uninstall-All {
    Write-Host @"
╔════════════════════════════════════════════╗
║  DESINSTALACIÓN COMPLETA                  ║
║  ⚠ Esta acción eliminará aplicaciones    ║
╚════════════════════════════════════════════╝
"@ -ForegroundColor Red
    
    Write-Host ""
    $confirm = Read-Host "¿Estás seguro de desinstalar todo? (escribe 'SI' para confirmar)"
    
    if ($confirm -ne "SI") {
        Write-Info "Desinstalación cancelada"
        return
    }
    
    Write-Host "`n[1/5] Eliminando configuraciones..." -ForegroundColor Yellow
    
    # Lista de archivos de configuración a eliminar
    $configFiles = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        $PROFILE.CurrentUserAllHosts,
        "$env:USERPROFILE\.config\WindowsTerminal\pure.omp.json",
        "$env:LOCALAPPDATA\fastfetch\config.jsonc",
        "$env:LOCALAPPDATA\fastfetch\ascii.txt",
        "$env:USERPROFILE\.yasb\config.yaml",
        "$env:USERPROFILE\.yasb\styles.css",
        "$env:USERPROFILE\.yasb\update_colors.py"
    )
    
    foreach ($file in $configFiles) {
        if ($file -and (Test-Path $file)) {
            try {
                Remove-Item $file -Force -ErrorAction Stop
                Write-Success "Eliminado: $file"
            } catch {
                Write-Warning "No se pudo eliminar: $file"
            }
        }
    }
    
    # Directorios de configuración
    $configDirs = @(
        "$env:USERPROFILE\.yasb",
        "$env:USERPROFILE\.cache\wal",
        "$env:USERPROFILE\.config\wal",
        "$env:LOCALAPPDATA\fastfetch"
    )
    
    foreach ($dir in $configDirs) {
        if (Test-Path $dir) {
            try {
                Remove-Item $dir -Recurse -Force -ErrorAction Stop
                Write-Success "Directorio eliminado: $dir"
            } catch {
                Write-Warning "No se pudo eliminar: $dir"
            }
        }
    }
    
    Write-Host "`n[2/5] Desinstalando paquetes Python..." -ForegroundColor Yellow
    
    if (Test-CommandExists "python") {
        $pythonPackages = @("yasb", "pywal", "pillow", "PyYAML")
        
        foreach ($package in $pythonPackages) {
            Write-Step "Desinstalando $package..."
            python -m pip uninstall -y $package 2>&1 | Out-Null
        }
        
        Write-Success "Paquetes Python desinstalados"
    } else {
        Write-Info "Python no encontrado, saltando"
    }
    
    Write-Host "`n[3/5] Desinstalando aplicaciones Scoop..." -ForegroundColor Yellow
    
    if (Test-CommandExists "scoop") {
        $scoopApps = @("oh-my-posh", "fastfetch", "gsudo", "FiraCode-NF")
        
        foreach ($app in $scoopApps) {
            Write-Step "Desinstalando $app..."
            scoop uninstall $app 2>&1 | Out-Null
        }
        
        Write-Success "Aplicaciones Scoop desinstaladas"
        
        $removeScoopConfirm = Read-Host "`n¿Eliminar Scoop completamente? (S/N)"
        if ($removeScoopConfirm -eq "S" -or $removeScoopConfirm -eq "s") {
            Write-Step "Eliminando Scoop..."
            scoop uninstall scoop
            Remove-Item "$env:USERPROFILE\scoop" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Scoop eliminado"
        }
    } else {
        Write-Info "Scoop no encontrado, saltando"
    }
    
    Write-Host "`n[4/5] Desinstalando aplicaciones Winget..." -ForegroundColor Yellow
    
    if (Test-CommandExists "winget") {
        $wingetApps = @(
            @{Name="Git.Git"; Display="Git"},
            @{Name="Python.Python.3.12"; Display="Python 3.12"},
            @{Name="Mozilla.Firefox"; Display="Firefox"},
            @{Name="FlowLauncher.FlowLauncher"; Display="Flow Launcher"},
            @{Name="Obsidian.Obsidian"; Display="Obsidian"}
        )
        
        $uninstallConfirm = Read-Host "`n¿Desinstalar aplicaciones de Winget? (S/N)"
        if ($uninstallConfirm -eq "S" -or $uninstallConfirm -eq "s") {
            foreach ($app in $wingetApps) {
                Write-Step "Desinstalando $($app.Display)..."
                winget uninstall -e --id $app.Name --silent 2>&1 | Out-Null
            }
            Write-Success "Aplicaciones Winget desinstaladas"
        } else {
            Write-Info "Aplicaciones Winget conservadas"
        }
    } else {
        Write-Info "Winget no encontrado, saltando"
    }
    
    Write-Host "`n[5/5] Limpieza final..." -ForegroundColor Yellow
    
    # Limpiar variables de entorno del perfil
    if (Test-Path $PROFILE.CurrentUserAllHosts) {
        Write-Info "Perfil de PowerShell eliminado - Crea uno nuevo si es necesario"
    }
    
    Write-Host ""
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║  DESINSTALACIÓN COMPLETADA                                    ║
╚════════════════════════════════════════════════════════════════╝

Se han eliminado:
✓ Configuraciones
✓ Paquetes Python
✓ Enlaces simbólicos
✓ Directorios de cache

Notas:
- Reinicia tu terminal para aplicar cambios
- Algunas aplicaciones pueden requerir reinicio manual desde Windows
- Los wallpapers en C:\Users\uriel\.config\Wallpapers NO fueron eliminados

"@ -ForegroundColor Cyan
    
    Write-Success "¡Desinstalación completada!"
}

# Función principal
function Main {
    Write-Host @"
╔════════════════════════════════════════════╗
║  Setup de Configuración Automático        ║
║  Windows Dotfiles Installer               ║
╚════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    # Si es desinstalación
    if ($Uninstall) {
        Uninstall-All
        return
    }
    
    # Si es solo verificación
    if ($CheckOnly) {
        Show-Status
        return
    }
    
    # Verificar permisos de administrador
    if (-not (Test-Administrator)) {
        Write-Warning "No se está ejecutando como Administrador"
        Write-Info "Se copiarán archivos en lugar de crear enlaces simbólicos"
        Write-Info "Para crear enlaces simbólicos, ejecuta: gsudo .\install.ps1"
        Write-Host ""
    } else {
        Write-Success "Ejecutando como Administrador"
    }
    
    # Instalar aplicaciones
    if (-not $SkipInstall) {
        Write-Host "`n[1/7] Instalación de dependencias" -ForegroundColor Yellow
        
        # Primero Winget (incluye Git)
        Install-WingetPackages
        
        # Luego Scoop (puede fallar con admin)
        Install-Scoop
        Install-ScoopPackages
        
        # Finalmente paquetes Python
        Install-PythonPackages
    } else {
        Write-Info "Saltando instalación de aplicaciones (-SkipInstall)"
    }
    
    # Crear directorios
    Write-Host "`n[2/7] Creación de directorios" -ForegroundColor Yellow
    New-RequiredDirectories
    
    # Configurar enlaces
    Write-Host "`n[3/7] Configuración de enlaces simbólicos" -ForegroundColor Yellow
    New-ConfigLinks
    
    # Instalar YASB
    Write-Host "`n[4/7] Instalación de YASB" -ForegroundColor Yellow
    Install-YASB
    
    # Configurar Git
    Write-Host "`n[5/7] Configuración de Git" -ForegroundColor Yellow
    Set-GitConfig
    
    # Mostrar estado
    Write-Host "`n[6/7] Verificación final" -ForegroundColor Yellow
    Show-Status
    
    # Instrucciones finales
    Write-Host "`n[7/7] Pasos finales" -ForegroundColor Yellow
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║  INSTALACIÓN COMPLETADA                                       ║
╚════════════════════════════════════════════════════════════════╝

Pasos adicionales recomendados:

1. Reinicia tu terminal para aplicar los cambios
2. Configura pywal con tu wallpaper favorito:
   wal -i "C:\Users\uriel\wallpaper.jpg"
   
3. Para actualizar colores en todas las apps:
   python "$env:USERPROFILE\.yasb\update_colors.py" "ruta\a\wallpaper.jpg"

4. Inicia YASB (barra de estado):
   yasb

5. Para Firefox: Ve a about:config y habilita 'toolkit.legacyUserProfileCustomizations.stylesheets'

6. Para Obsidian: Copia manualmente el tema pywal.css a tu vault

7. Si usas GlazeWM, instálalo con: scoop install glazewm

"@ -ForegroundColor Cyan

    Write-Success "¡Setup completado!"
}

# Ejecutar script principal
Main
