# Quita el fondo de cada foto de la carpeta de entrada y guarda <nombre>.png transparente en la de salida.
import sys, pathlib
from rembg import remove, new_session
from PIL import Image
ent, sal = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
sal.mkdir(parents=True, exist_ok=True)
s = new_session('birefnet-general-lite')
for f in sorted(ent.iterdir()):
    if f.suffix.lower() not in ('.jpg', '.jpeg', '.png', '.webp'): continue
    remove(Image.open(f).convert('RGB'), session=s).save(sal / (f.stem + '.png'))
    print('ok', f.name, flush=True)
