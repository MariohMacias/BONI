# BONI — Business Operations Neural Intelligence
## Guía completa de instalación y uso

---

## ¿Qué es BONI?

BONI es tu asistente de IA personal que corre **100% en tu computadora**:
- Sin suscripciones ni pagos
- Sin enviar datos a la nube
- Sin límites de uso
- Funciona sin internet (después de la instalación)

**Stack:**
- 🧠 **Ollama** — motor que ejecuta el modelo de lenguaje local
- 💬 **Open WebUI** — panel de chat (via Docker)
- 🤖 **qwen2.5:7b** — el modelo de lenguaje (~4.7 GB, buen español)

---

## Requisitos mínimos

| Componente | Mínimo | Tu máquina |
|---|---|---|
| RAM | 8 GB | 12 GB ✓ |
| CPU | 4 núcleos | Ryzen 3 5300U ✓ |
| Disco libre | 10 GB | — |
| OS | Windows 10 | Windows 10 ✓ |

---

## Instalación (3 pasos)

### Paso 0 — Instalar Docker Desktop (si no lo tienes)
https://www.docker.com/products/docker-desktop/

Asegúrate de que Docker Desktop esté **corriendo** antes de continuar.

### Paso 1 — Ejecutar el instalador
```
Doble clic en: 1_INSTALAR_BONI.bat
```
Esto instala Ollama, descarga el modelo (~4.7 GB) y levanta Open WebUI.
Primera vez puede tardar 10-20 minutos dependiendo de tu internet.

### Paso 2 — Configurar la personalidad de BONI
```
Doble clic en: 2_CONFIGURAR_BONI.bat
```
Sigue las instrucciones que aparecen.

### Paso 3 — Uso diario
```
Doble clic en: 3_INICIAR_BONI.bat
```
Menú para iniciar/detener/actualizar BONI.

---

## Configuración manual del system prompt

1. Abre http://localhost:3000
2. Crea tu cuenta (la primera cuenta = administrador)
3. Ve a **Settings → Workspace → Models**
4. Edita el modelo **qwen2.5:7b**
5. En el campo **System Prompt**, pega todo el contenido de `BONI_system_prompt.txt`
6. Guarda

---

## Instalar herramientas (Tools)

Las herramientas le dan a BONI la capacidad de actuar:

1. En Open WebUI ve a **Settings → Tools → (+) Add Tool**
2. Copia el código de `BONI_tools/tool_memoria.py` y pégalo
3. Guarda como "Memoria BONI"
4. Repite con `BONI_tools/tool_sistema.py` → "Sistema BONI"

Para activar en una conversación:
- Busca el ícono ⚙ en la barra inferior del chat
- Activa las tools que quieras usar

---

## ¿Cómo se "auto-modifica" BONI?

La "auto-modificación" en la práctica funciona así:

1. **Memoria persistente**: BONI guarda información entre sesiones. Puedes decirle "recuerda que prefiero respuestas cortas" y lo guardará en `~/.boni/memoria.json`.

2. **Ejecución de código**: Con `tool_sistema.py`, BONI puede escribir un script y ejecutarlo. Puedes pedirle que mejore sus propias herramientas.

3. **Actualización del system prompt**: Puedes pedirle a BONI que sugiera mejoras a su propio system prompt y luego aplicarlas tú en la configuración.

4. **Pipelines** (avanzado): Open WebUI tiene una función llamada "Pipelines" que permite crear flujos de procesamiento que BONI puede usar para tareas complejas.

---

## Comandos útiles

```bash
# Ver modelos instalados
ollama list

# Descargar un modelo adicional (más pequeño, más rápido)
ollama pull phi3.5:3.8b

# Ver contenedor de Open WebUI
docker ps

# Reiniciar Open WebUI
docker restart open-webui

# Ver logs si algo falla
docker logs open-webui --tail 50
```

---

## Estructura de archivos

```
BONI/
├── 1_INSTALAR_BONI.bat      ← Instalación completa
├── 2_CONFIGURAR_BONI.bat    ← Configuración guiada
├── 3_INICIAR_BONI.bat       ← Control diario
├── BONI.bat                 ← Lanzar UI de escritorio
├── BONI_panel.html          ← Dashboard visual (abrir en navegador)
├── BONI_system_prompt.txt   ← Personalidad de BONI
├── boni_ui.py               ← UI de escritorio (PyQt6)
├── ollama_proxy.py          ← Proxy para funcionalidad extra
├── requirements.txt         ← Dependencias Python
├── .env.example             ← Configuración de entorno (copiar a .env)
├── .gitignore
├── LICENSE                  ← MIT
├── README.md                ← Esta guía
├── BONI_tools/
│   ├── tool_memoria.py      ← Memoria persistente
│   ├── tool_sistema.py      ← Archivos y terminal
│   ├── tool_pc_control.py   ← Control de mouse/teclado
│   └── tool_navegador.py    ← Automatización de navegador
├── voz/
│   ├── clonar_voz.py        ← Clonación de voz TTS
│   └── preparar_audios.py   ← Preparación de muestras
└── *.{bat,ps1}              ← Scripts de instalación/control
```

### Instalación desde código fuente

```bash
# 1. Clonar
git clone https://github.com/tuusuario/boni.git
cd boni

# 2. Instalar dependencias Python
pip install -r requirements.txt

# 3. Copiar y configurar entorno
cp .env.example .env
# Edita .env con tus valores

# 4. Ejecutar
python boni_ui.py
```

---

## Solución de problemas

**"Ollama no responde"**
```bat
ollama serve
```

**"Open WebUI no carga"**
```bat
docker start open-webui
```

**"El modelo responde muy lento"**
- Prueba con un modelo más pequeño: `ollama pull phi3.5:3.8b`
- Cierra otras aplicaciones pesadas mientras usas BONI

**"Error de Docker"**
- Asegúrate de que Docker Desktop esté abierto y corriendo
- Reinicia Docker Desktop si es necesario

---

## Fase 2 — Integración con WhatsApp (opcional)

Una vez que BONI funcione bien en el panel web, puedes conectarlo a WhatsApp usando OpenClaw (que ya tienes instalado):

1. En OpenClaw, cambia el backend de Groq a Ollama
2. Configura `ollamaUrl: "http://localhost:11434"`
3. Usa el modelo `qwen2.5:7b`

Esto te permitirá hablarle a BONI por WhatsApp y recibir respuestas del modelo local.

---

*BONI v2.1 — Creado por Mario Macías — Monterrey, México*
