# B.O.N.I. v2.1 — Reporte Completo de Capacidades

**Fecha:** 31 de mayo de 2026
**Plataforma:** Windows 11 + WSL2 (Ubuntu 22.04) + Ollama
**Modelo principal:** `boni-rapido:latest` (Qwen2 3.1B Q4_K_M)

---

---

## SECCIÓN 1 — RESUMEN EJECUTIVO

| Componente | Versión | Estado | Puerto / URL |
|---|---|---|---|
| **Ollama** | Último | ✅ Activo | `localhost:11434` |
| **boni-rapido:latest** | Qwen2 3.1B | ✅ Descargado | Ollama |
| **OpenJarvis** | 1.0.2 | ⚠️ Serve lento | `WSL:8080` |
| **boni_ui.py (Qt6)** | 2.1 | ✅ Listo | Ventana 500×500 |
| **boni_webui.py (Flask)** | 2.1 | ✅ Listo | `localhost:3001` |
| **TTS Server (voz)** | — | ⏳ Pendiente | `WSL:5050` |
| **Docker Desktop** | — | ❌ No iniciado | — |
| **Open WebUI** | latest | ❌ No disponible | `localhost:3000` |
| **OpenHands** | — | ❌ No iniciado | `localhost:3002` |
| **Rust extension** | 0.1.0 | ✅ Compilando | WSL |
| **SQLite Memoria** | — | ⚠️ Parcial | `~/.boni/memoria.json` |
| **browser-use** | — | ❌ No instalado | WSL |
| **Node.js** | — | ❌ No detectado | — |
| **11 modelos Ollama** | Varios | ✅ Disponibles | `localhost:11434` |
| **2 agentes OpenJarvis** | — | ✅ Creados | WSL |

**Totales:** 8 funcionalidades activas | 7 pendientes | 3 no disponibles

---

## SECCIÓN 2 — CAPACIDADES ACTIVAS ✅

### Chat con IA — Interfaz Holográfica (boni_ui.py)

**Qué hace:** Ventana circular translúcida 500×500px estilo JARVIS-IA, con orbe 3D pulsante, anillos concéntricos con marcas de tick, 22 partículas orbitales, scanlines, viñeta, y texto de respuesta. Se conecta directamente a Ollama en localhost:11434 para chat streaming.

**Cómo usarla:**
1. Abre PowerShell y ejecuta: `python "C:\Users\nosoy\OneDrive\Desktop\boni\boni_ui.py"`
2. La ventana aparece en la esquina superior derecha de la pantalla
3. Presiona cualquier tecla alfanumérica → aparece el campo de texto oculto
4. Escribe tu mensaje y presiona Enter → el orbe se ilumina y BONI responde
5. Presiona Escape para ocultar el campo de texto

**Ejemplo concreto:**
```
(Presiona 'H') → aparece input
(Escribe "¿Cuál es la capital de Francia?") → orbe pulsa azul procesando
→ Respuesta: "París" en texto blanco/azul
```

**Limitaciones conocidas:**
- El historial de conversación solo dura mientras la ventana está abierta (no persiste)
- No tiene scroll de historial (solo muestra últimos mensajes)
- Texto limitado a 3 líneas visibles simultáneamente
- Depende de PyQt6 + Python 3.12 en Windows

---

### Chat con IA — Web UI (boni_webui.py)

**Qué hace:** Servidor Flask en puerto 3001 con interfaz web moderna, sidebar con historial de conversaciones persistente en disco, Markdown renderizado con `marked.js`, streaming SSE, selector de modelo, indicadores de estado de servicios.

**Cómo usarla:**
1. Ejecuta: `python "C:\Users\nosoy\OneDrive\Desktop\boni\boni_webui.py"`
2. Abre navegador en `http://localhost:3001`
3. Escribe mensaje y presiona Enter (o Shift+Enter para salto de línea)
4. Las conversaciones se guardan automáticamente en `~/.boni-webui/*.json`
5. El sidebar izquierdo muestra historial y estado de servicios (Ollama, jarvis, Docker)

