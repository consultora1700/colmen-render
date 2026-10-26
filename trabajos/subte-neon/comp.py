# Composición final: placa + cartel de neón warpeado por el track, tapado por lo que no es cielo.
import json, subprocess, sys, cv2, numpy as np
import neon
from comun import leer, FPS, T_ENCIENDE, W, H
tr = json.load(open('out/track.json'))
El, Ep, Es = neon.capas()
prueba = [float(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else None
enc = None
if not prueba:
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                            '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', 'out/video-mudo.mp4'], stdin=subprocess.PIPE)
rng = np.random.default_rng(7)
for i, f in enumerate(leer('orig.mp4')):
    t = i / FPS
    if prueba and not any(abs(t - p) < 0.5 / FPS for p in prueba): continue
    L, P, S = neon.intensidades(t - T_ENCIENDE)
    if (L + P + S) > 0 and str(i) in tr:
        M = np.array(tr[str(i)], np.float32)
        E = El * L + Ep * P + Es * S
        Ew = cv2.warpAffine(E, M, (W, H), flags=cv2.INTER_LINEAR)
        Ew = cv2.GaussianBlur(Ew, (0, 0), 0.7)                          # misma nitidez que el celular
        Ew *= (1 + rng.normal(0, 0.03, (H, W, 1)).astype(np.float32))   # grano del sensor
        plate = f.astype(np.float32) / 255
        m = neon.mascara_cielo(plate)
        f = (neon.componer(plate, Ew, m) * 255 + 0.5).astype(np.uint8)
    if prueba: cv2.imwrite(f'out/prueba-{t:.2f}.jpg', cv2.cvtColor(f, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 90])
    else: enc.stdin.write(f.tobytes())
if enc: enc.stdin.close(); enc.wait()
print('comp ok')
