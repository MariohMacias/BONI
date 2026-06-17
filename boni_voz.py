import threading, time, queue, json, os, tempfile, wave, struct, math
from pathlib import Path

try:
    import win32com.client
    import pythoncom
    HAS_SAPI = True
except ImportError:
    HAS_SAPI = False

try:
    import sounddevice as sd
    import numpy as np
    HAS_SOUNDDEVICE = True
except ImportError:
    HAS_SOUNDDEVICE = False

try:
    from faster_whisper import WhisperModel
    HAS_WHISPER = True
except ImportError:
    HAS_WHISPER = False

WHISPER_MODEL_SIZE = "tiny"
SAMPLE_RATE = 16000
CHANNELS = 1
BLOCK_SIZE = 1600
SILENCE_THRESHOLD = 0.015
SILENCE_DURATION = 1.0
MIN_AUDIO_LEN = 0.5


class VoiceInput:
    def __init__(self, on_text=None):
        self.on_text = on_text
        self.running = False
        self.thread = None
        self._mode = "sapi"
        self._whisper = None
        self._audio_buffer = []
        self._silence_counter = 0
        self._speaking = False
        self._stream = None

    @property
    def mode(self):
        if HAS_WHISPER:
            return "whisper"
        if HAS_SAPI:
            return "sapi"
        return "none"

    def start(self):
        if self.running:
            return True
        self.running = True

        if HAS_WHISPER:
            self._mode = "whisper"
            self.thread = threading.Thread(target=self._run_whisper, daemon=True)
        elif HAS_SAPI:
            self._mode = "sapi"
            self.thread = threading.Thread(target=self._run_sapi, daemon=True)
        else:
            self.running = False
            return False

        self.thread.start()
        return True

    def stop(self):
        self.running = False
        if self._stream:
            try:
                self._stream.stop()
                self._stream.close()
            except:
                pass

    def _run_sapi(self):
        pythoncom.CoInitialize()
        try:
            recognizer = win32com.client.Dispatch("SAPI.SpRecognizer")
            grammar = recognizer.CreateGrammar()
            grammar.DictationSetState(1)

            while self.running:
                try:
                    result = recognizer.Recognize()
                    if result:
                        text = result.PhraseInfo.GetText().strip()
                        if text and self.on_text:
                            self.on_text(text)
                except:
                    pass
                time.sleep(0.05)
        except:
            pass
        finally:
            pythoncom.CoUninitialize()

    def _energy(self, data):
        return math.sqrt(np.mean(data.astype(np.float32) ** 2))

    def _audio_callback(self, indata, frames, time_info, status):
        if status:
            return
        self._audio_buffer.append(indata.copy())

    def _run_whisper(self):
        if not HAS_SOUNDDEVICE:
            return
        try:
            self._whisper = WhisperModel(
                WHISPER_MODEL_SIZE,
                device="cpu",
                compute_type="int8",
                cpu_threads=4,
                num_workers=2
            )
        except:
            return

        try:
            self._stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                blocksize=BLOCK_SIZE,
                callback=self._audio_callback
            )
            self._stream.start()

            while self.running:
                if len(self._audio_buffer) < 5:
                    time.sleep(0.05)
                    continue

                data = np.concatenate(self._audio_buffer[-50:], axis=0).flatten()
                energy = self._energy(data[-1600:])

                if energy > SILENCE_THRESHOLD:
                    self._silence_counter = 0
                    if not self._speaking:
                        self._speaking = True
                        self._audio_buffer = self._audio_buffer[-100:]
                elif self._speaking:
                    self._silence_counter += 1
                    silence_frames = self._silence_counter * BLOCK_SIZE / SAMPLE_RATE
                    if silence_frames > SILENCE_DURATION and len(self._audio_buffer) > 10:
                        audio = np.concatenate(self._audio_buffer, axis=0).flatten()
                        audio_len = len(audio) / SAMPLE_RATE
                        self._speaking = False
                        self._audio_buffer = []
                        self._silence_counter = 0

                        if audio_len > MIN_AUDIO_LEN:
                            self._transcribe(audio)
                else:
                    if len(self._audio_buffer) > 200:
                        self._audio_buffer = self._audio_buffer[-50:]

                time.sleep(0.02)

        except:
            pass

    def _transcribe(self, audio):
        try:
            segments, _ = self._whisper.transcribe(audio, language="es")
            text = " ".join(seg.text for seg in segments).strip()
            if text and self.on_text:
                self.on_text(text)
        except:
            pass
