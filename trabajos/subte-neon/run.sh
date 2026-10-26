#!/usr/bin/env bash
# Corre en GitHub Actions. MODO=prueba → cuadros sueltos; MODO=video → mp4 final.
set -euo pipefail
mkdir -p out
python track.py
if [ "${MODO:-video}" = prueba ]; then python comp.py "${PRUEBAS:-19.3,19.8,20.5,21,22.5,24,25.5}"; exit 0; fi
python comp.py
python sonido.py
ffmpeg -v error -y -i out/video-mudo.mp4 -i out/audio.wav -c:v copy -c:a aac -b:a 192k -shortest -movflags +faststart out/colmen-subte-neon.mp4
rm out/video-mudo.mp4
ls -la out
