# Sonido del neón sintetizado (sin material de terceros) + audio original de la toma.
import subprocess, numpy as np, wave
import neon
from comun import T_ENCIENDE
SR = 48000
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', 'orig.mp4', '-vn', '-ac', '2', '-ar', str(SR), '-f', 's16le', '-'], capture_output=True).stdout
orig = np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768
n = len(orig); t = np.arange(n) / SR
rng = np.random.default_rng(3)
L = np.array([neon.intensidades(x - T_ENCIENDE) for x in t[::480]])     # cada 10 ms
L = np.repeat(L, 480, axis=0)[:n]; on = np.clip(L[:, 0] + 0.6 * L[:, 2], 0, 1.3)
hum = (np.sin(2*np.pi*100*t) * .5 + np.sin(2*np.pi*200*t) * .3 + np.sign(np.sin(2*np.pi*100*t)) * .15) * 0.05
buzz = rng.normal(0, 1, n) * 0.012
d = np.abs(np.diff(on, prepend=0)); clic = np.convolve(d * rng.normal(0, 1, n) * 3.0, np.exp(-np.arange(400) / 60), 'same')
golpe = np.zeros(n); k = int((T_ENCIENDE + 0.72) * SR)
tt = np.arange(int(0.8 * SR)) / SR
golpe[k:k + len(tt)] = np.sin(2*np.pi*(55 - 20*tt)*tt) * np.exp(-tt * 5) * 0.55
neon_snd = (hum + buzz) * on + clic * 0.25 + golpe
mix = orig * 0.8 + neon_snd[:, None] * np.array([1.0, 0.95])
pk = np.max(np.abs(mix)); mix = mix / max(pk, 1e-6) * 0.89
with wave.open('out/audio.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((mix * 32767).astype(np.int16).tobytes())
print('sonido ok', n / SR)
