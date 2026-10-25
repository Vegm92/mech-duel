import { ARENA, PILLARS, SPAWNS, MECH_R, LANCE, SHIELD, HEAL, HEAT, SURGE, ULTS, BOOSTERS, DASH_MOVES, TRAILS, ult, ultOf, airborne, maxArmor, arenaCorners, clampArena, PADS, PICKUP, TRAPS, HAZARDS, untilSlam, untilZap, ventPhase, vents } from './sim.js'
import { t } from './i18n.js'
import { TAU, BOOST_C, TEAM, TEAM_LIGHT, TEAM_DARK, SURGE_C, STEEL, ITEM_C, rgba, shade, health, circle, rrect, glow, heatGauge, tileHash } from './paint.js'
import { hud, cursor } from './hud.js'
import { drawGarage } from './garage.js'
import { hype, mood } from './hype.js'
import { drawMech, shieldArc } from './mechart.js'
import { SIN, COS, GUN_H, FLOOR_PAD, target as frame, clear, clearFloor, floorFull, blend, drawCrowd, mesh, scene, buildMech, buildPart, buildPickup, draw3d, clearFloorZoom } from './pix3d.js'

const SHOT = [[255, 200, 110], [130, 205, 255]]
const ULT_C = { lance: [255, 90, 70], swarm: [255, 170, 60], overdrive: [255, 225, 80], emp: [110, 220, 255], orbital: [255, 70, 70], repair: [90, 255, 150], bubble: [190, 120, 255], stasis: [150, 130, 255], mines: [255, 200, 60], berserk: [255, 60, 60], blink: [190, 210, 255], well: [150, 90, 255], wall: [255, 210, 90], meltdown: [255, 110, 40], deflect: [90, 255, 230], mirror: [235, 245, 255], rail: [90, 200, 255], shroud: [170, 170, 185] }
const GUN_C = { laser: [140, 240, 255], tesla: [150, 190, 255], ricochet: [150, 255, 170] }
const PPM = 24
const BORDER = 3
const MAX_ZOOM = 1.8
const VIEW = { w: 32, h: 24 }
const SEEN = 12
const PIX = 16
const AIR = GUN_H
const FLOOR_FX = new Set(['chunk', 'casing', 'ring'])

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
const rand = (lo, hi) => lo + Math.random() * (hi - lo)
const angleDiff = (a, b) => {
  let d = (a - b) % TAU
  if (d > Math.PI) d -= TAU
  if (d < -Math.PI) d += TAU
  return d
}
const times = (n, f) => {
  let k = Math.floor(n) + (Math.random() < n % 1 ? 1 : 0)
  while (k-- > 0) f()
}

const particles = []
const ghosts = []
const banners = []
const decals = []
const seen = new WeakSet()
const legs = new Map()
const kick = new Map()
const heatWas = new Map()
const chip = new Map()
const cam = { x: ARENA.w / 2, y: ARENA.h / 2, z: 1 }
const cheer = [0, 0]
let view = null
let shake = 0
let last = 0
let round = 0
let floorCache = null
let px = null

export function layout(canvas) {
  const w = canvas.width
  const h = canvas.height
  const u = Math.max(1, Math.min(w / 900, h / 600))
  const top = 100 * u
  const bottom = 118 * u
  const sw = Math.max(120, w - 32 * u)
  const sh = Math.max(120, h - top - bottom)
  const fit = Math.max(1, Math.min(sw / (ARENA.w + 2), sh / (ARENA.h + 2)))
  return { w, h, u, top, bottom, sw, sh, fit, cx: w / 2, cy: top + sh / 2 }
}

export function cut() {
  for (const a of [particles, ghosts, banners, decals]) a.length = 0
  shake = 0
  cam.snap = true
}

export const toWorld = (sx, sy) => (view ? { x: view.x0 + (sx - view.cx) / view.S, y: view.y0 + ((sy - view.cy) / view.S + view.h * view.cos) / view.sin } : { x: 0, y: 0 })

export function draw(ctx, state, ui) {
  const now = performance.now()
  const dt = Math.min(0.05, last ? (now - last) / 1000 : 0)
  last = now
  const L = layout(ctx.canvas)
  if (state.round !== round) {
    round = state.round
    decals.length = 0
  }
  react(state)
  if (mood(hype()) === 2) for (const i of [0, 1]) cheer[i] = Math.max(cheer[i], now + 300)
  ambient(state, dt)
  age(dt)
  ctx.fillStyle = '#05070a'
  ctx.fillRect(0, 0, L.w, L.h)
  if (ui.screen !== 'garage') (ui.pixel ? world3d : world2d)(ctx, state, L, dt, now)
  vignette(ctx, L)
  if (ui.screen === 'match') drawBanners(ctx, L, now)
  if (ui.screen === 'garage') drawGarage(ctx, L, ui, now, ui.pixel ? drawMechPreview3d : drawMechPreview, drawPartThumb)
  else hud(ctx, state, ui, L, now, ui.pixel ? drawMechPreview3d : null)
  if (!ui.menuW) cursor(ctx, ui.mouse, L.u, ui.screen === 'garage', ui.screen === 'match' && !ui.paused && ui.replay == null ? state.mechs[0] : null, now)
}

function world2d(ctx, state, L, dt, now) {
  const fit = Math.max(1, Math.min(L.sw / VIEW.w, L.sh / VIEW.h))
  camera(state, L, dt, fit, 1)
  const S = fit * cam.z
  const v = { X: x => L.cx + (x - cam.x) * S, Y: y => L.cy + (y - cam.y) * S, S, u: L.u, now }
  view = { cx: L.cx, cy: L.cy, S, sin: 1, cos: 0, h: 0, x0: cam.x, y0: cam.y }
  ctx.save()
  if (shake > 0.2) ctx.translate(rand(-1, 1) * shake * L.u, rand(-1, 1) * shake * L.u)
  floor(ctx, v)
  lights(ctx, state, v)
  for (const d of decals) decal(ctx, d, v)
  edgeLights(ctx, v)
  healPad(ctx, state, v)
  pads(ctx, state, v)
  trapFloor(ctx, state, v)
  for (const f of state.fields) field(ctx, f, v)
  for (const mi of state.mines) mine(ctx, mi, v)
  for (const l of state.lobs) ground(ctx, l, v)
  for (const m of state.mechs) shadow(ctx, m, v)
  for (const p of PILLARS) pillar(ctx, p, v)
  pylons2d(ctx, state, v)
  for (const m of state.mechs) telegraph(ctx, m, v)
  for (const m of state.mechs) landing(ctx, m, v)
  for (const tr of state.trails) if (tr.kind !== 'smoke') trail(ctx, tr, v)
  for (const g of ghosts) ghost(ctx, g, v)
  chains(ctx, state, v)
  for (const m of state.mechs) mech(ctx, m, v)
  items(state, now, (kind, x, y, ghost) => item2d(ctx, kind, x, y, ghost, v))
  for (const m of state.mechs) aura(ctx, m, v)
  for (const s of state.shots) if (s.kind !== 'hook') shot(ctx, s, v)
  for (const w of state.walls) barrier(ctx, w, v)
  for (const l of state.lobs) if (l.kind === 'shell') shell(ctx, l, v)
  for (const f of state.fx) {
    if (f.k === 'beam') beam(ctx, f, v)
    if (f.k === 'zap') zap(ctx, f, v)
    if (f.k === 'slash') slash(ctx, f, v)
  }
  for (const p of particles) particle(ctx, p, v)
  for (const tr of state.trails) if (tr.kind === 'smoke') smokeTrail(ctx, tr, v)
  for (const m of state.mechs) if (m.overheat > 0) gauge(ctx, m, v)
  ctx.restore()
}

function pixBuffers(W, H) {
  const c = document.createElement('canvas')
  c.width = W
  c.height = H
  return { T: frame(W, H), c, g: c.getContext('2d', { willReadFrequently: true }) }
}

function world3d(ctx, state, full, dt, now) {
  const top = 78 * full.u
  const sh = Math.max(120, full.h - top - 112 * full.u)
  const L = { ...full, sh, cy: top + sh / 2 }
  const fit = Math.max(1, Math.min(L.sw / VIEW.w, L.sh / (VIEW.h * SIN)))
  camera(state, L, dt, fit, SIN)
  const k = Math.max(2, Math.round(fit / PIX))
  const W = Math.ceil(L.w / k)
  const H = Math.ceil(L.h / k)
  if (px?.T.W !== W || px.T.H !== H) px = pixBuffers(W, H)
  const S = (fit * cam.z) / k
  const nx = Math.round((cam.x + FLOOR_PAD) * S)
  const ny = Math.round((cam.y + FLOOR_PAD) * S * SIN)
  const V = { cx: Math.round(L.cx / k), cy: Math.round(L.cy / k), S, x0: nx / S - FLOOR_PAD, y0: ny / (S * SIN) - FLOOR_PAD }
  view = { cx: V.cx * k, cy: V.cy * k, S: S * k, sin: SIN, cos: COS, h: AIR, x0: V.x0, y0: V.y0 }
  const u = L.u / k
  const X = x => V.cx + (x - V.x0) * S
  const vg = { X, Y: y => V.cy / SIN + (y - V.y0) * S, S, u, now }
  const va = { X, Y: y => V.cy + ((y - V.y0) * SIN - AIR * COS) * S, S, u, now }
  const g = px.g
  g.clearRect(0, 0, W, H)
  g.setTransform(1, 0, 0, SIN, 0, 0)
  lights(g, state, vg)
  for (const d of decals) decal(g, d, vg)
  healPad(g, state, vg)
  pads(g, state, vg)
  trapFloor(g, state, vg)
  for (const f of state.fields) field(g, f, vg)
  for (const mi of state.mines) mine(g, mi, vg)
  for (const l of state.lobs) ground(g, l, vg)
  for (const m of state.mechs) if (!m.ko) circle(g, X(m.x), vg.Y(m.y), MECH_R * 1.3 * S, null, rgba(TEAM[m.id], 0.6), Math.max(1, 0.07 * S))
  for (const m of state.mechs) telegraph(g, m, vg)
  for (const m of state.mechs) landing(g, m, vg)
  for (const tr of state.trails) if (tr.kind !== 'smoke') trail(g, tr, vg)
  for (const gh of ghosts) ghost(g, gh, vg)
  for (const p of particles) if (FLOOR_FX.has(p.kind)) particle(g, p, vg)
  g.setTransform(1, 0, 0, 1, 0, 0)
  if (cam.z === 1) clearFloor(px.T, V, floorFull(S), nx - V.cx, ny - V.cy)
  else clearFloorZoom(px.T, V, floorFull(fit / k), fit / k)
  blend(px.T, g.getImageData(0, 0, W, H).data)
  g.clearRect(0, 0, W, H)
  const me = mesh()
  scene(me, V, now, state, cheer)
  for (const m of state.mechs) buildMech(me, m, legs.get(m.id) ?? { phase: 0, heading: m.aim }, kick.get(m.id), now)
  items(state, now, (kind, x, y, ghost) => buildPickup(me, x, y, kind, now, ghost))
  draw3d(px.T, V, me, true)
  drawCrowd(px.T, V, now, cheer)
  chains(g, state, va)
  for (const m of state.mechs) glows(g, m, va)
  for (const m of state.mechs) aura(g, m, va)
  for (const s of state.shots) if (s.kind !== 'hook') shot(g, s, va)
  for (const w of state.walls) barrier(g, w, va)
  for (const l of state.lobs) if (l.kind === 'shell') shell(g, l, va)
  for (const f of state.fx) {
    if (f.k === 'beam') beam(g, f, va)
    if (f.k === 'zap') zap(g, f, va)
    if (f.k === 'slash') slash(g, f, va)
  }
  for (const p of particles) if (!FLOOR_FX.has(p.kind) && p.kind !== 'text') particle(g, p, va)
  for (const tr of state.trails) if (tr.kind === 'smoke') smokeTrail(g, tr, va)
  const box = airBox(state, va, W, H)
  if (box) blend(px.T, g.getImageData(box.x, box.y, box.w, box.h).data, box)
  g.putImageData(px.T.img, 0, 0)
  const jolt = () => (shake > 0.2 ? Math.round(rand(-1, 1) * shake * u) * k : 0)
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(px.c, jolt(), jolt(), W * k, H * k)
  ctx.imageSmoothingEnabled = true
  const vt = { X: x => X(x) * k, Y: y => va.Y(y) * k, S: S * k, u: L.u, now }
  for (const m of state.mechs) if (m.overheat > 0) gauge(ctx, m, vt)
  for (const p of particles) if (p.kind === 'text') particle(ctx, p, vt)
  rivalArrow(ctx, state.mechs[1], vt, L, top, now)
}

