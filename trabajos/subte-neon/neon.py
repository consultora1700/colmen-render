# Cartel de neón "Colmen. / gestión gastronómica inteligente" estilo título de luz (New Rules).
# Todo en coordenadas del cuadro ancla (1080x1920). Solo PIL + numpy.
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

W, H = 1080, 1920
X0, Y0, ANCHO = 62, 250, 360           # logo en el cuadro ancla (21 s)
SUB = ['gestión gastronómica', 'inteligente']

def _f(im): return np.asarray(im, dtype=np.float32) / 255.0
def _blur(a, r): return _f(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)))

def _glow(core, color, k=1.0):
    g = core * 1.0 + _blur(core, 3) * 0.6 + _blur(core, 10) * 0.85 + _blur(core, 28) * 0.9 + _blur(core, 70) * 0.6
    halo = g - core
    rgb = core[..., None] * np.array([1, 1, 1], np.float32) + halo[..., None] * np.array(color, np.float32)
    return rgb * k

def capas():
    logo = Image.open('logo.png').convert('RGBA')
    alto = round(logo.height * ANCHO / logo.width)
    logo = logo.resize((ANCHO, alto), Image.LANCZOS)
    a = logo.getchannel('A'); rgb = np.asarray(logo.convert('RGB'), np.float32)
    lima = (rgb[..., 1] > 150) & (rgb[..., 2] < 90)            # el punto lima del logotipo
    la = Image.new('L', (W, H)); la.paste(a, (X0, Y0))
    am = np.zeros((H, W), np.float32); am[Y0:Y0 + alto, X0:X0 + ANCHO] = lima
    A = _f(la)
    letras = A * (1 - am); punto = A * am
    li = Image.fromarray((letras * 255).astype(np.uint8))
    tubo = _f(li.filter(ImageFilter.MinFilter(3))) - _f(li.filter(ImageFilter.MinFilter(13)))   # tubo de 5 px por dentro del borde
    tubo = _blur(np.clip(tubo, 0, 1), 1.2) * 1.15
    rell = letras * 0.10                                        # el vidrio apagado se ve apenas
    Elogo = _glow(np.clip(tubo, 0, 1), (0.80, 0.90, 1.0)) + rell[..., None] * 0.6
    Epunto = _glow(np.clip(_blur(punto, 1), 0, 1), (0.70, 0.95, 0.10))
    Epunto = Epunto * np.array([0.92, 1.0, 0.55], np.float32)
    s = Image.new('L', (W, H)); d = ImageDraw.Draw(s)
    f = ImageFont.truetype('Quicksand.ttf', 33); f.set_variation_by_name('Medium')
    for i, linea in enumerate(SUB):
        tw = d.textlength(linea, font=f)
        d.text((X0 + ANCHO / 2 - tw / 2, Y0 + alto + 22 + i * 44), linea, font=f, fill=255)
    Esub = _glow(_blur(_f(s), 0.6), (1.0, 0.86, 0.95), 0.95)
    return Elogo, Epunto, Esub

# Encendido (t en segundos desde que arranca el cartel)
def _parpadeo(t, cortes, base=1.0):
    for a, b in cortes:
        if a <= t < b: return base
    return 0.0

def intensidades(t):
    if t < 0: return 0.0, 0.0, 0.0
    L = _parpadeo(t, [(0.00, 0.05), (0.14, 0.20), (0.34, 0.37), (0.46, 0.60)], 0.85)
    if t >= 0.72: L = 1.0 + 0.25 * np.exp(-(t - 0.72) * 6) + 0.02 * np.sin(t * 2 * np.pi * 7.3)
    P = 0.0 if t < 1.05 else min(1.0, (t - 1.05) / 0.05) * (1 + 0.6 * np.exp(-(t - 1.05) * 5))
    S = _parpadeo(t, [(1.45, 1.50), (1.60, 1.66)], 0.7)
    if t >= 1.78: S = 1.0 + 0.02 * np.sin(t * 2 * np.pi * 5.1 + 1)
    return float(L), float(P), float(S)

def mascara_cielo(img):
    """img float RGB 0..1. 1 = cielo (azul, oscuro, no luces) ; 0 = poste, columna, edificios, faroles."""
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    azul = b - np.maximum(r, g)
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    m = np.clip((azul - 0.03) / 0.07, 0, 1) * np.clip((0.55 - lum) / 0.15, 0, 1)
    return _blur(m, 1.5)

def componer(plate, E, mask):
    """plate float 0..1, E emisión ya ubicada, mask cielo."""
    em = E * mask[..., None]
    spill = _blur_rgb(E, 60) * 0.10                              # la luz del cartel ilumina un poco alrededor
    out = 1 - (1 - plate) * (1 - np.clip(em, 0, 1))
    return np.clip(out + spill * (0.4 + 0.6 * plate), 0, 1)

def _blur_rgb(E, r):
    return np.stack([_blur(np.clip(E[..., i] / 2, 0, 1), r) * 2 for i in range(3)], -1)
