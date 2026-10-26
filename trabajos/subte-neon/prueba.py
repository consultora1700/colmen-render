import sys, numpy as np
from PIL import Image
import neon
El, Ep, Es = neon.capas()
plate = np.asarray(Image.open(sys.argv[1]).convert('RGB'), np.float32) / 255
m = neon.mascara_cielo(plate)
for t in [float(x) for x in sys.argv[3].split(',')]:
    L, P, S = neon.intensidades(t)
    E = El * L + Ep * P + Es * S
    out = neon.componer(plate, E, m)
    Image.fromarray((out * 255).astype(np.uint8)).save(f'{sys.argv[2]}-{t}.jpg', quality=92)
Image.fromarray((m * 255).astype(np.uint8)).save(f'{sys.argv[2]}-mask.jpg')