function trail(ctx, tr, { X, Y, S }) {
  const k = tr.t / tr.T
  const W = TRAILS[tr.kind].width * S
  const x1 = X(tr.x1)
  const y1 = Y(tr.y1)
  const x2 = X(tr.x2)
  const y2 = Y(tr.y2)
  const line = (w, c) => {
    ctx.strokeStyle = c
    ctx.lineWidth = w
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.stroke()
  }
  ctx.save()
  ctx.lineCap = 'round'
  ctx.globalCompositeOperation = 'lighter'
  if (tr.kind === 'arc') {
    line(W * 2, rgba(BOOST_C.arc, 0.16 * k))
    const n = Math.max(2, Math.ceil(Math.hypot(x2 - x1, y2 - y1) / (0.6 * S)))
    const nx = -(y2 - y1) / (Math.hypot(x2 - x1, y2 - y1) || 1)
    const ny = (x2 - x1) / (Math.hypot(x2 - x1, y2 - y1) || 1)
    ctx.strokeStyle = rgba([225, 240, 255], 0.9 * k)
    ctx.lineWidth = 0.1 * S
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    for (let i = 1; i < n; i++) {
      const j = rand(-0.5, 0.5) * W
      ctx.lineTo(x1 + ((x2 - x1) * i) / n + nx * j, y1 + ((y2 - y1) * i) / n + ny * j)
    }
    ctx.lineTo(x2, y2)
    ctx.stroke()
  } else if (tr.kind === 'flame') {
    line(W * 2.2, rgba([255, 100, 30], 0.28 * k))
    line(W, rgba([255, 200, 90], 0.4 * k))
  } else if (tr.kind === 'frost') {
    line(W * 2, rgba(BOOST_C.frost, 0.22 * k))
    line(0.08 * S, rgba([245, 252, 255], 0.6 * k))
  }
  ctx.restore()
}

function smokeTrail(ctx, tr, { X, Y, S, now }) {
  const k = Math.min(1, tr.t / 40) * Math.min(1, (tr.T - tr.t) / 8 + 0.4)
  const w = tr.w ?? TRAILS.smoke.width
  const n = Math.max(1, Math.ceil(Math.hypot(tr.x2 - tr.x1, tr.y2 - tr.y1) / 0.9))
  const puff = (x, y, r, i) => circle(ctx, X(x), Y(y), r * S * (0.9 + 0.2 * Math.sin(now / 420 + i * 1.7)), rgba([150, 152, 162], 0.78 * k))
  for (let i = 0; i <= n; i++) puff(tr.x1 + ((tr.x2 - tr.x1) * i) / n, tr.y1 + ((tr.y2 - tr.y1) * i) / n, Math.min(w, 1.6), i)
  if (w > 2) for (let i = 0; i < 8; i++) puff(tr.x1 + Math.cos(i * 0.785 + now / 3000) * w * 0.55, tr.y1 + Math.sin(i * 0.785 + now / 3000) * w * 0.55, w * 0.55, i + 3)
}

function barrier(ctx, w, { X, Y, S, now }) {
  const k = Math.min(1, w.t / 30, (w.T - w.t) / 6)
  const c = ULT_C.wall
  ctx.save()
  ctx.lineCap = 'round'
  for (const [lw, col, a] of [[0.55, c, 0.35], [0.2, [255, 240, 190], 0.9]]) {
    ctx.strokeStyle = rgba(col, a * k * (0.85 + 0.15 * Math.sin(now / 60)))
    ctx.lineWidth = lw * S
    ctx.beginPath()
    ctx.moveTo(X(w.x1), Y(w.y1))
    ctx.lineTo(X(w.x2), Y(w.y2))
    ctx.stroke()
  }
  for (const [x, y] of [[w.x1, w.y1], [w.x2, w.y2]]) circle(ctx, X(x), Y(y), 0.22 * S, rgba([60, 64, 74], k), rgba(c, k), 0.06 * S)
  ctx.restore()
}

function landing(ctx, m, { X, Y, S, u }) {
  if (!airborne(m)) return
  const a = m.act
  const r = (DASH_MOVES[a.move].land?.r ?? 1) * S
  const c = TEAM[m.id]
  const p = 1 - a.t / a.T
  circle(ctx, X(a.lx), Y(a.ly), r, rgba(c, 0.06 + 0.12 * p), rgba(c, 0.45 + 0.5 * p), 2 * u)
  circle(ctx, X(a.lx), Y(a.ly), r * p, rgba(c, 0.14))
}

function airBox(state, { X, Y }, W, H) {
  let x0 = Infinity
  let y0 = Infinity
  let x1 = -Infinity
  let y1 = -Infinity
  const add = (x, y, r) => {
    x0 = Math.min(x0, x - r)
    x1 = Math.max(x1, x + r)
    y0 = Math.min(y0, y - r)
    y1 = Math.max(y1, y + r)
  }
  for (const m of state.mechs) add(m.x, m.y, 3.6)
  for (const w of state.walls) {
    add(w.x1, w.y1, 1)
    add(w.x2, w.y2, 1)
  }
  for (const s of state.shots) {
    add(s.x, s.y, 1.5)
    add(s.x - s.vx * 0.16, s.y - s.vy * 0.16, 1.5)
  }
  for (const l of state.lobs) {
    if (l.kind !== 'shell') continue
    add(l.sx, l.sy, 1)
    add(l.x, l.y, 1)
    add((l.sx + l.x) / 2, (l.sy + l.y) / 2 - 3.5, 1.5)
  }
  for (const f of state.fx) {
    if (f.k === 'beam' || f.k === 'zap') {
      add(f.x1, f.y1, 2)
      add(f.x2, f.y2, 2)
    } else if (f.k === 'slash') add(f.x, f.y, f.range + 1.5)
  }
  for (const p of particles) if (!FLOOR_FX.has(p.kind) && p.kind !== 'text') add(p.x, p.y, 2 * (p.size ?? 0) + (p.r0 ?? 0) + (p.r1 ?? 0) + 0.5)
  for (const tr of state.trails) {
    if (tr.kind !== 'smoke') continue
    add(tr.x1, tr.y1, (tr.w ?? TRAILS.smoke.width) + 0.8)
    add(tr.x2, tr.y2, (tr.w ?? TRAILS.smoke.width) + 0.8)
  }
  const x = Math.max(0, Math.floor(X(x0)))
  const y = Math.max(0, Math.floor(Y(y0)))
  const w = Math.min(W, Math.ceil(X(x1))) - x
  const h = Math.min(H, Math.ceil(Y(y1))) - y
  return w > 0 && h > 0 ? { x, y, w, h } : null
}

function rivalArrow(ctx, o, { X, Y }, L, top, now) {
  if (o.ko) return
  const pad = 30 * L.u
  const box = [pad, top + pad, L.w - pad, top + L.sh - pad]
  const dx = X(o.x) - L.cx
  const dy = Y(o.y) - L.cy
  if (X(o.x) > box[0] && X(o.x) < box[2] && Y(o.y) > box[1] && Y(o.y) < box[3]) return
  const s = Math.min(dx > 0 ? (box[2] - L.cx) / dx : (box[0] - L.cx) / dx, dy > 0 ? (box[3] - L.cy) / dy : (box[1] - L.cy) / dy)
  const r = (13 + 2 * Math.sin(now / 150)) * L.u
  ctx.save()
  ctx.translate(L.cx + dx * s, L.cy + dy * s)
  ctx.rotate(Math.atan2(dy, dx))
  glow(ctx, 0, 0, r * 2.2, TEAM[1], 0.35)
  ctx.beginPath()
  ctx.moveTo(r, 0)
  ctx.lineTo(-r * 0.7, -r * 0.75)
  ctx.lineTo(-r * 0.35, 0)
  ctx.lineTo(-r * 0.7, r * 0.75)
  ctx.closePath()
  ctx.fillStyle = rgba(TEAM[1])
  ctx.strokeStyle = 'rgba(0,0,0,0.75)'
  ctx.lineWidth = 2 * L.u
  ctx.fill()
  ctx.stroke()
  ctx.restore()
}

function glows(ctx, m, { X, Y, S, now }) {
  const r = MECH_R * S
  const x = X(m.x)
  const y = Y(m.y)
  if (m.surge >= SURGE.max && !m.ko) glow(ctx, x, y, r * (2.1 + 0.2 * Math.sin(now / 110)), SURGE_C, 0.4)
  if (m.overheat > 0) glow(ctx, x, y, r * 1.6, [255, 60, 40], 0.45 + 0.2 * Math.sin(now / 50))
  shieldArc(ctx, m, x, y, r, S)
}

const gauge = (ctx, m, { X, Y, S, u, now }) => heatGauge(ctx, X(m.x), Y(m.y - MECH_R * 2.1), 0.36 * S, m.overheat / HEAT.overheat, u, now)

function previewMech(loadout, now, id = 0) {
  const max = maxArmor(loadout)
  return {
    id, preview: true, x: 0, y: 0, vx: 0, vy: 0, aim: -Math.PI / 2 + 0.4 * Math.sin(now / 900), loadout, max, armor: { ...max },
    heat: 0, overheat: 0, surge: 0, cd: { left: 0, right: 0, hook: 0, shield: 0, dash: 0 }, act: null, stagger: 0, pull: null, ko: false,
    buffs: { overdrive: 0, berserk: 0, bubble: 0, bubbleHp: 0, jam: 0, slow: 0 },
  }
}

export function drawMechPreview(ctx, loadout, x, y, r, now, u) {
  glow(ctx, x, y, r * 3, TEAM[0], 0.2)
  mech(ctx, previewMech(loadout, now), { X: () => x, Y: () => y, S: r / MECH_R, u, now })
}

const pvs = new Map()

function drawMechPreview3d(ctx, loadout, x, y, r, now, u, { id = 0, aim = now / 1400, N = 56, S = 11.5, cx = 0.44, cy = 0.58 } = {}) {
  if (!pvs.has(N)) pvs.set(N, pixBuffers(N, N))
  const pv = pvs.get(N)
  const m = previewMech(loadout, now, id)
  m.aim = aim
  const V = { cx: N * cx, cy: N * cy, S, x0: 0, y0: 0 }
  clear(pv.T, V)
  const me = mesh()
  buildMech(me, m, { phase: now / 220, heading: m.aim }, null, now)
  draw3d(pv.T, V, me, true)
  pv.g.putImageData(pv.T.img, 0, 0)
  glow(ctx, x, y, r * 1.6, TEAM[id], 0.2)
  const k = Math.max(1, Math.round((r * 4) / N))
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(pv.c, Math.round(x - V.cx * k), Math.round(y - V.cy * k), N * k, N * k)
  ctx.imageSmoothingEnabled = true
}

const thumbs = new Map()

function drawPartThumb(ctx, slot, key, x, y, size) {
  const id = `${slot}:${key}`
  if (!thumbs.has(id)) {
    const N = 40
    const b = pixBuffers(N, N)
    const V = { cx: N / 2, cy: N * 0.66, S: 14, x0: 0, y0: 0 }
    clear(b.T, V)
    const me = mesh()
    buildPart(me, slot, key, 0)
    draw3d(b.T, V, me, false)
    b.g.putImageData(b.T.img, 0, 0)
    thumbs.set(id, b.c)
  }
  const c = thumbs.get(id)
  const k = Math.max(1, Math.floor(size / c.width))
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(c, Math.round(x - (c.width * k) / 2), Math.round(y - (c.height * k) / 2), c.width * k, c.height * k)
  ctx.imageSmoothingEnabled = true
}