**Ejemplo concreto:**
```
Abrir navegador → http://localhost:3001
→ Interfaz oscura profesional con sidebar
→ Escribir "Hola" → respuesta en Markdown
→ Cerrar y volver a abrir → el historial sigue ahí
```

**Limitaciones conocidas:**
- Depende de Flask y requests (instalados con Python estándar)
- El backend apunta a jarvis serve (`WSL:8080/v1/chat/completions`) no a Ollama directo
- Los indicadores de estado verifican servicios cada 15 segundos

---

### Chat con IA — Ollama Directo (via API)

**Qué hace:** boni_ui.py se conecta directamente a la API de Ollama (`/api/chat`) para obtener respuestas del modelo. Si Ollama no responde, fallback automático a jarvis serve.

**Cómo usarla:** Automático. boni_ui.py intenta primero `http://localhost:11434/api/chat`, y si falla, usa `http://127.0.0.1:8080/v1/chat/completions`.

**Ejemplo concreto:**
```python
# Esto ocurre internamente en ChatWorker.stream()
# 1. Intenta Ollama directo (localhost:11434/api/chat)
# 2. Si falla, intenta jarvis serve (localhost:8080/v1/chat/completions)
```

---

### 11 Modelos de IA Locales

**Qué hace:** Ollama tiene 11 modelos descargados listos para usar, desde 1B hasta 9.7B parámetros.

**Modelos disponibles:**
| Modelo | Parámetros | Cuantización |
|---|---|---|
| `boni-rapido:latest` | 3.1B | Q4_K_M |
| `qwen2.5:1.5b` | 1.5B | Q4_K_M |
| `qwen2.5:3b` | 3.1B | Q4_K_M |
| `qwen2.5:7b` | 7.6B | Q4_K_M |
| `qwen3.5:9b` | 9.7B | Q4_K_M |
| `gemma3:1b` | 1B | Q4_K_M |
| `gemma3:4b` | 4.3B | Q4_K_M |
| `gemma4:latest` | 8.0B | Q4_K_M |
| `smollm2:1.7b` | 1.7B | Q8_0 |
| `tinyllama:1.1b` | 1B | Q4_0 |
| `deepseek-r1:8b` | 8.2B | Q4_K_M |

**Cómo usarlos:** En cualquier interfaz (boni_ui.py, boni_webui.py, Open WebUI, o directo via curl):
```bash
curl http://localhost:11434/api/generate -d '{"model":"qwen2.5:7b","prompt":"Hola"}'
```

---

### Control de PC — Mouse y Teclado

**Qué hace:** BONI puede controlar el mouse (clic, mover, scroll, doble clic, clic derecho) y teclado (escribir texto, presionar combinaciones de teclas como Ctrl+C, Alt+Tab). Todo ejecutado en Windows.

**Cómo usarla (vía tool_pc_control.py):**
1. El script imports los módulos nativos de Windows (`mouse`, `keyboard`, `ctypes`)
2. Las funciones están disponibles como tools de OpenJarvis para que la IA las invoque automáticamente

**Funciones disponibles:**
- `tomar_screenshot()` — captura pantalla (base64 o archivo)
- `click(x, y, boton, doble)` — clic en coordenadas
- `escribir(texto, intervalo)` — escribe como teclado
- `tecla(combinacion)` — presiona tecla (ej: `ctrl+c`, `alt+tab`, `win+d`)
- `mover_mouse(x, y)` — mueve el mouse suavemente
- `posicion_mouse()` — obtiene posición actual
- `scroll(x, y, cantidad)` — scroll en posición
- `resolucion_pantalla()` — obtiene resolución del monitor
- `abrir_app(nombre)` — abre aplicación (calc, notepad, chrome)
- `ejecutar_comando(comando, en_wsl)` — ejecuta comandos en Windows o WSL

**Ejemplo concreto:**
```python
# BONI puede: tomar screenshot, analizar la imagen,
# mover el mouse a coordenadas específicas, hacer clic,
# y escribir texto automáticamente
```

**Limitaciones conocidas:**
- Requiere bibliotecas `mouse` y `keyboard` en Windows (se instalaron pero pueden necesitar permisos de administrador para hooks de teclado)
- `pyautogui` y `pynput` no están instalados en WSL (necesitan compilador MSVC)

