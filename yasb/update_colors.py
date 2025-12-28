#!/usr/bin/env python3
"""
Script para extraer colores del wallpaper usando pywal e insertarlos en styles.css
Extrae los 16 colores del esquema de pywal y los aplica a las variables CSS.
"""

import subprocess
import json
import re
import sys
import os
from pathlib import Path

# Ruta del archivo CSS
CSS_FILE = Path(__file__).parent / "styles.css"
# Ruta del tema de Vencord
VENCORD_THEME_FILE = Path(r"c:\Users\uriel\AppData\Roaming\Vencord\themes\midnight-paywall.theme.css")
# Ruta del tema de Firefox
FIREFOX_CSS_FILE = Path(r"c:\Users\uriel\AppData\Roaming\Mozilla\Firefox\Profiles\ui3arn7s.default-release\chrome\userChrome.css")
# Ruta del settings.json de Windows Terminal
WINDOWS_TERMINAL_SETTINGS = Path(r"c:\Users\uriel\.config\WindowsTerminal\settings.json")

def get_wallpaper_path():
    """Obtiene la ruta del wallpaper actual o solicita una."""
    if len(sys.argv) > 1:
        return sys.argv[1]
    
    # Intentar obtener el wallpaper desde el cache de wal
    wal_cache = Path.home() / ".cache" / "wal" / "wal"
    if wal_cache.exists():
        with open(wal_cache, 'r') as f:
            return f.read().strip()
    
    print("Uso: python update_colors.py <ruta_del_wallpaper>")
    print("O ejecuta 'wal -i <imagen>' primero para generar los colores.")
    sys.exit(1)

def generate_colors(wallpaper_path):
    """Genera los colores usando pywal."""
    print(f"Generando colores desde: {wallpaper_path}")
    
    try:
        # Ejecutar wal para generar los colores
        subprocess.run(
            ["wal", "-i", wallpaper_path, "-n", "-q"],
            check=True,
            capture_output=True
        )
    except FileNotFoundError:
        print("Error: pywal no está instalado.")
        print("Instálalo con: pip install pywal")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error al ejecutar wal: {e}")
        sys.exit(1)

def load_wal_colors():
    """Carga los colores generados por pywal."""
    colors_file = Path.home() / ".cache" / "wal" / "colors.json"
    
    if not colors_file.exists():
        print("Error: No se encontró el archivo de colores de wal.")
        print("Ejecuta 'wal -i <imagen>' primero.")
        sys.exit(1)
    
    with open(colors_file, 'r') as f:
        return json.load(f)

def update_file_colors(file_path, color_mapping):
    """Actualiza un archivo CSS con los nuevos colores."""
    if not file_path.exists():
        print(f"Advertencia: No se encontró el archivo: {file_path}")
        return

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Reemplazar cada variable de color
        updated = False
        for var_name, new_color in color_mapping.items():
            # Patrón para encontrar la declaración de la variable
            pattern = rf"({re.escape(var_name)}:\s*)#[0-9a-fA-F]{{6}}"
            replacement = rf"\g<1>{new_color}"
            new_content = re.sub(pattern, replacement, content)
            if new_content != content:
                content = new_content
                updated = True
        
        if updated:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✓ Actualizado: {file_path}")
        else:
            print(f"ℹ Sin cambios necesarios en: {file_path}")
            
    except Exception as e:
        print(f"Error actualizando {file_path}: {e}")

