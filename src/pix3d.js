import { ARENA, PILLARS, SPAWNS, FORMATS, spawnsOf, HEAT, MECH_R, WALLS, TRAPS, WEAPONS, BOOSTERS, HANDS, ARM_OF, isGun, heightOf, arenaCorners, elapsed, untilSlam, untilZap, ventPhase, vents } from './sim.js'
import { TAU, BOOST_C, TEAM, TEAM_LIGHT, TEAM_DARK, EYES, hue, ITEM_C, health, tileHash } from './paint.js'
import { CORE_C, reach } from './mechart.js'

export const SIN = 0.75
export const COS = Math.sqrt(1 - SIN * SIN)
const VIS = 2 * MECH_R
export const GUN_H = 0.9 * VIS
const LEN = Math.hypot(0.5, 0.45, 0.74)
const LX = -0.5 / LEN
const LY = -0.45 / LEN
const LH = 0.74 / LEN
const AMB = [18, 22, 46]
const EDGE = 0.18
const WALL = 1
const WALL_H = 0.6

const STEEL = [170, 180, 198]
const STEEL_D = [96, 104, 120]
const JOINT = [44, 48, 58]
const DARK = [30, 33, 40]
const GOLD = [222, 178, 70]
const BONE = [238, 236, 228]
const RED = [206, 54, 44]
const COPPER = [214, 128, 70]
const LASER = [255, 80, 120]
const ARC = [170, 210, 255]
const RICO = [120, 255, 150]
const ORB = [190, 110, 255]

const WALL_C = [44, 50, 62]
const HAZARD = [214, 168, 44]
const HAZARD_D = [34, 30, 20]
const PILLAR_C = [[40, 45, 56], [70, 80, 98], [100, 112, 132]]

const cl = v => (v < 0 ? 0 : v > 255 ? 255 : v | 0)
const fr = v => v - Math.floor(v)
export const pack = (r, g, b) => 0xff000000 | (cl(b) << 16) | (cl(g) << 8) | cl(r)
const lit = (c, k) => pack(c[0] * k + AMB[0] * (1 - k), c[1] * k + AMB[1] * (1 - k), c[2] * k + AMB[2] * (1 - k))
const INK = pack(10, 12, 18)
const XRAY = TEAM.map(c => pack(c[0], c[1], c[2]))
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map(v => (v + 0.5) / 16)

function bands(nx, ny, nh) {
  const d = nx * LX + ny * LY + nh * LH
  return d > 0.7 ? 1.1 : d > 0.35 ? 0.92 : d > 0 ? 0.74 : 0.58
}

export const T3 = (x, y, h) => [1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, h]
const rot = (c, s, axis) => (axis === 'z' ? [c, s, 0, -s, c, 0, 0, 0, 1, 0, 0, 0] : axis === 'y' ? [c, 0, -s, 0, 1, 0, s, 0, c, 0, 0, 0] : [1, 0, 0, 0, c, s, 0, -s, c, 0, 0, 0])
const Rz = a => rot(Math.cos(a), Math.sin(a), 'z')
const Ry = a => rot(Math.cos(a), Math.sin(a), 'y')
const Rx = a => rot(Math.cos(a), Math.sin(a), 'x')
const Sc = k => [k, 0, 0, 0, k, 0, 0, 0, k, 0, 0, 0]

function mul(A, ...Bs) {
  for (const B of Bs) {
    const r = new Array(12)
    for (let c = 0; c < 4; c++) {
      const x = B[c * 3]
      const y = B[c * 3 + 1]
      const h = B[c * 3 + 2]
      const t = c === 3 ? 1 : 0
      r[c * 3] = A[0] * x + A[3] * y + A[6] * h + A[9] * t
      r[c * 3 + 1] = A[1] * x + A[4] * y + A[7] * h + A[10] * t
      r[c * 3 + 2] = A[2] * x + A[5] * y + A[8] * h + A[11] * t
    }
    A = r
  }
  return A
}

const at = (M, x, y, h) => [M[0] * x + M[3] * y + M[6] * h + M[9], M[1] * x + M[4] * y + M[7] * h + M[10], M[2] * x + M[5] * y + M[8] * h + M[11]]
const dir = (M, x, y, h) => [M[0] * x + M[3] * y + M[6] * h, M[1] * x + M[4] * y + M[7] * h, M[2] * x + M[5] * y + M[8] * h]

export function target(W, H) {
  const img = new ImageData(W, H)
  const n = W * H
  return { W, H, img, col: new Uint32Array(img.data.buffer), zb: new Float32Array(n), id: new Uint8Array(n), xr: new Uint8Array(n), sh: new Uint8Array(n), r0: new Int32Array(H), r1: new Int32Array(H) }
}

export function clear(T, V, src) {
  if (src) T.col.set(new Uint32Array(src))
  else T.col.fill(0)
  depthReset(T, V)
}

export function clearFloor(T, V, F, ox, oy) {
  const { W, H, col } = T
  col.fill(pack(9, 12, 17))
  const a = Math.max(0, -ox)
  const b = Math.min(W, F.w - ox)
  for (let y = 0; y < H; y++) {
    const fy = y + oy
    if (fy >= 0 && fy < F.h && b > a) col.set(F.px.subarray(fy * F.w + ox + a, fy * F.w + ox + b), y * W + a)
  }
  depthReset(T, V)
}

function depthReset(T, V) {
  T.id.fill(0)
  T.xr.fill(0)
  T.r0.fill(T.W)
  T.r1.fill(-1)
  for (let y = 0; y < T.H; y++) T.zb.fill((V.y0 + (y + 0.5 - V.cy) / (V.S * SIN)) * COS, y * T.W, (y + 1) * T.W)
}

export const mesh = () => ({ f: [], oid: 0, xr: 0, k: 1, flash: false, cast: true })

function face(me, pts, n, c, emis, tex) {
  const l = Math.hypot(n[0], n[1], n[2])
  n = [n[0] / l, n[1] / l, n[2] / l]
  let r = c[0] * me.k
  let g = c[1] * me.k
  let b = c[2] * me.k
  if (me.flash) {
    r += (255 - r) * 0.7
    g += (255 - g) * 0.7
    b += (255 - b) * 0.7
  }
  me.f.push({ pts, n, c: [r, g, b], emis, tex, oid: me.oid, xr: me.xr, cast: me.cast })
}

function box(me, M, x, y, h, w, d, t, c, emis, tex) {
  const a = w / 2
  const b = d / 2
  const e = t / 2
  const v = [[-a, -b, -e], [a, -b, -e], [a, b, -e], [-a, b, -e], [-a, -b, e], [a, -b, e], [a, b, e], [-a, b, e]].map(p => at(M, x + p[0], y + p[1], h + p[2]))
  const F = (i, j, k, l, nx, ny, nh, tx) => face(me, [v[i], v[j], v[k], v[l]], dir(M, nx, ny, nh), c, emis, tx)
  F(4, 5, 6, 7, 0, 0, 1, tex)
  F(0, 1, 2, 3, 0, 0, -1)
  F(1, 2, 6, 5, 1, 0, 0)
  F(0, 3, 7, 4, -1, 0, 0)
  F(3, 2, 6, 7, 0, 1, 0)
  F(0, 1, 5, 4, 0, -1, 0)
}

function slab(me, pts, h, c, tex) {
  const cx = pts.reduce((a, p) => a + p.x, 0) / pts.length
  const cy = pts.reduce((a, p) => a + p.y, 0) / pts.length
  face(me, pts.map(p => [p.x, p.y, h]), [0, 0, 1], c, false, tex)
  pts.forEach((p, i) => {
    const q = pts[(i + 1) % pts.length]
    const flip = (q.y - p.y) * ((p.x + q.x) / 2 - cx) + (p.x - q.x) * ((p.y + q.y) / 2 - cy) < 0 ? -1 : 1
    face(me, [[p.x, p.y, 0], [q.x, q.y, 0], [q.x, q.y, h], [p.x, p.y, h]], [(q.y - p.y) * flip, (p.x - q.x) * flip, 0], c)
  })
}

