import sys, os, json, time, threading, subprocess, tempfile, random, math, uuid, re
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from PyQt6.QtWidgets import (
    QApplication, QWidget, QLineEdit, QSystemTrayIcon, QMenu,
    QMessageBox, QDialog, QVBoxLayout, QHBoxLayout, QLabel
)
from PyQt6.QtCore import Qt, QTimer, QRect, QRectF, QPoint, QPointF, QUrl
from PyQt6.QtGui import (
    QPainter, QColor, QRadialGradient, QBrush, QPen, QFont, QPainterPath,
    QPixmap, QIcon, QAction, QDesktopServices, QFontMetrics, QMouseEvent,
    QKeyEvent, QCloseEvent, QCursor
)


OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
JARVIS_URL = os.environ.get("JARVIS_URL", "http://127.0.0.1:8000")
JARVIS_KEY = os.environ.get("JARVIS_KEY", "boni-local-key")
TTS_PORT = 5050
MODELO_BONI = "boni-rapido:latest"
HISTORIAL_PATH = os.path.expanduser("~/.boni/chat_history.json")

W, H = 520, 580
CX, CY = W / 2, 240
ORBE_R = 110

FONDO = QColor(0x00, 0x00, 0x08)
ORBE_C1 = QColor(0xFF, 0xFF, 0xFF)
ORBE_C2 = QColor(0x7E, 0xC8, 0xE3)
ORBE_C3 = QColor(0x4A, 0x9B, 0xC7)
ANILLO = QColor(0x1A, 0x3A, 0x5A)
ANILLO_ACT = QColor(0x4A, 0x9B, 0xC7)
PARTICULA = QColor(0x2A, 0x6A, 0x9A)
TEXTO = QColor(0xE8, 0xF4, 0xFD)
TEXTO_USER = QColor(0x7E, 0xC8, 0xE3)
ACENTO = QColor(0x00, 0xD4, 0xFF)
LINEAS_SCAN = QColor(0x0A, 0x1A, 0x2A)
GLOW = QColor(0x4A, 0x9B, 0xC7, 90)


class AutoTune:
    CONTEXTOS = {
        "creative":   {"temperature": 0.9, "top_p": 0.95, "keywords": ["escribe", "crea", "imagina", "historia", "poema", "inventa"]},
        "technical":  {"temperature": 0.2, "top_p": 0.85, "keywords": ["codigo", "error", "debug", "funcion", "script", "instala", "configura"]},
        "factual":    {"temperature": 0.1, "top_p": 0.80, "keywords": ["que es", "como funciona", "explica", "define", "cuando", "donde"]},
        "reasoning":  {"temperature": 0.4, "top_p": 0.90, "keywords": ["analiza", "compara", "por que", "evalua", "decide", "estrategia"]},
        "casual":     {"temperature": 0.7, "top_p": 0.92, "keywords": ["hola", "oye", "que", "como estas", "ayuda", "dime"]}
    }
    EMA_ALPHA = 0.1

    def __init__(self):
        self.scores = {ctx: 0.5 for ctx in self.CONTEXTOS}
        self.history_file = os.path.expanduser("~/.boni/autotune.json")
        self.cargar()

    def detectar_contexto(self, texto):
        lower = texto.lower()
        scores = {}
        for ctx, data in self.CONTEXTOS.items():
            scores[ctx] = sum(1 for kw in data["keywords"] if kw in lower)
        mejor = max(scores, key=scores.get)
        return mejor if scores[mejor] > 0 else "casual"

    def get_params(self, texto):
        ctx = self.detectar_contexto(texto)
        params = self.CONTEXTOS[ctx].copy()
        params.pop("keywords")
        params["context_type"] = ctx
        return params

    def feedback(self, contexto, positivo):
        delta = self.EMA_ALPHA if positivo else -self.EMA_ALPHA
        self.scores[contexto] = max(0.1, min(0.9, self.scores[contexto] + delta))
        self.guardar()

    def cargar(self):
        try:
            with open(self.history_file) as f:
                self.scores = json.load(f)
        except Exception:
            pass

    def guardar(self):
        os.makedirs(os.path.dirname(self.history_file), exist_ok=True)
        with open(self.history_file, 'w') as f:
            json.dump(self.scores, f)


