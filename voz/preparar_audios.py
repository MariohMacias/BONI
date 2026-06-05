import os, subprocess, glob
from pathlib import Path

AUDIOS_INPUT  = r"C:\Users\nosoy\OneDrive\Desktop\boni\voz\originales"
AUDIOS_OUTPUT = r"C:\Users\nosoy\OneDrive\Desktop\boni\voz\procesados"
os.makedirs(AUDIOS_INPUT, exist_ok=True)
os.makedirs(AUDIOS_OUTPUT, exist_ok=True)

def convertir_a_wav(archivo_entrada, archivo_salida):
    cmd = [
        "ffmpeg", "-y",
        "-i", archivo_entrada,
        "-ar", "22050",
        "-ac", "1",
        "-acodec", "pcm_s16le",
        archivo_salida
    ]
    resultado = subprocess.run(cmd, capture_output=True, text=True)
    return resultado.returncode == 0

def limpiar_audio(archivo_wav):
    temp = archivo_wav.replace(".wav", "_temp.wav")
    cmd = [
        "ffmpeg", "-y",
        "-i", archivo_wav,
        "-af", "highpass=f=80,lowpass=f=8000,volume=1.5,silenceremove=1:0:-50dB",
        temp
    ]
    subprocess.run(cmd, capture_output=True)
    if os.path.exists(temp):
        os.replace(temp, archivo_wav)

def procesar_todos():
    formatos = ["*.opus", "*.ogg", "*.m4a", "*.mp3", "*.mp4", "*.wav"]
    archivos = []
    for fmt in formatos:
        archivos.extend(glob.glob(os.path.join(AUDIOS_INPUT, fmt)))
    
    print(f"Encontrados {len(archivos)} archivos de audio")
    
    procesados = 0
    for i, archivo in enumerate(archivos):
        nombre = f"boni_voice_{i+1:03d}.wav"
        salida = os.path.join(AUDIOS_OUTPUT, nombre)
        
        print(f"  Procesando {os.path.basename(archivo)} \u2192 {nombre}...")
        if convertir_a_wav(archivo, salida):
            limpiar_audio(salida)
            procesados += 1
            print(f"  \u2713 OK ({os.path.getsize(salida)//1024}KB)")
        else:
            print(f"  \u2717 Error al convertir {archivo}")
    
    print(f"\nProcesados: {procesados}/{len(archivos)}")
    print(f"Archivos WAV en: {AUDIOS_OUTPUT}")
    return procesados

if __name__ == "__main__":
    print("=== Preparador de audios BONI ===")
    print(f"Pon tus audios de WhatsApp en:")
    print(f"  {AUDIOS_INPUT}")
    print()
    input("Cuando est\u00e9n listos, presiona Enter para continuar...")
    procesar_todos()