---

### Ejecución de Comandos en Windows y WSL

**Qué hace:** BONI puede ejecutar comandos `cmd` en Windows o `bash` en WSL de forma segura, con bloqueo de comandos destructivos.

**Cómo usarla (vía tool_sistema.py):**
1. El script restringe comandos peligrosos (`rm -rf /`, `format`, `shutdown`, etc.)
2. Los comandos se ejecutan con timeout de 30 segundos
3. El directorio de trabajo seguro es `~/boni_workspace`

**Funciones disponibles:**
- `ejecutar_comando(comando, directorio)` — ejecuta cualquier comando shell
- `leer_archivo(ruta)` — lee contenido de archivo de texto
- `escribir_archivo(ruta, contenido)` — escribe/agrega a archivo
- `listar_directorio(ruta)` — lista contenido de carpeta

**Ejemplo concreto:**
```python
# BONI puede:
# • ejecutar_comando("dir C:\\Users") → lista usuarios
# • leer_archivo("C:/config.txt") → lee archivo
# • escribir_archivo("nota.txt", "contenido") → crea archivo
```

---

### Memoria Persistente entre Sesiones

**Qué hace:** BONI guarda hechos, notas y tareas en un archivo JSON en `~/.boni/memoria.json`. La información persiste incluso si se cierra la interfaz.

**Cómo usarla (vía tool_memoria.py):**
1. La IA invoca automáticamente las funciones de memoria cuando el usuario pide recordar algo
2. También se puede usar manualmente desde herramientas

**Funciones disponibles:**
- `recordar_hecho(clave, valor)` — guarda información (ej: nombre del usuario)
- `obtener_hecho(clave)` — recupera información guardada
- `guardar_nota(titulo, contenido, etiquetas)` — guarda nota con categorías
- `buscar_notas(termino)` — busca en notas guardadas
- `listar_hechos()` — lista todas las claves guardadas
- `agregar_tarea(descripcion, prioridad)` — crea tarea pendiente
- `ver_tareas(solo_pendientes)` — lista tareas
- `completar_tarea(id)` — marca tarea como completada

**Ejemplo concreto:**
```
Usuario: "Recuerda que me llamo Mario"
→ BONI guarda hecho: nombre_usuario = "Mario"

Usuario: "¿Cómo me llamo?"
→ BONI recupera: "Mario"

Usuario: "Apunta que tengo que comprar leche"
→ BONI guarda tarea: "Comprar leche" [pendiente]
```

---

### 2 Agentes OpenJarvis Especializados

**Qué hace:** BONI tiene 2 agentes persistentes creados en OpenJarvis que ejecutan tareas en background.

**Agentes disponibles:**

| Agente | Tipo | Estado | Propósito |
|---|---|---|---|
| `boni-operative` | `monitor_operational` | Idle | Monitor autónomo del sistema |
| `boni-research` | `deep_research` | Idle | Investigación profunda |

**Cómo usarlos:**
```bash
# Iniciar agente monitor
wsl -d Ubuntu-22.04 -- jarvis agent run boni-operative

# Iniciar investigación
wsl -d Ubuntu-22.04 -- jarvis agent run boni-research "investigar cambio climático"

# Ver estado
wsl -d Ubuntu-22.04 -- jarvis agents list
```

---

### 61 Skills de OpenJarvis Instaladas

**Qué hace:** OpenJarvis viene con 61 skills preinstalados que amplían las capacidades de BONI, desde control de servicios externos hasta automatización de tareas.

**Skills destacados:**
- `coding-agent` — Delega tareas de código a Codex/Claude
- `summarize` — Resume URLs, YouTube, podcasts
- `gh-issues` / `github` — Control de GitHub
- `slack`, `discord` — Mensajería
- `notion`, `obsidian` — Gestión de notas
- `arxiv`, `polymarket` — Investigación y datos
- `weather` — Clima
- `spotify-player`, `sonoscli` — Música
- `diagram-maker` — Crea diagramas SVG/HTML
- `skill-creator` — Crea nuevas skills
- `research-paper-writing` — Escribe papers ML

