# colmen-render

Render en paralelo de las escenas 3D (three.js) de los reels de Colmen, en GitHub Actions.

Cada cuadro depende solo del tiempo `t` (`window.render(t)`), así que el video se parte en tramos:
N máquinas dibujan un tramo cada una con Chromium + SwiftShader y un último paso arma el MP4 (H.264, CRF 18, 30 fps).

- `escenas/` — páginas de cada escena y sus imágenes
- `render.mjs` — dibuja todos los cuadros, un tramo (`3/12`) o cuadros sueltos (`--prueba 1,5,9`)
- `.github/workflows/render.yml` — plan → tramos en paralelo → video
- `render-remoto.sh` — desde el servidor: sube la escena, espera, baja el video y le mezcla la voz (el audio no se sube)

Disparo manual: Actions → render → Run workflow (escena + cantidad de partes).

## Trabajos en paralelo (desde 28/10/2026)
Cada script (`render-remoto.sh`, `transcribir-remoto.sh`, `recortar-remoto.sh`, `render-hf.sh`) sube su pedido en una rama
propia `trabajo/<tipo>-<fecha>-<pid>` armada con un índice temporal (`lib-trabajo.sh`): no toca el directorio del clon,
así que pueden correr varios a la vez sin candado. Los workflows se disparan por esa rama y la rama se borra al terminar.
Lo único que usa CPU en el server (ffmpeg) pasa por `liviano` = `flock /tmp/colmen-ffmpeg.lock nice -n 19`.
Límite real: 20 máquinas a la vez por cuenta (GitHub Free); un render en 12 partes usa 12.
`vfx-remoto.sh` sigue con el esquema viejo (commit en main, espera que no haya otros runs).