function prism(me, M, x, y, h, r, t, n, c, emis) {
  const lo = []
  const hi = []
  for (let i = 0; i < n; i++) {
    const a = ((i + 0.5) / n) * TAU
    lo.push(at(M, x + Math.cos(a) * r, y + Math.sin(a) * r, h - t / 2))
    hi.push(at(M, x + Math.cos(a) * r, y + Math.sin(a) * r, h + t / 2))
  }
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n
    const a = ((i + 1) / n) * TAU
    face(me, [lo[i], lo[j], hi[j], hi[i]], dir(M, Math.cos(a), Math.sin(a), 0), c, emis)
  }
  face(me, hi, dir(M, 0, 0, 1), c, emis)
  face(me, lo, dir(M, 0, 0, -1), c, emis)
}

function tri(T, ax, ay, az, bx, by, bz, cx, cy, cz, f, c, k) {
  let area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
  if (area < 0) {
    ;[bx, by, bz, cx, cy, cz] = [cx, cy, cz, bx, by, bz]
    area = -area
  }
  if (area < 1e-6) return
  const W = T.W
  const x0 = Math.max(0, Math.floor(Math.min(ax, bx, cx)))
  const x1 = Math.min(W - 1, Math.ceil(Math.max(ax, bx, cx)))
  const y0 = Math.max(0, Math.floor(Math.min(ay, by, cy)))
  const y1 = Math.min(T.H - 1, Math.ceil(Math.max(ay, by, cy)))
  const qx = x0 + 0.5
  const s0 = by - cy
  const s1 = cy - ay
  const s2 = ay - by
  for (let py = y0; py <= y1; py++) {
    const qy = py + 0.5
    let w0 = (cx - bx) * (qy - by) - (cy - by) * (qx - bx)
    let w1 = (ax - cx) * (qy - cy) - (ay - cy) * (qx - cx)
    let w2 = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax)
    let lo = x0
    let hi = x1
    if (s0 > 0) lo = Math.max(lo, x0 + Math.ceil(-w0 / s0))
    else if (s0 < 0) hi = Math.min(hi, x0 + Math.floor(w0 / -s0))
    else if (w0 < 0) continue
    if (s1 > 0) lo = Math.max(lo, x0 + Math.ceil(-w1 / s1))
    else if (s1 < 0) hi = Math.min(hi, x0 + Math.floor(w1 / -s1))
    else if (w1 < 0) continue
    if (s2 > 0) lo = Math.max(lo, x0 + Math.ceil(-w2 / s2))
    else if (s2 < 0) hi = Math.min(hi, x0 + Math.floor(w2 / -s2))
    else if (w2 < 0) continue
    if (lo > hi) continue
    if (lo < T.r0[py]) T.r0[py] = lo
    if (hi > T.r1[py]) T.r1[py] = hi
    w0 += s0 * (lo - x0)
    w1 += s1 * (lo - x0)
    w2 += s2 * (lo - x0)
    for (let px = lo; px <= hi; px++, w0 += s0, w1 += s1, w2 += s2) {
      if (w0 < 0 || w1 < 0 || w2 < 0) continue
      const i = py * W + px
      if (!f) {
        T.sh[i] = 1
        continue
      }
      const z = (w0 * az + w1 * bz + w2 * cz) / area
      if (z > T.zb[i]) {
        T.zb[i] = z
        T.id[i] = f.oid
        T.col[i] = f.tex ? f.tex(px, py, k) : c
      } else if (f.xr && T.id[i] > 0 && T.id[i] < 8) T.xr[i] = f.xr
    }
  }
}

const offscreen = (T, X, Y) => Math.max(...X) < 0 || Math.min(...X) > T.W || Math.max(...Y) < 0 || Math.min(...Y) > T.H

function shadows(T, V, me) {
  for (const f of me.f) {
    const [nx, ny, nh] = f.n
    if (!f.cast || nx * LX + ny * LY + nh * LH <= 0) continue
    const X = []
    const Y = []
    for (const q of f.pts) {
      const t = q[2] / LH
      X.push(V.cx + (q[0] - t * LX - V.x0) * V.S)
      Y.push(V.cy + (q[1] - t * LY - V.y0) * SIN * V.S)
    }
    if (offscreen(T, X, Y)) continue
    for (let i = 1; i < X.length - 1; i++) tri(T, X[0], Y[0], 0, X[i], Y[i], 0, X[i + 1], Y[i + 1], 0, null)
  }
  const { W, H, sh, col, r0, r1 } = T
  for (let y = 0; y < H; y++) {
    for (let i = y * W + r0[y], e = y * W + r1[y]; i <= e; i++) {
      if (!sh[i]) continue
      sh[i] = 0
      const c = col[i]
      col[i] = c ? pack((c & 255) * 0.5, ((c >> 8) & 255) * 0.53, ((c >> 16) & 255) * 0.66) : 0x66000000
    }
  }
}

function outline(T) {
  const { W, H, col, zb, id, xr, r0, r1 } = T
  for (let y = 1; y < H - 1; y++) {
    const a = Math.max(1, Math.min(r0[y - 1], r0[y], r0[y + 1]) - 1)
    const b = Math.min(W - 2, Math.max(r1[y - 1], r1[y], r1[y + 1]) + 1)
    for (let x = a; x <= b; x++) {
      const i = y * W + x
      const o = id[i]
      const z = zb[i] + EDGE
      const n = i - W
      const s = i + W
      if ((id[i - 1] && id[i - 1] !== o && zb[i - 1] > z) || (id[i + 1] && id[i + 1] !== o && zb[i + 1] > z) || (id[n] && id[n] !== o && zb[n] > z) || (id[s] && id[s] !== o && zb[s] > z)) col[i] = INK
      else if (o && zb[n] < zb[i] - EDGE) {
        const c = col[i]
        col[i] = pack((c & 255) * 1.2 + 14, ((c >> 8) & 255) * 1.2 + 14, ((c >> 16) & 255) * 1.2 + 16)
      }
      if (xr[i] && o && o < 8 && (x + y) & 1) col[i] = XRAY[xr[i] - 1]
    }
  }
}

export function blend(T, d, r = { x: 0, y: 0, w: T.W, h: T.H }) {
  const { W, col } = T
  for (let y = 0; y < r.h; y++) {
    const Y = y + r.y
    for (let x = 0; x < r.w; x++) {
      const j = (y * r.w + x) * 4
      const a = d[j + 3]
      if (!a) continue
      const X = x + r.x
      const q = Math.floor((a / 255) * 4 - 0.4 + BAYER[(Y & 3) * 4 + (X & 3)]) / 4
      if (q <= 0) continue
      const i = Y * W + X
      const c = col[i]
      col[i] = pack((c & 255) + (d[j] - (c & 255)) * q, ((c >> 8) & 255) + (d[j + 1] - ((c >> 8) & 255)) * q, ((c >> 16) & 255) + (d[j + 2] - ((c >> 16) & 255)) * q)
    }
  }
}

export function draw3d(T, V, me, cast) {
  if (cast) shadows(T, V, me)
  for (const f of me.f) {
    const [nx, ny, nh] = f.n
    if (ny * COS + nh * SIN <= 1e-3) continue
    const k = f.emis ? 1 : bands(nx, ny, nh)
    const c = f.tex ? 0 : f.emis ? pack(f.c[0], f.c[1], f.c[2]) : lit(f.c, k)
    const X = []
    const Y = []
    const Z = []
    for (const q of f.pts) {
      X.push(V.cx + (q[0] - V.x0) * V.S)
      Y.push(V.cy + ((q[1] - V.y0) * SIN - q[2] * COS) * V.S)
      Z.push(q[1] * COS + q[2] * SIN)
    }
    if (offscreen(T, X, Y)) continue
    for (let i = 1; i < X.length - 1; i++) tri(T, X[0], Y[0], Z[0], X[i], Y[i], Z[i], X[i + 1], Y[i + 1], Z[i + 1], f, c, k)
  }
  outline(T)
}