def read_css_variables(css_file_path):
    """Lee las variables CSS de un archivo y las extrae."""
    variables = {}
    
    if not css_file_path.exists():
        print(f"Error: No se encontró el archivo: {css_file_path}")
        return variables
    
    try:
        with open(css_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Buscar todas las variables CSS en formato --nombre: #color;
        pattern = r'--(color\d+|background|foreground|cursor):\s*(#[0-9a-fA-F]{6})'
        matches = re.findall(pattern, content)
        
        for var_name, color_value in matches:
            variables[var_name] = color_value
        
        return variables
    
    except Exception as e:
        print(f"Error leyendo {css_file_path}: {e}")
        return variables

def update_windows_terminal_scheme(variables):
    """Actualiza el esquema 'Custom Warm' en settings.json de Windows Terminal."""
    
    if not WINDOWS_TERMINAL_SETTINGS.exists():
        print(f"Advertencia: No se encontró settings.json de Windows Terminal en {WINDOWS_TERMINAL_SETTINGS}")
        return
    
    # Mapeo de variables CSS a propiedades de Windows Terminal
    color_map = {
        'color0': 'black',
        'color1': 'red',
        'color2': 'green',
        'color3': 'yellow',
        'color4': 'blue',
        'color5': 'purple',
        'color6': 'cyan',
        'color7': 'white',
        'color8': 'brightBlack',
        'color9': 'brightRed',
        'color10': 'brightGreen',
        'color11': 'brightYellow',
        'color12': 'brightBlue',
        'color13': 'brightPurple',
        'color14': 'brightCyan',
        'color15': 'brightWhite',
        'background': 'background',
        'foreground': 'foreground',
        'cursor': 'cursorColor'
    }
    
    try:
        # Leer el archivo settings.json
        with open(WINDOWS_TERMINAL_SETTINGS, 'r', encoding='utf-8') as f:
            settings = json.load(f)
        
        # Buscar el esquema "Custom Warm"
        schemes = settings.get('schemes', [])
        custom_warm_idx = None
        
        for idx, scheme in enumerate(schemes):
            if scheme.get('name') == 'Custom Warm':
                custom_warm_idx = idx
                break
        
        if custom_warm_idx is None:
            print("Advertencia: No se encontró el esquema 'Custom Warm' en settings.json")
            return
        
        # Actualizar los colores del esquema
        for css_var, wt_prop in color_map.items():
            if css_var in variables:
                # Manejar background con transparencia - remover el sufijo 'ad'
                color_value = variables[css_var]
                if css_var == 'background' and len(color_value) == 9:
                    color_value = color_value[:7]  # Tomar solo los primeros 7 caracteres (#RRGGBB)
                
                schemes[custom_warm_idx][wt_prop] = color_value.upper()
        
        # También actualizar selectionBackground con color8
        if 'color8' in variables:
            schemes[custom_warm_idx]['selectionBackground'] = variables['color8'].upper()
        
        # Guardar el archivo actualizado
        with open(WINDOWS_TERMINAL_SETTINGS, 'w', encoding='utf-8') as f:
            json.dump(settings, f, indent=4)
        
        print(f"✓ Actualizado esquema 'Custom Warm' en Windows Terminal")
        
    except Exception as e:
        print(f"Error actualizando Windows Terminal: {e}")

def update_css(colors_data):
    """Actualiza los archivos CSS con los nuevos colores."""
    
    # Extraer los 16 colores (color0-color15)
    colors = colors_data.get("colors", {})
    special = colors_data.get("special", {})
    
    # Mapeo directo de colores de wal a variables CSS
    color_mapping = {}
    
    # Agregar color0 a color15
    for i in range(16):
        color_key = f"color{i}"
        css_var = f"--{color_key}"
        color_mapping[css_var] = colors.get(color_key, "#000000")
        
    # Agregar colores especiales
    color_mapping["--background"] = special.get("background", "#000000")
    color_mapping["--foreground"] = special.get("foreground", "#ffffff")
    color_mapping["--cursor"] = special.get("cursor", "#ffffff")
    
    print("\nAplicando colores a los archivos...")
    
    # Actualizar styles.css local
    update_file_colors(CSS_FILE, color_mapping)
    
    # Actualizar tema de Vencord
    update_file_colors(VENCORD_THEME_FILE, color_mapping)

    # Actualizar tema de Firefox
    update_file_colors(FIREFOX_CSS_FILE, color_mapping)
    
    # Actualizar Windows Terminal
    # Convertir el mapeo de colores al formato que espera la función
    css_variables = {}
    for var_name, color in color_mapping.items():
        # Remover el prefijo '--' de las variables
        clean_name = var_name.replace('--', '')
        css_variables[clean_name] = color
    
    update_windows_terminal_scheme(css_variables)
    
    print("\nColores aplicados:")
    for var_name, color in color_mapping.items():
        print(f"  {var_name}: {color}")

def print_color_preview(colors_data):
    """Muestra una vista previa de los colores extraídos."""
    colors = colors_data.get("colors", {})
    special = colors_data.get("special", {})
    
    print("\n" + "="*50)
    print("Colores extraídos del wallpaper:")
    print("="*50)
    print(f"Background: {special.get('background', 'N/A')}")
    print(f"Foreground: {special.get('foreground', 'N/A')}")
    print(f"Cursor: {special.get('cursor', 'N/A')}")
    print("-"*50)
    
    for i in range(16):
        color = colors.get(f"color{i}", "N/A")
        print(f"color{i:02d}: {color}")
    
    print("="*50 + "\n")

def main():
    print("="*50)
    print("  Actualizador de colores YASB con pywal")
    print("="*50 + "\n")
    
    # Obtener ruta del wallpaper
    wallpaper = get_wallpaper_path()
    
    # Verificar que el wallpaper existe
    if not os.path.exists(wallpaper):
        print(f"Error: El archivo no existe: {wallpaper}")
        sys.exit(1)
    
    # Generar colores con pywal
    generate_colors(wallpaper)
    
    # Cargar los colores generados
    colors_data = load_wal_colors()
    
    # Mostrar vista previa de colores
    print_color_preview(colors_data)
    
    # Actualizar el CSS
    update_css(colors_data)
    
    print("\n¡Listo! Reinicia YASB para ver los cambios.")

def update_windows_terminal_from_css():
    """Lee las variables CSS de styles.css y actualiza Windows Terminal."""
    print("="*60)
    print("  Actualizador de Windows Terminal desde styles.css")
    print("="*60 + "\n")
    
    # Leer variables CSS
    print(f"Leyendo variables desde: {CSS_FILE}")
    variables = read_css_variables(CSS_FILE)
    
    if not variables:
        print("Error: No se encontraron variables CSS válidas.")
        return
    
    print(f"\nVariables encontradas: {len(variables)}")
    for var_name, color in sorted(variables.items()):
        print(f"  --{var_name}: {color}")
    
    # Actualizar Windows Terminal
    print("\nActualizando Windows Terminal...")
    update_windows_terminal_scheme(variables)
    
    print("\n¡Listo! Los cambios se han aplicado a Windows Terminal.")
    print("Puede que necesites reiniciar Windows Terminal para ver los cambios.")

if __name__ == "__main__":
    # Si se pasa el argumento --wt, solo actualiza Windows Terminal
    if len(sys.argv) > 1 and sys.argv[1] == "--wt":
        update_windows_terminal_from_css()
    else:
        main()