function camera(state, L, dt, fit, sin) {
  const down = state.phase === 'ko' || state.phase === 'over' ? state.mechs.find(m => m.ko) : null
  const want = down ? MAX_ZOOM : 1
  const snap = cam.snap
  cam.snap = false
  cam.z += (want - cam.z) * (snap ? 1 : 1 - Math.exp(-dt * (down ? 3 : 6)))
  if (Math.abs(want - cam.z) < 0.002) cam.z = want
  const S = fit * cam.z
  const hw = L.sw / 2 / S
  const hh = L.sh / 2 / (S * sin)
  const [p, o] = state.mechs
  let fx = down ? down.x : clamp((p.x + o.x) / 2, p.x - hw * 0.7, p.x + hw * 0.7)
  let fy = down ? down.y : clamp((p.y + o.y) / 2, p.y - hh * 0.7, p.y + hh * 0.7)
  if (!down && !snap) {
    fx = Math.abs(fx - cam.x) < hw * 0.15 ? cam.x : fx - Math.sign(fx - cam.x) * hw * 0.15
    fy = Math.abs(fy - cam.y) < hh * 0.15 ? cam.y : fy - Math.sign(fy - cam.y) * hh * 0.15
  }
  const cx = hw * 2 >= ARENA.w + 2 * SEEN ? ARENA.w / 2 : clamp(fx, hw - SEEN, ARENA.w + SEEN - hw)
  const cy = hh * 2 >= ARENA.h + 2 * SEEN ? ARENA.h / 2 : clamp(fy, hh - SEEN, ARENA.h + SEEN - hh)
  const k = snap ? 1 : 1 - Math.exp(-dt * (down ? 3 : 2.2))
  cam.x += (cx - cam.x) * k
  cam.y += (cy - cam.y) * k
}

function sparks(x, y, dir, spread, n, rgb, speed, life) {
  for (let i = 0; i < n; i++) {
    const a = dir + rand(-spread, spread)
    const sp = speed * rand(0.35, 1.1)
    particles.push({ kind: 'spark', x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, drag: 3, size: rand(0.04, 0.08), rgb, life: life * rand(0.5, 1.1), max: life })
  }
}

function chunks(x, y, n, rgb, speed) {
  for (let i = 0; i < n; i++) {
    const a = rand(0, TAU)
    const sp = speed * rand(0.3, 1)
    particles.push({ kind: 'chunk', x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, drag: 3.5, size: rand(0.1, 0.24), rot: rand(0, TAU), spin: rand(-14, 14), rgb, life: rand(0.8, 1.3), max: 1.3, settle: true })
  }
}

const smoke = (x, y, vx, vy, rgb, size, grow, life) => ({ kind: 'smoke', x, y, vx, vy, drag: 2, size, grow, rgb, life: life * rand(0.6, 1), max: life })
const ember = (x, y, vx, vy, rgb, size, life, drag = 2) => ({ kind: 'ember', x, y, vx, vy, drag, size, rgb, life, max: life })
const text = (x, y, s, px, rgb, life = 0.9) => ({ kind: 'text', x, y, vx: 0, vy: -1.4, drag: 1.5, text: s, px, rgb, life, max: life })
const addDecal = d => {
  decals.push(d)
  if (decals.length > 180) decals.shift()
}

function react(state) {
  for (const f of state.fx) {
    if (seen.has(f)) continue
    seen.add(f)
    const cheerFor = { hit: f.n >= 30 || f.head ? 900 : 0, hooked: 900, break: 1600, ko: 3500 }[f.k]
    if (cheerFor) cheer[1 - f.id] = Math.max(cheer[1 - f.id], performance.now() + cheerFor)
    if (f.k === 'muzzle') {
      kick.set(f.id, { ...kick.get(f.id), [f.hand]: performance.now() })
      if (f.gun === 'flamer') {
        times(5, () => particles.push(ember(f.x, f.y, Math.cos(f.a + rand(-0.3, 0.3)) * rand(4, 9), Math.sin(f.a + rand(-0.3, 0.3)) * rand(4, 9), [255, Math.round(rand(90, 190)), 30], rand(0.06, 0.12), rand(0.15, 0.3), 3)))
        shake += 0.15
      } else if (GUN_C[f.gun]) {
        sparks(f.x, f.y, f.a, 0.5, 8, GUN_C[f.gun], 10, 0.14)
        particles.push({ kind: 'flash', x: f.x, y: f.y, size: 0.9, rgb: GUN_C[f.gun], life: 0.1, max: 0.1 })
        shake += f.gun === 'ricochet' ? 1.2 : 0.8
      } else if (f.gun === 'mortar' || f.gun === 'missiles') {
        particles.push({ kind: 'flash', x: f.x, y: f.y, size: 1.1, rgb: [255, 210, 150], life: 0.12, max: 0.12 })
        times(8, () => particles.push(smoke(f.x, f.y, Math.cos(f.a) * rand(-1, 3) + rand(-1, 1), Math.sin(f.a) * rand(-1, 3) + rand(-1, 1), [120, 120, 128], 0.18, 0.9, 0.8)))
        shake += f.gun === 'mortar' ? 3.5 : 1.5
      } else {
        const big = f.gun === 'needle' ? 1.6 : f.gun === 'gatling' ? 0.6 : 1
        sparks(f.x, f.y, f.a, f.gun === 'scatter' ? 0.6 : 0.3, f.gun === 'scatter' ? 18 : f.gun === 'gatling' ? 4 : 9, [255, 220, 150], 14 * big, 0.14)
        particles.push({ kind: 'flash', x: f.x, y: f.y, size: 0.8 * big, rgb: f.gun === 'needle' ? [190, 230, 255] : [255, 220, 160], life: 0.09, max: 0.09 })
        const side = f.a + Math.PI / 2 + rand(-0.4, 0.4)
        const sp = rand(2.5, 4)
        particles.push({ kind: 'casing', x: f.x, y: f.y, vx: Math.cos(side) * sp, vy: Math.sin(side) * sp, drag: 4, size: 0.12 * Math.max(0.7, big), rot: rand(0, TAU), spin: rand(-20, 20), rgb: [214, 170, 80], life: 0.9, max: 0.9, settle: true })
        shake += f.gun === 'gatling' ? 0.35 : 1.2
      }
    } else if (f.k === 'zap') {
      const c = f.kind === 'tesla' ? [150, 190, 255] : [150, 240, 255]
      sparks(f.x2, f.y2, Math.atan2(f.y1 - f.y2, f.x1 - f.x2), 1.2, 10, c, 8, 0.25)
      particles.push({ kind: 'flash', x: f.x2, y: f.y2, size: 0.8, rgb: c, life: 0.1, max: 0.1 })
      if (f.kind === 'laser') addDecal({ kind: 'mark', x: f.x2, y: f.y2, r: 0.2 })
    } else if (f.k === 'boom') {
      particles.push({ kind: 'flash', x: f.x, y: f.y, size: f.r * 1.3, rgb: f.big ? [255, 120, 100] : [255, 200, 130], life: 0.2, max: 0.2 })
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.3, r1: f.r, rgb: f.big ? [255, 90, 80] : [255, 190, 120], life: 0.35, max: 0.35 })
      sparks(f.x, f.y, 0, Math.PI, f.big ? 50 : 24, [255, 200, 120], f.big ? 14 : 9, 0.45)
      times(f.big ? 18 : 9, () => particles.push(smoke(f.x + rand(-0.5, 0.5), f.y + rand(-0.5, 0.5), rand(-2.5, 2.5), rand(-2.5, 2.5), [80, 78, 82], 0.3, 1.4, 1.3)))
      chunks(f.x, f.y, f.big ? 10 : 4, STEEL[0], 6)
      addDecal({ kind: 'scorch', x: f.x, y: f.y, r: f.r * 0.7 })
      shake += f.big ? 18 : 6
    } else if (f.k === 'emp') {
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.5, r1: f.r, rgb: [110, 220, 255], life: 0.45, max: 0.45 })
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.2, r1: f.r * 0.7, rgb: [200, 240, 255], life: 0.3, max: 0.3 })
      sparks(f.x, f.y, 0, Math.PI, 40, [130, 220, 255], 16, 0.4)
      shake += 7
    } else if (f.k === 'soak') {
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: MECH_R * 1.6, r1: 0.4, rgb: [200, 150, 255], life: 0.25, max: 0.25 })
    } else if (f.k === 'ult') {
      const c = ULT_C[f.ult]
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.4, r1: 2.4, rgb: c, life: 0.4, max: 0.4 })
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.2, r1: 4, rgb: [255, 255, 255], life: 0.25, max: 0.25 })
      sparks(f.x, f.y, 0, Math.PI, 26, c, 11, 0.4)
      banners.push({ id: f.id, kind: f.ult, core: state.mechs[f.id].loadout.core, at: performance.now() })
      shake += 4
    } else if (f.k === 'blink') {
      ghosts.push({ x: f.x, y: f.y, aim: f.a, id: f.id, life: 0.6, max: 0.6 })
      for (const [x, y] of [[f.x, f.y], [f.x2, f.y2]]) {
        particles.push({ kind: 'flash', x, y, size: 1.4, rgb: ULT_C.blink, life: 0.14, max: 0.14 })
        sparks(x, y, 0, Math.PI, 14, ULT_C.blink, 8, 0.3)
      }
    } else if (f.k === 'magnet') {
      const dir = Math.atan2(f.y1 - f.y2, f.x1 - f.x2)
      for (let i = 0; i < 12; i++) {
        const k = i / 12
        sparks(f.x2 + (f.x1 - f.x2) * k, f.y2 + (f.y1 - f.y2) * k, dir, 0.3, 1, BOOST_C.magnet, 6, 0.3)
      }
      particles.push({ kind: 'ring', x: f.x2, y: f.y2, r0: 1.6, r1: -1.2, rgb: BOOST_C.magnet, life: 0.3, max: 0.3 })
    } else if (f.k === 'land') {
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.3, r1: f.r, rgb: [225, 215, 195], life: 0.35, max: 0.35 })
      times(10, () => particles.push(smoke(f.x + rand(-0.6, 0.6), f.y + rand(-0.6, 0.6), rand(-3, 3), rand(-3, 3), [120, 112, 100], 0.2, 1.2, 0.7)))
      chunks(f.x, f.y, 5, [120, 110, 95], 5)
      addDecal({ kind: 'scorch', x: f.x, y: f.y, r: f.r * 0.45 })
      shake += f.r * 2.5
    } else if (f.k === 'dash') {
      const m = state.mechs[f.id]
      const c = BOOST_C[BOOSTERS[m.loadout.booster].trail]
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.4, r1: 1.6, rgb: [190, 200, 215], life: 0.3, max: 0.3 })
      particles.push({ kind: 'flash', x: f.x - Math.cos(m.aim) * 0.5, y: f.y - Math.sin(m.aim) * 0.5, size: 1.2, rgb: c, life: 0.12, max: 0.12 })
      times(6, () => particles.push(smoke(f.x + rand(-0.4, 0.4), f.y + rand(-0.4, 0.4), rand(-2, 2), rand(-2, 2), [110, 112, 120], 0.16, 1.1, 0.5)))
    } else if (f.k === 'slash') {
      const n = f.arc > 2 ? 30 : 14
      for (let i = 0; i < n; i++) {
        const a = f.a - f.arc + (2 * f.arc * i) / (n - 1)
        const d = f.range * rand(0.75, 1)
        sparks(f.x + Math.cos(a) * d, f.y + Math.sin(a) * d, a + Math.PI / 2, 0.5, 1, [255, 230, 170], 7, 0.25)
      }
      shake += f.blade === 'hammer' ? 5 : 2
    } else if (f.k === 'heal') {
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.5, r1: 2, rgb: [90, 255, 150], life: 0.5, max: 0.5 })
      particles.push(text(f.x, f.y - 1.1, `+${f.n ?? HEAL.amount}`, 20, [120, 255, 170], 1.2))
      for (let i = 0; i < 24; i++) particles.push(ember(f.x + rand(-0.6, 0.6), f.y + rand(-0.6, 0.6), rand(-0.5, 0.5), rand(-2.5, -0.5), [110, 255, 160], rand(0.04, 0.08), rand(0.5, 1), 1))
    } else if (f.k === 'pickup') {
      const c = ITEM_C[f.item]
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.3, r1: 2, rgb: c, life: 0.45, max: 0.45 })
      particles.push(text(f.x, f.y - 1.4, t(`i_${f.item}`).toUpperCase(), 15, c, 1.3))
      sparks(f.x, f.y, 0, Math.PI, 18, c, 8, 0.35)
    } else if (f.k === 'crush') {
      chunks(f.x, f.y, 8, STEEL[0], 6)
      sparks(f.x, f.y, 0, Math.PI, 30, [255, 220, 150], 10, 0.4)
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 1, r1: 3, rgb: [255, 200, 120], life: 0.35, max: 0.35 })
      times(14, () => particles.push(smoke(f.x + rand(-1.5, 1.5), f.y + rand(-1.5, 1.5), rand(-3, 3), rand(-3, 3), [90, 88, 92], 0.25, 1.2, 1)))
      shake += 9
    } else if (f.k === 'healUp') {
      particles.push({ kind: 'ring', x: HEAL.x, y: HEAL.y, r0: 0.4, r1: 1.6, rgb: [90, 255, 150], life: 0.6, max: 0.6 })
      particles.push(text(HEAL.x, HEAL.y - 1.3, t('healReady'), 13, [120, 255, 170], 1.4))
    } else if (f.k === 'hooked') {
      sparks(f.x, f.y, 0, Math.PI, 14, [255, 210, 140], 7, 0.3)
      shake += 3
    } else if (f.k === 'hit' && f.n < 15 && !f.head) {
      sparks(f.x, f.y, f.from, 1.1, 4, [255, 235, 190], 6, 0.2)
      const c = chip.get(f.id) ?? { n: 0, at: performance.now() }
      chip.set(f.id, Object.assign(c, { n: c.n + f.n, x: f.x, y: f.y }))
      shake += 0.4
    } else if (f.k === 'hit') {
      sparks(f.x, f.y, f.from, 1.1, f.head ? 26 : 12, [255, 235, 190], f.head ? 12 : 8, 0.3)
      if (f.n >= 40 || f.head) {
        particles.push({ kind: 'flash', x: f.x + Math.cos(f.from) * 0.5, y: f.y + Math.sin(f.from) * 0.5, size: f.head ? 1.8 : 1.2, rgb: [255, 250, 235], life: 0.1, max: 0.1 })
        particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.5, r1: f.head ? 2.2 : 1.3, rgb: f.head ? [255, 110, 90] : [255, 230, 190], life: 0.22, max: 0.22 })
      }
      particles.push(text(f.x + rand(-0.3, 0.3), f.y - 0.8, String(f.n), f.head ? 24 : 16, f.head ? [255, 80, 70] : [255, 240, 220]))
      shake += f.head ? 14 : 2.5
    } else if (f.k === 'parry') {
      particles.push({ kind: 'ring', x: f.x, y: f.y, r0: 0.3, r1: 1.8, rgb: [255, 255, 255], life: 0.35, max: 0.35 })
      particles.push(text(f.x, f.y - 1, t('perfect'), 16, [200, 240, 255]))
      shake += 4
    } else if (f.k === 'beam') {
      const dir = Math.atan2(f.y2 - f.y1, f.x2 - f.x1)
      for (let i = 0; i < 28; i++) {
        const k = i / 28
        sparks(f.x1 + (f.x2 - f.x1) * k, f.y1 + (f.y2 - f.y1) * k, dir + (i % 2 ? 1 : -1) * Math.PI / 2, 0.6, 1, [255, 200, 140], 6, 0.35)
      }
      sparks(f.x2, f.y2, dir + Math.PI, 1.2, 16, [255, 210, 160], 10, 0.4)
      addDecal({ kind: 'line', x1: f.x1, y1: f.y1, x2: f.x2, y2: f.y2 })
      shake += 9
    } else if (f.k === 'break') {
      chunks(f.x, f.y, 14, STEEL[0], 7)
      sparks(f.x, f.y, 0, Math.PI, 30, [255, 200, 120], 12, 0.5)
      particles.push({ kind: 'flash', x: f.x, y: f.y, size: 2.2, rgb: [255, 210, 150], life: 0.18, max: 0.18 })
      particles.push(text(f.x, f.y - 1.4, t(`broke_${f.part}`), 18, [255, 120, 90], 1.5))
      addDecal({ kind: 'scorch', x: f.x, y: f.y, r: 1.3 })
      shake += 10
    } else if (f.k === 'ping') {
      sparks(f.x, f.y, f.a + Math.PI, 1, 6, [255, 225, 170], 6, 0.2)
      addDecal({ kind: 'mark', x: f.x, y: f.y, r: 0.22 })
    } else if (f.k === 'ko') {
      sparks(f.x, f.y, 0, Math.PI, 60, [255, 170, 80], 14, 0.8)
      chunks(f.x, f.y, 22, STEEL[0], 9)
      for (let i = 0; i < 24; i++) particles.push(smoke(f.x, f.y, rand(-3, 3), rand(-3, 3), [70, 70, 78], 0.3, 1.6, 1.6))
      particles.push({ kind: 'flash', x: f.x, y: f.y, size: 4, rgb: [255, 200, 140], life: 0.3, max: 0.3 })
      addDecal({ kind: 'scorch', x: f.x, y: f.y, r: 2.6 })
      shake += 22
    }
  }
}

