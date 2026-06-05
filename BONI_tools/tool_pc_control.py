"""
BONI Tool: Control de PC
Permite a BONI controlar mouse, teclado, tomar screenshots, ejecutar comandos en Windows.
Compatible con Open WebUI (validacion en Linux, ejecucion en Windows).
"""
import subprocess, os, base64, io, json, time
from datetime import datetime

# Diferir imports de Windows para que Open WebUI pueda validar en Linux
PIL = None
MOUSE_LIB = None
KEYBOARD_LIB = None
USER32 = None

def _init_platform():
    global PIL, MOUSE_LIB, KEYBOARD_LIB, USER32
    try:
        from PIL import ImageGrab
        PIL = ImageGrab
    except ImportError:
        pass
    try:
        import mouse
        MOUSE_LIB = mouse
    except ImportError:
        pass
    try:
        import keyboard
        KEYBOARD_LIB = keyboard
    except ImportError:
        pass
    try:
        import ctypes
        USER32 = ctypes.windll.user32
    except (ImportError, AttributeError):
        pass

SCREENSHOTS_DIR = os.path.expanduser("~/.boni/screenshots")
ALLOWED_DIR = os.path.expanduser("~/boni_workspace")
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
os.makedirs(ALLOWED_DIR, exist_ok=True)
BLOCKED_COMMANDS = ["rm -rf", "format", "shutdown", "reboot", "del /f /s"]

class Tools:
    class Valves:
        pass

    def __init__(self):
        _init_platform()

    def tomar_screenshot(self, guardar: bool = False) -> str:
        """Toma un screenshot de la pantalla actual. Args: guardar: True para guardar en disco"""
        try:
            if PIL is None:
                return json.dumps({"error": "Pillow no instalado en Windows"})
            img = PIL.grab()
            if guardar:
                ruta = os.path.join(SCREENSHOTS_DIR, f"screen_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png")
                os.makedirs(os.path.dirname(ruta), exist_ok=True)
                img.save(ruta)
                return json.dumps({"guardado": ruta, "size": img.size})
            buffer = io.BytesIO()
            img.save(buffer, format='PNG')
            return json.dumps({"base64": base64.b64encode(buffer.getvalue()).decode(), "size": img.size})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def click(self, x: int, y: int, boton: str = "left", doble: bool = False) -> str:
        """Hace click en coordenadas x,y. Args: x, y: coordenadas, boton: left/right/middle, doble: True para doble click"""
        try:
            if MOUSE_LIB:
                MOUSE_LIB.move(x, y, absolute=True, duration=0.3)
                time.sleep(0.1)
                if doble:
                    MOUSE_LIB.double_click(button=boton)
                else:
                    MOUSE_LIB.click(button=boton)
            elif USER32:
                USER32.SetCursorPos(x, y)
                time.sleep(0.1)
                flags = {"left": 0x0002, "right": 0x0008, "middle": 0x0020}
                up = {"left": 0x0004, "right": 0x0010, "middle": 0x0040}
                b = boton.lower()
                for _ in range(2 if doble else 1):
                    USER32.mouse_event(flags.get(b, 0x0002), 0, 0, 0, 0)
                    USER32.mouse_event(up.get(b, 0x0004), 0, 0, 0, 0)
                    time.sleep(0.05)
            return json.dumps({"click": f"({x},{y})", "boton": boton, "doble": doble})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def escribir(self, texto: str, intervalo: float = 0.05) -> str:
        """Escribe texto como teclado. Args: texto: a escribir, intervalo: segundos entre tecla"""
        try:
            if KEYBOARD_LIB:
                KEYBOARD_LIB.write(texto, delay=intervalo)
            else:
                for c in texto:
                    vk = ord(c.upper())
                    USER32.keybd_event(vk, 0, 0, 0)
                    USER32.keybd_event(vk, 0, 0x0002, 0)
                    time.sleep(intervalo)
            preview = texto[:50] + "..." if len(texto) > 50 else texto
            return json.dumps({"escrito": preview})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def tecla(self, combinacion: str) -> str:
        """Presiona tecla o combinacion. Ej: enter, ctrl+c, alt+tab, win+d"""
        try:
            if KEYBOARD_LIB:
                KEYBOARD_LIB.press_and_release(combinacion)
                return json.dumps({"tecla": combinacion})
            return json.dumps({"error": "Requiere modulo keyboard en Windows"})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def ejecutar_comando(self, comando: str, en_wsl: bool = False) -> str:
        """Ejecuta comando en Windows o WSL. Args: comando: a ejecutar, en_wsl: True para WSL"""
        try:
            for blocked in BLOCKED_COMMANDS:
                if blocked.lower() in comando.lower():
                    return json.dumps({"error": "Comando bloqueado por seguridad"})
            cmd = (["wsl", "-d", "Ubuntu-22.04", "--", "bash", "-c", comando]
                   if en_wsl else ["cmd", "/c", comando])
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=60,
                encoding='utf-8', errors='replace')
            return json.dumps({"stdout": r.stdout[:2000], "stderr": r.stderr[:500], "codigo": r.returncode})
        except subprocess.TimeoutExpired:
            return json.dumps({"error": "Comando tardo mas de 60 segundos"})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def abrir_app(self, nombre: str) -> str:
        """Abre aplicacion por nombre. Ej: chrome, notepad, calc"""
        try:
            subprocess.Popen(nombre, shell=True)
            return json.dumps({"abierto": nombre})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def mover_mouse(self, x: int, y: int, duracion: float = 0.5) -> str:
        """Mueve el mouse suavemente a x,y. Args: x, y: destino, duracion: segundos"""
        try:
            if MOUSE_LIB:
                MOUSE_LIB.move(x, y, absolute=True, duration=duracion)
            elif USER32:
                USER32.SetCursorPos(x, y)
            return json.dumps({"movido_a": f"({x},{y})"})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def posicion_mouse(self) -> str:
        """Retorna posicion actual del mouse"""
        try:
            if MOUSE_LIB:
                x, y = MOUSE_LIB.get_position()
            elif USER32:
                import ctypes
                from ctypes import wintypes
                pt = wintypes.POINT()
                USER32.GetCursorPos(ctypes.byref(pt))
                x, y = pt.x, pt.y
            else:
                return json.dumps({"error": "No disponible en este sistema"})
            return json.dumps({"x": x, "y": y})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def scroll(self, x: int, y: int, cantidad: int) -> str:
        """Hace scroll en x,y. Args: x, y: posicion, cantidad: +arriba -abajo"""
        try:
            if USER32:
                USER32.SetCursorPos(x, y)
                USER32.mouse_event(0x0800, 0, 0, cantidad, 0)
            return json.dumps({"scroll": cantidad, "en": f"({x},{y})"})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def resolucion_pantalla(self) -> str:
        """Retorna la resolucion de la pantalla"""
        try:
            if USER32:
                return json.dumps({"ancho": USER32.GetSystemMetrics(0), "alto": USER32.GetSystemMetrics(1)})
            return json.dumps({"error": "Solo disponible en Windows"})
        except Exception as e:
            return json.dumps({"error": str(e)})
