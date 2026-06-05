import os, sys, json
from pathlib import Path
from TTS.api import TTS

AUDIOS_DIR  = "/mnt/c/Users/nosoy/OneDrive/Desktop/boni/voz/procesados"
MODELO_DIR  = "/root/boni_voice/modelo"
SALIDA_DIR  = "/mnt/c/Users/nosoy/OneDrive/Desktop/boni/voz/output"
SPEAKER_WAV = None

os.makedirs(MODELO_DIR, exist_ok=True)
os.makedirs(SALIDA_DIR, exist_ok=True)

def seleccionar_mejor_audio():
    audios = list(Path(AUDIOS_DIR).glob("*.wav"))
    if not audios:
        print("ERROR: No hay audios en", AUDIOS_DIR)
        sys.exit(1)
    audios.sort(key=lambda x: x.stat().st_size, reverse=True)
    mejor = str(audios[0])
    print(f"Audio de referencia: {audios[0].name} ({audios[0].stat().st_size//1024}KB)")
    return mejor

def inicializar_tts():
    print("Cargando XTTS v2 (primera vez descarga ~1.8GB)...")
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2")
    print("Modelo cargado OK")
    return tts

def generar_audio(texto: str, archivo_salida: str, speaker_wav: str, tts=None):
    if tts is None:
        tts = inicializar_tts()
    tts.tts_to_file(
        text=texto,
        speaker_wav=speaker_wav,
        language="es",
        file_path=archivo_salida
    )
    return archivo_salida

def test_voz():
    speaker = seleccionar_mejor_audio()
    tts = inicializar_tts()

    frases_prueba = [
        "Hola Mario, soy BONI. Estoy lista para ayudarte.",
        "Procesando tu solicitud, un momento por favor.",
        "He completado la tarea exitosamente.",
        "No entend\u00ed bien, \u00bfpuedes repetirlo?",
        "Iniciando modo de investigaci\u00f3n profunda."
    ]

    print("\nGenerando audios de prueba...")
    for i, frase in enumerate(frases_prueba):
        salida = f"{SALIDA_DIR}/prueba_{i+1:02d}.wav"
        print(f"  Generando: '{frase[:40]}...'")
        generar_audio(frase, salida, speaker, tts)
        print(f"  \u2713 Guardado: {salida}")

    config = {
        "speaker_wav": speaker,
        "modelo": "xtts_v2",
        "idioma": "es",
        "audios_referencia": [str(a) for a in Path(AUDIOS_DIR).glob("*.wav")]
    }
    with open(f"{SALIDA_DIR}/voz_config.json", "w") as f:
        json.dump(config, f, indent=2)

    print(f"\n\u2713 Voz clonada lista. Audios de prueba en: {SALIDA_DIR}")
    print(f"  Config guardada en: {SALIDA_DIR}/voz_config.json")

if __name__ == "__main__":
    test_voz()