function ambient(state, dt) {
  for (const tr of state.trails) {
    if (tr.kind !== 'flame') continue
    times(dt * 18 * (tr.t / tr.T), () => {
      const k = Math.random()
      particles.push(ember(tr.x1 + (tr.x2 - tr.x1) * k + rand(-0.3, 0.3), tr.y1 + (tr.y2 - tr.y1) * k + rand(-0.3, 0.3), rand(-0.4, 0.4), rand(-1.6, -0.4), [255, Math.round(rand(90, 190)), 40], rand(0.04, 0.08), rand(0.3, 0.6), 1))
    })
  }
  for (const s of state.shots) if (s.kind === 'missile') times(dt * 45, () => particles.push(smoke(s.x - s.vx * 0.02, s.y - s.vy * 0.02, rand(-0.4, 0.4), rand(-0.4, 0.4), [150, 150, 158], 0.1, 0.8, 0.5)))
  for (const [id, c] of chip) {
    if (performance.now() - c.at < 300) continue
    particles.push(text(c.x + rand(-0.3, 0.3), c.y - 0.8, String(c.n), 14, [255, 225, 190]))
    chip.delete(id)
  }
  for (let i = ghosts.length - 1; i >= 0; i--) if ((ghosts[i].life -= dt) <= 0) ghosts.splice(i, 1)
  for (const m of state.mechs) {
    const lg = legs.get(m.id) ?? { phase: 0, heading: m.aim }
    legs.set(m.id, lg)
    const sp = Math.hypot(m.vx, m.vy)
    lg.phase += sp * dt * 2.6
    if (sp > 0.4) lg.heading += angleDiff(Math.atan2(m.vy, m.vx), lg.heading) * Math.min(1, dt * 14)
    if (m.overheat > 0 && !(heatWas.get(m.id) > 0)) particles.push(text(m.x, m.y - 2.1, t('overheat'), 15, [255, 150, 70], 1.2))
    heatWas.set(m.id, m.overheat)
    if (m.ko) {
      times(dt * 12, () => particles.push(smoke(m.x + rand(-0.3, 0.3), m.y + rand(-0.3, 0.3), rand(-0.6, 0.6), rand(-0.6, 0.6), [50, 50, 56], 0.2, 0.9, 1.6)))
      continue
    }
    const fx = Math.cos(m.aim)
    const fy = Math.sin(m.aim)
    const bx = m.x - fx * 0.42
    const by = m.y - fy * 0.42
    if (m.overheat > 0) {
      const k = m.overheat / HEAT.overheat
      for (const side of [-1, 1]) {
        const sx = bx - fy * side * 0.28
        const sy = by + fx * side * 0.28
        const dir = m.aim + Math.PI + side * 0.55
        times(dt * (20 + 40 * k), () => {
          const a = dir + rand(-0.22, 0.22)
          const sp = rand(3.5, 7) * (0.5 + 0.5 * k)
          particles.push(smoke(sx, sy, Math.cos(a) * sp + m.vx * 0.5, Math.sin(a) * sp + m.vy * 0.5, [228, 234, 242], 0.07, 1.5, 0.65))
        })
      }
      times(dt * 30 * k, () => particles.push(ember(m.x + rand(-0.4, 0.4), m.y + rand(-0.4, 0.4), rand(-0.5, 0.5), rand(-2, -0.6), [255, Math.round(rand(60, 140)), 40], rand(0.03, 0.06), rand(0.3, 0.6), 1)))
    } else if (m.heat >= HEAT.hot) {
      const k = (m.heat - HEAT.hot) / (HEAT.max - HEAT.hot)
      times(dt * (6 + 50 * k), () => particles.push(ember(bx + rand(-0.12, 0.12), by + rand(-0.12, 0.12), -fx * 1.4 + rand(-0.6, 0.6), -fy * 1.4 + rand(-0.6, 0.6), [255, Math.round(rand(110, 200)), 40], rand(0.03, 0.06), rand(0.3, 0.7))))
    }
    for (const p of ['rarm', 'larm', 'legs']) {
      if (m.armor[p] <= 0) times(dt * 3, () => sparks(m.x + rand(-0.4, 0.4), m.y + rand(-0.4, 0.4), rand(0, TAU), Math.PI, 3, [255, 220, 120], 4, 0.25))
    }
    if (health(m, 'head') >= 2) times(dt * 6, () => particles.push(smoke(m.x, m.y, rand(-0.5, 0.5), rand(-0.5, 0.5), [60, 60, 66], 0.12, 0.6, 1.2)))
    const a = m.act
    if (a?.k === 'dash' && a.ph === 'go') {
      const c = BOOST_C[BOOSTERS[m.loadout.booster].trail]
      ghosts.push({ x: m.x, y: m.y, aim: m.aim, id: m.id, life: 0.22, max: 0.22 })
      times(3, () => particles.push(ember(m.x - a.dx * 0.45, m.y - a.dy * 0.45, -a.dx * 6 + rand(-1.5, 1.5), -a.dy * 6 + rand(-1.5, 1.5), shade(c, rand(0.8, 1.15)), rand(0.05, 0.1), rand(0.15, 0.3), 4)))
    }
    if (a?.k === 'ult' && a.ph === 'wind') {
      const kind = ultOf(m.loadout)
      const lance = kind === 'lance'
      const tx = lance ? m.x + Math.cos(a.angle) * MECH_R : m.x
      const ty = lance ? m.y + Math.sin(a.angle) * MECH_R : m.y
      times(dt * 60, () => {
        const ang = rand(0, TAU)
        const d = rand(0.8, 1.4)
        particles.push(ember(tx + Math.cos(ang) * d, ty + Math.sin(ang) * d, -Math.cos(ang) * d * 3.5, -Math.sin(ang) * d * 3.5, ULT_C[kind], rand(0.03, 0.06), 0.28, 0))
      })
    }
    const b = m.buffs
    if (b.berserk > 0) times(dt * 30, () => particles.push(ember(m.x + rand(-0.5, 0.5), m.y + rand(-0.5, 0.5), rand(-0.6, 0.6), rand(-2.2, -0.6), [255, Math.round(rand(40, 90)), 40], rand(0.04, 0.08), rand(0.3, 0.6), 1)))
    if (b.overdrive > 0) times(dt * 20, () => sparks(m.x + rand(-0.5, 0.5), m.y + rand(-0.5, 0.5), rand(0, TAU), Math.PI, 1, [255, 230, 110], 3, 0.25))
    if (b.jam > 0) times(dt * 14, () => sparks(m.x + rand(-0.5, 0.5), m.y + rand(-0.5, 0.5), rand(0, TAU), Math.PI, 2, [130, 220, 255], 5, 0.18))
    for (const [k, c] of [['speed', ITEM_C.speed], ['power', ITEM_C.power], ['cool', ITEM_C.coolant]]) {
      if (b[k] > 0) times(dt * 16, () => particles.push(ember(m.x + rand(-0.5, 0.5), m.y + rand(-0.5, 0.5), rand(-0.4, 0.4), rand(-2, -0.6), c, rand(0.04, 0.08), rand(0.3, 0.6), 1)))
    }
    if (b.slow > 0) times(dt * 10, () => particles.push(smoke(m.x + rand(-0.4, 0.4), m.y + rand(-0.4, 0.4), rand(-0.3, 0.3), rand(-0.3, 0.3), [150, 130, 255], 0.12, 0.5, 0.7)))
  }
  const v = ventPhase(state)
  if (v?.burn) {
    vents(state.shrink).forEach(g => {
      if (g.wall % 2 !== v.set) return
      times(dt * 50, () => {
        const d = rand(0, HAZARDS.reach)
        const w = rand(-0.7, 0.7) * HAZARDS.half
        const sp = rand(2, 6)
        particles.push(ember(g.x + g.dx * d - g.dy * w, g.y + g.dy * d + g.dx * w, g.dx * sp, g.dy * sp, [255, Math.round(rand(90, 200)), 30], rand(0.08, 0.16), rand(0.2, 0.4), 3))
      })
    })
  }
  for (const s of state.shots) {
    if (s.kind === 'missile') times(dt * 70, () => particles.push(smoke(s.x - s.vx * 0.02, s.y - s.vy * 0.02, rand(-0.4, 0.4), rand(-0.4, 0.4), [150, 150, 160], 0.07, 0.5, 0.45)))
    if (s.kind === 'flame') times(dt * 40, () => particles.push(ember(s.x, s.y, s.vx * 0.2 + rand(-1, 1), s.vy * 0.2 + rand(-1, 1), [255, Math.round(rand(80, 170)), 30], rand(0.04, 0.09), rand(0.12, 0.25), 3)))
  }
}