const RGB = new Float64Array(3)

function mix(c, a) {
  RGB[0] += (c[0] - RGB[0]) * a
  RGB[1] += (c[1] - RGB[1]) * a
  RGB[2] += (c[2] - RGB[2]) * a
}

const SPOTS = { 2: SPAWNS, 4: spawnsOf(FORMATS.ffa) }

function floorColor(x, y, e, ey, sides) {
  const A = ARENA
  let out = -1
  for (const w of WALLS) out = Math.max(out, x * w.nx + y * w.ny - w.d)
  if (out > 0) return fr((x + y) * 1.4) < e * 1.6 ? pack(16, 19, 25) : pack(9, 12, 17)
  const i = Math.floor(x / 2)
  const j = Math.floor(y / 2)
  const h = tileHash(i, j)
  const fx = x - i * 2
  const fy = y - j * 2
  const b = 23 + (h % 7)
  let m = 1
  if (fx < e || fy < ey) m = 1.45
  else if (fx > 2 - 2 * e || fy > 2 - 2 * ey) m = 0.45
  else {
    const kind = h % 11
    if (kind === 0 && fx > 0.44 && fx < 1.56 && fy > 0.42 && fy < 1.62 && Math.floor((fy - 0.42) / 0.2) % 2 === 0) m = 0.55
    else if (kind === 1 && Math.abs(Math.hypot(fx - 1, fy - 1) - 0.6) < ey * 0.62) m = 0.6
    else if (kind === 2 && fy > 0.84 && fy < 1.16 && fx > 0.2 && fx < 1.8) m = 0.78
    else if (h % 3 !== 0 && Math.abs(fx - (fx < 1 ? 0.2 : 1.8)) < e * 0.6 && Math.abs(fy - (fy < 1 ? 0.2 : 1.8)) < ey * 0.6) m = 2.2
  }
  RGB[0] = b * m
  RGB[1] = (b + 5) * m
  RGB[2] = (b + 12) * m
  const s = sideOf(x, y, sides)
  const dx = x - A.w / 2
  const dy = y - A.h / 2
  mix(TEAM[s], 0.1 * (sides > 2 ? Math.max(Math.abs(dx) / (A.w / 2), Math.abs(dy) / (A.h / 2)) : Math.abs(dx) / (A.w / 2)))
  const dc = Math.sqrt(dx * dx + dy * dy)
  if ((Math.abs(dx) < e * 0.6 && fr((y - 0.3) / 1.2) < 0.5) || Math.abs(dc - 2.4) < ey * 0.62 || Math.abs(dc - 1.4) < ey * 0.62) mix([200, 210, 225], 0.16)
  const p = SPOTS[sides][s]
  const sx = x - p.x
  const sy = y - p.y
  if (Math.abs(sx) < 3.6 && Math.abs(sy) < 1.3) {
    const d = Math.sqrt(sx * sx + sy * sy)
    if (d < 1.2) mix(TEAM[s], 0.1)
    if (Math.abs(d - 1.2) < ey * 0.62 || Math.abs(d - 0.8) < ey * 0.62) mix(TEAM[s], 0.5)
    const u = sx * (p.x < A.w / 2 ? 1 : -1)
    const v = Math.abs(sy)
    for (let k = 0; k < 3; k++) if (v <= 0.35 && Math.abs(u - (1.8 + k * 0.6 - 0.714 * v)) < e * 0.9) mix(TEAM[s], 0.4 - k * 0.1)
  }
  return pack(RGB[0], RGB[1], RGB[2])
}

let fullS = 0
let fullSides = 0
let full = null
export const FLOOR_PAD = 14

export function floorFull(S, sides) {
  if (full && fullS === S && fullSides === sides) return full
  const w = Math.ceil((ARENA.w + 2 * FLOOR_PAD) * S)
  const h = Math.ceil((ARENA.h + 2 * FLOOR_PAD) * S * SIN)
  const px = new Uint32Array(w * h)
  const e = 1 / S
  for (let qy = 0; qy < h; qy++) {
    const y = (qy + 0.5) / (S * SIN) - FLOOR_PAD
    for (let qx = 0; qx < w; qx++) px[qy * w + qx] = floorColor((qx + 0.5) / S - FLOOR_PAD, y, e, e / SIN, sides)
  }
  fullS = S
  fullSides = sides
  full = { px, w, h }
  return full
}

export function clearFloorZoom(T, V, F, S1) {
  const { W, H, col } = T
  const cols = new Int32Array(W)
  for (let x = 0; x < W; x++) {
    const q = Math.floor((V.x0 + (x + 0.5 - V.cx) / V.S + FLOOR_PAD) * S1)
    cols[x] = q >= 0 && q < F.w ? q : -1
  }
  const bg = pack(9, 12, 17)
  for (let y = 0; y < H; y++) {
    const q = Math.floor((V.y0 + (y + 0.5 - V.cy) / (V.S * SIN) + FLOOR_PAD) * S1 * SIN)
    const o = y * W
    if (q < 0 || q >= F.h) {
      col.fill(bg, o, o + W)
      continue
    }
    const row = q * F.w
    for (let x = 0; x < W; x++) col[o + x] = cols[x] < 0 ? bg : F.px[row + cols[x]]
  }
  depthReset(T, V)
}

export function scene(me, V, now, state, cheer, sides) {
  const shrink = state.shrink
  stands(me, now, cheer, sides)
  const A = ARENA
  Object.assign(me, { k: 1, flash: false, xr: 0, oid: WALL })
  const top = (px, py, k) => {
    const x = V.x0 + (px + 0.5 - V.cx) / V.S
    const y = V.y0 + ((py + 0.5 - V.cy) / V.S + WALL_H * COS) / SIN
    let w = WALLS[0]
    let o = -1e9
    for (const v of WALLS) {
      const d = x * v.nx + y * v.ny - v.d + shrink
      if (d > o) [o, w] = [d, v]
    }
    const across = o - 0.5
    const along = y * w.nx - x * w.ny
    const lo = Math.floor(along / 2) * 2 + 1
    if (Math.abs(along - lo) < 0.15 && Math.abs(across) < 0.15) {
      const c = TEAM[sideOf(x, y, sides)]
      const a = 0.75 + 0.35 * Math.sin(now / 320 + lo * 0.7)
      return pack(c[0] * a + 40, c[1] * a + 40, c[2] * a + 40)
    }
    return lit(Math.abs(across) > 0.42 ? STEEL_D : fr((along + across) * 0.8) < 0.5 ? HAZARD : HAZARD_D, k)
  }
  const inner = arenaCorners(-shrink)
  const outer = arenaCorners(1 - shrink)
  WALLS.forEach((w, i) => {
    const j = (i + WALLS.length - 1) % WALLS.length
    slab(me, [inner[j], inner[i], outer[i], outer[j]], WALL_H, WALL_C, top)
  })
  me.oid = 2
  for (const p of PILLARS) {
    const M = T3(p.x, p.y, 0)
    const pulse = 0.6 + 0.4 * Math.sin(now / 600 + p.x)
    const glowC = [120 * pulse, 210 * pulse, 255 * pulse]
    prism(me, M, 0, 0, 0.15, p.r + 0.18, 0.3, 8, PILLAR_C[0])
    prism(me, M, 0, 0, 1.15, p.r + 0.02, 1.7, 8, PILLAR_C[1])
    prism(me, M, 0, 0, 1.3, p.r + 0.05, 0.1, 8, glowC, true)
    prism(me, M, 0, 0, 2.12, p.r + 0.12, 0.24, 8, PILLAR_C[2])
    prism(me, M, 0, 0, 2.27, 0.45, 0.07, 8, [170 + 60 * pulse, 235, 255], true)
  }
  const blink = Math.floor(now / 80) % 2
  TRAPS.tesla.at.forEach((p, i) => {
    const M = T3(p.x, p.y, 0)
    const warn = untilZap(state, i) <= TRAPS.tesla.warn
    const ring = warn ? (blink ? [235, 245, 255] : ARC) : [80, 110, 170]
    prism(me, M, 0, 0, 0.1, 0.6, 0.2, 8, PILLAR_C[0])
    prism(me, M, 0, 0, 0.85, 0.36, 1.3, 8, COPPER)
    for (const h of [0.5, 0.9, 1.3]) prism(me, M, 0, 0, h, 0.46, 0.07, 8, ring, true)
    prism(me, M, 0, 0, 1.62, 0.22, 0.2, 8, warn ? [255, 255, 255] : ARC, true)
  })
  me.oid = 3
  TRAPS.crush.at.forEach((p, i) => {
    const h = crushHeight(state, i, now)
    const s = TRAPS.crush.half * 2
    box(me, T3(p.x, p.y, 0), 0, 0, h + 0.3, s, s, 0.6, STEEL_D)
    box(me, T3(p.x, p.y, 0), 0, 0, h + 0.65, s - 0.5, s - 0.5, 0.1, HAZARD)
    box(me, T3(p.x, p.y, 0), 0, 0, h + 1.45, 0.5, 0.5, 1.5, JOINT)
    if (untilSlam(state, i) <= TRAPS.crush.warn && blink) box(me, T3(p.x, p.y, 0), 0.9, 0.9, h + 0.8, 0.3, 0.3, 0.2, [255, 60, 40], true)
  })
  me.oid = 1
  const v = ventPhase(state)
  vents(shrink).forEach(g => {
    const live = v && g.wall % 2 === v.set && (v.burn || (v.warn && blink))
    const c = !live ? [40, 30, 26] : v.burn ? [255, 190, 70] : [255, 90, 40]
    box(me, mul(T3(g.x + g.dx * 0.3, g.y + g.dy * 0.3, 0), Rz(Math.atan2(g.dy, g.dx))), 0, 0, 0.1, 0.5, 1.6, 0.2, c, live)
  })
}

