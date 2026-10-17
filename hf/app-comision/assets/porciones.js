// Corta una malla de pizza en n porciones con cortes rectos de verdad
// (triángulo por triángulo contra dos semiplanos) y le pone tapa al corte,
// para que la porción que se lleva la app no se vea hueca.
import * as THREE from "three";

const ATR = ["position", "normal", "uv", "uv1", "tangent"];

function triangulos(geo) {
  const g = geo.index ? geo.toNonIndexed() : geo;
  const at = ATR.filter((a) => g.attributes[a]).map((a) => [a, g.attributes[a]]);
  const out = [];
  for (let i = 0; i < g.attributes.position.count; i += 3) {
    const t = [];
    for (let k = 0; k < 3; k++) {
      const v = {};
      for (const [a, b] of at) { v[a] = []; for (let c = 0; c < b.itemSize; c++) v[a].push(b.array[(i + k) * b.itemSize + c]); }
      t.push(v);
    }
    out.push(t);
  }
  return { tris: out, nombres: at.map(([a, b]) => [a, b.itemSize]) };
}

const mezclar = (a, b, t) => { const v = {}; for (const k in a) v[k] = a[k].map((x, i) => x + (b[k][i] - x) * t); return v; };

function recortar(poli, f) {
  const out = [];
  for (let i = 0; i < poli.length; i++) {
    const A = poli[i], B = poli[(i + 1) % poli.length], fa = f(A.position), fb = f(B.position);
    if (fa >= 0) out.push(A);
    if ((fa >= 0) !== (fb >= 0)) out.push(mezclar(A, B, fa / (fa - fb)));
  }
  return out;
}

function armar(polis, nombres) {
  const datos = Object.fromEntries(nombres.map(([a]) => [a, []]));
  for (const p of polis) for (let i = 1; i + 1 < p.length; i++) for (const v of [p[0], p[i], p[i + 1]]) for (const [a] of nombres) datos[a].push(...v[a]);
  const g = new THREE.BufferGeometry();
  for (const [a, n] of nombres) g.setAttribute(a, new THREE.Float32BufferAttribute(datos[a], n));
  return g;
}

// tapa del corte sobre el rayo de ángulo `ang` desde el centro: perfil alto/bajo por franjas de radio
function tapa(polis, ang, R, lado) {
  const d = [Math.cos(ang), Math.sin(ang)], N = 48, lo = new Array(N).fill(Infinity), hi = new Array(N).fill(-Infinity);
  for (const p of polis) for (const v of p) {
    const [x, y, z] = v.position, perp = d[0] * z - d[1] * x, r = x * d[0] + z * d[1];
    if (Math.abs(perp) > R * 0.004 || r < 0) continue;
    const b = Math.min(N - 1, Math.floor((r / R) * N));
    lo[b] = Math.min(lo[b], y); hi[b] = Math.max(hi[b], y);
  }
  const BANDAS = [[0, 0xb98247], [0.14, 0xe8d3a8], [0.66, 0xa8361a], [0.76, 0xefc463], [1, 0xf4d27a]];
  const pos = [], col = [], nor = [], c = new THREE.Color(), nx = -d[1] * lado, nz = d[0] * lado;
  const cols = [];
  for (let b = 0; b < N; b++) if (lo[b] < hi[b]) cols.push([((b + 0.5) / N) * R, lo[b], hi[b]]);
  for (let i = 0; i + 1 < cols.length; i++) {
    const [r0, l0, h0] = cols[i], [r1, l1, h1] = cols[i + 1];
    for (let k = 0; k + 1 < BANDAS.length; k++) {
      const [t0, c0] = BANDAS[k], [t1] = BANDAS[k + 1];
      const q = [[r0, l0 + (h0 - l0) * t0], [r1, l1 + (h1 - l1) * t0], [r1, l1 + (h1 - l1) * t1], [r0, l0 + (h0 - l0) * t1]];
      for (const j of [0, 1, 2, 0, 2, 3]) { const [r, y] = q[j]; pos.push(r * d[0], y, r * d[1]); nor.push(nx, 0, nz); c.setHex(c0); col.push(c.r, c.g, c.b); }
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute("normal", new THREE.Float32BufferAttribute(nor, 3));
  g.setAttribute("color", new THREE.Float32BufferAttribute(col, 3));
  return g;
}

// geo centrada en (0,?,0) en XZ. Devuelve [{geo, tapas:[geo,geo], mitad}] con `mitad` = ángulo central
export function porciones(geo, n, giro = 0) {
  const { tris, nombres } = triangulos(geo);
  geo.computeBoundingBox();
  let R = 0; for (const t of tris) for (const v of t) R = Math.max(R, Math.hypot(v.position[0], v.position[2]));
  const res = [];
  for (let i = 0; i < n; i++) {
    const a0 = giro + (i / n) * Math.PI * 2, a1 = giro + ((i + 1) / n) * Math.PI * 2;
    const d0 = [Math.cos(a0), Math.sin(a0)], d1 = [Math.cos(a1), Math.sin(a1)];
    const f0 = (p) => d0[0] * p[2] - d0[1] * p[0], f1 = (p) => p[0] * d1[1] - p[2] * d1[0];
    const polis = [];
    for (const t of tris) {
      let p = recortar(t, f0); if (p.length < 3) continue;
      p = recortar(p, f1); if (p.length >= 3) polis.push(p);
    }
    res.push({ geo: armar(polis, nombres), tapas: [tapa(polis, a0, R, -1), tapa(polis, a1, R, 1)], mitad: (a0 + a1) / 2 });
  }
  return { porciones: res, R };
}
