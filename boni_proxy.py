import http.server, urllib.request, json, os, sys, socket, re

DIR = os.path.dirname(os.path.abspath(__file__))
OLLAMA = "http://127.0.0.1:11434"
JARVIS = "http://127.0.0.1:8000"
TTS_IP = "127.0.0.1"
TTS_PORT = 5050
SANDBOX = "http://127.0.0.1:8765"

def _load_env(key, default=""):
    try:
        with open(os.path.join(DIR, ".env")) as f:
            for line in f:
                if line.startswith(key + "="):
                    return line.strip().split("=", 1)[1]
    except:
        pass
    return default

def detect_tts():
    global TTS_IP
    candidates = ["127.0.0.1"]
    wsl_ip = _load_env("WSL_IP")
    win_gw = _load_env("WIN_GW")
    if wsl_ip:
        candidates.append(wsl_ip)
    if win_gw:
        candidates.append(win_gw)
    for gw in ["172.17.0.1", "172.29.176.1", "172.29.191.230"]:
        if gw not in candidates:
            candidates.append(gw)
    for ip in candidates:
        try:
            r = urllib.request.urlopen(f"http://{ip}:{TTS_PORT}/health", timeout=2)
            if r.status == 200:
                TTS_IP = ip
                return
        except:
            pass

ROUTES = {
    # Ollama
    ("GET", "/api/ollama/tags"):     (OLLAMA, "/api/tags"),
    ("POST", "/api/ollama/chat"):    (OLLAMA, "/api/chat"),
    ("POST", "/api/ollama/generate"):(OLLAMA, "/api/generate"),
    # Jarvis
    ("GET", "/api/jarvis/health"):   (JARVIS, "/health"),
    ("GET", "/api/jarvis/skills"):   (JARVIS, "/api/skills"),
    ("POST", "/api/jarvis/chat"):    (JARVIS, "/v1/chat/completions"),
    ("POST", "/api/jarvis/tools/screenshot"): (JARVIS, "/api/tools/screenshot"),
    # TTS
    ("GET", "/api/tts/health"):      (f"http://{TTS_IP}:{TTS_PORT}", "/health"),
    ("POST", "/api/tts/speak"):      (f"http://{TTS_IP}:{TTS_PORT}", "/tts"),
    # Sandbox
    ("POST", "/api/sandbox/ejecutar"):(SANDBOX, "/ejecutar"),
}

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/boni_chat.html":
            self._serve_file("boni_chat.html", "text/html; charset=utf-8")
        elif (k := ("GET", self.path)) in ROUTES:
            base, path = ROUTES[k]
            self._proxy(base, path)
        else:
            self._proxy(OLLAMA, "/api/" + self.path.split("/api/")[-1]) if "/api/" in self.path else self._json(404, {"error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        if (k := ("POST", self.path)) in ROUTES:
            base, path = ROUTES[k]
            self._proxy_post(base, path, body)
        else:
            self._json(404, {"error": "not found"})

    def do_OPTIONS(self):
        self._cors()
        self.send_response(200)
        self.end_headers()

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, code, data):
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def _serve_file(self, name, mime):
        path = os.path.join(DIR, name)
        if not os.path.exists(path):
            self._json(404, {"error": f"{name} not found"})
            return
        try:
            with open(path, "rb") as f:
                content = f.read()
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self._json(500, {"error": str(e)})

    def _proxy(self, base, path):
        url = base.rstrip("/") + "/" + path.lstrip("/")
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "BONI-Proxy"})
            with urllib.request.urlopen(req, timeout=10) as r:
                self.send_response(r.status)
                self._cors()
                ct = r.headers.get("Content-Type", "application/octet-stream")
                self.send_header("Content-Type", ct)
                self.end_headers()
                while True:
                    chunk = r.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            self._json(502, {"error": str(e)})

    def _proxy_post(self, base, path, body):
        url = base.rstrip("/") + "/" + path.lstrip("/")
        try:
            is_stream = b'"stream":true' in body or b'"stream": true' in body
            req = urllib.request.Request(url, data=body,
                headers={"Content-Type": "application/json", "User-Agent": "BONI-Proxy"})
            with urllib.request.urlopen(req, timeout=300) as r:
                self.send_response(r.status)
                self._cors()
                ct = r.headers.get("Content-Type", "application/octet-stream")
                self.send_header("Content-Type", ct)
                self.end_headers()
                if is_stream:
                    for chunk in iter(lambda: r.read(4096), b""):
                        self.wfile.write(chunk)
                        self.wfile.flush()
                else:
                    data = r.read()
                    self.wfile.write(data)
        except urllib.error.HTTPError as e:
            try:
                data = e.read()
                self.send_response(e.code)
                self._cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(data)
            except:
                self._json(e.code, {"error": str(e)})
        except Exception as e:
            self._json(502, {"error": str(e)})

    def log_message(self, fmt, *args):
        msg = fmt % args
        if "200" in msg:
            sys.stderr.write(f"  [OK] {msg}\n")
        else:
            sys.stderr.write(f"  [{msg.split(' ')[-2]}] {msg}\n")

if __name__ == "__main__":
    detect_tts()
    port = 8080
    server = http.server.HTTPServer(("0.0.0.0", port), ProxyHandler)
    print(f"BONI Proxy Server: http://localhost:{port}")
    print(f"  Ollama  -> {OLLAMA}")
    print(f"  Jarvis  -> {JARVIS}")
    print(f"  TTS     -> http://{TTS_IP}:{TTS_PORT}")
    print(f"  Sandbox -> {SANDBOX}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
