"""
BONI Tool: Ejecutor de comandos del sistema
Permite a BONI ejecutar comandos de terminal de manera controlada.
"""
import json, subprocess, os
from typing import Optional

ALLOWED_DIR = os.path.expanduser("~/boni_workspace")
os.makedirs(ALLOWED_DIR, exist_ok=True)
BLOCKED_COMMANDS = ["rm -rf /", "format", "del /f /s /q C:\\", "shutdown", "reboot"]

class Tools:
    class Valves:
        pass

    def __init__(self):
        pass

    def ejecutar_comando(self, comando: str, directorio: Optional[str] = None) -> str:
        """Ejecuta un comando de terminal y retorna el resultado. Args: comando: El comando a ejecutar (ej: dir, python script.py, ollama list), directorio: Directorio donde ejecutar"""
        for blocked in BLOCKED_COMMANDS:
            if blocked.lower() in comando.lower():
                return '{"error": "Comando bloqueado por seguridad"}'
        work_dir = directorio or ALLOWED_DIR
        try:
            result = subprocess.run(comando, shell=True, capture_output=True, text=True,
                timeout=30, cwd=work_dir, encoding='utf-8', errors='replace')
            return json.dumps({"stdout": result.stdout[:2000] if result.stdout else "",
                "stderr": result.stderr[:500] if result.stderr else "",
                "codigo_retorno": result.returncode})
        except subprocess.TimeoutExpired:
            return '{"error": "Comando tardó más de 30 segundos"}'
        except Exception as e:
            return json.dumps({"error": str(e)})

    def leer_archivo(self, ruta: str) -> str:
        """Lee el contenido de un archivo de texto. Args: ruta: Ruta del archivo a leer"""
        try:
            ruta_expandida = os.path.expanduser(ruta)
            if not os.path.exists(ruta_expandida):
                return json.dumps({"error": f"Archivo no encontrado: {ruta}"})
            with open(ruta_expandida, 'r', encoding='utf-8', errors='replace') as f:
                contenido = f.read()
            return json.dumps({"contenido": contenido[:5000], "lineas": contenido.count('\n'),
                "tamaño_bytes": os.path.getsize(ruta_expandida)})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def escribir_archivo(self, ruta: str, contenido: str, modo: str = "w") -> str:
        """Escribe contenido en un archivo. Args: ruta: Ruta del archivo, contenido: Texto a escribir, modo: w sobreescribir, a agregar"""
        try:
            ruta_expandida = os.path.expanduser(ruta)
            if not os.path.isabs(ruta_expandida):
                ruta_expandida = os.path.join(ALLOWED_DIR, ruta)
            os.makedirs(os.path.dirname(ruta_expandida) or '.', exist_ok=True)
            with open(ruta_expandida, modo, encoding='utf-8') as f:
                f.write(contenido)
            return json.dumps({"exito": True, "ruta": ruta_expandida,
                "bytes_escritos": len(contenido.encode('utf-8'))})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def listar_directorio(self, ruta: Optional[str] = None) -> str:
        """Lista el contenido de un directorio. Args: ruta: Ruta a listar"""
        directorio = os.path.expanduser(ruta) if ruta else ALLOWED_DIR
        try:
            items = []
            for item in os.listdir(directorio):
                ruta_item = os.path.join(directorio, item)
                items.append({"nombre": item, "tipo": "carpeta" if os.path.isdir(ruta_item) else "archivo",
                    "tamaño": os.path.getsize(ruta_item) if os.path.isfile(ruta_item) else None})
            return json.dumps({"directorio": directorio, "items": items, "total": len(items)})
        except Exception as e:
            return json.dumps({"error": str(e), "items": []})