const PITS = { 2: [6, 2], 4: [7, 3, 1, 5] }
export const sideOf = (x, y, n) => (n > 2 ? (x < ARENA.w / 2 ? (y < ARENA.h / 2 ? 0 : 3) : y < ARENA.h / 2 ? 2 : 1) : x < ARENA.w / 2 ? 0 : 1)
const PADDOCK = { half: 4.5, tiers: 2 }
const SKIN = [[241, 194, 150], [198, 134, 90], [141, 85, 52], [255, 220, 180]]
const NEUTRAL = [[230, 230, 236], [60, 64, 74], [240, 200, 60], [120, 200, 120]]
const SEAT = [[34, 38, 50], [44, 48, 62]]
const TIER = { from: 1.3, depth: 2.2, n: 4 }
const tierH = (w, t) => (w.ny > 0.1 ? 0.35 + t * 0.25 : 0.9 + t * 0.85)
const rnd = n => fr(Math.sin(n * 127.1 + 311.7) * 43758.5453)

function edge(i, o) {
  const c = arenaCorners(o)
  return [c[(i + WALLS.length - 1) % WALLS.length], c[i]]
}

function pitFrame(i) {
  const w = WALLS[i]
  const [a, b] = edge(i, 0)
  const mx = (a.x + b.x) / 2
  const my = (a.y + b.y) / 2
  return {
    w,
    P: (s, o) => ({ x: mx - w.ny * s + w.nx * o, y: my + w.nx * s + w.ny * o }),
    along: p => -(p.x - mx) * w.ny + (p.y - my) * w.nx,
  }
}

const fansOf = sides => WALLS.flatMap((w, i) => {
  const pit = PITS[sides].includes(i) && pitFrame(i)
  const out = []
  for (let t = 0; t < TIER.n; t++) {
    for (const row of [0.6, 1.5]) {
      const [a, b] = edge(i, TIER.from + t * TIER.depth + row)
      const len = Math.hypot(b.x - a.x, b.y - a.y)
      for (let d = 0.4; d < len - 0.4; d += 0.55) {
        const n = (t * 2 + row) * 7919 + d * 131 + i * 9973
        if (rnd(n) < 0.08) continue
        const x = a.x + ((b.x - a.x) * d) / len
        const y = a.y + ((b.y - a.y) * d) / len
        if (pit && t < PADDOCK.tiers && Math.abs(pit.along({ x, y })) < PADDOCK.half + 0.3) continue
        const team = rnd(n + 1) < 0.2 ? -1 : sideOf(x, y, sides)
        const base = team < 0 ? NEUTRAL[Math.floor(rnd(n + 2) * NEUTRAL.length)] : TEAM[team]
        const k = 0.75 + rnd(n + 3) * 0.4
        out.push({ x, y, h: tierH(w, t), team, ph: rnd(n + 4) * TAU, shirt: pack(base[0] * k, base[1] * k, base[2] * k), skin: pack(...SKIN[Math.floor(rnd(n + 5) * SKIN.length)]) })
      }
    }
  }
  return out
})
const FANS = { 2: fansOf(2), 4: fansOf(4) }

function stands(me, now, cheer, sides) {
  Object.assign(me, { k: 1, flash: false, xr: 0, oid: 4, cast: false })
  WALLS.forEach((w, i) => {
    const pit = PITS[sides].includes(i) && pitFrame(i)
    for (let t = 0; t <= TIER.n; t++) {
      const o0 = TIER.from + t * TIER.depth
      const o1 = t < TIER.n ? o0 + TIER.depth : o0 + 0.5
      const [a0, b0] = edge(i, o0)
      const [a1, b1] = edge(i, o1)
      const h = t < TIER.n ? tierH(w, t) : tierH(w, t) + 1.2
      const c = t < TIER.n ? SEAT[t % 2] : [24, 27, 36]
      if (!pit || t >= PADDOCK.tiers) {
        slab(me, [a0, b0, b1, a1], h, c)
        continue
      }
      const g = Math.sign(pit.along(a0)) * PADDOCK.half
      slab(me, [a0, pit.P(g, o0), pit.P(g, o1), a1], h, c)
      slab(me, [pit.P(-g, o0), b0, b1, pit.P(-g, o1)], h, c)
    }
  })
  PITS[sides].forEach((wi, team) => {
    const { w, P } = pitFrame(wi)
    const G = PADDOCK.half
    const front = TIER.from
    const back = TIER.from + PADDOCK.tiers * TIER.depth
    const yaw = Math.atan2(-w.ny, -w.nx)
    const hype = cheer[team] > now
    me.oid = 5
    me.cast = false
    slab(me, [P(-G, front), P(G, front), P(G, back), P(-G, back)], 0.25, [40, 44, 54])
    for (const sd of [-1, 1]) slab(me, [P(sd * G, front), P(sd * (G - 0.12), front), P(sd * (G - 0.12), back), P(sd * G, back)], tierH(w, PADDOCK.tiers - 1) + 0.25, TEAM_DARK[team])
    me.cast = true
    for (const [s, o] of [[-3.6, 5], [-2.7, 5.05], [3.3, 4.95]]) box(me, T3(P(s, o).x, P(s, o).y, 0), 0, 0, 0.47, 0.6, 0.5, 0.45, s < 0 ? RED : STEEL_D)
    const pole = P(G - 0.8, 1.9)
    box(me, T3(pole.x, pole.y, 0), 0, 0, 1.8, 0.1, 0.1, 3.4, STEEL)
    box(me, mul(T3(pole.x, pole.y, 2.9), Rz(yaw + Math.PI / 2 + 0.35 * Math.sin(now / 300 + team))), 0.6, 0, 0, 1.2, 0.06, 0.7, TEAM[team])
    for (let c = 0; c < 5; c++) {
      const s = -3.4 + c * 1.6 + Math.sin(now / 900 + c * 1.7) * 0.5
      const p = P(s, 2.3 + (c % 2) * 1.2)
      const jump = hype ? Math.max(0, Math.sin(now / 110 + c)) * 0.35 : 0.02 * Math.sin(now / 250 + c)
      const M = mul(T3(p.x, p.y, 0.25 + jump), Rz(yaw))
      box(me, M, 0, 0, 0.38, 0.32, 0.4, 0.62, TEAM[team])
      box(me, M, 0.02, 0, 0.82, 0.26, 0.26, 0.24, c % 2 ? [255, 210, 60] : BONE)
      if (hype) for (const sd of [-1, 1]) box(me, M, 0, sd * 0.26, 0.85, 0.1, 0.1, 0.4, TEAM[team])
    }
  })
  Object.assign(me, { oid: WALL, cast: true })
}

