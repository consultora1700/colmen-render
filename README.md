# colmen-render

Render en paralelo de las escenas 3D (three.js) de los reels de Colmen, en GitHub Actions.

Cada cuadro depende solo del tiempo `t` (`window.render(t)`), así que el video se parte en tramos:
N máquinas dibujan un tramo cada una con Chromium + SwiftShader y un último paso arma el MP4 (H.264, CRF 18, 30 fps).

- `escenas/` — páginas de cada escena y sus imágenes
- `render.mjs` — dibuja todos los cuadros, un tramo (`3/12`) o cuadros sueltos (`--prueba 1,5,9`)
- `.github/workflows/render.yml` — plan → tramos en paralelo → video
- `render-remoto.sh` — desde el servidor: sube la escena, espera, baja el video y le mezcla la voz (el audio no se sube)

Disparo manual: Actions → render → Run workflow (escena + cantidad de partes).