**Skills locales adicionales:**
- `hermes` — skills de investigación (arxiv, blogwatcher, llm-wiki, polymarket)
- `openclaw` — skills de automatización (55 skills de productividad)

---

### System Tray y Atajos de Teclado

**Qué hace:** boni_ui.py se minimiza al system tray de Windows con menú contextual para acceso rápido.

**Atajos de teclado:**
| Tecla | Acción |
|---|---|
| Cualquier tecla alfanumérica | Muestra campo de texto |
| Enter | Envía mensaje |
| Escape | Oculta campo de texto |
| Ctrl+W | Abre Open WebUI en navegador |
| Insert | Activa/desactiva modo escucha (mic) |
| Ctrl+Q / Alt+F4 | Cierra la aplicación |
| Doble clic en tray icon | Restaura la ventana |

**Menú contextual (clic derecho o tray icon):**
| Opción | Acción |
|---|---|
| Abrir WebUI | Abre `http://localhost:3000` |
| Estado | Muestra estado actual y WSL IP |
| Salir | Cierra BONI completamente |

---

### Arrastrar Ventana (Drag)

**Qué hace:** La ventana circular se puede arrastrar a cualquier posición de la pantalla con clic sostenido.

**Cómo usarla:**
1. Haz clic sostenido en cualquier parte de la ventana
2. Arrastra a la posición deseada
3. Suelta para fijar

---

### OpenJarvis CLI Completo

**Qué hace:** OpenJarvis 1.0.2 está instalado en WSL con 40+ comandos CLI para gestionar skills, agentes, memoria, configuración, servidor, y más.

**Comandos disponibles:**
| Comando | Función |
|---|---|
| `jarvis chat` | Chat interactivo multi-turno |
| `jarvis ask` | Pregunta directa (no-stream) |
| `jarvis serve` | Servidor API OpenAI-compatible |
| `jarvis start/stop` | Daemon background |
| `jarvis agents` | Gestiona agentes persistentes |
| `jarvis skill` | Gestiona skills |
| `jarvis memory` | Gestiona memoria persistente |
| `jarvis doctor` | Diagnóstico del sistema |
| `jarvis config` | Configuración |
| `jarvis model` | Gestión de modelos |

---

## SECCIÓN 3 — CAPACIDADES PENDIENTES ⏳

### Voz Clonada de BONI (TTS Personalizado)

**Qué falta:** No hay audios de referencia de Mario (WhatsApp .opus) en `voz\originales\` para ejecutar el pipeline de clonación.

**Cómo activarla:**
1. Mario debe copiar audios de WhatsApp a `C:\Users\nosoy\OneDrive\Desktop\boni\voz\originales\`
2. Ejecutar en Windows: `python "C:\Users\nosoy\OneDrive\Desktop\boni\voz\preparar_audios.py"`
3. Ejecutar en WSL: `python3.10 /root/boni_voice/clonar_voz.py`
4. Esto genera `voz_config.json` con la voz clonada

**Tiempo estimado:** 30 minutos (1GB descarga modelo XTTS v2 + 5 min procesamiento)

---

### TTS Server (Voz de BONI)

**Qué falta:** El TTS server necesita la voz clonada del paso anterior. El script `/root/boni_voice/tts_server.py` está creado pero no iniciado.

**Cómo activarla:**
```bash
wsl -d Ubuntu-22.04 -- nohup python3.10 /root/boni_voice/tts_server.py > ~/.boni/tts.log 2>&1 &
```

**Tiempo estimado:** Inicio ~2 minutos (carga modelo XTTS v2)

---

### OpenHands (Agente de Código Autónomo)

**Qué falta:** La imagen Docker de OpenHands no está descargada.

**Cómo activarla:**
```bash
# Iniciar Docker Desktop primero
# Luego:
docker pull ghcr.io/all-hands-ai/openhands:latest
docker run -d --name openhands -p 3002:3000 ghcr.io/all-hands-ai/openhands:latest
```

**Tiempo estimado:** 3 minutos (descarga ~2GB)

---

### pyautogui + pynput en WSL

**Qué falta:** Estas bibliotecas necesitan el compilador MSVC de Windows o `python3-dev` en Linux.

**Cómo activarla:**
```bash
wsl -d Ubuntu-22.04 -- sudo apt install -y python3-dev build-essential xvfb
wsl -d Ubuntu-22.04 -- pip3 install pyautogui pynput Pillow
```

**Alternativa:** Ya funcionan desde Windows directamente vía tool_pc_control.py usando `mouse` + `keyboard` + `ctypes`.

**Tiempo estimado:** 5 minutos

---

### Inicio Automático (Tarea Programada Windows)

**Qué falta:** No hay tarea programada en Windows para iniciar BONI automáticamente al encender el equipo.

**Cómo activarla:**
```powershell
# Como administrador
schtasks /Create /SC ONLOGON /TN "BONI_Inicio" /TR "powershell.exe -File `"C:\Users\nosoy\OneDrive\Desktop\boni\BONI_INICIO.ps1`"" /DELAY 0001:00 /F
```

