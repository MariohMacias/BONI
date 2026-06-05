#!/usr/bin/env python3
import os, json, subprocess, urllib.request, urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

def get_gw():
    try:
        out = subprocess.check_output(["ip","route"], text=True)
        for line in out.splitlines():
            p = line.split()
            if p[0] == "default":
                return p[2]
    except:
        pass
    return "172.29.176.1"

OLLAMA = os.environ.get("OLLAMA_URL", f"http://{get_gw()}:11434")

def oreq(method, path, body=None):
    url = f"{OLLAMA}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    if data:
        req.add_header("Content-Type","application/json")
    try:
        resp = urllib.request.urlopen(req, timeout=120)
        return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return {"error":f"HTTP {e.code}: {e.read().decode()}"}
    except Exception as e:
        return {"error":str(e)}

class H(BaseHTTPRequestHandler):
    def _json(self, data, s=200):
        self.send_response(s)
        self.send_header("Content-Type","application/json")
        self.send_header("Access-Control-Allow-Origin","*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin","*")
        self.send_header("Access-Control-Allow-Methods","GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers","Content-Type,Authorization")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            return self._json({"status":"healthy","proxy":"ollama-proxy"})
        if self.path == "/v1/models":
            m = oreq("GET","/api/tags")
            data = []
            if "models" in m:
                for mo in m["models"]:
                    data.append({"id":mo["name"],"object":"model"})
            return self._json({"object":"list","data":data})
        self._json({"error":"Not found"},404)

    def do_POST(self):
        if self.path == "/v1/chat/completions":
            clen = int(self.headers.get("Content-Length",0))
            raw = self.rfile.read(clen) if clen else b"{}"
            body = json.loads(raw.decode())
            model = body.get("model","boni-rapido:latest")
            msgs = body.get("messages",[])
            stream = body.get("stream",False)
            # Build Ollama payload
            opayload = {
                "model": model,
                "messages": msgs,
                "stream": stream,
                "options": {"temperature": body.get("temperature",0.7)}
            }
            if stream:
                return self._stream_chat(opayload)
            resp = oreq("POST","/api/chat",opayload)
            if "error" in resp:
                return self._json(resp,500)
            return self._json({
                "id":"chat-1","object":"chat.completion","model":model,
                "choices":[{"index":0,"message":{"role":"assistant","content":resp.get("message",{}).get("content","")},"finish_reason":"stop"}],
                "usage":{"prompt_tokens":resp.get("prompt_eval_count",0),"completion_tokens":resp.get("eval_count",0)}
            })
        self._json({"error":"Not found"},404)

    def _stream_chat(self, opayload):
        url = f"{OLLAMA}/api/chat"
        data = json.dumps(opayload).encode()
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Content-Type","application/json")
        self.send_response(200)
        self.send_header("Content-Type","text/event-stream")
        self.send_header("Cache-Control","no-cache")
        self.send_header("Access-Control-Allow-Origin","*")
        self.end_headers()
        try:
            resp = urllib.request.urlopen(req, timeout=120)
            for line in resp:
                if line.strip():
                    try:
                        j = json.loads(line.decode())
                        if "message" in j:
                            content = j["message"].get("content","")
                            if content:
                                oa_data = {
                                    "id":"chat-1","object":"chat.completion.chunk","model":opayload["model"],
                                    "choices":[{"index":0,"delta":{"content":content},"finish_reason":None}]
                                }
                                self.wfile.write(f"data: {json.dumps(oa_data)}\n\n".encode())
                                self.wfile.flush()
                    except:
                        pass
            # Done
            done = {"id":"chat-1","object":"chat.completion.chunk","model":opayload["model"],"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
            self.wfile.write(f"data: {json.dumps(done)}\n\n".encode())
            self.wfile.write("data: [DONE]\n\n".encode())
        except Exception as e:
            err = {"error":str(e)}
            self.wfile.write(f"data: {json.dumps(err)}\n\n".encode())

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    host = os.environ.get("PROXY_HOST","0.0.0.0")
    port = int(os.environ.get("PROXY_PORT","8080"))
    print(f"Ollama proxy on {host}:{port} -> {OLLAMA}", flush=True)
    HTTPServer((host,port), H).serve_forever()