function age(dt) {
  shake = Math.min(30, Math.max(0, shake * Math.exp(-dt * 9) - dt))
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i]
    if ((p.life -= dt) <= 0) {
      if (p.settle) addDecal({ kind: 'chunk', x: p.x, y: p.y, size: p.size, rot: p.rot, rgb: p.rgb })
      particles.splice(i, 1)
      continue
    }
    const k = Math.exp(-(p.drag ?? 0) * dt)
    p.vx = (p.vx ?? 0) * k
    p.vy = (p.vy ?? 0) * k
    p.x += p.vx * dt
    p.y += p.vy * dt
    if (p.grow) p.size += p.grow * dt
    if (p.spin) p.rot += p.spin * dt * Math.min(1, Math.hypot(p.vx, p.vy))
  }
  if (particles.length > 900) particles.splice(0, particles.length - 900)
}

function plate(g, x, y, s, h) {
  let seed = h
  const r = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0
    return seed / 4294967296
  }
  const base = 23 + (h % 7)
  g.fillStyle = `rgb(${base},${base + 5},${base + 12})`
  g.fillRect(x, y, s, s)
  g.fillStyle = 'rgba(255,255,255,0.05)'
  g.fillRect(x, y, s, 2)
  g.fillRect(x, y, 2, s)
  g.fillStyle = 'rgba(0,0,0,0.5)'
  g.fillRect(x, y + s - 3, s, 3)
  g.fillRect(x + s - 3, y, 3, s)
  const kind = h % 11
  if (kind === 0) {
    g.fillStyle = 'rgba(0,0,0,0.45)'
    for (let k = 0; k < 6; k++) g.fillRect(x + s * 0.22, y + s * (0.24 + k * 0.09), s * 0.56, s * 0.045)
  } else if (kind === 1) {
    g.strokeStyle = 'rgba(0,0,0,0.45)'
    g.lineWidth = 4
    g.beginPath()
    g.arc(x + s / 2, y + s / 2, s * 0.3, 0, TAU)
    g.stroke()
    g.strokeStyle = 'rgba(255,255,255,0.05)'
    g.lineWidth = 2
    g.beginPath()
    g.arc(x + s / 2, y + s / 2, s * 0.26, 0, TAU)
    g.stroke()
  } else if (kind === 2) {
    g.fillStyle = 'rgba(0,0,0,0.25)'
    g.fillRect(x + s * 0.1, y + s * 0.42, s * 0.8, s * 0.16)
  }
  if (h % 3 !== 0) {
    for (const [bx, by] of [[0.09, 0.09], [0.91, 0.09], [0.09, 0.91], [0.91, 0.91]]) {
      g.fillStyle = '#3a414e'
      g.beginPath()
      g.arc(x + s * bx, y + s * by, s * 0.025, 0, TAU)
      g.fill()
    }
  }
  g.strokeStyle = 'rgba(255,255,255,0.035)'
  g.lineWidth = 1.5
  for (let k = 0; k < h % 4; k++) {
    const sx = x + r() * s
    const sy = y + r() * s
    const a = r() * TAU
    const len = s * (0.1 + r() * 0.3)
    g.beginPath()
    g.moveTo(sx, sy)
    g.lineTo(sx + Math.cos(a) * len, sy + Math.sin(a) * len)
    g.stroke()
  }
}

function buildFloor() {
  const W = ARENA.w + BORDER * 2
  const H = ARENA.h + BORDER * 2
  const c = document.createElement('canvas')
  c.width = W * PPM
  c.height = H * PPM
  const g = c.getContext('2d')
  const P = m => m * PPM
  const A = m => (m + BORDER) * PPM
  g.fillStyle = '#090c11'
  g.fillRect(0, 0, c.width, c.height)
  g.strokeStyle = 'rgba(255,255,255,0.025)'
  g.lineWidth = 3
  for (let i = -H; i < W; i += 0.6) {
    g.beginPath()
    g.moveTo(P(i), 0)
    g.lineTo(P(i + H), P(H))
    g.stroke()
  }
  const ring = o => arenaCorners(o).forEach((p, i) => (i ? g.lineTo(A(p.x), A(p.y)) : g.moveTo(A(p.x), A(p.y))))
  g.save()
  g.beginPath()
  ring(1)
  ring(0)
  g.clip('evenodd')
  g.fillStyle = '#16130a'
  g.fillRect(0, 0, c.width, c.height)
  g.fillStyle = 'rgba(230,180,40,0.5)'
  for (let i = -H; i < W + H; i += 1) {
    g.beginPath()
    g.moveTo(P(i), 0)
    g.lineTo(P(i + 0.5), 0)
    g.lineTo(P(i + 0.5 + H), P(H))
    g.lineTo(P(i + H), P(H))
    g.closePath()
    g.fill()
  }
  g.restore()
  g.save()
  g.beginPath()
  ring(0)
  g.clip()
  for (let i = 0; i < ARENA.w / 2; i++) for (let j = 0; j < ARENA.h / 2; j++) plate(g, A(i * 2), A(j * 2), P(2), tileHash(i, j))
  const tint = g.createLinearGradient(A(0), 0, A(ARENA.w), 0)
  tint.addColorStop(0, 'rgba(255,122,47,0.08)')
  tint.addColorStop(0.5, 'rgba(0,0,0,0)')
  tint.addColorStop(1, 'rgba(79,157,255,0.08)')
  g.fillStyle = tint
  g.fillRect(A(0), A(0), P(ARENA.w), P(ARENA.h))
  g.fillStyle = 'rgba(255,255,255,0.07)'
  for (let y = 0.3; y < ARENA.h; y += 1.2) g.fillRect(A(ARENA.w / 2) - P(0.04), A(y), P(0.08), P(0.6))
  g.strokeStyle = 'rgba(255,255,255,0.08)'
  g.lineWidth = P(0.08)
  g.beginPath()
  g.arc(A(ARENA.w / 2), A(ARENA.h / 2), P(2.4), 0, TAU)
  g.stroke()
  g.beginPath()
  for (let k = 0; k <= 6; k++) {
    const a = (k / 6) * TAU + Math.PI / 6
    g.lineTo(A(ARENA.w / 2) + Math.cos(a) * P(1.4), A(ARENA.h / 2) + Math.sin(a) * P(1.4))
  }
  g.stroke()
  SPAWNS.forEach((p, i) => {
    g.fillStyle = rgba(TEAM[i], 0.08)
    g.strokeStyle = rgba(TEAM[i], 0.45)
    g.lineWidth = P(0.07)
    g.beginPath()
    g.arc(A(p.x), A(p.y), P(1.2), 0, TAU)
    g.fill()
    g.stroke()
    g.beginPath()
    g.arc(A(p.x), A(p.y), P(0.8), 0, TAU)
    g.stroke()
    const dir = i === 0 ? 1 : -1
    g.lineWidth = P(0.12)
    for (let k = 0; k < 3; k++) {
      const cx = A(p.x + dir * (1.8 + k * 0.6))
      g.strokeStyle = rgba(TEAM[i], 0.3 - k * 0.08)
      g.beginPath()
      g.moveTo(cx - P(0.25 * dir), A(p.y - 0.35))
      g.lineTo(cx, A(p.y))
      g.lineTo(cx - P(0.25 * dir), A(p.y + 0.35))
      g.stroke()
    }
  })
  g.restore()
  g.lineJoin = 'round'
  g.strokeStyle = '#2c3442'
  g.lineWidth = P(0.3)
  g.beginPath()
  ring(0.15)
  g.closePath()
  g.stroke()
  g.strokeStyle = 'rgba(255,255,255,0.14)'
  g.lineWidth = P(0.05)
  g.beginPath()
  ring(0)
  g.closePath()
  g.stroke()
  return c
}

function floor(ctx, { X, Y, S }) {
  floorCache ??= buildFloor()
  ctx.drawImage(floorCache, X(-BORDER), Y(-BORDER), (ARENA.w + BORDER * 2) * S, (ARENA.h + BORDER * 2) * S)
}

function lights(ctx, state, { X, Y, S }) {
  SPAWNS.forEach((p, i) => glow(ctx, X(p.x), Y(p.y), 4 * S, TEAM[i], 0.09))
  for (const p of PILLARS) glow(ctx, X(p.x), Y(p.y), 3.2 * S, [110, 200, 255], 0.07)
  for (const m of state.mechs) if (!m.ko) glow(ctx, X(m.x), Y(m.y), 2.2 * S, TEAM[m.id], 0.14)
  for (const s of state.shots) glow(ctx, X(s.x), Y(s.y), 1.4 * S, s.reflected ? [255, 255, 255] : SHOT[s.owner], 0.12)
}

function edgeLights(ctx, { X, Y, S, now }) {
  const dot = (x, y, i, c) => {
    const a = 0.35 + 0.3 * Math.sin(now / 320 + i * 0.7)
    glow(ctx, X(x), Y(y), 0.5 * S, c, a * 0.6)
    circle(ctx, X(x), Y(y), 0.07 * S, rgba(c, 0.5 + a))
  }
  const mid = arenaCorners(0.5)
  mid.forEach((q, i) => {
    const p = mid[(i + mid.length - 1) % mid.length]
    const len = Math.hypot(q.x - p.x, q.y - p.y)
    for (let d = 1; d < len; d += 2) {
      const x = p.x + ((q.x - p.x) * d) / len
      const y = p.y + ((q.y - p.y) * d) / len
      dot(x, y, x + y, x < ARENA.w / 2 ? TEAM[0] : TEAM[1])
    }
  })
}

