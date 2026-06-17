import sys, os, subprocess, json, tempfile, textwrap

ALLOWED_DIR = os.path.expanduser("~/boni_workspace")
MAX_OUTPUT = 10000
TIMEOUT = 30

os.makedirs(ALLOWED_DIR, exist_ok=True)

def ejecutar_en_sandbox(codigo, nombre="web_exec"):
    resultado = {"exito": False, "output": "", "error": None}
    try:
        codigo_limpio = textwrap.dedent(codigo).strip()
        exec_globals = {"__builtins__": __builtins__}
        exec_locals = {}
        old_stdout = sys.stdout
        sys.stdout = buffer = _StringIO()

        try:
            exec(codigo_limpio, exec_globals, exec_locals)
            resultado["output"] = buffer.getvalue()[:MAX_OUTPUT]
            resultado["exito"] = True
        except Exception as e:
            resultado["error"] = str(e)[:500]
            resultado["output"] = buffer.getvalue()[:MAX_OUTPUT]
        finally:
            sys.stdout = old_stdout
    except Exception as e:
        resultado["error"] = str(e)[:500]
    return resultado


class _StringIO:
    def __init__(self):
        self.buf = ""
    def write(self, s):
        self.buf += str(s)
    def getvalue(self):
        return self.buf
    def flush(self):
        pass


def ejecutar_como_proceso(codigo, nombre="web_exec"):
    resultado = {"exito": False, "output": "", "error": None}
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False, dir=ALLOWED_DIR) as f:
            f.write(codigo)
            script_path = f.name
        try:
            r = subprocess.run(
                [sys.executable, script_path],
                capture_output=True, text=True, timeout=TIMEOUT,
                cwd=ALLOWED_DIR
            )
            resultado["output"] = (r.stdout + r.stderr)[:MAX_OUTPUT]
            resultado["exito"] = r.returncode == 0
            if r.returncode != 0:
                resultado["error"] = r.stderr[:500]
        finally:
            try:
                os.unlink(script_path)
            except Exception:
                pass
    except subprocess.TimeoutExpired:
        resultado["error"] = f"Timeout de {TIMEOUT}s"
    except Exception as e:
        resultado["error"] = str(e)[:500]
    return resultado