export function drawCrowd(T, V, now, cheer, sides) {
  const fw = Math.max(2, Math.round(0.34 * V.S))
  const fh = Math.max(3, Math.round(0.42 * V.S))
  const hd = Math.max(1, Math.round(0.22 * V.S))
  const { W, H, zb, col } = T
  const plot = (x0, y0, w, h, z, c) => {
    for (let y = Math.max(0, y0); y < Math.min(H, y0 + h); y++) {
      for (let x = Math.max(0, x0); x < Math.min(W, x0 + w); x++) {
        const i = y * W + x
        if (z >= zb[i]) {
          zb[i] = z
          col[i] = c
        }
      }
    }
  }
  for (const f of FANS[sides]) {
    const hype = f.team < 0 ? Math.max(...cheer) > now : cheer[f.team] > now
    const jump = hype ? Math.max(0, Math.sin(now / 120 + f.ph)) * 0.35 : 0.03 * Math.sin(now / 400 + f.ph)
    const h = f.h + jump
    const sx = Math.round(V.cx + (f.x - V.x0) * V.S - fw / 2)
    const sy = Math.round(V.cy + ((f.y - V.y0) * SIN - h * COS) * V.S) - fh
    if (sx < -fw || sy < -fh - hd || sx > W || sy > H) continue
    const z = f.y * COS + (h + 0.3) * SIN
    plot(sx, sy, fw, fh, z, f.shirt)
    plot(sx + Math.floor((fw - hd) / 2), sy - hd, hd, hd, z, f.skin)
    if (hype && jump > 0.12) {
      plot(sx - 1, sy - hd - 1, 1, hd + 1, z, f.skin)
      plot(sx + fw, sy - hd - 1, 1, hd + 1, z, f.skin)
    }
  }
}

function crushHeight(state, i, now) {
  const C = TRAPS.crush
  const top = 2.8
  const u = untilSlam(state, i)
  const since = C.every - u
  const slammed = elapsed(state) - since > 0
  if (slammed && since < 6) return 0.35
  if (slammed && since < 66) return 0.35 + ((since - 6) / 60) * (top - 0.35)
  if (u <= 4) return 0.35 + (top - 0.85) * (u / 4)
  if (u <= C.warn) return top - 0.5 * (1 - u / C.warn) + (Math.floor(now / 40) % 2 ? 0.04 : -0.04)
  return top
}

const biped = o => (me, L, P) => {
  const sw = Math.sin(P.phase) * o.swing * P.moving
  box(me, L, 0, 0, 0.5, 0.28, 0.44, 0.13, JOINT)
  for (const s of [-1, 1]) {
    const H = mul(L, T3(0, s * o.hip, 0.48), Ry(sw * s))
    box(me, H, 0, 0, -0.13, o.thigh, o.thigh, 0.26, P.dark)
    box(me, H, 0.02, 0, -0.33, o.shin, o.shin, 0.2, STEEL_D)
    o.foot(me, H, P)
  }
}

const FEET = {
  greaves: biped({ swing: 0.5, hip: 0.2, thigh: 0.15, shin: 0.13, foot: (me, H) => box(me, H, 0.06, 0, -0.45, 0.26, 0.16, 0.07, STEEL) }),
  jets: biped({
    swing: 0.35, hip: 0.21, thigh: 0.15, shin: 0.13,
    foot: (me, H, P) => {
      box(me, H, 0.04, 0, -0.44, 0.24, 0.18, 0.09, P.team)
      box(me, H, -0.11, 0, -0.42, 0.06, 0.12, 0.08, [255, 150, 60], true)
    },
  }),
  stompers: biped({ swing: 0.3, hip: 0.22, thigh: 0.22, shin: 0.2, foot: (me, H) => box(me, H, 0.06, 0, -0.44, 0.36, 0.26, 0.1, STEEL_D) }),
  skates: biped({
    swing: 0.25, hip: 0.2, thigh: 0.12, shin: 0.1,
    foot: (me, H, P) => {
      box(me, H, 0.02, 0, -0.43, 0.2, 0.13, 0.08, P.team)
      box(me, H, 0.04, 0, -0.475, 0.44, 0.06, 0.04, BONE)
    },
  }),
  hover(me, L, P) {
    const b = Math.sin(P.now / 280 + P.m.id) * 0.03
    box(me, L, 0, 0, 0.48 + b, 0.3, 0.42, 0.14, JOINT)
    for (const s of [-1, 1]) {
      prism(me, L, 0, s * 0.26, 0.3 + b, 0.17, 0.16, 8, P.dark)
      prism(me, L, 0, s * 0.26, 0.2 + b, 0.12, 0.04, 8, [110, 230, 255], true)
    }
  },
  treads(me, L, P) {
    box(me, L, 0, 0, 0.38, 0.46, 0.34, 0.16, P.dark)
    for (const s of [-1, 1]) {
      box(me, L, 0, s * 0.28, 0.14, 0.72, 0.18, 0.26, DARK)
      for (let c = 0; c < 4; c++) box(me, L, (fr(P.phase * 0.25 + c / 4) - 0.5) * 0.64, s * 0.28, 0.28, 0.07, 0.19, 0.03, STEEL_D)
    }
  },
  spider(me, L, P) {
    box(me, L, -0.05, 0, 0.44, 0.4, 0.34, 0.16, P.dark)
    for (let k = 0; k < 4; k++) {
      const lift = Math.max(0, Math.sin(P.phase + k * 1.6)) * 0.08 * P.moving
      const G = mul(L, Rz((k < 2 ? 0.7 : 2.4) * (k % 2 ? 1 : -1)), T3(0.14, 0, 0.46 + lift))
      box(me, G, 0.16, 0, 0.06, 0.32, 0.07, 0.07, STEEL_D)
      box(me, G, 0.32, 0, -0.2, 0.07, 0.07, 0.5, JOINT)
    }
  },
  wheels(me, L, P) {
    box(me, L, 0, 0, 0.42, 0.34, 0.4, 0.16, P.dark)
    box(me, L, 0, 0, 0.25, 0.12, 0.56, 0.1, JOINT)
    for (const s of [-1, 1]) {
      const G = mul(L, T3(0, s * 0.32, 0.24), Rx(Math.PI / 2), Rz(-P.phase * 1.3))
      prism(me, G, 0, 0, 0, 0.24, 0.13, 8, DARK)
      prism(me, G, 0, 0, 0, 0.11, 0.15, 6, GOLD)
    }
  },
  quad(me, L, P) {
    box(me, L, 0, 0, 0.48, 0.44, 0.4, 0.14, JOINT)
    for (const [x, y, d] of [[0.22, 0.2, 1], [-0.22, -0.2, 1], [0.22, -0.2, -1], [-0.22, 0.2, -1]]) {
      const H = mul(L, T3(x, y, 0.46), Ry(Math.sin(P.phase) * 0.4 * d * P.moving))
      box(me, H, 0, 0, -0.2, 0.13, 0.13, 0.36, P.dark)
      box(me, H, 0.03, 0, -0.43, 0.18, 0.16, 0.06, STEEL)
    }
  },
  mono(me, L, P) {
    const G = mul(L, T3(0, 0, 0.3), Rx(Math.PI / 2), Rz(-P.phase * 1.1))
    prism(me, G, 0, 0, 0, 0.3, 0.16, 8, DARK)
    prism(me, G, 0, 0, 0, 0.13, 0.18, 6, GOLD)
    for (const s of [-1, 1]) box(me, L, 0, s * 0.14, 0.38, 0.4, 0.06, 0.3, P.team)
    box(me, L, 0, 0, 0.56, 0.36, 0.34, 0.08, P.dark)
  },
}

