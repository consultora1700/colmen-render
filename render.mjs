// Render 3D determinista: sirve escenas/ por http, llama window.render(t) por cuadro y guarda JPG numerados.
// Cada cuadro depende solo de t, así que el video se puede partir en tramos y dibujar en paralelo.
// Uso: node render.mjs escena3.html cuadros/           → todos los cuadros
//      node render.mjs escena3.html cuadros/ 3/10      → solo el tramo 4 de 10 (contiguo, numeración global)
//      node render.mjs escena3.html prueba/ --prueba 1,5,9   → cuadros sueltos en esos segundos
import fs from 'fs'; import path from 'path'; import http from 'http';
import { chromium } from 'playwright';
const [, , pagina, salida, tramo, lista] = process.argv;
const FPS = 30, base = path.resolve('escenas');
const MIME = { '.html': 'text/html', '.glb': 'model/gltf-binary', '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.js': 'text/javascript' };
const srv = http.createServer((q, r) => {
  const p = path.join(base, decodeURIComponent(q.url.split('?')[0]));
  try { const d = fs.readFileSync(p); r.writeHead(200, { 'content-type': MIME[path.extname(p)] || 'application/octet-stream' }); r.end(d); }
  catch { r.writeHead(404); r.end(); }
});
await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
// lienzo: 1080x1920 por defecto (reels); una escena puede pedir otro con <html data-lienzo="1920x1080">
const LZ = (fs.readFileSync(path.join(base, pagina), 'utf8').match(/data-lienzo="(\d+)x(\d+)"/) || [0, 1080, 1920]).slice(1).map(Number);
const p = await b.newPage({ viewport: { width: LZ[0], height: LZ[1] } });
p.on('pageerror', (e) => console.log('[error]', e.message));
await p.goto(`http://127.0.0.1:${srv.address().port}/${pagina}`);
await p.waitForFunction('window.listo === true', null, { timeout: 180000 });
const DUR = await p.evaluate(() => window.DURACION), N = Math.round(DUR * FPS);
const cuadro = async (t, archivo) => { await p.evaluate((t) => window.render(t), t); await p.screenshot({ path: archivo, type: 'jpeg', quality: 92, timeout: 180000 }); };
fs.mkdirSync(salida, { recursive: true });
if (tramo === '--prueba') {
  for (const t of lista.split(',').map(Number)) await cuadro(t, path.join(salida, `${t}.jpg`));
} else {
  const [i, P] = (tramo || '0/1').split('/').map(Number);
  const desde = Math.floor((i * N) / P), hasta = Math.floor(((i + 1) * N) / P), t0 = Date.now();
  console.log(`${pagina}: ${DUR} s, ${N} cuadros; este tramo ${i + 1}/${P} = cuadros ${desde}..${hasta - 1}`);
  for (let k = desde; k < hasta; k++) {
    const arch = path.join(salida, `${String(k).padStart(5, '0')}.jpg`); if (fs.existsSync(arch)) continue;
    await cuadro(k / FPS, arch);
    if ((k - desde) % 30 === 0) console.log(`cuadro ${k} (${k - desde + 1}/${hasta - desde}) · ${((Date.now() - t0) / 1000).toFixed(0)} s`);
  }
  console.log('listo', hasta - desde, 'cuadros en', ((Date.now() - t0) / 1000).toFixed(0), 's');
}
await b.close(); srv.close();
