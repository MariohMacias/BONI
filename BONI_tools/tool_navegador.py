"""
BONI Tool: Navegador Web (via WSL + browser-use)
Permite a BONI controlar el navegador para automatizar tareas web.
Ejecuta browser-use en WSL con Python 3.12.
"""
import json, subprocess, os

WSL_DISTRO = "Ubuntu-22.04"

class Tools:
    class Valves:
        pass

    def __init__(self):
        pass

    def navegar(self, tarea: str) -> str:
        """Controla el navegador para realizar una tarea web. Args: tarea: Descripcion de que hacer en el navegador (ej: 'Abre google y busca clima')"""
        try:
            cmd = ["wsl", "-d", WSL_DISTRO, "--", "bash", "-c",
                   "python3.12 /root/.openjarvis/tools/tool_navegador.py " + self._escapar(tarea)]
            resultado = subprocess.run(cmd, capture_output=True, text=True,
                timeout=300, encoding='utf-8', errors='replace')
            out = resultado.stdout.strip() or resultado.stderr.strip()
            return json.dumps({"resultado": out[:2000]})
        except subprocess.TimeoutExpired:
            return json.dumps({"error": "La tarea del navegador tardo mas de 5 minutos"})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def abrir_pagina(self, url: str) -> str:
        """Abre una URL en el navegador. Args: url: URL completa a abrir"""
        return self.navegar("Abre " + url + " y espera a que cargue")

    def _escapar(self, texto: str) -> str:
        return texto.replace("'", "'\\''")