const GUNS = {
  rivet(me, A) {
    box(me, A, 0.42, 0, 0, 0.36, 0.16, 0.16, STEEL)
    box(me, A, 0.64, 0, 0, 0.08, 0.2, 0.2, DARK)
    prism(me, A, 0.26, 0.1, 0.1, 0.09, 0.1, 8, GOLD)
  },
  needle(me, A) {
    box(me, A, 0.56, 0, 0, 0.72, 0.08, 0.08, BONE)
    for (const x of [0.32, 0.46, 0.6]) box(me, A, x, 0, 0, 0.06, 0.15, 0.15, COPPER)
    box(me, A, 0.3, 0, 0.11, 0.2, 0.07, 0.07, DARK)
    box(me, A, 0.41, 0, 0.11, 0.03, 0.07, 0.07, [120, 220, 255], true)
  },
  scatter(me, A, P) {
    for (const s of [-1, 1]) box(me, A, 0.44, s * 0.065, 0, 0.36, 0.11, 0.13, STEEL)
    box(me, A, 0.3, 0, 0, 0.1, 0.28, 0.16, P.dark)
    box(me, A, 0.2, 0.16, 0, 0.14, 0.07, 0.1, RED)
  },
  gatling(me, A, P) {
    box(me, A, 0.18, 0, 0, 0.16, 0.2, 0.2, DARK)
    const G = mul(A, T3(0.44, 0, 0), Ry(Math.PI / 2), Rz(P.now / (P.shooting ? 25 : 400)))
    prism(me, G, 0, 0, 0, 0.11, 0.42, 6, STEEL)
    prism(me, G, 0, 0, 0.2, 0.12, 0.05, 6, DARK)
  },
  flamer(me, A) {
    box(me, A, 0.44, 0, 0, 0.34, 0.11, 0.11, STEEL)
    box(me, A, 0.64, 0, 0, 0.07, 0.15, 0.15, DARK)
    prism(me, mul(A, T3(0.24, 0, 0.13), Ry(Math.PI / 2)), 0, 0, 0, 0.08, 0.26, 8, RED)
    box(me, A, 0.7, 0, -0.05, 0.05, 0.06, 0.06, [255, 160, 50], true)
  },
  missiles(me, A, P) {
    box(me, A, 0.36, 0, 0.03, 0.34, 0.3, 0.24, P.dark)
    for (const y of [-0.07, 0.07]) for (const h of [-0.03, 0.09]) box(me, A, 0.54, y, h, 0.04, 0.08, 0.08, h > 0 ? [255, 240, 220] : [255, 90, 60], true)
  },
  mortar(me, A, P) {
    box(me, A, 0.2, 0, -0.03, 0.24, 0.24, 0.12, P.dark)
    const G = mul(A, T3(0.26, 0, 0.04), Ry(-0.65))
    box(me, G, 0.16, 0, 0, 0.38, 0.2, 0.2, STEEL)
    box(me, G, 0.36, 0, 0, 0.06, 0.24, 0.24, DARK)
  },
  laser(me, A, P) {
    box(me, A, 0.42, 0, 0, 0.36, 0.14, 0.14, DARK)
    box(me, A, 0.38, 0, 0.1, 0.22, 0.06, 0.08, P.team)
    box(me, A, 0.62, 0, 0, 0.06, 0.12, 0.12, LASER, true)
  },
  tesla(me, A) {
    box(me, A, 0.34, 0, 0, 0.26, 0.1, 0.1, COPPER)
    for (const x of [0.28, 0.38]) box(me, A, x, 0, 0, 0.05, 0.18, 0.18, ARC, true)
    for (const s of [-1, 1]) box(me, A, 0.56, s * 0.08, 0, 0.22, 0.06, 0.07, STEEL)
  },
  ricochet(me, A) {
    box(me, A, 0.44, 0, 0, 0.4, 0.13, 0.13, STEEL)
    for (const x of [0.34, 0.54]) box(me, A, x, 0, 0, 0.05, 0.17, 0.17, RICO, true)
  },
}

const BLADES = {
  saw(me, A, P) {
    box(me, A, 0.22, 0, 0, 0.26, 0.14, 0.14, JOINT)
    const D = mul(A, T3(0.52, 0, 0), Rz(P.now / (P.melee ? 30 : 160)))
    prism(me, D, 0, 0, 0, 0.3, 0.05, 8, STEEL)
    for (let k = 0; k < 4; k++) box(me, mul(D, Rz((k * Math.PI) / 2)), 0.3, 0, 0, 0.09, 0.07, 0.06, BONE)
    prism(me, D, 0, 0, 0.035, 0.09, 0.04, 6, GOLD)
  },
  drill(me, A, P) {
    box(me, A, 0.16, 0, 0, 0.22, 0.22, 0.22, P.dark)
    const D = mul(A, T3(0.3, 0, 0), Rx(P.now / (P.melee ? 25 : 140)))
    for (const [x, s, c] of [[0.02, 0.22, GOLD], [0.14, 0.17, STEEL], [0.25, 0.12, GOLD], [0.34, 0.08, STEEL], [0.41, 0.06, BONE]]) box(me, D, x, 0, 0, 0.11, s, s, c)
  },
  hammer(me, A) {
    box(me, A, 0.3, 0, 0, 0.44, 0.08, 0.08, JOINT)
    box(me, A, 0.56, 0, 0, 0.2, 0.38, 0.26, STEEL_D)
    box(me, A, 0.67, 0, 0, 0.03, 0.34, 0.22, GOLD)
  },
  claws(me, A, P) {
    box(me, A, 0.2, 0, 0, 0.24, 0.2, 0.16, P.dark)
    for (const j of [-1, 0, 1]) box(me, mul(A, T3(0.32, j * 0.075, 0), Rz(j * 0.28)), 0.15, 0, 0, 0.3, 0.06, 0.07, BONE)
  },
  whip(me, A, P) {
    box(me, A, 0.2, 0, 0, 0.22, 0.13, 0.13, JOINT)
    const ext = Math.max(0, P.reach)
    for (let s = 1; s <= 7; s++) {
      const wave = (1 - ext) * s
      box(me, A, 0.28 + s * (0.1 + ext * 0.5), Math.sin(P.now / 160 + s * 0.9) * 0.025 * wave, -0.03 * wave, 0.1, 0.07, 0.07, s % 2 ? COPPER : DARK)
    }
  },
  bunker(me, A, P) {
    box(me, A, 0.32, 0, 0, 0.42, 0.24, 0.24, STEEL_D)
    box(me, A, 0.3, 0, 0, 0.1, 0.28, 0.28, GOLD)
    box(me, A, 0.6 + Math.max(0, P.reach) * 0.5, 0, 0, 0.32, 0.07, 0.07, BONE)
  },
  katana(me, A) {
    box(me, A, 0.18, 0, 0, 0.2, 0.13, 0.13, JOINT)
    box(me, A, 0.3, 0, 0, 0.04, 0.18, 0.18, GOLD)
    box(me, A, 0.68, 0, 0, 0.72, 0.07, 0.1, [205, 240, 255])
  },
  bash(me, A, P) {
    box(me, A, 0.16, 0, 0, 0.22, 0.14, 0.14, JOINT)
    box(me, A, 0.34, -0.04, 0, 0.08, 0.5, 0.42, P.team)
    box(me, A, 0.39, -0.04, 0, 0.03, 0.36, 0.3, P.light)
    box(me, A, 0.41, -0.04, 0, 0.04, 0.1, 0.1, GOLD)
  },
  fist(me, A, P) {
    const ext = Math.max(0, P.reach) * 1.4
    box(me, A, 0.2, 0, 0, 0.3, 0.15, 0.15, JOINT)
    box(me, A, 0.44 + ext, 0, 0, 0.24, 0.26, 0.24, P.team)
    box(me, A, 0.57 + ext, 0, 0.03, 0.04, 0.26, 0.1, STEEL)
    if (ext > 0) box(me, A, 0.3 + ext, 0, 0, 0.06, 0.12, 0.12, [255, 170, 70], true)
  },
  flail(me, A, P) {
    box(me, A, 0.2, 0, 0, 0.24, 0.1, 0.1, JOINT)
    const a = P.now / (P.melee ? 60 : 220)
    const bx = 0.62 + Math.cos(a) * 0.16
    const by = Math.sin(a) * 0.16
    for (let k = 1; k <= 3; k++) box(me, A, 0.32 + ((bx - 0.32) * k) / 4, (by * k) / 4, 0, 0.06, 0.06, 0.06, STEEL_D)
    box(me, A, bx, by, 0, 0.2, 0.2, 0.2, STEEL_D)
    for (const [w, d, t] of [[0.32, 0.06, 0.06], [0.06, 0.32, 0.06], [0.06, 0.06, 0.32]]) box(me, A, bx, by, 0, w, d, t, BONE)
  },
}