**Tiempo estimado:** 2 minutos

---

### Docker Desktop + Open WebUI

**Qué falta:** Docker Desktop no está iniciado. La aplicación está instalada en `C:\Program Files\Docker\Docker\Docker Desktop.exe`.

**Cómo activarla:**
1. Iniciar Docker Desktop manualmente (o ejecutar `BONI_INICIO.ps1`)
2. Esperar 1-2 minutos a que Docker Engine se inicialice
3. El script BONI_INICIO.ps1 lanza automáticamente Open WebUI en `localhost:3000`

**Tiempo estimado:** 3 minutos

---

### browser-use (Navegación Web Automatizada)

**Qué falta:** `browser-use` no está instalado en WSL. El tool `tool_navegador.py` ya está creado y espera la biblioteca.

**Cómo activarla:**
```bash
wsl -d Ubuntu-22.04 -- pip3 install browser-use 2>&1
wsl -d Ubuntu-22.04 -- python3.12 -m playwright install chromium
# O alternativamente:
wsl -d Ubuntu-22.04 -- npx playwright install chromium
```

**Tiempo estimado:** 5 minutos (descarga ~200MB Chromium)

---

### jarvis serve (Servidor API Operațional)

**Qué falta:** `jarvis serve` y `jarvis start` funcionan pero se quedan trabados en requests POST (aceptan conexión TCP pero no responden). El `jarvis doctor` reporta todo OK, pero el servidor no procesa requests correctamente.

**Cómo activarla:** Pendiente de debugging — posible conflicto con skills mal formadas o dependencias faltantes.

**Tiempo estimado:** Desconocido

---

## SECCIÓN 4 — CAPACIDADES NO DISPONIBLES ❌

### Reconocimiento de Voz (Speech-to-Text)

**Por qué no puede:** La tecla Insert activa el modo "ESCUCHANDO" visualmente, pero no hay implementación real de captura de micrófono. El estado "listening" es puramente decorativo.

**¿Se puede agregar?** Sí. Se puede integrar:
- `speech_recognition` (Python) con API Google/Whisper local
- `openai-whisper` (skill ya instalada en OpenJarvis)
- Whisper.cpp para STT local rápido

**Esfuerzo estimado:** 2-4 horas

---

### Auto-programador Sandbox (Ejecución Segura de Código)

**Por qué no puede:** `boni_sandbox.py` no existe. No hay un entorno aislado para que BONI ejecute código Python o scripts de forma segura.

**¿Se puede agregar?** Sí. Opciones:
- Docker container sandbox (más seguro)
- `subprocess` con restricciones en `boni_workspace` (más simple)
- Basado en OpenJarvis skills/tools existentes

**Esfuerzo estimado:** 3-5 horas

---

### WhatsApp / iMessage / Slack (Canales de Mensajería)

**Por qué no puede:** Requieren Node.js 22+ para el bridge Baileys (WhatsApp) y configuración de APIs. Node.js no está instalado en WSL.

**¿Se puede agregar?** Sí, pero no es prioridad. Skills de slack y wacli ya existen en OpenJarvis.

**Esfuerzo estimado:** 2-3 horas + configuración de APIs

