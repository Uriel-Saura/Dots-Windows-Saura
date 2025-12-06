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

def update_css(colors_data):
    """Actualiza el archivo CSS con los nuevos colores."""
    
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
    
    # Leer el archivo CSS
    if not CSS_FILE.exists():
        print(f"Error: No se encontró el archivo CSS: {CSS_FILE}")
        sys.exit(1)
    
    with open(CSS_FILE, 'r', encoding='utf-8') as f:
        css_content = f.read()
    
    # Reemplazar cada variable de color
    for var_name, new_color in color_mapping.items():
        # Patrón para encontrar la declaración de la variable
        pattern = rf"({re.escape(var_name)}:\s*)#[0-9a-fA-F]{{6}}"
        replacement = rf"\g<1>{new_color}"
        css_content = re.sub(pattern, replacement, css_content)
    
    # Guardar el archivo CSS actualizado
    with open(CSS_FILE, 'w', encoding='utf-8') as f:
        f.write(css_content)
    
    print("✓ Archivo CSS actualizado correctamente!")
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

if __name__ == "__main__":
    main()