const HEAD_ART = {
  horn(me, H) {
    const G = mul(H, T3(0.12, 0, 0.08), Ry(-0.7))
    box(me, G, 0.14, 0, 0, 0.3, 0.09, 0.09, BONE)
    box(me, G, 0.3, 0, 0, 0.06, 0.07, 0.07, GOLD)
  },
  pincer(me, H) {
    for (const s of [-1, 1]) {
      const G = mul(H, T3(0.14, s * 0.11, 0.03), Rz(-s * 0.35))
      box(me, G, 0.13, 0, 0, 0.26, 0.07, 0.07, BONE)
      box(me, mul(G, T3(0.26, 0, 0), Rz(s * 1.1)), 0.06, 0, 0, 0.13, 0.06, 0.06, BONE)
    }
  },
  crest(me, H, P) {
    box(me, H, -0.05, 0, 0.18, 0.34, 0.06, 0.16, P.light)
    box(me, H, 0.12, 0, 0.21, 0.06, 0.07, 0.1, GOLD)
  },
  dish(me, H) {
    box(me, H, -0.06, 0.06, 0.16, 0.05, 0.05, 0.12, JOINT)
    const G = mul(H, T3(-0.06, 0.06, 0.22), Ry(-0.5))
    prism(me, G, 0, 0, 0, 0.17, 0.03, 8, BONE)
    prism(me, G, 0, 0, 0.025, 0.05, 0.03, 6, [110, 220, 255], true)
  },
  visor(me, H) {
    box(me, H, 0.165, 0, 0.01, 0.04, 0.34, 0.07, [255, 70, 70], true)
  },
  medic(me, H) {
    box(me, H, 0, 0, 0.14, 0.2, 0.07, 0.03, [90, 255, 150], true)
    box(me, H, 0, 0, 0.14, 0.07, 0.2, 0.03, [90, 255, 150], true)
  },
  orb(me, H) {
    prism(me, H, -0.02, 0, 0.17, 0.13, 0.1, 8, ORB, true)
  },
  antenna(me, H) {
    for (const s of [-1, 1]) {
      box(me, H, -0.06, s * 0.1, 0.27, 0.06, 0.06, 0.32, STEEL)
      box(me, H, -0.06, s * 0.1, 0.44, 0.08, 0.08, 0.07, [150, 130, 255], true)
    }
  },
  dispenser(me, H, P) {
    box(me, H, -0.2, 0, 0.02, 0.14, 0.3, 0.2, P.dark)
    for (const y of [-0.09, 0, 0.09]) box(me, H, -0.2, y, 0.14, 0.08, 0.06, 0.08, GOLD)
  },
  demon(me, H) {
    for (const s of [-1, 1]) box(me, mul(H, T3(0.02, s * 0.15, 0.08), Rz(s * 1.0), Ry(-0.8)), 0.12, 0, 0, 0.24, 0.07, 0.07, [120, 24, 30])
  },
}

const ITEM_ART = {
  repair(me, M, c) {
    box(me, M, 0, 0, 0, 0.5, 0.16, 0.16, c)
    box(me, M, 0, 0, 0, 0.16, 0.5, 0.16, c)
  },
  shield(me, M, c) {
    prism(me, M, 0, 0, 0, 0.3, 0.1, 8, c)
    prism(me, M, 0, 0, 0.06, 0.12, 0.06, 6, BONE, true)
  },
  speed(me, M, c) {
    for (const x of [-0.12, 0.12]) for (const s of [-1, 1]) box(me, mul(M, T3(x, s * 0.08, 0), Rz(s * 0.8)), 0, 0, 0, 0.28, 0.09, 0.12, c)
  },
  power(me, M, c) {
    box(me, mul(M, Rx(0.785), Ry(0.615)), 0, 0, 0, 0.32, 0.32, 0.32, c)
  },
  coolant(me, M, c) {
    prism(me, M, 0, 0, 0, 0.15, 0.36, 8, c)
    for (const h of [-0.2, 0.2]) prism(me, M, 0, 0, h, 0.12, 0.05, 8, STEEL)
  },
  surge(me, M, c) {
    for (const a of [0, 0.785]) box(me, mul(M, Rz(a)), 0, 0, 0, 0.34, 0.34, 0.12, c)
    box(me, M, 0, 0, 0, 0.14, 0.14, 0.2, BONE, true)
  },
}

export function buildPickup(me, x, y, kind, now, ghost) {
  if (ghost && Math.floor(now / 90) % 2) return
  Object.assign(me, { k: ghost ? 0.55 : 1, flash: false, xr: 0, oid: 9 })
  ITEM_ART[kind](me, mul(T3(x, y, 1.1 + 0.12 * Math.sin(now / 300 + x)), Sc(2), Rz(now / 600)), ITEM_C[kind])
}

const ARM_ART = {
  wire(me, B, s, P) {
    box(me, B, 0, s * 0.33, 1.0, 0.2, 0.14, 0.12, P.dark)
    box(me, B, -0.06, s * 0.36, 1.1, 0.04, 0.04, 0.14, P.light)
  },
  reed(me, B, s, P) {
    prism(me, B, 0, s * 0.35, 1.0, 0.13, 0.16, 8, P.dark)
  },
  frame(me, B, s, P) {
    box(me, B, 0, s * 0.36, 1.0, 0.3, 0.2, 0.18, P.dark)
  },
  brace(me, B, s, P) {
    box(me, B, 0, s * 0.36, 1.0, 0.3, 0.22, 0.2, P.dark)
    box(me, B, 0, s * 0.45, 1.0, 0.24, 0.05, 0.14, STEEL)
  },
  bulwark(me, B, s, P) {
    box(me, B, 0, s * 0.38, 1.02, 0.36, 0.26, 0.24, P.team)
    box(me, B, 0, s * 0.38, 1.15, 0.3, 0.2, 0.04, P.light)
  },
  anvil(me, B, s, P) {
    box(me, B, 0, s * 0.4, 1.02, 0.42, 0.3, 0.28, STEEL_D)
    box(me, B, 0, s * 0.4, 1.17, 0.36, 0.24, 0.04, P.team)
    for (const x of [-0.12, 0.12]) box(me, B, x, s * 0.56, 1.02, 0.05, 0.03, 0.05, GOLD)
  },
}

