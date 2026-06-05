#!/usr/bin/env python3
"""Registra las herramientas de BONI en Open WebUI"""
import requests, json, sys

WEBUI = "http://localhost:3000"
EMAIL = "mario@boni.local"
PASS = "boni2024mario"

# 1. Login
r = requests.post(f"{WEBUI}/api/v1/auths/signin",
    json={"email": EMAIL, "password": PASS})
print(f"Login: HTTP {r.status_code}", end="")
if r.status_code == 200:
    token = r.json()["token"]
    print(" OK")
else:
    r = requests.post(f"{WEBUI}/api/v1/auths/signup",
        json={"name": "Mario", "email": EMAIL, "password": PASS})
    print(f" Signup: HTTP {r.status_code}")
    if r.status_code == 200:
        token = r.json()["token"]
    else:
        print(f"ERROR: {r.text[:200]}")
        sys.exit(1)

H = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# 2. Read tool files
with open("C:/Users/nosoy/OneDrive/Desktop/boni/BONI_tools/tool_pc_control.py", encoding="utf-8") as f:
    pc_tool = f.read()
with open("C:/Users/nosoy/OneDrive/Desktop/boni/BONI_tools/tool_navegador.py", encoding="utf-8") as f:
    nav_tool = f.read()

# 3. Also register the existing tools if they're not already
tools = [
    {
        "id": "pc_control_boni",
        "name": "Control PC",
        "description": "Permite a BONI controlar mouse, teclado, tomar screenshots y ejecutar comandos en Windows",
        "meta": {},
        "content": pc_tool
    },
    {
        "id": "navegador_boni",
        "name": "Navegador Web",
        "description": "Permite a BONI controlar el navegador para automatizar tareas web usando browser-use en WSL",
        "meta": {},
        "content": nav_tool
    }
]

for tool in tools:
    r = requests.post(f"{WEBUI}/api/v1/tools/create", headers=H, json=tool)
    if r.status_code == 200:
        print(f"[OK] {tool['name']}: Creado exitosamente")
    else:
        print(f"[ERR] {tool['name']}: HTTP {r.status_code} - {r.text[:150]}")

print("Hecho")
