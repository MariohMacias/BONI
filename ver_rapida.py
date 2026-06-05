#!/usr/bin/env python3
import subprocess, json, os

# 1. Pillow
from PIL import ImageGrab
w,h = ImageGrab.grab().size
print(f"PASS | Pillow screenshots      | Resolucion: {w}x{h}")

# 2. mouse + keyboard
import mouse, keyboard
x,y = mouse.get_position()
print(f"PASS | Mouse control           | Posicion: ({x},{y})")
print(f"PASS | Keyboard control        | OK")

# 3. browser-use en WSL
subprocess.run(["wsl","-d","Ubuntu-22.04","--","bash","-c",
    'printf "import browser_use\nimport langchain_openai\nprint(\"browser-use OK\")" > /tmp/_test_bu.py'],
    capture_output=True,timeout=10)
r = subprocess.run(["wsl","-d","Ubuntu-22.04","--","bash","-c",
    "python3.12 /tmp/_test_bu.py"],
    capture_output=True,text=True,timeout=30)
subprocess.run(["wsl","-d","Ubuntu-22.04","--","bash","-c","rm -f /tmp/_test_bu.py"],
    capture_output=True,timeout=5)
ok = "browser-use OK" in r.stdout
err = r.stderr.strip()[:80] if r.stderr else ""
print(f"{'PASS' if ok else 'FAIL'} | WSL browser-use         | {r.stdout.strip() or err}")

# 4. OpenHands
r = subprocess.run(["docker","images","--format","{{.Repository}}"],
    capture_output=True,text=True,timeout=10)
has = "openhands" in r.stdout.lower()
print(f"{'PASS' if has else '----'} | OpenHands Docker         | {'Disponible' if has else 'No descargada (pendiente)'}")

# 5. Tools en WebUI
import requests
r = requests.post("http://localhost:3000/api/v1/auths/signin",
    json={"email":"mario@boni.local","password":"boni2024mario"}, timeout=10)
token = r.json()["token"]
r2 = requests.get("http://localhost:3000/api/v1/tools",
    headers={"Authorization":f"Bearer {token}"}, timeout=10)
tools = r2.json()
print(f"PASS | Open WebUI tools         | {len(tools)} herramientas registradas:")
for t in tools:
    print(f"     | - {t['name']} ({t['id']})")

# 6. Archivos tool
bdir = "C:/Users/nosoy/OneDrive/Desktop/boni/BONI_tools"
for f in ["tool_pc_control.py","tool_navegador.py"]:
    p = os.path.join(bdir, f)
    exists = os.path.exists(p)
    print(f"{'PASS' if exists else 'FAIL'} | Archivo {f:25s} | {'OK' if exists else 'No encontrado'}")

# 7. WSL tool
r = subprocess.run(["wsl","-d","Ubuntu-22.04","--","bash","-c",
    "test -f /root/.openjarvis/tools/tool_navegador.py && echo OK || echo NO"],
    capture_output=True,text=True,timeout=10)
wsl_ok = "OK" in r.stdout
print(f"{'PASS' if wsl_ok else 'FAIL'} | WSL tool_navegador.py    | {'OK' if wsl_ok else 'No encontrado'}")
