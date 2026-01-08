# 🎨 Windows Dotfiles - Configuración Automática

Configuración personal automatizada para Windows con temas dinámicos usando pywal.

## 📋 Características

- **Terminal personalizada**: Windows Terminal con Oh My Posh y tema Pure
- **Pywal**: Esquemas de color dinámicos desde wallpapers
- **YASB**: Barra de estado personalizada para Windows
- **Temas sincronizados**: Discord, Firefox, Flow Launcher, Obsidian
- **Fastfetch**: Información del sistema con ASCII art personalizado
- **Instalación automática**: Un script para configurar todo

## 🚀 Instalación Rápida

### Opción 1: Instalación completa (Recomendado)

```powershell
# Ejecutar como Administrador para enlaces simbólicos
cd C:\Users\uriel\.config
.\install.ps1
```

### Opción 2: Solo copiar configuraciones (sin permisos admin)

```powershell
.\install.ps1 -SkipInstall
```

### Opción 3: Solo instalar aplicaciones

```powershell
.\install.ps1
# Luego copiar manualmente los archivos de configuración
```

## 📦 Qué se instala

### Gestores de paquetes
- **Scoop**: Package manager para Windows
- **Winget**: Si no está disponible, se intentará usar

### Aplicaciones principales
- **Python 3.12**: Para scripts de automatización
- **Oh My Posh**: Prompt personalizado para PowerShell
- **Fastfetch**: Información del sistema
- **Git**: Control de versiones
- **Firefox**: Navegador con userChrome personalizado
- **Flow Launcher**: Lanzador de aplicaciones
- **Obsidian**: Editor de notas
- **FiraCode Nerd Font**: Fuente con iconos

### Paquetes Python
- **pywal**: Generador de esquemas de color
- **Pillow**: Procesamiento de imágenes
- **PyYAML**: Parser de YAML
- **YASB**: Barra de estado

## 🎯 Opciones del instalador

```powershell
# Ver solo el estado actual (no instala nada)
.\install.ps1 -CheckOnly

# Saltar instalación de aplicaciones
.\install.ps1 -SkipInstall

# Forzar sobrescritura de archivos existentes
.\install.ps1 -Force

# Combinación de opciones
.\install.ps1 -SkipInstall -Force
```

## 📁 Estructura de archivos

```
.config/
├── Discord/              # Tema de Discord/Vencord
├── fastfetch/           # Configuración de fastfetch
├── firefox/             # userChrome.css
├── FlowLaucnher/        # Tema de Flow Launcher
├── Obsidian/            # Tema pywal para Obsidian
├── wal/                 # Esquemas de color y templates
├── WindowsTerminal/     # Config de terminal y PowerShell
├── yasb/                # Barra de estado personalizada
├── install.ps1          # Script de instalación principal
├── update-configs.ps1   # Actualizar solo configuraciones
└── README.md            # Este archivo
```

## 🎨 Uso de Pywal

### Generar esquema de color desde un wallpaper

```powershell
# Generar colores
wal -i "C:\ruta\a\tu\wallpaper.jpg"

# Actualizar todas las aplicaciones con los nuevos colores
python C:\Users\uriel\.yasb\update_colors.py "C:\ruta\a\tu\wallpaper.jpg"
```

### Actualizar colores automáticamente

El script `update_colors.py` actualiza:
- YASB (barra de estado)
- Windows Terminal
- Discord/Vencord
- Firefox
- Flow Launcher
- Obsidian

## 🔧 Configuración manual adicional

### Firefox
1. Ve a `about:config`
2. Busca `toolkit.legacyUserProfileCustomizations.stylesheets`
3. Cambia el valor a `true`
4. Reinicia Firefox

### Obsidian
1. Copia `Obsidian/pywal.css` a `TuVault/.obsidian/themes/`
2. En Obsidian: Settings → Appearance → Themes → Pywal

### Discord (Vencord)
1. Instala [Vencord](https://vencord.dev/)
2. El tema se copiará automáticamente a `%APPDATA%\Vencord\themes`
3. Actívalo en Settings → Vencord → Themes

### GlazeWM (Opcional)
Si usas GlazeWM como window manager:

```powershell
scoop install glazewm
```

## 🔄 Actualizar configuraciones

Si solo necesitas actualizar los archivos de configuración (sin reinstalar apps):

```powershell
.\update-configs.ps1
```

O con el instalador principal:

```powershell
.\install.ps1 -SkipInstall -Force
```

## 🖥️ YASB - Barra de Estado

### Iniciar YASB

```powershell
yasb
```

### Configurar inicio automático

1. Presiona `Win + R`
2. Escribe `shell:startup`
3. Crea un acceso directo a:
   ```
   pythonw -m yasb
   ```

## 🐛 Solución de problemas

### Los enlaces simbólicos no se crean
- Ejecuta el script como Administrador: `gsudo .\install.ps1`
- O usa `-Force` para copiar archivos en lugar de enlaces

### Oh My Posh no se carga
- Verifica que la ruta en el profile sea correcta
- Reinicia tu terminal completamente

### Pywal no encuentra el comando
- Asegúrate de que Python esté en el PATH
- Reinstala: `pip install --upgrade pywal`

### YASB no inicia
- Verifica que Python 3.12+ esté instalado
- Reinstala: `pip install --upgrade yasb`

### Fastfetch no encuentra el config
- Verifica la ruta en el PowerShell profile
- Usa rutas absolutas en lugar de relativas

## 📝 Personalización

### Modificar el tema de Oh My Posh
Edita `WindowsTerminal/pure.omp.json`

### Cambiar colores de YASB
Edita `yasb/styles.css` o regenera con pywal

### Personalizar la barra YASB
Edita `yasb/config.yaml` para cambiar widgets y layout

## 🔗 Enlaces útiles

- [Oh My Posh Themes](https://ohmyposh.dev/docs/themes)
- [Pywal Wiki](https://github.com/dylanaraps/pywal/wiki)
- [YASB Documentation](https://github.com/amnweb/yasb)
- [Flow Launcher](https://www.flowlauncher.com/)
- [Vencord](https://vencord.dev/)

## 📜 Licencia

Libre para uso personal. Modifica y adapta a tu gusto.

## 🤝 Contribuir

Siéntete libre de hacer fork y personalizar para tu propio uso.

---

**Nota**: Este setup está optimizado para Windows 10/11. Algunas funciones pueden requerir ajustes en versiones anteriores.