function decal(ctx, d, { X, Y, S }) {
  if (d.kind === 'scorch') {
    const g = ctx.createRadialGradient(X(d.x), Y(d.y), 0, X(d.x), Y(d.y), d.r * S)
    g.addColorStop(0, 'rgba(0,0,0,0.6)')
    g.addColorStop(0.6, 'rgba(10,6,4,0.35)')
    g.addColorStop(1, 'rgba(0,0,0,0)')
    ctx.fillStyle = g
    ctx.beginPath()
    ctx.arc(X(d.x), Y(d.y), d.r * S, 0, TAU)
    ctx.fill()
  } else if (d.kind === 'mark') {
    circle(ctx, X(d.x), Y(d.y), d.r * S, 'rgba(0,0,0,0.45)')
    circle(ctx, X(d.x), Y(d.y), d.r * 0.45 * S, 'rgba(255,170,90,0.15)')
  } else if (d.kind === 'line') {
    ctx.save()
    ctx.lineCap = 'round'
    ctx.strokeStyle = 'rgba(0,0,0,0.45)'
    ctx.lineWidth = 0.7 * S
    ctx.beginPath()
    ctx.moveTo(X(d.x1), Y(d.y1))
    ctx.lineTo(X(d.x2), Y(d.y2))
    ctx.stroke()
    ctx.strokeStyle = 'rgba(255,110,60,0.12)'
    ctx.lineWidth = 0.15 * S
    ctx.stroke()
    ctx.restore()
  } else if (d.kind === 'chunk') {
    ctx.save()
    ctx.translate(X(d.x), Y(d.y))
    ctx.rotate(d.rot)
    ctx.fillStyle = rgba(shade(d.rgb, 0.5))
    ctx.fillRect(-d.size * S * 0.5, -d.size * S * 0.3, d.size * S, d.size * S * 0.6)
    ctx.restore()
  }
}

function pillar(ctx, p, { X, Y, S, now }) {
  const x = X(p.x)
  const y = Y(p.y)
  const r = p.r * S
  ctx.fillStyle = 'rgba(0,0,0,0.5)'
  ctx.beginPath()
  ctx.ellipse(x + 0.3 * S, y + 0.45 * S, r * 1.05, r, 0, 0, TAU)
  ctx.fill()
  circle(ctx, x, y, r, '#191d25', '#4a5468', 0.08 * S)
  const g = ctx.createRadialGradient(x - r * 0.35, y - r * 0.4, r * 0.1, x, y, r * 0.86)
  g.addColorStop(0, '#68758c')
  g.addColorStop(0.6, '#323a48')
  g.addColorStop(1, '#1c2029')
  circle(ctx, x, y, r * 0.86, g)
  ctx.strokeStyle = 'rgba(0,0,0,0.35)'
  ctx.lineWidth = 0.04 * S
  ctx.beginPath()
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * TAU
    ctx.moveTo(x + Math.cos(a) * r * 0.42, y + Math.sin(a) * r * 0.42)
    ctx.lineTo(x + Math.cos(a) * r * 0.86, y + Math.sin(a) * r * 0.86)
  }
  ctx.stroke()
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * TAU + Math.PI / 6
    circle(ctx, x + Math.cos(a) * r * 0.93, y + Math.sin(a) * r * 0.93, 0.05 * S, '#5a6578')
  }
  const pulse = 0.5 + 0.5 * Math.sin(now / 600 + p.x)
  glow(ctx, x, y, 0.95 * S, [120, 210, 255], 0.25 + 0.2 * pulse)
  circle(ctx, x, y, 0.24 * S, '#0e1a22', 'rgba(140,220,255,0.9)', 0.05 * S)
  circle(ctx, x, y, 0.1 * S, 'rgba(190,240,255,0.95)')
}

function shadow(ctx, m, { X, Y, S }) {
  ctx.fillStyle = 'rgba(0,0,0,0.42)'
  ctx.beginPath()
  ctx.ellipse(X(m.x) + 0.14 * S, Y(m.y) + 0.24 * S, MECH_R * S * 1.08, MECH_R * S * 0.92, 0, 0, TAU)
  ctx.fill()
}

function target(m, range) {
  const d = Math.min(range, Math.hypot(m.tx - m.x, m.ty - m.y))
  const a = Math.atan2(m.ty - m.y, m.tx - m.x)
  return clampArena(m.x + Math.cos(a) * d, m.y + Math.sin(a) * d)
}

function telegraph(ctx, m, v) {
  const { X, Y, S, u, now } = v
  const a = m.act
  if (!(a?.k === 'ult' && a.ph === 'wind')) return
  const h = ult(m)
  if (h.kind !== 'lance') {
    const p = 1 - a.t / h.windup
    const c = ULT_C[h.kind]
    const r = h.kind === 'emp' || h.kind === 'meltdown' ? h.radius : h.kind === 'mines' ? h.ring : MECH_R * 2.2
    circle(ctx, X(m.x), Y(m.y), r * S, rgba(c, 0.05 + 0.1 * p), rgba(c, 0.4 + 0.5 * p), 2 * u)
    circle(ctx, X(m.x), Y(m.y), r * S * p, rgba(c, 0.1))
    ctx.save()
    ctx.setLineDash([8 * u, 6 * u])
    ctx.lineDashOffset = -now / 20
    ctx.strokeStyle = rgba(c, 0.5 + 0.5 * p)
    ctx.lineWidth = 2 * u
    if (['orbital', 'stasis', 'well', 'blink'].includes(h.kind)) {
      const at = target(m, h.range)
      circle(ctx, X(at.x), Y(at.y), (h.kind === 'blink' ? 1.2 : h.radius) * S, rgba(c, 0.08 + 0.12 * p), rgba(c, 0.6 + 0.4 * p), 2 * u)
    } else if (h.kind === 'rail' || h.kind === 'wall') {
      const fx = Math.cos(m.aim)
      const fy = Math.sin(m.aim)
      ctx.beginPath()
      if (h.kind === 'rail') {
        ctx.moveTo(X(m.x + fx * MECH_R), Y(m.y + fy * MECH_R))
        ctx.lineTo(X(m.x + fx * h.length), Y(m.y + fy * h.length))
      } else {
        const cx = m.x + fx * h.dist
        const cy = m.y + fy * h.dist
        ctx.moveTo(X(cx - (fy * h.len) / 2), Y(cy + (fx * h.len) / 2))
        ctx.lineTo(X(cx + (fy * h.len) / 2), Y(cy - (fx * h.len) / 2))
      }
      ctx.stroke()
    }
    ctx.restore()
    return
  }
  const p = 1 - a.t / LANCE.windup
  const hw = LANCE.halfWidth * S
  const len = LANCE.length * S
  const x0 = MECH_R * S
  ctx.save()
  ctx.translate(X(m.x), Y(m.y))
  ctx.rotate(a.angle)
  const g = ctx.createLinearGradient(x0, 0, x0 + len, 0)
  g.addColorStop(0, `rgba(255,60,50,${0.16 + 0.22 * p})`)
  g.addColorStop(1, 'rgba(255,60,50,0.02)')
  ctx.fillStyle = g
  ctx.fillRect(x0, -hw, len, hw * 2)
  ctx.fillStyle = 'rgba(255,130,110,0.2)'
  ctx.fillRect(x0, -hw * 0.25, len * p, hw * 0.5)
  ctx.setLineDash([10 * u, 8 * u])
  ctx.lineDashOffset = -now / 15
  ctx.strokeStyle = `rgba(255,90,80,${0.35 + 0.55 * p})`
  ctx.lineWidth = 1.5 * u
  ctx.beginPath()
  ctx.moveTo(x0, -hw)
  ctx.lineTo(x0 + len, -hw)
  ctx.moveTo(x0, hw)
  ctx.lineTo(x0 + len, hw)
  ctx.stroke()
  ctx.restore()
  glow(ctx, X(m.x + Math.cos(a.angle) * MECH_R), Y(m.y + Math.sin(a.angle) * MECH_R), (0.3 + 0.6 * p) * S, [255, 90, 70], 0.5 + 0.4 * p)
}

function ghost(ctx, g, { X, Y, S }) {
  const r = MECH_R * S
  ctx.save()
  ctx.translate(X(g.x), Y(g.y))
  ctx.rotate(g.aim)
  ctx.globalCompositeOperation = 'lighter'
  ctx.fillStyle = rgba(TEAM[g.id], 0.3 * (g.life / g.max))
  ctx.beginPath()
  ctx.ellipse(-0.05 * r, 0, 0.65 * r, 0.98 * r, 0, 0, TAU)
  ctx.fill()
  ctx.restore()
}

function slash(ctx, f, { X, Y, S }) {
  const a = f.t / 12
  const x = X(f.x)
  const y = Y(f.y)
  const from = f.a - f.arc
  const to = f.a - f.arc + 2 * f.arc * Math.min(1, (1 - a) * 2.5)
  ctx.save()
  ctx.globalCompositeOperation = 'lighter'
  ctx.lineCap = 'round'
  const c = f.blade === 'hammer' ? [140, 205, 255] : [255, 220, 160]
  for (const [k, w, al] of [[1, 0.5, 0.18], [0.92, 0.28, 0.45], [0.88, 0.08, 1]]) {
    ctx.beginPath()
    ctx.arc(x, y, f.range * k * S, from, to)
    ctx.strokeStyle = rgba(k > 0.9 ? c : [255, 255, 245], al * a)
    ctx.lineWidth = w * S
    ctx.stroke()
  }
  if (f.blade === 'drill') {
    ctx.strokeStyle = `rgba(255,240,200,${a})`
    ctx.lineWidth = 0.18 * S
    ctx.beginPath()
    ctx.moveTo(x, y)
    ctx.lineTo(x + Math.cos(f.a) * f.range * S, y + Math.sin(f.a) * f.range * S)
    ctx.stroke()
  }
  if (f.blade === 'hammer') glow(ctx, x + Math.cos(f.a) * f.range * 0.7 * S, y + Math.sin(f.a) * f.range * 0.7 * S, 1.6 * S * a, [140, 205, 255], 0.5 * a)
  ctx.restore()
}

function healPad(ctx, state, { X, Y, S, now }) {
  const x = X(HEAL.x)
  const y = Y(HEAL.y)
  const r = HEAL.radius * S
  const h = state.heal
  circle(ctx, x, y, r * 1.35, 'rgba(8,26,18,0.65)', 'rgba(90,255,150,0.4)', 0.06 * S)
  const cross = alpha => {
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(h.ready ? now / 1500 : 0)
    ctx.fillStyle = `rgba(110,255,160,${alpha})`
    ctx.fillRect(-0.45 * r, -0.14 * r, 0.9 * r, 0.28 * r)
    ctx.fillRect(-0.14 * r, -0.45 * r, 0.28 * r, 0.9 * r)
    ctx.restore()
  }
  if (h.ready) {
    const p = 0.5 + 0.5 * Math.sin(now / 250)
    glow(ctx, x, y, r * 2.4, [90, 255, 150], 0.22 + 0.15 * p)
    cross(0.85)
  } else {
    const frac = 1 - Math.min(1, h.timer / HEAL.respawn)
    ctx.strokeStyle = 'rgba(110,255,160,0.6)'
    ctx.lineWidth = 0.09 * S
    ctx.beginPath()
    ctx.arc(x, y, r * 1.15, -Math.PI / 2, -Math.PI / 2 + TAU * frac)
    ctx.stroke()
    cross(0.18)
  }
}

const upcoming = state => (state.wave.t <= PICKUP.warn ? state.wave.next : null)

function items(state, now, put) {
  const next = upcoming(state)
  state.pads.forEach((kind, i) => {
    const k = kind ?? next?.[i >> 1]
    if (k) put(k, PADS[i].x, PADS[i].y, !kind)
  })
}

