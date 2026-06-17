#!/bin/bash
set -e
source ~/.bashrc 2>/dev/null || true

echo "=== 1. Matando procesos viejos ==="
pkill -f "openjarvis" 2>/dev/null || true
pkill -f "tts_server" 2>/dev/null || true
sleep 1

echo "=== 2. Iniciando OpenJarvis Server ==="
cd ~/OpenJarvis 2>/dev/null || cd ~
nohup python3.10 -m openjarvis.server --port 8000 > ~/.boni/jarvis.log 2>&1 &
sleep 3
curl -s http://127.0.0.1:8000/health && echo " JARVIS_OK" || echo " JARVIS_DOWN"

echo "=== 3. Iniciando TTS Server ==="
cat > ~/.boni/tts_server.py << 'PYEOF'
from flask import Flask, request, jsonify
import subprocess, os, sys
app = Flask(__name__)
@app.route('/health')
def health():
    return jsonify({'status':'ok','pid':os.getpid()})
@app.route('/tts', methods=['POST'])
def tts():
    texto = request.json.get('texto', '')
    path = f'/tmp/tts_{os.getpid()}.wav'
    subprocess.run(['espeak-ng','-w',path,texto[:300]], capture_output=True, timeout=30)
    if os.path.exists(path):
        with open(path,'rb') as f:
            data = f.read()
        os.unlink(path)
        return data, 200, {'Content-Type':'audio/wav'}
    return jsonify({'error':'fallo TTS'}), 500
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050)
PYEOF
nohup python3.10 ~/.boni/tts_server.py > ~/.boni/tts.log 2>&1 &
sleep 2
curl -s http://127.0.0.1:5050/health && echo " TTS_OK" || echo " TTS_DOWN"

echo "=== 4. Resumen ==="
echo "OpenJarvis: 127.0.0.1:8000"
curl -s http://127.0.0.1:8000/health 2>/dev/null || echo "caido"
echo "TTS: 127.0.0.1:5050"
curl -s http://127.0.0.1:5050/health 2>/dev/null || echo "caido"