class STMModules:
    HEDGES_ES = [
        r"(?i)^(claro que si[,.]?\s*)",
        r"(?i)^(por supuesto[,.]?\s*)",
        r"(?i)^(entendido[,.]?\s*)",
        r"(?i)^(desde luego[,.]?\s*)",
        r"(?i)^(con mucho gusto[,.]?\s*)",
        r"(?i)\b(creo que|me parece que|posiblemente|quizas|tal vez|podria ser que)\b",
        r"(?i)\b(en mi opinion|a mi parecer|segun mi criterio)\b",
        r"(?i)(espero que esto (te |le )?ayude\.?\s*$)",
        r"(?i)(si (tienes|tiene) (mas )?preguntas.{0,50}$)",
        r"(?i)((hay|existe) algo mas (en )?que pueda ayudarte\??\.?\s*$)",
        r"(?i)(no dudes en (preguntar|consultarme).{0,50}$)",
    ]

    PREAMBLES = [
        r"(?i)^((hola|buenas)[!,.]?\s*)",
        r"(?i)^(esa es una (buena|excelente|interesante) (pregunta|consulta)[.!,]\s*)",
        r"(?i)^(me alegra que (lo preguntes|preguntes eso)[.!,]\s*)",
    ]

    DIRECT_PATTERNS = [
        (r"(?i)en primer lugar,?\s*", ""),
        (r"(?i)en segundo lugar,?\s*", ""),
        (r"(?i)en resumen,?\s*", ""),
        (r"(?i)como conclusion,?\s*", ""),
    ]

    def __init__(self):
        self.hedge_reducer = True
        self.direct_mode = True
        self.curiosity_bias = True

    def aplicar(self, texto):
        if self.hedge_reducer:
            for patron in self.HEDGES_ES + self.PREAMBLES:
                texto = re.sub(patron, "", texto)
        if self.direct_mode:
            for patron, reemplazo in self.DIRECT_PATTERNS:
                texto = re.sub(patron, reemplazo, texto)
        texto = re.sub(r'\n{3,}', '\n\n', texto)
        texto = texto.strip()
        return texto


class GodmodeLocal:
    MODELOS = [
        {"nombre": "BONI",      "model": "boni-rapido:latest",  "emoji": chr(0x1F535)},
        {"nombre": "QWEN 7B",   "model": "qwen2.5:7b",          "emoji": chr(0x1F7E3)},
        {"nombre": "DEEPSEEK",  "model": "deepseek-r1:8b",      "emoji": chr(0x1F7E1)},
        {"nombre": "GEMMA",     "model": "gemma3:4b",           "emoji": chr(0x1F7E2)},
    ]

    def __init__(self, stm):
        self.stm = stm
        self.activo = False

    def consultar_modelo(self, modelo_cfg, mensaje, params):
        inicio = time.time()
        try:
            r = requests.post(f"{OLLAMA_URL}/api/chat", json={
                "model": modelo_cfg["model"],
                "messages": [{"role": "user", "content": mensaje}],
                "stream": False,
                "options": {
                    "temperature": params.get("temperature", 0.7),
                    "top_p": params.get("top_p", 0.9),
                }
            }, timeout=60)
            if r.status_code == 200:
                texto = r.json()["message"]["content"]
                texto = self.stm.aplicar(texto)
                return {
                    "nombre": modelo_cfg["nombre"],
                    "emoji": modelo_cfg["emoji"],
                    "modelo": modelo_cfg["model"],
                    "texto": texto,
                    "tiempo": round(time.time() - inicio, 1),
                    "exito": True
                }
        except Exception:
            pass
        return {
            "nombre": modelo_cfg["nombre"],
            "emoji": modelo_cfg["emoji"],
            "texto": "Sin respuesta",
            "tiempo": round(time.time() - inicio, 1),
            "exito": False
        }

    def consultar_todos(self, mensaje, params):
        resultados = []
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {executor.submit(self.consultar_modelo, m, mensaje, params): m for m in self.MODELOS}
            for future in as_completed(futures):
                resultados.append(future.result())
        return sorted(resultados, key=lambda x: x["tiempo"])


class ChatHistory:
    def __init__(self):
        self.path = HISTORIAL_PATH
        self.conversaciones = []

    def cargar(self, max_conv=10):
        try:
            with open(self.path) as f:
                data = json.load(f)
            self.conversaciones = data.get("conversaciones", [])[-max_conv:]
        except Exception:
            self.conversaciones = []

    def guardar(self, entry):
        try:
            with open(self.path) as f:
                data = json.load(f)
        except Exception:
            data = {"conversaciones": []}
        data["conversaciones"].append(entry)
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, 'w') as f:
            json.dump(data, f)

    def obtener_contexto(self):
        ctx = []
        for c in self.conversaciones[-6:]:
            ctx.append({"role": "user", "content": c["usuario"]})
            ctx.append({"role": "assistant", "content": c["respuesta"]})
        return ctx


class BONIWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedSize(W, H)

        screen = QApplication.primaryScreen().geometry()
        self.move(screen.width() - W - 30, screen.height() - H - 60)

        self.state = "idle"
        self.angle = 0.0
        self.pulse = 0.0
        self.status_text = ""
        self.response_text = ""
        self.response_display = ""
        self.user_text = ""
        self.streaming = False
        self.showing_input = False
        self.godmode_active = False
        self.godmode_results = []
        self.godmode_loading = False
        self.last_context = "casual"
        self.fade_alpha = 0
        self.token_buffer = ""
        self.token_timer = 0
        self.tts_playing = False
        self.dragging = False
        self.drag_pos = QPoint()
        self.wsl_ip = "172.17.0.1"
        self.conversation = []
        self.last_response_full = ""

        self.autotune = AutoTune()
        self.stm = STMModules()
        self.godmode = GodmodeLocal(self.stm)
        self.history = ChatHistory()
        self.history.cargar()
        self.conversation = self.history.obtener_contexto()

        self.particles = []
        for _ in range(25):
            a = random.random() * math.pi * 2
            r_val = random.random() * 130 + ORBE_R + 20
            self.particles.append({
                "angle": a, "radius": r_val,
                "speed": (random.random() - 0.5) * 0.008,
                "size": random.random() * 3 + 1.5,
                "alpha": random.random() * 80 + 40,
                "phase": random.random() * math.pi * 2,
                "color_group": random.randint(0, 3)
            })

        self.input_field = QLineEdit(self)
        self.input_field.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.input_field.setFixedSize(320, 34)
        self.input_field.move((W - 320) // 2, H - 80)
        self.input_field.hide()
        self.input_field.setStyleSheet(
            "QLineEdit {"
            "  background: rgba(0,0,10,0.85);"
            "  color: #7EC8E3;"
            "  border: 1px solid #1A3A5A;"
            "  border-radius: 17px;"
            "  padding: 4px 16px;"
            "  font-size: 13px;"
            "  font-family: 'Consolas', monospace;"
            "  selection-background-color: #4A9BC7;"
            "}"
            "QLineEdit:focus { border-color: #4A9BC7; }"
        )
        self.input_field.returnPressed.connect(self._on_input_send)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self._tick)
        self.timer.start(30)

        self._detect_wsl_ip()
        self._setup_tray()

    def _setup_tray(self):
        pix = QPixmap(16, 16)
        pix.fill(QColor(0x4A, 0x9B, 0xC7))
        self.tray = QSystemTrayIcon(QIcon(pix), self)
        menu = QMenu()
        menu.setStyleSheet(
            "QMenu { background: #05050F; color: #7EC8E3; border: 1px solid #1A3A5A; padding: 4px; }"
            "QMenu::item:selected { background: #1A3A5A; }"
        )
        a_webui = menu.addAction("Abrir WebUI (Ctrl+W)")
        a_webui.triggered.connect(lambda: QDesktopServices.openUrl(QUrl("http://localhost:3000")))
        a_godmode = menu.addAction("GODMODE (Ctrl+G)")
        a_godmode.triggered.connect(self.toggle_godmode)
        a_status = menu.addAction("Estado (F1)")
        a_status.triggered.connect(self.mostrar_estado_sistema)
        menu.addSeparator()
        a_salir = menu.addAction("Salir")
        a_salir.triggered.connect(self.close)
        self.tray.setContextMenu(menu)
        self.tray.setToolTip("B.O.N.I. v2.1")
        self.tray.show()
        self.tray.activated.connect(
            lambda r: self.show() if r == QSystemTrayIcon.ActivationReason.DoubleClick else None
        )

    def _detect_wsl_ip(self):
        threading.Thread(target=self._detect_wsl_ip_async, daemon=True).start()

    def _detect_wsl_ip_async(self):
        try:
            out = subprocess.check_output(
                ["wsl", "-d", "Ubuntu-22.04", "--", "hostname", "-I"],
                text=True, timeout=8
            ).strip().split()[0]
            if out:
                self.wsl_ip = out
        except Exception:
            pass

    def _tick(self):
        self.angle += 1.2
        speeds = {"idle": 0.02, "listening": 0.10, "processing": 0.07, "speaking": 0.14, "godmode": 0.08}
        self.pulse += speeds.get(self.state, 0.02)
        if self.fade_alpha > 0:
            self.fade_alpha = max(0, self.fade_alpha - 4)

        for p in self.particles:
            p["angle"] += p["speed"]
            if self.state == "processing":
                p["angle"] += 0.003
            elif self.state == "godmode":
                p["angle"] += 0.005 * (1 + p["color_group"] * 0.3)

        if self.token_buffer and self.state != "processing":
            self._flush_token_buffer()
        if self.token_buffer:
            self.token_timer += 1
            if self.token_timer >= 3:
                self._flush_token_buffer()

        self.update()

    def _flush_token_buffer(self):
        if self.token_buffer:
            self.response_display += self.token_buffer
            self.token_buffer = ""
        self.token_timer = 0

    def set_state(self, s):
        self.state = s
        mapa = {"idle": "", "listening": "ESCUCHANDO", "processing": "PROCESANDO",
                "speaking": "HABLANDO", "godmode": "GODMODE"}
        self.status_text = mapa.get(s, "")

    def _pulse_scale(self):
        base = {"idle": 0.02, "listening": 0.10, "processing": 0.07, "speaking": 0.14, "godmode": 0.06}.get(self.state, 0.02)
        return 1 + math.sin(self.pulse) * base * 0.4

    def _ring_speed(self, idx):
        speeds = {"idle": [1.0, -0.7, 0.5], "speaking": [2.5, -2.0, 1.8], "godmode": [2.0, -1.5, 2.5]}
        s = speeds.get(self.state, [1.5, -1.2, 1.0])
        return s[idx] if idx < len(s) else 1.0

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)

        painter.fillRect(self.rect(), Qt.GlobalColor.transparent)
        self._draw_vignette(painter)
        self._draw_scanlines(painter)

        ring_angles = [
            self.angle * self._ring_speed(0),
            self.angle * self._ring_speed(1),
            self.angle * self._ring_speed(2)
        ]
        for idx, (rad, col) in enumerate([(ORBE_R + 35, ANILLO), (ORBE_R + 75, ANILLO), (ORBE_R + 115, ANILLO)]):
            active = ANILLO_ACT if self.state in ("processing", "speaking", "godmode") else ANILLO
            self._draw_ring(painter, rad, active, ring_angles[idx], idx)

        if self.state == "godmode":
            self._draw_godmode_orbits(painter)

        self._draw_particles(painter)
        self._draw_orbe(painter)

        shadow = QRadialGradient(CX, CY + ORBE_R * 0.8, ORBE_R * 0.5)
        shadow.setColorAt(0.0, QColor(0, 0, 10, 60))
        shadow.setColorAt(1.0, QColor(0, 0, 10, 0))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QBrush(shadow))
        painter.drawEllipse(QPointF(CX, CY + ORBE_R * 1.0), ORBE_R * 0.4, ORBE_R * 0.12)

        self._draw_text(painter)
        self._draw_bottom_bar(painter)

    def _draw_vignette(self, painter):
        grad = QRadialGradient(CX, CY, W * 0.55)
        grad.setColorAt(0.0, QColor(0, 0, 0, 0))
        grad.setColorAt(0.6, QColor(0, 0, 0, 0))
        grad.setColorAt(0.85, QColor(0, 0, 8, 80))
        grad.setColorAt(1.0, QColor(0, 0, 8, 200))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QBrush(grad))
        painter.drawRect(self.rect())

    def _draw_scanlines(self, painter):
        painter.setPen(QPen(LINEAS_SCAN, 1))
        for y in range(0, H, 3):
            painter.drawLine(0, y, W, y)

    def _draw_ring(self, painter, radius, color, angle_offset, idx):
        pen = QPen(QColor(color.red(), color.green(), color.blue(), 60), 1)
        pen.setStyle(Qt.PenStyle.DashLine)
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawEllipse(QPointF(CX, CY), radius, radius)

        pen2 = QPen(QColor(color.red(), color.green(), color.blue(), 140), 1.5)
        painter.setPen(pen2)
        for deg in range(0, 360, 30):
            rad = math.radians(deg + angle_offset)
            x1 = CX + (radius - 3) * math.cos(rad)
            y1 = CY + (radius - 3) * math.sin(rad)
            x2 = CX + (radius + 5) * math.cos(rad)
            y2 = CY + (radius + 5) * math.sin(rad)
            painter.drawLine(QPointF(x1, y1), QPointF(x2, y2))

    def _draw_godmode_orbits(self, painter):
        colors = [QColor(0x4A, 0x9B, 0xC7), QColor(0x9B, 0x59, 0xB6),
                  QColor(0xE5, 0xA0, 0x3D), QColor(0x3A, 0xC9, 0x6C)]
        radii = [ORBE_R + 45, ORBE_R + 85, ORBE_R + 125, ORBE_R + 165]
        for i, (rad, col) in enumerate(zip(radii, colors)):
            offset = self.angle * (1.0 + i * 0.3) + i * 45
            pen = QPen(QColor(col.red(), col.green(), col.blue(), 80), 1)
            pen.setStyle(Qt.PenStyle.DotLine)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawEllipse(QPointF(CX, CY), rad, rad)

            tick_rad = math.radians(offset)
            x1 = CX + (rad - 4) * math.cos(tick_rad)
            y1 = CY + (rad - 4) * math.sin(tick_rad)
            x2 = CX + (rad + 6) * math.cos(tick_rad)
            y2 = CY + (rad + 6) * math.sin(tick_rad)
            painter.setPen(QPen(col, 2))
            painter.drawLine(QPointF(x1, y1), QPointF(x2, y2))

    def _get_godmode_color(self, group):
        colors = [QColor(0x4A, 0x9B, 0xC7), QColor(0x9B, 0x59, 0xB6),
                  QColor(0xE5, 0xA0, 0x3D), QColor(0x3A, 0xC9, 0x6C)]
        return colors[group % 4]

    def _draw_particles(self, painter):
        for p in self.particles:
            x = CX + p["radius"] * math.cos(p["angle"])
            y = CY + p["radius"] * math.sin(p["angle"])
            alpha_factor = 0.6 + 0.4 * abs(math.sin(self.pulse + p["phase"]))
            alpha = int(p["alpha"] * alpha_factor)

            if self.state == "godmode":
                col = self._get_godmode_color(p["color_group"])
                color = QColor(col.red(), col.green(), col.blue(), alpha)
            else:
                color = QColor(PARTICULA.red(), PARTICULA.green(), PARTICULA.blue(), alpha)

            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QBrush(color))
            painter.drawEllipse(QPointF(x, y), p["size"], p["size"])

    def _draw_orbe(self, painter):
        scale = self._pulse_scale()
        r = ORBE_R * scale

        glow = QRadialGradient(CX, CY, r * 2.2)
        glow_alpha = int(50 + 20 * abs(math.sin(self.pulse)))
        if self.state == "speaking":
            glow_alpha = int(50 + 30 * abs(math.sin(self.pulse * 3)))
        elif self.state == "processing":
            glow_alpha = int(80 + 30 * abs(math.sin(self.pulse * 2)))
        elif self.state == "godmode":
            glow_alpha = int(70 + 25 * abs(math.sin(self.pulse * 1.5)))

        c = QColor(GLOW.red(), GLOW.green(), GLOW.blue(), glow_alpha)
        glow.setColorAt(0.0, c)
        glow.setColorAt(0.5, QColor(c.red(), c.green(), c.blue(), 20))
        glow.setColorAt(1.0, QColor(c.red(), c.green(), c.blue(), 0))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QBrush(glow))
        painter.drawEllipse(QPointF(CX, CY), r * 2.2, r * 2.2)

        grad = QRadialGradient(CX - r * 0.25, CY - r * 0.25, r)
        grad.setColorAt(0.0, ORBE_C1)
        grad.setColorAt(0.5, ORBE_C2)
        grad.setColorAt(0.85, ORBE_C3)
        grad.setColorAt(1.0, QColor(ORBE_C3.red(), ORBE_C3.green(), ORBE_C3.blue(), 200))
        painter.setBrush(QBrush(grad))
        painter.setPen(QPen(QColor(255, 255, 255, 40), 1))
        painter.drawEllipse(QPointF(CX, CY), r, r)

        hl_r = r * 0.35
        hl = QRadialGradient(CX - r * 0.3, CY - r * 0.3, hl_r)
        hl.setColorAt(0.0, QColor(255, 255, 255, 100))
        hl.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(hl))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QPointF(CX - r * 0.3, CY - r * 0.3), hl_r, hl_r)

        if self.state in ("processing", "speaking", "godmode"):
            arc_pen = QPen(ACENTO, 2.5)
            arc_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
            painter.setPen(arc_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            start = int(self.angle * 16)
            span = int((90 + 60 * abs(math.sin(self.pulse * 0.5))) * 16)
            painter.drawArc(QRectF(CX - r * 0.92, CY - r * 0.92, r * 1.84, r * 1.84), start, span)
            painter.drawArc(QRectF(CX - r * 0.92, CY - r * 0.92, r * 1.84, r * 1.84), start + 180 * 16, span)

        if self.state == "speaking":
            for w in range(1, 4):
                w_r = r + w * 15 + int(10 * abs(math.sin(self.pulse * 2 + w)))
                wp = QPen(QColor(ACENTO.red(), ACENTO.green(), ACENTO.blue(), 60 - w * 12), 1)
                painter.setPen(wp)
                painter.setBrush(Qt.BrushStyle.NoBrush)
                painter.drawEllipse(QPointF(CX, CY), w_r, w_r)

    def _draw_text(self, painter):
        if self.status_text:
            f_status = QFont("Consolas", 10)
            painter.setFont(f_status)
            painter.setPen(QPen(QColor(ACENTO.red(), ACENTO.green(), ACENTO.blue(), 180), 1))
            painter.drawText(QRectF(0, 30, W, 22), Qt.AlignmentFlag.AlignCenter, self.status_text)

        f_title = QFont("Consolas", 13)
        painter.setFont(f_title)
        painter.setPen(QPen(ORBE_C2, 1))
        painter.drawText(QRectF(0, CY + ORBE_R + 10, W, 20), Qt.AlignmentFlag.AlignCenter, "B.O.N.I.")

        f_ver = QFont("Consolas", 9)
        painter.setFont(f_ver)
        painter.setPen(QPen(ACENTO, 1))
        painter.drawText(QRectF(0, CY + ORBE_R + 28, W, 16), Qt.AlignmentFlag.AlignCenter, "v2.1")

        if self.response_display:
            f_resp = QFont("Consolas", 10)
            painter.setFont(f_resp)
            text_color = QColor(TEXTO.red(), TEXTO.green(), TEXTO.blue(), 230)
            painter.setPen(QPen(text_color, 1))
            lines = self._wrap_text(self.response_display, W - 80, f_resp)
            display_lines = lines[:4]
            text_rect = QRectF(40, CY + ORBE_R + 48, W - 80, 90)
            y_pos = text_rect.y()
            for line in display_lines:
                painter.drawText(QRectF(text_rect.x(), y_pos, text_rect.width(), 18),
                                 Qt.AlignmentFlag.AlignCenter, line)
                y_pos += 18

        if self.user_text:
            painter.setPen(QPen(TEXTO_USER, 1))
            f_user = QFont("Consolas", 10)
            painter.setFont(f_user)
            painter.drawText(QRectF(40, H - 105, W - 80, 20),
                             Qt.AlignmentFlag.AlignCenter, f"> {self.user_text}")

    def _draw_bottom_bar(self, painter):
        bar_y = H - 44
        bar_h = 38
        painter.fillRect(QRectF(0, bar_y, W, bar_h), QColor(0, 0, 10, 160))
        painter.setPen(QPen(QColor(ANILLO.red(), ANILLO.green(), ANILLO.blue(), 80), 1))
        painter.drawLine(0, bar_y, W, bar_y)

        icons = [
            (chr(0x1F399), "Voz", 40),
            (chr(0x26A1), "GODMODE", 130),
            (chr(0x1F310), "WebUI", 220),
            (chr(0x1F4CA), "Estado", 310),
            (chr(0x2716), "Minimizar", 400),
        ]
        f_icon = QFont("Segoe UI", 14)
        f_label = QFont("Consolas", 7)
        for sym, label, x in icons:
            is_active = (label == "GODMODE" and self.godmode_active)
            col = ACENTO if is_active else QColor(0x7E, 0xC8, 0xE3, 160)
            painter.setPen(QPen(col, 1))
            painter.setFont(f_icon)
            painter.drawText(QRectF(x - 15, bar_y + 2, 30, 22),
                             Qt.AlignmentFlag.AlignCenter, sym)
            painter.setFont(f_label)
            painter.setPen(QPen(QColor(col.red(), col.green(), col.blue(), 120), 1))
            painter.drawText(QRectF(x - 25, bar_y + 22, 50, 14),
                             Qt.AlignmentFlag.AlignCenter, label)

    def _wrap_text(self, text, max_width, font):
        metrics = QFontMetrics(font)
        words = text.split()
        lines = []
        current = ""
        for w in words:
            test = current + (" " if current else "") + w
            if metrics.horizontalAdvance(test) > max_width:
                if current:
                    lines.append(current)
                current = w
            else:
                current = test
        if current:
            lines.append(current)
        return lines if lines else [text]

    def keyPressEvent(self, event):
        key = event.key()
        mods = event.modifiers()

        if key == Qt.Key.Key_Insert:
            self._toggle_mic()
            return
        if key == Qt.Key.Key_Escape:
            if self.showing_input:
                self._hide_input()
            else:
                self.hide()
                self.tray.showMessage("B.O.N.I.", "Minimizado a bandeja",
                                      QSystemTrayIcon.MessageIcon.Information, 1500)
            return
        if key == Qt.Key.Key_F1:
            self.mostrar_estado_sistema()
            return

        if mods == Qt.KeyboardModifier.ControlModifier:
            if key == Qt.Key.Key_G:
                self.toggle_godmode()
                return
            if key == Qt.Key.Key_W:
                QDesktopServices.openUrl(QUrl("http://localhost:3000"))
                return
            if key == Qt.Key.Key_S:
                self._abrir_sandbox()
                return
            if key == Qt.Key.Key_Up:
                self._feedback_positivo()
                return
            if key == Qt.Key.Key_Down:
                self._feedback_negativo()
                return

        if event.matches(QKeySequence.StandardKey.Close):
            self.close()
            return

        if not self.showing_input:
            text = event.text()
            if text and (text.isprintable() or key in (Qt.Key.Key_Backspace, Qt.Key.Key_Return)):
                self._show_input()
                if key != Qt.Key.Key_Return:
                    self.input_field.setText(text)
                    self.input_field.setCursorPosition(1)
                return

        super().keyPressEvent(event)

    def _show_input(self):
        self.showing_input = True
        self.input_field.show()
        self.input_field.setFocus()
        self.input_field.clear()

    def _hide_input(self):
        self.showing_input = False
        self.input_field.hide()
        self.input_field.clear()
        self.setFocus()

    def _on_input_send(self):
        texto = self.input_field.text().strip()
        self._hide_input()
        if texto:
            self._send_message(texto)

    def _toggle_mic(self):
        if self.state == "idle":
            self.set_state("listening")
        else:
            self.set_state("idle")

    def _send_message(self, texto):
        if self.streaming:
            return
        self.streaming = True
        self.user_text = texto
        self.response_text = ""
        self.response_display = ""
        self.token_buffer = ""
        self.token_timer = 0
        self.fade_alpha = 255

        params = self.autotune.get_params(texto)
        self.last_context = params["context_type"]

        if self.godmode_active:
            self.set_state("godmode")
            self.godmode_loading = True
            self.godmode_results = []
            self.response_display = "GODMODE consultando 4 modelos...\n"
            threading.Thread(target=self._run_godmode, args=(texto, params), daemon=True).start()
        else:
            self.set_state("processing")
            self.conversation.append({"role": "user", "content": texto})
            threading.Thread(target=self._run_normal, args=(texto, params), daemon=True).start()

    def _run_normal(self, texto, params):
        try:
            payload = {
                "model": MODELO_BONI,
                "messages": self.conversation.copy(),
                "stream": True,
                "options": {
                    "temperature": params.get("temperature", 0.7),
                    "top_p": params.get("top_p", 0.9),
                }
            }
            r = requests.post(f"{OLLAMA_URL}/api/chat", json=payload, stream=True, timeout=60)
            full = ""
            for line in r.iter_lines():
                if not line:
                    continue
                d = json.loads(line.decode())
                content = d.get("message", {}).get("content", "")
                if content:
                    full += content
                    self.token_buffer += content
                    self.token_timer = 0
                if d.get("done"):
                    break
            cleaned = self.stm.aplicar(full)
            self.last_response_full = cleaned
            self.conversation.append({"role": "assistant", "content": cleaned})
            self._guardar_historial(texto, cleaned, params)
            self._on_response_done(cleaned)
        except requests.exceptions.ConnectionError:
            self._on_response_error("Ollama no disponible (Ctrl+G para GODMODE)")
        except Exception as e:
            self._on_response_error(f"Error: {str(e)[:60]}")

    def _run_godmode(self, texto, params):
        resultados = self.godmode.consultar_todos(texto, params)
        self.godmode_results = resultados
        self.godmode_loading = False
        lines = ["[ GODMODE ]\n"]
        for r in resultados:
            status = "" if r["exito"] else " [fallo]"
            resp_preview = r["texto"][:80].replace("\n", " ") + ("..." if len(r["texto"]) > 80 else "")
            lines.append(f"{r['emoji']} {r['nombre']} ({r['tiempo']}s):{status}")
            lines.append(f"  {resp_preview}\n")
        full = "\n".join(lines)
        self.last_response_full = full
        self._guardar_historial(texto, full, params)
        self._on_response_done(full)

    def _on_response_done(self, texto):
        self.streaming = False
        self._flush_token_buffer()
        self.set_state("speaking")
        QTimer.singleShot(100, lambda: self._reproducir_tts(texto))

    def _on_response_error(self, msg):
        self.streaming = False
        self.token_buffer = ""
        self.response_display = msg
        self.set_state("idle")

    def _guardar_historial(self, texto_usuario, texto_respuesta, params):
        entry = {
            "id": str(uuid.uuid4()),
            "fecha": datetime.now().isoformat(),
            "modo": "godmode" if self.godmode_active else "normal",
            "contexto_autotune": params.get("context_type", "casual"),
            "params": {"temperature": params.get("temperature"), "top_p": params.get("top_p")},
            "usuario": texto_usuario,
            "respuesta": texto_respuesta,
            "tiempo_respuesta": 0,
            "feedback": None
        }
        threading.Thread(target=self.history.guardar, args=(entry,), daemon=True).start()

    def _reproducir_tts(self, texto):
        if self.tts_playing:
            return
        try:
            texto_tts = texto[:300]
            r = requests.post(f"http://{self.wsl_ip}:{TTS_PORT}/tts",
                              json={"texto": texto_tts}, timeout=30)
            if r.status_code == 200:
                self.tts_playing = True
                import pygame
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                    tmp.write(r.content)
                    p = tmp.name
                try:
                    pygame.mixer.init()
                    pygame.mixer.music.load(p)
                    pygame.mixer.music.play()
                    while pygame.mixer.music.get_busy():
                        time.sleep(0.1)
                except Exception:
                    pass
                finally:
                    try:
                        os.unlink(p)
                    except Exception:
                        pass
                    self.tts_playing = False
        except Exception:
            pass
        finally:
            QTimer.singleShot(2000, lambda: self.set_state("idle"))

    def toggle_godmode(self):
        self.godmode_active = not self.godmode_active
        self.godmode.activo = self.godmode_active
        if self.godmode_active:
            self.set_state("godmode")
            msg = "GODMODE activado"
        else:
            self.set_state("idle")
            msg = "GODMODE desactivado"
        self.tray.showMessage("B.O.N.I.", msg, QSystemTrayIcon.MessageIcon.Information, 1500)

    def mostrar_estado_sistema(self):
        lines = []
        lines.append("B.O.N.I. v2.1 — Estado del sistema\n")

        lines.append(f"Estado UI: {self.state.upper()}")
        lines.append(f"GODMODE: {'ACTIVO' if self.godmode_active else 'inactivo'}")
        lines.append(f"AutoTune: {self.last_context}")
        lines.append("")

        try:
            r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=3)
            if r.status_code == 200:
                models = r.json().get("models", [])
                lines.append(f"Ollama: OK ({len(models)} modelos)")
                for m in models[:4]:
                    lines.append(f"  - {m['name']}")
            else:
                lines.append("Ollama: ERROR")
        except Exception:
            lines.append("Ollama: No disponible")

        lines.append("")
        try:
            r = requests.get(f"{JARVIS_URL}/health", timeout=3)
            if r.status_code == 200:
                lines.append("OpenJarvis: OK")
            else:
                lines.append("OpenJarvis: ERROR")
        except Exception:
            lines.append("OpenJarvis: No disponible")

        lines.append("")
        try:
            r = requests.get(f"http://{self.wsl_ip}:{TTS_PORT}/health", timeout=3)
            if r.status_code == 200:
                lines.append(f"TTS Server: OK")
            else:
                lines.append(f"TTS Server: Error")
        except Exception:
            lines.append(f"TTS Server: No disponible")

        lines.append("")
        lines.append(f"WSL IP: {self.wsl_ip}")
        lines.append(f"AutoTune scores: {json.dumps({k: round(v,2) for k,v in self.autotune.scores.items()})}")

        msg = "\n".join(lines)
        dialog = QDialog(self)
        dialog.setWindowTitle("Estado B.O.N.I.")
        dialog.setFixedSize(380, 420)
        dialog.setStyleSheet(
            "QDialog { background: #000008; color: #7EC8E3; border: 1px solid #1A3A5A; }"
            "QLabel { color: #7EC8E3; font-family: Consolas; font-size: 10px; padding: 6px; }"
        )
        layout = QVBoxLayout()
        label = QLabel(msg)
        label.setWordWrap(True)
        layout.addWidget(label)
        dialog.setLayout(layout)
        dialog.exec()

    def _feedback_positivo(self):
        self.autotune.feedback(self.last_context, True)
        self.tray.showMessage("AutoTune", f"Feedback + para {self.last_context}",
                              QSystemTrayIcon.MessageIcon.Information, 1500)

    def _feedback_negativo(self):
        self.autotune.feedback(self.last_context, False)
        self.tray.showMessage("AutoTune", f"Feedback - para {self.last_context}",
                              QSystemTrayIcon.MessageIcon.Information, 1500)

    def _abrir_sandbox(self):
        try:
            subprocess.Popen(["python", os.path.expanduser("~/Desktop/boni/boni_sandbox.py")],
                             creationflags=subprocess.CREATE_NO_WINDOW)
        except Exception:
            pass

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            bar_y = H - 44
            mx = int(event.position().x())
            my = int(event.position().y())

            if bar_y <= my <= H:
                button_centers = [40, 130, 220, 310, 400]
                labels = ["Voz", "GODMODE", "WebUI", "Estado", "Minimizar"]
                for x, lbl in zip(button_centers, labels):
                    if abs(mx - x) < 30:
                        if lbl == "Voz":
                            self._toggle_mic()
                        elif lbl == "GODMODE":
                            self.toggle_godmode()
                        elif lbl == "WebUI":
                            QDesktopServices.openUrl(QUrl("http://localhost:3000"))
                        elif lbl == "Estado":
                            self.mostrar_estado_sistema()
                        elif lbl == "Minimizar":
                            self.hide()
                            self.tray.showMessage("B.O.N.I.", "Minimizado a bandeja",
                                                  QSystemTrayIcon.MessageIcon.Information, 1500)
                        return

            self.drag_pos = event.globalPosition().toPoint()
            self.dragging = True

    def mouseMoveEvent(self, event):
        if hasattr(self, 'dragging') and self.dragging:
            delta = event.globalPosition().toPoint() - self.drag_pos
            self.move(self.pos() + delta)
            self.drag_pos = event.globalPosition().toPoint()

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.dragging = False

    def contextMenuEvent(self, event):
        menu = QMenu(self)
        menu.setStyleSheet(
            "QMenu { background: #05050F; color: #7EC8E3; border: 1px solid #1A3A5A; padding: 4px; }"
            "QMenu::item:selected { background: #1A3A5A; }"
        )
        a_webui = menu.addAction("Abrir WebUI")
        a_webui.triggered.connect(lambda: QDesktopServices.openUrl(QUrl("http://localhost:3000")))
        a_gm = menu.addAction(f"{'Desactivar' if self.godmode_active else 'Activar'} GODMODE")
        a_gm.triggered.connect(self.toggle_godmode)
        a_state = menu.addAction(f"Estado: {self.state.upper()}")
        a_state.setEnabled(False)
        menu.addSeparator()
        a_salir = menu.addAction("Salir")
        a_salir.triggered.connect(self.close)
        menu.exec(event.globalPosition().toPoint())

    def closeEvent(self, event):
        self.tray.hide()
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    w = BONIWindow()
    w.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
