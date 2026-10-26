import subprocess, numpy as np
FPS = 30
T_ANCLA = 21.0      # cuadro donde está diseñado el cartel
T_ENCIENDE = 18.8   # primer parpadeo
W, H = 1080, 1920

def leer(path, w=W, h=H, gris=False):
    fmt = 'gray' if gris else 'rgb24'; c = 1 if gris else 3
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', path, '-vf', f'fps={FPS},scale={w}:{h}', '-f', 'rawvideo', '-pix_fmt', fmt, '-'],
                         stdout=subprocess.PIPE, bufsize=10**8)
    n = w * h * c
    while True:
        b = p.stdout.read(n)
        if len(b) < n: break
        a = np.frombuffer(b, np.uint8).reshape(h, w) if gris else np.frombuffer(b, np.uint8).reshape(h, w, 3)
        yield a
    p.wait()
