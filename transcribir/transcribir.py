# Transcribe transcribir/in/audio.* con tiempos por palabra. Modelo e idioma salen de pedido.json.
import sys, json, glob, pathlib, subprocess
import numpy as np
from faster_whisper import WhisperModel
p = json.load(open('transcribir/pedido.json'))
sal = pathlib.Path(sys.argv[1]); sal.mkdir(parents=True, exist_ok=True)
audio = glob.glob('transcribir/in/audio.*')[0]
raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', audio, '-ac', '1', '-ar', '16000', '-f', 's16le', '-'], capture_output=True, check=True).stdout
a = np.frombuffer(raw, np.int16).astype(np.float32) / 32768
m = WhisperModel(p.get('modelo', 'medium'), device='cpu', compute_type='int8')
segs, _ = m.transcribe(a, language=p.get('idioma', 'es'), word_timestamps=True)
W = [(round(w.start, 3), round(w.end, 3), w.word.strip()) for s in segs for w in s.words]
json.dump(W, open(sal / 'palabras.json', 'w'), ensure_ascii=False)
print(len(W), 'palabras')
