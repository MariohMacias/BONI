from http.server import HTTPServer, BaseHTTPRequestHandler
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from boni_sandbox import ejecutar_en_sandbox

class SandboxHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/ejecutar':
            length = int(self.headers.get('Content-Length', 0))
            data = json.loads(self.rfile.read(length))
            resultado = ejecutar_en_sandbox(
                data.get('codigo', ''),
                data.get('nombre', 'web_exec')
            )
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(resultado).encode())

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def log_message(self, *args):
        pass

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8765), SandboxHandler)
    print('Sandbox server en localhost:8765')
    server.serve_forever()