const nozzle = (me, B, y, r, len, P) => {
  prism(me, mul(B, T3(-0.46, y, 0.98), Ry(Math.PI / 2)), 0, 0, 0, r, len, 8, DARK)
  if (P.burn > 0) box(me, B, -0.46 - len / 2 - 0.08 * P.burn, y, 0.98, 0.16 * P.burn, r * 1.2, r * 1.2, P.flame, true)
}
const BOOSTER_ART = {
  flicker(me, B, P) {
    nozzle(me, B, 0, 0.07, 0.12, P)
  },
  wisp(me, B, P) {
    for (const s of [-1, 1]) {
      nozzle(me, B, s * 0.14, 0.06, 0.12, P)
      box(me, B, -0.42, s * 0.24, 1.08, 0.12, 0.03, 0.14, P.light)
    }
  },
  thruster(me, B, P) {
    box(me, B, -0.42, 0, 0.98, 0.1, 0.34, 0.2, P.dark)
    for (const s of [-1, 1]) nozzle(me, B, s * 0.12, 0.08, 0.14, P)
  },
  twin(me, B, P) {
    box(me, B, -0.42, 0, 1.0, 0.12, 0.42, 0.24, P.dark)
    for (const s of [-1, 1]) nozzle(me, B, s * 0.15, 0.1, 0.18, P)
  },
  comet(me, B, P) {
    box(me, B, -0.42, 0, 1.0, 0.12, 0.3, 0.28, P.team)
    nozzle(me, B, 0, 0.15, 0.22, P)
  },
  rocket(me, B, P) {
    for (const s of [-1, 1]) {
      box(me, B, -0.48, s * 0.17, 1.02, 0.26, 0.14, 0.14, STEEL_D)
      box(me, B, -0.38, s * 0.17, 1.12, 0.1, 0.1, 0.06, RED)
      nozzle(me, B, s * 0.17, 0.08, 0.3, P)
    }
  },
}

const MIRROR = [1, 0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0]
const THRUST = new Set(['drill', 'bunker', 'fist', 'whip', 'katana'])
const partK = (m, part) => (m.ko ? 0.4 : [1, 0.86, 0.72, 0.45][health(m, part)])

function weaponArt(me, key, A, P, rec, s) {
  const gun = isGun(WEAPONS[key])
  const r = P.reach
  const pose = gun ? T3(-0.12 * rec, 0, 0) : THRUST.has(key) ? T3(r > 0 ? r * 0.3 : r * 0.12, 0, 0) : Rz(r < 0 ? r * 0.9 : r * 0.55)
  const H = mul(A, (s > 0) !== gun ? MIRROR : Sc(1), pose)
  box(me, H, 0.1, 0, 0, 0.24, 0.15, 0.15, JOINT)
  ;(gun ? GUNS[key] : BLADES[key])(me, H, P)
}

const THUMB = { head: [2.7, 0.55], core: [1.9, 1.07], arms: [3, 1.07], legs: [2, 1.07], booster: [3.4, -1.57], left: [2.2, -0.3], right: [2.2, -0.3] }

export function buildPart(me, slot, key, now, id = 0) {
  const P = { m: { id, preview: true }, now, team: TEAM[id], light: TEAM_LIGHT[id], dark: TEAM_DARK[id], phase: now / 220, moving: 0, shooting: false, melee: false, reach: 0, burn: 0 }
  Object.assign(me, { k: 1, flash: false, xr: 0, oid: 1 })
  const [k, turn] = THUMB[slot]
  const R = mul(Sc(VIS * k), Rz(turn))
  if (slot === 'left' || slot === 'right') return weaponArt(me, key, mul(R, T3(-0.4, 0, 0.12)), P, 0, 1)
  if (slot === 'legs') return FEET[key](me, R, P)
  if (slot === 'arms') return ARM_ART[key](me, mul(R, T3(0, -0.38, -0.86)), 1, P)
  if (slot === 'booster') return BOOSTER_ART[key](me, mul(R, T3(0.45, 0, -0.84)), P)
  if (slot === 'core') {
    box(me, R, 0, 0, 0.22, 0.6, 0.54, 0.4, P.team)
    return box(me, R, 0.31, 0, 0.24, 0.05, 0.22, 0.16, CORE_C[key] ?? CORE_C.furnace, true)
  }
  const H = mul(R, T3(0, 0, 0.12))
  box(me, H, 0, 0, 0, 0.3, 0.3, 0.22, key === 'medic' ? BONE : STEEL)
  box(me, H, -0.03, 0, 0.12, 0.26, 0.28, 0.04, P.team)
  if (key !== 'visor') for (const s of [-1, 1]) box(me, H, 0.165, s * 0.08, 0.01, 0.04, 0.08, 0.07, key === 'demon' ? [255, 60, 50] : EYES[id], true)
  HEAD_ART[key]?.(me, H, P)
}

export function buildMech(me, m, lg, kickAt, now) {
  const c = hue(m)
  const base = 10 + m.id * 8
  const lo = m.loadout
  const ko = m.ko
  const P = {
    m, now, team: TEAM[c], light: TEAM_LIGHT[c], dark: TEAM_DARK[c], phase: lg.phase,
    moving: m.preview ? 1 : Math.min(1, Math.hypot(m.vx, m.vy) / 2),
    shooting: false, melee: false, reach: 0,
    burn: m.act?.k === 'dash' && m.act.ph === 'go' ? 1 : m.afterburn > 0 ? 0.4 : 0,
    flame: BOOST_C[BOOSTERS[lo.booster]?.trail] ?? BOOST_C.clean,
  }
  me.xr = m.preview ? 0 : c + 1
  me.flash = !ko && m.stagger > 0 && Math.floor(now / 50) % 2 === 1
  const drop = ko ? -0.16 : 0
  const slump = ko ? Rx(0.3) : T3(0, 0, 0)
  const root = mul(T3(m.x, m.y, drop + heightOf(m)), Sc(VIS))
  me.oid = base
  me.k = partK(m, 'legs')
  ;(FEET[lo.legs] ?? FEET.greaves)(me, mul(root, Rz(lg.heading), slump), P)
  const bob = ko ? 0 : Math.abs(Math.sin(lg.phase)) * 0.025 * P.moving
  const B = mul(root, T3(0, 0, bob), Rz(m.aim), slump)
  me.oid = base + 1
  me.k = ko ? 0.4 : 1
  box(me, B, 0, 0, 0.6, 0.2, 0.22, 0.14, JOINT)
  box(me, B, 0, 0, 0.84, 0.6, 0.54, 0.4, P.team)
  box(me, B, -0.04, -0.13, 1.065, 0.46, 0.22, 0.05, P.light)
  box(me, B, -0.04, 0.13, 1.065, 0.46, 0.22, 0.05, P.light)
  box(me, B, 0.31, 0, 0.86, 0.05, 0.18, 0.12, CORE_C[lo.core] ?? CORE_C.furnace, true)
  const hot = m.overheat > 0 ? 1 : Math.max(0, Math.min(1, (m.heat - 30) / (HEAT.max - 30)))
  box(me, B, -0.31, 0, 0.88, 0.05, 0.36, 0.18, [30 + 225 * hot, 33 + 57 * hot, 40], hot > 0.05)
  ;(BOOSTER_ART[lo.booster] ?? BOOSTER_ART.thruster)(me, B, P)
  for (const hand of HANDS) {
    const part = ARM_OF[hand]
    const s = hand === 'right' ? 1 : -1
    me.oid = base + (s > 0 ? 3 : 4)
    me.k = partK(m, part)
    ;(ARM_ART[lo.arms] ?? ARM_ART.frame)(me, B, s, P)
    P.shooting = P.melee = m.act?.k === hand
    P.reach = reach(m, hand, WEAPONS[lo[hand]])
    const rec = Math.max(0, 1 - (now - (kickAt?.[hand] ?? -1e9)) / 130)
    weaponArt(me, lo[hand], mul(B, T3(0.02, s * 0.44, 0.9), Ry(m.armor[part] <= 0 && !ko ? 0.55 : 0)), P, rec, s)
  }
  me.oid = base + 2
  me.k = partK(m, 'head')
  const H = mul(B, T3(0.12, 0, 1.2))
  const kind = lo.head
  box(me, H, 0, 0, 0, 0.3, 0.3, 0.22, kind === 'medic' ? BONE : STEEL)
  box(me, H, -0.03, 0, 0.12, 0.26, 0.28, 0.04, P.team)
  const charging = m.act?.k === 'ult' && m.act.ph === 'wind' && Math.floor(now / 70) % 2 === 0
  const eye = charging ? [255, 255, 255] : kind === 'demon' ? [255, 60, 50] : EYES[c]
  if (kind !== 'visor') for (const s of [-1, 1]) box(me, H, 0.165, s * 0.08, 0.01, 0.04, 0.08, 0.07, eye, true)
  HEAD_ART[kind]?.(me, H, P)
}