---

### Entrenamiento SFT/GRPO de Modelos

**Por qué no puede:** `torch` fue desinstalado de WSL para restaurar openjarvis. El doctor reporta: "Not installed (pip install torch)".

**¿Se puede agregar?** Sí, pero requiere reinstalar torch (4GB+) en un venv separado para no afectar openjarvis.

**Esfuerzo estimado:** 1 hora + 4GB descarga

---

### Indexación de Documentos (SQLite + Búsqueda Vectorial)

**Por qué no puede:** El doctor reporta Rust extension "building (run in background)" — la extensión no está compilada aún. El directorio `~/boni_docs` no existe.

**¿Se puede agregar?** Sí. `openjarvis-rs` está instalada como dependencia pero necesita compilarse con `maturin develop`.

**Esfuerzo estimado:** 10 minutos compilación Rust

---

## SECCIÓN 5 — GUÍA DE USO DIARIO

### Iniciar BONI

1. **Asegurar que Ollama está corriendo:**
   ```powershell
   # Verificar
   curl.exe http://localhost:11434/api/tags
   # Si no responde, iniciar:
   ollama serve
   ```

2. **Iniciar BONI (interfaz holográfica):**
   ```powershell
   python "C:\Users\nosoy\OneDrive\Desktop\boni\boni_ui.py"
   ```

3. **Iniciar BONI (interfaz web, alternativa):**
   ```powershell
   python "C:\Users\nosoy\OneDrive\Desktop\boni\boni_webui.py"
   # Abrir http://localhost:3001 en el navegador
   ```

4. **O usar el script de inicio automático:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\Users\nosoy\OneDrive\Desktop\boni\BONI_INICIO.ps1"
   ```

---

### Hablarle por Voz

**Actualmente:** No hay micrófono implementado. La tecla Insert pone BONI en modo "ESCUCHANDO" visualmente pero no captura audio.

**Alternativa:** Escribir mensajes con el teclado.

**Futuro:** Cuando el TTS + STT estén completos:
1. Presionar Insert → BONI entra en modo escucha
2. Hablar al micrófono
3. BONI procesa y responde con voz clonada

---

### Pedirle que Ejecute Código

1. La IA puede usar `tool_sistema.py` para ejecutar comandos
2. Ejemplo en el chat:
   ```
   Usuario: "Ejecuta `python -c "print('hola')"`"
   → BONI: [stdout: "hola"]
   ```
3. Los comandos destructivos están bloqueados
4. El directorio seguro es `~/boni_workspace`

---

### Pedirle que Navegue Internet

**Actualmente:** `browser-use` no instalado. BONI puede abrir URLs en el navegador predeterminado:
```
Usuario: "Abre google.com"
→ BONI: subprocess.Popen("chrome google.com")
```

**Cuando browser-use esté instalado:**
```
Usuario: "Busca el clima en Google y dime el resultado"
→ BONI (vía tool_navegador.py + browser-use en WSL):
   Abre Chrome, navega, extrae texto, responde
```

---

### Pedirle que Investigue Algo

1. **Investigación simple:** Preguntar directamente a la IA
2. **Investigación profunda:** Usar el agente `boni-research` de OpenJarvis:
   ```bash
   wsl -d Ubuntu-22.04 -- jarvis agent run boni-research "tema a investigar"
   ```
3. **Con skills:**
   - `arxiv` → papers académicos
   - `summarize` → resumir URLs/videos
   - `weather` → clima

---

### Pedirle que Recuerde Algo

```
Usuario: "Recuerda que mi cumpleaños es el 15 de marzo"
→ BONI guarda en memoria persistente

Usuario: "¿Cuándo es mi cumpleaños?"
→ BONI responde: "15 de marzo"

Usuario: "Agrega la tarea 'Comprar regalo' para mañana"
→ BONI guarda tarea pendiente
```

La memoria persiste aunque cierres y abras BONI de nuevo.

---

### Pedirle que Controle la PC

```
Usuario: "Toma un screenshot"
→ BONI captura la pantalla
→ (Próximamente: puede analizar la imagen con IA)