function pads(ctx, state, { X, Y, S, now }) {
  const next = upcoming(state)
  state.pads.forEach((kind, i) => {
    const x = X(PADS[i].x)
    const y = Y(PADS[i].y)
    const c = ITEM_C[kind ?? next?.[i >> 1]] ?? [120, 130, 150]
    circle(ctx, x, y, S, 'rgba(10,14,20,0.6)', rgba(c, kind ? 0.75 : 0.3), Math.max(1, 0.08 * S))
    if (kind) glow(ctx, x, y, 1.7 * S, c, 0.2 + 0.08 * Math.sin(now / 200 + i))
    else if (next) circle(ctx, x, y, S * (1 - state.wave.t / PICKUP.warn), rgba(c, 0.3))
  })
}

function trapFloor(ctx, state, { X, Y, S, u, now }) {
  const blink = Math.floor(now / 80) % 2
  for (const p of TRAPS.oil.at) {
    circle(ctx, X(p.x), Y(p.y), TRAPS.oil.r * S, 'rgba(6,8,12,0.8)')
    circle(ctx, X(p.x - 0.5), Y(p.y - 0.4), TRAPS.oil.r * 0.45 * S, 'rgba(130,90,210,0.12)')
    circle(ctx, X(p.x + 0.6), Y(p.y + 0.3), TRAPS.oil.r * 0.3 * S, 'rgba(60,210,190,0.12)')
  }
  const C = TRAPS.crush
  C.at.forEach((p, i) => {
    const s = C.half * S
    const left = untilSlam(state, i)
    ctx.fillStyle = left <= C.warn ? `rgba(255,60,40,${0.3 + 0.3 * (1 - left / C.warn) * (blink ? 1 : 0.5)})` : 'rgba(30,26,14,0.9)'
    ctx.fillRect(X(p.x) - s, Y(p.y) - s, 2 * s, 2 * s)
    ctx.strokeStyle = 'rgba(230,180,40,0.75)'
    ctx.lineWidth = Math.max(1, 0.12 * S)
    ctx.strokeRect(X(p.x) - s, Y(p.y) - s, 2 * s, 2 * s)
  })
  const Z = TRAPS.tesla
  Z.at.forEach((p, i) => {
    const k = 1 - untilZap(state, i) / Z.warn
    if (k >= 0) circle(ctx, X(p.x), Y(p.y), Z.reach * S, `rgba(120,170,255,${0.06 + 0.14 * k})`, `rgba(170,210,255,${0.4 + 0.5 * k})`, Math.max(1, 1.5 * u))
  })
  const v = ventPhase(state)
  if (v?.warn || v?.burn) {
    vents(state.shrink).forEach(g => {
      if (g.wall % 2 !== v.set) return
      ctx.save()
      ctx.translate(X(g.x), Y(g.y))
      ctx.rotate(Math.atan2(g.dy, g.dx))
      ctx.fillStyle = v.burn ? 'rgba(255,150,40,0.55)' : `rgba(255,90,40,${blink ? 0.32 : 0.16})`
      ctx.fillRect(0, -HAZARDS.half * S, HAZARDS.reach * S, 2 * HAZARDS.half * S)
      ctx.restore()
    })
  }
  if (state.shrink <= 0) return
  ctx.beginPath()
  for (const o of [0, -state.shrink]) arenaCorners(o).forEach((p, i) => (i ? ctx.lineTo(X(p.x), Y(p.y)) : ctx.moveTo(X(p.x), Y(p.y))))
  ctx.fillStyle = `rgba(255,40,30,${0.16 + 0.06 * blink})`
  ctx.fill('evenodd')
}

function pylons2d(ctx, state, { X, Y, S }) {
  TRAPS.tesla.at.forEach((p, i) => {
    const warn = untilZap(state, i) <= TRAPS.tesla.warn
    if (warn) glow(ctx, X(p.x), Y(p.y), 1.4 * S, [150, 200, 255], 0.5)
    circle(ctx, X(p.x), Y(p.y), TRAPS.tesla.r * S, '#3a3f4c', warn ? '#e6f0ff' : '#6f8fc8', 0.1 * S)
  })
}

function item2d(ctx, kind, x, y, ghost, { X, Y, S, now }) {
  if (ghost && Math.floor(now / 90) % 2) return
  const c = ITEM_C[kind]
  const h = 0.8 + 0.1 * Math.sin(now / 300 + x)
  glow(ctx, X(x), Y(y - h), 0.9 * S, c, ghost ? 0.25 : 0.55)
  circle(ctx, X(x), Y(y - h), 0.32 * S, rgba(c, ghost ? 0.4 : 1), 'rgba(255,255,255,0.8)', 0.05 * S)
}

function chain(ctx, from, x1, y1, { X, Y, S }, head) {
  const x0 = X(from.x)
  const y0 = Y(from.y)
  const hx = X(x1)
  const hy = Y(y1)
  ctx.save()
  ctx.strokeStyle = 'rgba(30,34,42,0.9)'
  ctx.lineWidth = 0.14 * S
  ctx.beginPath()
  ctx.moveTo(x0, y0)
  ctx.lineTo(hx, hy)
  ctx.stroke()
  ctx.strokeStyle = '#aab3c2'
  ctx.lineWidth = 0.07 * S
  ctx.setLineDash([0.16 * S, 0.1 * S])
  ctx.stroke()
  ctx.restore()
  if (!head) return
  const a = Math.atan2(hy - y0, hx - x0)
  ctx.save()
  ctx.translate(hx, hy)
  ctx.rotate(a)
  ctx.fillStyle = '#d6dbe4'
  ctx.strokeStyle = 'rgba(0,0,0,0.7)'
  ctx.lineWidth = 0.03 * S
  ctx.beginPath()
  ctx.moveTo(0.35 * S, 0)
  ctx.lineTo(-0.1 * S, -0.28 * S)
  ctx.lineTo(0.02 * S, 0)
  ctx.lineTo(-0.1 * S, 0.28 * S)
  ctx.closePath()
  ctx.fill()
  ctx.stroke()
  ctx.restore()
  glow(ctx, hx, hy, 0.6 * S, [255, 190, 120], 0.35)
}

function chains(ctx, state, v) {
  for (const s of state.shots) if (s.kind === 'hook') chain(ctx, state.mechs[s.owner], s.x, s.y, v, true)
  for (const m of state.mechs) if (m.pull) chain(ctx, state.mechs[m.pull.by], m.x, m.y, v, false)
}

function shot(ctx, s, { X, Y, S, now }) {
  const c = s.reflected ? [255, 255, 255] : SHOT[s.owner]
  const hx = X(s.x)
  const hy = Y(s.y)
  if (s.kind === 'flame') {
    const f = 0.8 + 0.4 * Math.sin(now / 30 + s.cast * 7 + s.x * 3)
    ctx.save()
    ctx.globalCompositeOperation = 'lighter'
    glow(ctx, hx, hy, s.r * 2.6 * S * f, [255, 110, 30], 0.55)
    glow(ctx, hx, hy, s.r * 1.3 * S, [255, 210, 90], 0.7)
    ctx.restore()
    return
  }
  if (s.kind === 'missile') {
    ctx.save()
    ctx.translate(hx, hy)
    ctx.rotate(Math.atan2(s.vy, s.vx))
    glow(ctx, -0.32 * S, 0, 0.45 * S, [255, 170, 80], 0.7)
    rrect(ctx, -0.3 * S, -0.09 * S, 0.5 * S, 0.18 * S, 0.09 * S, rgba(shade(c, 0.85)), 'rgba(0,0,0,0.6)', 0.03 * S)
    circle(ctx, 0.2 * S, 0, 0.07 * S, '#ffffff')
    ctx.restore()
    return
  }
  const len = s.r < 0.25 ? 0.05 : Math.hypot(s.vx, s.vy) > 80 ? 0.15 : 0.08
  const tx = X(s.x - s.vx * len)
  const ty = Y(s.y - s.vy * len)
  ctx.save()
  ctx.globalCompositeOperation = 'lighter'
  ctx.lineCap = 'round'
  for (const [w, col, al] of [[1.4, c, 0.85], [0.45, [255, 255, 255], 0.9]]) {
    const g = ctx.createLinearGradient(tx, ty, hx, hy)
    g.addColorStop(0, rgba(col, 0))
    g.addColorStop(1, rgba(col, al))
    ctx.strokeStyle = g
    ctx.lineWidth = s.r * w * S
    ctx.beginPath()
    ctx.moveTo(tx, ty)
    ctx.lineTo(hx, hy)
    ctx.stroke()
  }
  ctx.restore()
  glow(ctx, hx, hy, s.r * 2.4 * S, c, 0.55)
  circle(ctx, hx, hy, s.r * 0.55 * S, '#ffffff')
}

function beam(ctx, f, { X, Y, S }) {
  const a = f.t / 18
  const rail = f.kind === 'rail'
  ctx.save()
  ctx.globalCompositeOperation = 'lighter'
  ctx.lineCap = 'round'
  for (const [w, c, al] of rail ? [[2.6, [60, 150, 255], 0.25], [1.4, [120, 210, 255], 0.55], [0.45, [235, 250, 255], 1]] : [[2.6, [255, 110, 60], 0.25], [1.4, [255, 180, 110], 0.55], [0.45, [255, 255, 240], 1]]) {
    ctx.strokeStyle = rgba(c, al * a)
    ctx.lineWidth = (rail ? ULTS.rail.halfWidth : LANCE.halfWidth) * w * S * (0.6 + 0.4 * a)
    ctx.beginPath()
    ctx.moveTo(X(f.x1), Y(f.y1))
    ctx.lineTo(X(f.x2), Y(f.y2))
    ctx.stroke()
  }
  ctx.restore()
  glow(ctx, X(f.x2), Y(f.y2), 1.6 * S * a, [255, 160, 90], 0.6 * a)
}

function zap(ctx, f, { X, Y, S }) {
  const a = f.t / 10
  ctx.save()
  ctx.globalCompositeOperation = 'lighter'
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  if (f.kind === 'tesla') {
    for (const [w, al] of [[0.28, 0.35], [0.09, 1]]) {
      ctx.strokeStyle = rgba(w > 0.1 ? [120, 170, 255] : [230, 240, 255], al * a)
      ctx.lineWidth = w * S
      ctx.beginPath()
      ctx.moveTo(X(f.x1), Y(f.y1))
      const n = 7
      for (let i = 1; i < n; i++) {
        const k = i / n
        const j = rand(-0.45, 0.45)
        const nx = -(f.y2 - f.y1)
        const ny = f.x2 - f.x1
        const l = Math.hypot(nx, ny) || 1
        ctx.lineTo(X(f.x1 + (f.x2 - f.x1) * k + (nx / l) * j), Y(f.y1 + (f.y2 - f.y1) * k + (ny / l) * j))
      }
      ctx.lineTo(X(f.x2), Y(f.y2))
      ctx.stroke()
    }
  } else {
    const c = SHOT[f.id]
    for (const [w, col, al] of [[0.7, c, 0.25], [0.32, [150, 240, 255], 0.6], [0.1, [255, 255, 255], 1]]) {
      ctx.strokeStyle = rgba(col, al * a)
      ctx.lineWidth = w * S * (0.5 + 0.5 * a)
      ctx.beginPath()
      ctx.moveTo(X(f.x1), Y(f.y1))
      ctx.lineTo(X(f.x2), Y(f.y2))
      ctx.stroke()
    }
  }
  ctx.restore()
}

