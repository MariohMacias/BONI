import requests, subprocess, tempfile, os, time, sys

print("=== BONI TTS Test ===")
print("Obteniendo IP de WSL...")

WSL_IP = subprocess.check_output(
    ["wsl", "-d", "Ubuntu-22.04", "--", "bash", "-c", "hostname -I | awk '{print $1}'"],
    text=True
).strip()

print(f"WSL IP: {WSL_IP}")
print(f"TTS Server: http://{WSL_IP}:5050")

# Check health
try:
    r = requests.get(f"http://{WSL_IP}:5050/health", timeout=5)
    print(f"Health: {r.json()}")
    if r.json().get("model_loaded") != True:
        print("Modelo no cargado. Espera ~5 min y reintenta.")
        sys.exit(1)
except requests.exceptions.ConnectionError:
    print(f"ERROR: No se puede conectar a http://{WSL_IP}:5050")
    print("Inicia el TTS server con: wsl -d Ubuntu-22.04 -- python3.10 /root/boni_voice/tts_server.py &")
    sys.exit(1)

# Generate TTS
print("\nGenerando audio...")
r = requests.post(
    f"http://{WSL_IP}:5050/tts",
    json={"texto": "Hola Mario, soy BONI. Mi voz está lista.", "idioma": "es"},
    timeout=300
)

print(f"Status: {r.status_code}")
print(f"Content-Type: {r.headers.get('content-type')}")
print(f"Size: {len(r.content)} bytes")

if r.status_code == 200 and len(r.content) > 100:
    output_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(output_dir, "test_voz_resultado.wav")
    with open(output_path, "wb") as f:
        f.write(r.content)
    print(f"\nAudio guardado en: {output_path}")
    print("Abre el archivo para escuchar!")
    
    # Try to play
    try:
        import winsound
        winsound.PlaySound(output_path, winsound.SND_FILENAME)
        print("Reproduciendo...")
    except:
        print("(no se pudo reproducir automaticamente)")
    
    print("\nVOZ OK!")
else:
    print(f"Error: {r.text[:200]}")
