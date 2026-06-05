#!/usr/bin/env python3
"""Verificacion final de todos los componentes BONI v2.1"""
import json, subprocess, sys

def check(componente, ok, detalle=""):
    status = "OK" if ok else "FALLO"
    icon = "PASS" if ok else "FAIL"
    print(f"| {icon:4s} | {componente:30s} | {detalle:40s} |")

def verificar():
    print("=" * 90)
    print("VERIFICACION FINAL - BONI v2.1 Control Autonomo de PC")
    print("=" * 90)
    print(f"| {'':4s} | {'Componente':30s} | {'Detalle':40s} |")
    print("-" * 90)

    # 1. Windows Python + librerias
    try:
        from PIL import ImageGrab
        w, h = ImageGrab.grab().size
        check("Pillow (screenshots)", True, f"Resolucion: {w}x{h}")
    except Exception as e:
        check("Pillow (screenshots)", False, str(e)[:40])

    try:
        import mouse
        x, y = mouse.get_position()
        check("Mouse control", True, f"Mouse en: ({x},{y})")
    except ImportError:
        check("Mouse control", False, "No instalado")

    try:
        import keyboard
        check("Keyboard control", True, "Disponible")
    except ImportError:
        check("Keyboard control", False, "No instalado")

    # 2. WSL + browser-use
    try:
        r = subprocess.run(
            ["wsl", "-d", "Ubuntu-22.04", "--", "bash", "-c",
             "python3.12 -c 'import browser_use; import langchain_openai; print(\"OK\")'"],
            capture_output=True, text=True, timeout=30)
        if "OK" in r.stdout:
            check("WSL browser-use", True, "Python 3.12 + browser-use")
        else:
            check("WSL browser-use", False, r.stderr[:40])
    except Exception as e:
        check("WSL browser-use", False, str(e)[:40])

    # 3. Docker + Open WebUI
    try:
        r = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=15)
        containers = r.stdout.strip().split("\n")
        if "open-webui" in containers:
            check("Open WebUI", True, "Corriendo en Docker")
        else:
            check("Open WebUI", False, "No encontrado")
    except Exception as e:
        check("Open WebUI", False, str(e)[:40])

    # 4. OpenHands
    try:
        r = subprocess.run(
            ["docker", "images", "--format", "{{.Repository}}"],
            capture_output=True, text=True, timeout=15)
        if "openhands" in r.stdout.lower():
            check("OpenHands", True, "Imagen disponible")
        else:
            check("OpenHands", False, "No descargada")
    except Exception as e:
        check("OpenHands", False, str(e)[:40])

    # 5. Tools registrados en Open WebUI
    try:
        import requests
        r = requests.post("http://localhost:3000/api/v1/auths/signin",
            json={"email": "mario@boni.local", "password": "boni2024mario"}, timeout=10)
        if r.status_code == 200:
            token = r.json()["token"]
            r2 = requests.get("http://localhost:3000/api/v1/tools",
                headers={"Authorization": f"Bearer {token}"}, timeout=10)
            tools = r2.json()
            if isinstance(tools, list):
                for t in tools:
                    check(f"Tool: {t.get('name','?')}", True, f"ID: {t.get('id','?')}")
            else:
                check("Tools WebUI", True, str(type(tools).__name__))
        else:
            check("Tools WebUI", False, f"HTTP {r.status_code}")
    except Exception as e:
        check("Tools WebUI", False, str(e)[:40])

    # 6. Archivos de tool creados
    import os
    for f in ["tool_pc_control.py", "tool_navegador.py"]:
        path = f"C:/Users/nosoy/OneDrive/Desktop/boni/BONI_tools/{f}"
        if os.path.exists(path):
            size = os.path.getsize(path)
            check(f"Archivo: {f}", True, f"{size} bytes")
        else:
            check(f"Archivo: {f}", False, "No encontrado")

    # 7. WSL tool_navegador.py
    try:
        r = subprocess.run(
            ["wsl", "-d", "Ubuntu-22.04", "--", "bash", "-c",
             "test -f /root/.openjarvis/tools/tool_navegador.py && echo EXISTE"],
            capture_output=True, text=True, timeout=10)
        if "EXISTE" in r.stdout:
            check("WSL tool_navegador.py", True, "En /root/.openjarvis/tools/")
        else:
            check("WSL tool_navegador.py", False, "No encontrado")
    except Exception as e:
        check("WSL tool_navegador.py", False, str(e)[:40])

    print("-" * 90)

if __name__ == "__main__":
    verificar()
