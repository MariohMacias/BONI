"""
BONI Tool: Ejecutor de comandos del sistema
Permite a BONI ejecutar comandos de terminal de manera controlada.

Instalación en Open WebUI:
  Settings > Tools > (+) Add Tool > pegar este código
"""

import subprocess
import os
from typing import Optional

# ── Configuración ────────────────────────────────────────────────
# Directorio de trabajo permitido (para mayor seguridad)
ALLOWED_DIR = os.path.expanduser("~/boni_workspace")
os.makedirs(ALLOWED_DIR, exist_ok=True)

# Comandos prohibidos por seguridad
BLOCKED_COMMANDS = ["rm -rf /", "format", "del /f /s /q C:\\", "shutdown", "reboot"]

def ejecutar_comando(comando: str, directorio: Optional[str] = None) -> dict:
    """
    Ejecuta un comando de terminal y retorna el resultado.
    
    Args:
        comando: El comando a ejecutar (ej: "dir", "python script.py", "ollama list")
        directorio: Directorio donde ejecutar (por defecto: boni_workspace)
    
    Returns:
        dict con stdout, stderr y código de retorno
    """
    # Verificar comandos bloqueados
    for blocked in BLOCKED_COMMANDS:
        if blocked.lower() in comando.lower():
            return {"error": f"Comando bloqueado por seguridad: {blocked}", "stdout": "", "stderr": ""}
    
    work_dir = directorio or ALLOWED_DIR
    
    try:
        result = subprocess.run(
            comando,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=work_dir,
            encoding='utf-8',
            errors='replace'
        )
        return {
            "stdout": result.stdout[:2000] if result.stdout else "",
            "stderr": result.stderr[:500] if result.stderr else "",
            "codigo_retorno": result.returncode,
            "directorio": work_dir
        }
    except subprocess.TimeoutExpired:
        return {"error": "El comando tardó más de 30 segundos y fue cancelado.", "stdout": "", "stderr": ""}
    except Exception as e:
        return {"error": str(e), "stdout": "", "stderr": ""}


def leer_archivo(ruta: str) -> dict:
    """
    Lee el contenido de un archivo de texto.
    
    Args:
        ruta: Ruta del archivo a leer
    
    Returns:
        dict con el contenido del archivo o error
    """
    try:
        ruta_expandida = os.path.expanduser(ruta)
        if not os.path.exists(ruta_expandida):
            return {"error": f"Archivo no encontrado: {ruta}", "contenido": ""}
        
        with open(ruta_expandida, 'r', encoding='utf-8', errors='replace') as f:
            contenido = f.read()
        
        return {
            "contenido": contenido[:5000],  # máx 5000 chars
            "lineas": contenido.count('\n'),
            "tamaño_bytes": os.path.getsize(ruta_expandida)
        }
    except Exception as e:
        return {"error": str(e), "contenido": ""}


def escribir_archivo(ruta: str, contenido: str, modo: str = "w") -> dict:
    """
    Escribe contenido en un archivo.
    
    Args:
        ruta: Ruta del archivo (relativa a boni_workspace o absoluta)
        contenido: Texto a escribir
        modo: "w" para sobreescribir, "a" para agregar al final
    
    Returns:
        dict con resultado de la operación
    """
    try:
        ruta_expandida = os.path.expanduser(ruta)
        
        # Si es relativa, usar boni_workspace
        if not os.path.isabs(ruta_expandida):
            ruta_expandida = os.path.join(ALLOWED_DIR, ruta)
        
        # Crear directorios si no existen
        os.makedirs(os.path.dirname(ruta_expandida) or '.', exist_ok=True)
        
        with open(ruta_expandida, modo, encoding='utf-8') as f:
            f.write(contenido)
        
        return {
            "exito": True,
            "ruta": ruta_expandida,
            "bytes_escritos": len(contenido.encode('utf-8'))
        }
    except Exception as e:
        return {"error": str(e), "exito": False}


def listar_directorio(ruta: Optional[str] = None) -> dict:
    """
    Lista el contenido de un directorio.
    
    Args:
        ruta: Ruta a listar (por defecto: boni_workspace)
    
    Returns:
        dict con lista de archivos y carpetas
    """
    directorio = os.path.expanduser(ruta) if ruta else ALLOWED_DIR
    
    try:
        items = []
        for item in os.listdir(directorio):
            ruta_item = os.path.join(directorio, item)
            items.append({
                "nombre": item,
                "tipo": "carpeta" if os.path.isdir(ruta_item) else "archivo",
                "tamaño": os.path.getsize(ruta_item) if os.path.isfile(ruta_item) else None
            })
        
        return {
            "directorio": directorio,
            "items": items,
            "total": len(items)
        }
    except Exception as e:
        return {"error": str(e), "items": []}