function ground(ctx, l, { X, Y, S, u, now }) {
  const p = 1 - l.t / l.T
  const c = l.kind === 'strike' ? [255, 70, 70] : SHOT[l.owner]
  const x = X(l.x)
  const y = Y(l.y)
  circle(ctx, x, y, l.r * S, rgba(c, 0.05 + 0.12 * p), rgba(c, 0.45 + 0.5 * p * (0.8 + 0.2 * Math.sin(now / 40))), 2 * u)
  circle(ctx, x, y, l.r * S * p, rgba(c, 0.1 + 0.2 * p))
  if (l.kind !== 'strike') return
  ctx.strokeStyle = rgba(c, 0.5 + 0.5 * p)
  ctx.lineWidth = 1.5 * u
  ctx.beginPath()
  for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    ctx.moveTo(x + dx * l.r * 0.5 * S, y + dy * l.r * 0.5 * S)
    ctx.lineTo(x + dx * l.r * 1.25 * S, y + dy * l.r * 1.25 * S)
  }
  ctx.stroke()
  if (l.t < 12) {
    ctx.save()
    ctx.globalCompositeOperation = 'lighter'
    const g = ctx.createLinearGradient(x, 0, x, y)
    g.addColorStop(0, 'rgba(255,80,70,0)')
    g.addColorStop(1, `rgba(255,140,120,${0.6 * (1 - l.t / 12)})`)
    ctx.fillStyle = g
    ctx.fillRect(x - l.r * 0.35 * S, 0, l.r * 0.7 * S, y)
    ctx.restore()
  }
}

function shell(ctx, l, { X, Y, S }) {
  const k = 1 - l.t / l.T
  const x = l.sx + (l.x - l.sx) * k
  const y = l.sy + (l.y - l.sy) * k
  const h = 4 * k * (1 - k) * 3.2
  circle(ctx, X(x), Y(y), 0.22 * S, 'rgba(0,0,0,0.35)')
  const s = 0.22 * (1 + h * 0.18)
  glow(ctx, X(x), Y(y - h), s * 2.2 * S, SHOT[l.owner], 0.45)
  circle(ctx, X(x), Y(y - h), s * S, '#3a3f48', rgba(SHOT[l.owner]), 0.05 * S)
}

function mine(ctx, mi, { X, Y, S, u, now }) {
  const x = X(mi.x)
  const y = Y(mi.y)
  const armed = mi.arm <= 0
  const c = SHOT[mi.owner]
  if (armed) circle(ctx, x, y, (ULTS.mines.trigger + 0.1) * S, rgba(c, 0.04), rgba(c, 0.18), u)
  circle(ctx, x, y, 0.26 * S, '#2b3039', 'rgba(0,0,0,0.7)', 0.04 * S)
  circle(ctx, x, y, 0.16 * S, '#454c58')
  const on = !armed || Math.floor(now / (mi.life < 120 ? 90 : 260) + mi.cast) % 2 === 0
  if (on) glow(ctx, x, y, 0.3 * S, armed ? [255, 70, 50] : c, 0.8)
  circle(ctx, x, y, 0.06 * S, on ? '#ffffff' : '#5a2020')
}

function field(ctx, f, { X, Y, S, u, now }) {
  const a = Math.min(1, f.t / 30, (f.T - f.t) / 10)
  const c = ULT_C[f.kind] ?? ULT_C.stasis
  if (f.kind === 'well') circle(ctx, X(f.x), Y(f.y), f.r * S * (1 - ((now / 900) % 1)), null, rgba(c, 0.5 * a), 2 * u)
  circle(ctx, X(f.x), Y(f.y), f.r * S, rgba(c, 0.12 * a), null)
  ctx.save()
  ctx.setLineDash([12 * u, 9 * u])
  ctx.lineDashOffset = now / 25
  circle(ctx, X(f.x), Y(f.y), f.r * S, null, rgba(c, 0.75 * a), 2.5 * u)
  ctx.lineDashOffset = -now / 40
  circle(ctx, X(f.x), Y(f.y), f.r * 0.6 * S, null, rgba(c, 0.35 * a), 1.5 * u)
  ctx.restore()
}

function aura(ctx, m, { X, Y, S, u, now }) {
  if (m.ko) return
  const b = m.buffs
  const x = X(m.x)
  const y = Y(m.y)
  if (b.bubble > 0 && b.bubbleHp > 0) {
    const k = b.bubbleHp / ULTS.bubble.absorb
    const r = MECH_R * 1.75 * S * (1 + 0.03 * Math.sin(now / 120))
    const g = ctx.createRadialGradient(x, y, r * 0.6, x, y, r)
    g.addColorStop(0, 'rgba(190,120,255,0)')
    g.addColorStop(1, `rgba(190,120,255,${0.15 + 0.25 * k})`)
    circle(ctx, x, y, r, g, `rgba(220,180,255,${0.4 + 0.5 * k})`, 2 * u)
  }
  if (b.berserk > 0) glow(ctx, x, y, MECH_R * 2.4 * S, ULT_C.berserk, 0.25 + 0.1 * Math.sin(now / 70))
  if (b.overdrive > 0) {
    ctx.save()
    ctx.setLineDash([6 * u, 10 * u])
    ctx.lineDashOffset = -now / 12
    circle(ctx, x, y, MECH_R * 1.6 * S, null, rgba(ULT_C.overdrive, 0.8), 2 * u)
    ctx.restore()
  }
  if (b.jam > 0) circle(ctx, x, y, MECH_R * 1.4 * S, null, `rgba(130,220,255,${0.4 + 0.4 * Math.sin(now / 50)})`, 1.5 * u)
  if (b.deflect > 0) {
    ctx.save()
    ctx.setLineDash([4 * u, 8 * u])
    ctx.lineDashOffset = now / 10
    circle(ctx, x, y, ULTS.deflect.radius * S, rgba(ULT_C.deflect, 0.06), rgba(ULT_C.deflect, 0.7), 2 * u)
    ctx.restore()
  }
  if (b.mirror > 0) {
    ctx.save()
    ctx.globalCompositeOperation = 'lighter'
    ctx.lineCap = 'round'
    for (const [w, a] of [[0.4, 0.3], [0.12, 1]]) {
      ctx.strokeStyle = rgba(ULT_C.mirror, a)
      ctx.lineWidth = w * S
      ctx.beginPath()
      ctx.arc(x, y, MECH_R * 1.6 * S, m.aim - ULTS.mirror.arc, m.aim + ULTS.mirror.arc)
      ctx.stroke()
    }
    ctx.restore()
  }
}

function particle(ctx, p, { X, Y, S, u }) {
  const a = Math.max(0, p.life / p.max)
  const x = X(p.x)
  const y = Y(p.y)
  if (p.kind === 'spark') {
    ctx.save()
    ctx.globalCompositeOperation = 'lighter'
    ctx.strokeStyle = rgba(p.rgb, a)
    ctx.lineWidth = p.size * S
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(x, y)
    ctx.lineTo(X(p.x - p.vx * 0.035), Y(p.y - p.vy * 0.035))
    ctx.stroke()
    ctx.restore()
  } else if (p.kind === 'ember') {
    ctx.save()
    ctx.globalCompositeOperation = 'lighter'
    circle(ctx, x, y, p.size * S * 1.8, rgba(p.rgb, a * 0.9))
    ctx.restore()
  } else if (p.kind === 'casing' || p.kind === 'chunk') {
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(p.rot)
    ctx.fillStyle = rgba(p.kind === 'chunk' ? shade(p.rgb, 0.75) : p.rgb)
    ctx.fillRect(-p.size * S * 0.5, -p.size * S * (p.kind === 'chunk' ? 0.3 : 0.22), p.size * S, p.size * S * (p.kind === 'chunk' ? 0.6 : 0.44))
    ctx.restore()
  } else if (p.kind === 'smoke') {
    circle(ctx, x, y, p.size * S, rgba(p.rgb, a * 0.35))
  } else if (p.kind === 'flash') {
    glow(ctx, x, y, p.size * S, p.rgb, a)
  } else if (p.kind === 'ring') {
    circle(ctx, x, y, (p.r0 + (1 - a) * p.r1) * S, null, rgba(p.rgb, a), 3 * u)
  } else if (p.kind === 'text') {
    ctx.font = `800 ${Math.round(p.px * u)}px 'Segoe UI', system-ui, sans-serif`
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.lineWidth = 3.5 * u
    ctx.strokeStyle = `rgba(0,0,0,${Math.min(1, a * 2) * 0.85})`
    ctx.strokeText(p.text, x, y)
    ctx.fillStyle = rgba(p.rgb, Math.min(1, a * 2))
    ctx.fillText(p.text, x, y)
  }
}

const BANNER = 1200

function drawBanners(ctx, L, now) {
  for (let i = banners.length - 1; i >= 0; i--) if (now - banners[i].at > BANNER) banners.splice(i, 1)
  const u = L.u
  banners.forEach((b, n) => {
    const p = (now - b.at) / BANNER
    const enter = 1 - (1 - Math.min(1, p / 0.12)) ** 3
    const c = ULT_C[b.kind]
    const w = Math.min(L.w * 0.62, 620 * u)
    const h = 58 * u
    const sk = 18 * u
    const dir = b.id === 0 ? -1 : 1
    if (p < 0.1) {
      ctx.fillStyle = rgba(c, 0.14 * (1 - p / 0.1))
      ctx.fillRect(0, 0, L.w, L.h)
    }
    ctx.save()
    ctx.globalAlpha = p > 0.75 ? 1 - (p - 0.75) / 0.25 : 1
    ctx.translate(L.w / 2 + dir * (1 - enter) * L.w * 0.7, L.h * 0.21 + n * (h + 10 * u))
    const band = (hw, hh, fill) => {
      ctx.beginPath()
      ctx.moveTo(-hw + sk, -hh)
      ctx.lineTo(hw + sk, -hh)
      ctx.lineTo(hw - sk, hh)
      ctx.lineTo(-hw - sk, hh)
      ctx.closePath()
      ctx.fillStyle = fill
      ctx.fill()
    }
    const g = ctx.createLinearGradient(-w / 2, 0, w / 2, 0)
    g.addColorStop(0, rgba(c, 0))
    g.addColorStop(0.22, rgba(c, 0.8))
    g.addColorStop(0.78, rgba(c, 0.8))
    g.addColorStop(1, rgba(c, 0))
    band(w / 2, h / 2, g)
    band(w / 2 - 8 * u, h * 0.36, 'rgba(6,10,18,0.62)')
    ctx.fillStyle = 'rgba(255,255,255,0.22)'
    for (let k = 0; k < 6; k++) ctx.fillRect((((now * 0.9 * -dir + k * 157) % w) + w) % w - w / 2, -h * 0.36, 2 * u, h * 0.72)
    ctx.save()
    ctx.translate(dir * (w / 2 - 34 * u), 0)
    band(9 * u, h * 0.36, rgba(TEAM[b.id]))
    ctx.restore()
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.shadowColor = rgba(c)
    ctx.shadowBlur = 18 * u
    ctx.font = `900 ${Math.round(30 * u)}px 'Segoe UI', system-ui, sans-serif`
    ctx.fillStyle = '#ffffff'
    ctx.fillText(t(`u_${b.kind}`).toUpperCase(), 0, -5 * u)
    ctx.shadowBlur = 0
    ctx.font = `700 ${Math.round(11 * u)}px 'Segoe UI', system-ui, sans-serif`
    ctx.fillStyle = rgba(shade(c, 1.3))
    ctx.fillText(t(`p_${b.core}`), 0, 15 * u)
    ctx.restore()
  })
}

let vig = null

function vignette(ctx, L) {
  if (vig?.w !== L.w || vig.h !== L.h) {
    const c = document.createElement('canvas')
    c.width = Math.ceil(L.w / 8)
    c.height = Math.ceil(L.h / 8)
    const v = c.getContext('2d')
    const g = v.createRadialGradient(c.width / 2, c.height / 2, Math.min(c.width, c.height) * 0.35, c.width / 2, c.height / 2, Math.max(c.width, c.height) * 0.75)
    g.addColorStop(0, 'rgba(0,0,0,0)')
    g.addColorStop(1, 'rgba(0,0,0,0.6)')
    v.fillStyle = g
    v.fillRect(0, 0, c.width, c.height)
    vig = { c, w: L.w, h: L.h }
  }
  ctx.drawImage(vig.c, 0, 0, L.w, L.h)
}

function mech(ctx, m, v) {
  const lg = m.preview ? { phase: v.now / 220, heading: m.aim } : (legs.get(m.id) ?? { phase: 0, heading: m.aim })
  drawMech(ctx, m, v, lg, kick.get(m.id))
}