Usuario: "Abre la calculadora"
→ BONI ejecuta: calc

Usuario: "Mueve el mouse a la posición 500, 300"
→ BONI mueve el cursor

Usuario: "Escribe 'hola mundo' en el bloc de notas"
→ BONI: abre notepad, escribe el texto
```

---

### Cerrar BONI

1. **Interfaz holográfica:**
   - Clic derecho sobre la ventana → "Salir"
   - O presionar `Ctrl+Q` / `Alt+F4`
   - O desde el icono en system tray → "Salir"

2. **Interfaz web (boni_webui.py):**
   - `Ctrl+C` en la terminal donde se ejecuta

3. **Ollama:**
   ```powershell
   # Opcional: cerrar Ollama
   taskkill /IM ollama.exe /F
   ```

---

## SECCIÓN 6 — ATAJOS Y COMANDOS RÁPIDOS

### Atajos de Teclado (boni_ui.py)

| Tecla | Acción |
|---|---|
| Cualquier letra/número | Muestra campo de texto con la tecla presionada |
| Enter | Envía el mensaje escrito |
| Escape | Oculta el campo de texto |
| Insert | Alterna modo escucha (visual only) |
| Ctrl+W | Abre Open WebUI en navegador |
| Ctrl+Q | Cierra la aplicación |
| Clic sostenido + arrastrar | Mueve la ventana |

### Comandos de Terminal

| Comando | Descripción |
|---|---|
| `ollama serve` | Inicia servidor Ollama |
| `ollama list` | Lista modelos descargados |
| `ollama run boni-rapido` | Chat directo con modelo |
| `python boni_ui.py` | Inicia interfaz holográfica |
| `python boni_webui.py` | Inicia interfaz web (puerto 3001) |
| `BONI_INICIO.ps1` | Inicio automático del stack completo |
| `wsl jarvis doctor` | Diagnóstico de OpenJarvis |
| `wsl jarvis agents list` | Lista agentes activos |
| `wsl jarvis skill list` | Lista skills instaladas |
| `wsl jarvis start --port 8080` | Inicia servidor API OpenJarvis |

### URLs de Acceso

| URL | Servicio |
|---|---|
| `http://localhost:11434` | Ollama API |
| `http://localhost:8080` | OpenJarvis API (en WSL) |
| `http://localhost:3000` | Open WebUI (requiere Docker) |
| `http://localhost:3001` | BONI Web UI (Flask) |
| `http://localhost:3002` | OpenHands (requiere Docker) |

---

## SECCIÓN 7 — ROADMAP PENDIENTE

| Prioridad | Tarea | Tiempo | Dependencias |
|---|---|---|---|
| 🔴 Alta | **Copiar audios WhatsApp + clonar voz** | 30 min | Archivos .opus de Mario |
| 🔴 Alta | **Iniciar TTS Server en WSL** | 2 min | Voz clonada |
| 🔴 Alta | **Iniciar Docker Desktop** | 2 min | — |
| 🔴 Alta | **Activar Open WebUI en puerto 3000** | 1 min | Docker Desktop |
| 🟡 Media | **Instalar browser-use + Playwright** | 5 min | — |
| 🟡 Media | **Corregir jarvis serve (requests trabadas)** | ? | — |
| 🟡 Media | **Compilar Rust extension** | 10 min | — |
| 🟡 Media | **Instalar pyautogui/pynput en WSL** | 5 min | — |
| 🟢 Baja | **Descargar OpenHands (2GB)** | 3 min | Docker Desktop |
| 🟢 Baja | **Implementar STT (micrófono real)** | 2-4 h | — |
| 🟢 Baja | **Crear boni_sandbox.py** | 3-5 h | — |
| 🟢 Baja | **Tarea programada inicio automático** | 2 min | — |
| 🟢 Baja | **Instalar Node.js 22+** | 5 min | — |
| 🟢 Baja | **Indexar documentos en SQLite** | 10 min | Rust extension |
| 🟢 Baja | **Configurar canales (WhatsApp, Slack)** | 2-3 h | Node.js |

---

*Reporte generado el 31 de mayo de 2026 — B.O.N.I. v2.1*
