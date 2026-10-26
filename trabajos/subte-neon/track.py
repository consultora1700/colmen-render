# Seguimiento de cámara sobre la zona alta (cielo + bordes de edificios): afín parcial por pares, acumulado al cuadro ancla.
import json, cv2, numpy as np
from comun import leer, FPS, T_ANCLA, T_ENCIENDE
S = 2  # se trackea a 540x960
desde = int((T_ENCIENDE - 1.0) * FPS); ancla = int(T_ANCLA * FPS)
fr = [f for i, f in enumerate(leer('orig.m4v', 540, 960, gris=True)) if i >= desde]
mask = np.zeros_like(fr[0]); mask[:480, :] = 255          # mitad de arriba
par = []                                                  # par[k]: cuadro k -> k+1
for a, b in zip(fr[:-1], fr[1:]):
    p0 = cv2.goodFeaturesToTrack(a, 500, 0.01, 7, mask=mask)
    p1, st, _ = cv2.calcOpticalFlowPyrLK(a, b, p0, None, winSize=(21, 21), maxLevel=3)
    ok = st.ravel() == 1
    M, _ = cv2.estimateAffinePartial2D(p0[ok], p1[ok], method=cv2.RANSAC, ransacReprojThreshold=1.5)
    par.append(np.vstack([M if M is not None else np.eye(2, 3), [0, 0, 1]]))
n = len(fr); A = ancla - desde
T = [None] * n; T[A] = np.eye(3)
for k in range(A + 1, n): T[k] = par[k - 1] @ T[k - 1]
for k in range(A - 1, -1, -1): T[k] = np.linalg.inv(par[k]) @ T[k + 1]
esc = np.diag([S, S, 1.0]); inv = np.diag([1 / S, 1 / S, 1.0])
out = {str(desde + k): (esc @ T[k] @ inv)[:2].tolist() for k in range(n)}
json.dump(out, open('out/track.json', 'w'))
print('track', n, 'cuadros desde', desde)
