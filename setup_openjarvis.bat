@echo off
:: ============================================================
:: BONI + OpenJarvis - Configuración final (Steps 9-14)
:: Corre como Administrador en Windows
:: ============================================================

echo ============================
echo  Configurando OpenJarvis...
echo ============================

:: Verificar WSL
wsl -d Ubuntu-22.04 -e echo OK || (
    echo ERROR: WSL no responde. Ejecuta: wsl --shutdown y espera 30s.
    pause
    exit /b 1
)

:: Crear estructura de directorios
wsl -d Ubuntu-22.04 -e mkdir -p /root/.openjarvis /root/.config/openjarvis

:: Paso 9: Crear archivo de conocimiento
wsl -d Ubuntu-22.04 -e python3 -c "
import os
os.makedirs('/root/.openjarvis', exist_ok=True)
os.makedirs('/root/.config/openjarvis', exist_ok=True)
c = '''# BONI Knowledge File\n\n## Usuario\n- Nombre: Mario Macias\n- Ciudad: Monterrey, Mexico\n- Entorno: Windows 10 + WSL2 Ubuntu, Ryzen 3 5300U, 12GB RAM\n\n## Stack tecnico preferido\n- HTML/JS (single-file tools)\n- Python, Node.js\n- Docker, Ollama\n- Bash y .bat scripts\n\n## Proyectos activos\n- RoviMusic: tiendas de instrumentos musicales\n- Dolibarr ERP en rovimusictools.com\n\n## Estilo de codigo\n- Archivos unicos cuando sea posible\n- Comentarios claros en espanol\n- Sin dependencias cloud\n\n## Directivas\n- Privacidad local\n- Accion sobre teoria\n- Espanol mexicano directo\n- Socio estrategico, no sirviente\n'''
open('/root/.openjarvis/knowledge.md','w').write(c)
print('Knowledge created OK')
"

:: Crear config.toml
wsl -d Ubuntu-22.04 python3 -c "
c = '[engine]\nname = \"ollama\"\n\n[engine.ollama]\nurl = \"http://host.docker.internal:11434\"\nmodel = \"qwen2.5:3b\"\n\n[system]\nlanguage = \"es\"\nmode = \"code-assistant\"\n\n[security]\nprofile = \"personal\"\n'
open('/root/.openjarvis/config.toml','w').write(c)
print('Config created OK')
"

:: Paso 10: Instalar skills
echo Instalando skills Hermes...
wsl -d Ubuntu-22.04 jarvis skill sync hermes --category code
wsl -d Ubuntu-22.04 jarvis skill sync hermes --category research

:: Paso 11: Verificar doctor
echo Verificando configuracion...
wsl -d Ubuntu-22.04 jarvis doctor

:: Paso 12: Probar conexion con Ollama
echo Probando conexion con Ollama...
wsl -d Ubuntu-22.04 python3 -c "
import urllib.request, json
try:
    r = urllib.request.urlopen('http://host.docker.internal:11434/api/tags', timeout=5)
    data = json.loads(r.read())
    models = [m['name'] for m in data.get('models',[])]
    print('Ollama OK - Modelos disponibles:', ', '.join(models))
except Exception as e:
    print('Ollama no responde:', e)
"

:: Paso 13: Crear acceso directo BONI en escritorio
echo Creando acceso directo en escritorio...
set "DESKTOP=%USERPROFILE%\Desktop"
set "BONI_BAT=%DESKTOP%\BONI.bat"

> "%BONI_BAT%" (
    echo @echo off
    echo echo Iniciando BONI - OpenJarvis...
    echo wsl -d Ubuntu-22.04 jarvis --mode chat
    echo pause
)

echo Acceso directo creado: %BONI_BAT%

:: Paso 14: Resumen
echo.
echo ========================================
echo  CONFIGURACION COMPLETA
echo ========================================
echo  Ollama local:   http://localhost:11434
echo  Open WebUI:     http://localhost:3000
echo  BONI (WebUI):   http://localhost:3000/workspace
echo  OpenJarvis:     %BONI_BAT%  (doble click)
echo.
echo  Proximo paso: Abre %BONI_BAT% y ejecuta
echo  'jarvis' para hablar con BONI desde terminal.
echo ========================================

pause
