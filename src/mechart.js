import { SHIELD, SURGE, HEAT, MECH_R, WEAPONS, ARMS, BOOSTERS, HANDS, ARM_OF, isGun } from './sim.js'
import { TAU, TEAM, TEAM_LIGHT, TEAM_DARK, SURGE_C, STEEL, rgba, shade, health, circle, rrect, glow } from './paint.js'

const EYES = [[255, 214, 120], [150, 235, 255]]
const BONE = ['#f1f2f6', '#c9ccd6']
const JOINT = '#22262e'
const INK = 'rgba(0,0,0,0.6)'

function lin(ctx, x0, y0, x1, y1, a, b) {
  const g = ctx.createLinearGradient(x0, y0, x1, y1)
  g.addColorStop(0, a)
  g.addColorStop(1, b)
  return g
}

const metal = (ctx, c, y0, y1) => lin(ctx, 0, y0, 0, y1, rgba(shade(c, 1.12)), rgba(shade(c, 0.55)))

function led(ctx, x, y, r, on, c = [125, 255, 154]) {
  if (on) glow(ctx, x, y, r * 3, c, 0.6)
  circle(ctx, x, y, r, on ? rgba(shade(c, 1.2)) : '#2a303a')
}

function crack(ctx, x, y, w, h, lw) {
  ctx.strokeStyle = 'rgba(20,10,8,0.85)'
  ctx.lineWidth = lw
  ctx.beginPath()
  ctx.moveTo(x, y)
  ctx.lineTo(x + w * 0.3, y + h * 0.5)
  ctx.lineTo(x + w * 0.55, y - h * 0.3)
  ctx.lineTo(x + w * 0.85, y + h * 0.4)
  ctx.stroke()
}

function teeth(ctx, r, n, inner) {
  ctx.beginPath()
  for (let i = 0; i < n * 2; i++) {
    const a = (i / (n * 2)) * TAU
    const rr = i % 2 ? r * inner : r
    ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr)
  }
  ctx.closePath()
}

function sawDisc(ctx, x, y, r, angle, c, busy, lw) {
  if (busy) glow(ctx, x, y, r * 2, [255, 210, 150], 0.45)
  ctx.save()
  ctx.translate(x, y)
  ctx.rotate(angle)
  teeth(ctx, r, 12, 0.8)
  ctx.fillStyle = busy ? '#f4f6fa' : rgba(shade(c, 1.05))
  ctx.fill()
  ctx.strokeStyle = INK
  ctx.lineWidth = lw
  ctx.stroke()
  circle(ctx, 0, 0, r * 0.62, null, 'rgba(0,0,0,0.25)', lw)
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * TAU
    circle(ctx, Math.cos(a) * r * 0.38, Math.sin(a) * r * 0.38, r * 0.1, 'rgba(0,0,0,0.35)')
  }
  circle(ctx, 0, 0, r * 0.2, '#2a2f38', '#d6dbe4', lw)
  ctx.restore()
}

function droop(ctx, m, part, r) {
  if (health(m, part) < 3) return
  const s = part === 'larm' ? -1 : 1
  ctx.translate(-0.06 * r, s * 0.08 * r)
  ctx.rotate(s * 0.28)
}

const LASER = [255, 80, 120]
const ARC = [190, 225, 255]
const FUEL = [214, 52, 44]
const COPPER = [214, 128, 70]
const RICO = [120, 255, 150]
const ORB = [190, 110, 255]
const BLADE = [90, 230, 255]
export const CORE_C = {
  furnace: [255, 150, 60],
  coolant: [110, 230, 255],
  reactor: [190, 255, 90],
  leech: [225, 40, 80],
  titan: [190, 202, 220],
  volt: [255, 230, 70],
  fury: [255, 64, 48],
  flywheel: [228, 232, 242],
  aegis: [90, 150, 255],
  glass: [255, 140, 210],
  phantom: [200, 220, 255],
  gravity: [150, 90, 255],
  bastion: [255, 210, 90],
  meltdown: [255, 90, 40],
  deflector: [90, 255, 230],
  mirror: [235, 245, 255],
  rail: [90, 200, 255],
  shroud: [160, 160, 175],
}

const art = (map, k) => (Object.hasOwn(map, k) ? map[k] : null)
const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t))
const ease = t => t * t * (3 - 2 * t)
const coreC = lo => art(CORE_C, lo?.core) ?? CORE_C.furnace
const hash = n => {
  const s = Math.sin(n * 91.345 + 7.13) * 43758.5453
  return s - Math.floor(s)
}

function cyl(ctx, x0, y0, x1, y1, c) {
  const g = ctx.createLinearGradient(x0, y0, x1, y1)
  g.addColorStop(0, rgba(shade(c, 0.5)))
  g.addColorStop(0.35, rgba(shade(c, 1.15)))
  g.addColorStop(1, rgba(shade(c, 0.45)))
  return g
}

function limb(ctx, pts, w, col, u) {
  ctx.save()
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  ctx.beginPath()
  pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)))
  for (const [s, lw] of [[INK, w + 2 * u], [col, w], ['rgba(255,255,255,0.2)', w * 0.3]]) {
    ctx.strokeStyle = s
    ctx.lineWidth = lw
    ctx.stroke()
  }
  ctx.restore()
}

function zap(ctx, x0, y0, x1, y1, seed, n, jit, lw, c) {
  const dx = x1 - x0
  const dy = y1 - y0
  const len = Math.hypot(dx, dy) || 1
  ctx.beginPath()
  ctx.moveTo(x0, y0)
  for (let i = 1; i < n; i++) {
    const o = (hash(seed + i * 3.7) - 0.5) * 2 * jit
    ctx.lineTo(x0 + (dx * i) / n - (dy / len) * o, y0 + (dy * i) / n + (dx / len) * o)
  }
  ctx.lineTo(x1, y1)
  ctx.save()
  ctx.globalCompositeOperation = 'lighter'
  ctx.strokeStyle = rgba(c, 0.9)
  ctx.lineWidth = lw
  ctx.stroke()
  ctx.restore()
}

function hazard(ctx, x, y, w, h, n) {
  const across = w >= h
  const step = (across ? w : h) / n
  for (let i = 0; i < n; i++) {
    ctx.fillStyle = i % 2 ? '#1b1e24' : '#e6b33a'
    if (across) ctx.fillRect(x + i * step, y, step, h)
    else ctx.fillRect(x, y + i * step, w, step)
  }
}

function tire(ctx, x, y, w, h, roll, u) {
  const along = w > h
  const len = along ? w : h
  const thick = along ? h : w
  const step = thick * 0.55
  rrect(ctx, x, y, w, h, thick * 0.45, '#16191e', INK, u)
  ctx.save()
  ctx.beginPath()
  ctx.roundRect(x, y, w, h, thick * 0.45)
  ctx.clip()
  ctx.strokeStyle = '#3b414c'
  ctx.lineWidth = thick * 0.14
  ctx.beginPath()
  const off = ((roll % step) + step) % step
  for (let d = off - step; d < len + step; d += step) {
    if (along) {
      ctx.moveTo(x + d, y)
      ctx.lineTo(x + d + thick * 0.2, y + h / 2)
      ctx.lineTo(x + d, y + h)
    } else {
      ctx.moveTo(x, y + d)
      ctx.lineTo(x + w / 2, y + d + thick * 0.2)
      ctx.lineTo(x + w, y + d)
    }
  }
  ctx.stroke()
  ctx.fillStyle = 'rgba(255,255,255,0.08)'
  if (along) ctx.fillRect(x, y + h * 0.15, w, h * 0.12)
  else ctx.fillRect(x + w * 0.15, y, w * 0.12, h)
  ctx.restore()
}

const hub = (ctx, r, u) => circle(ctx, 0, 0, 0.4 * r, '#262b35', 'rgba(255,255,255,0.08)', u)

export function reach(m, k = 'melee', b = WEAPONS[m.loadout.larm]) {
  const a = m.act
  if (a?.k !== k || !b) return 0
  if (a.ph === 'rec') return Math.min(1, a.t / (b.recovery * 0.55))
  return -Math.min(1, Math.max(0, 1 - a.t / ((a.ph === 'combo' ? b.gap : b.windup) || 1)))
}

const TOP_GUNS = {
  gatling(ctx, m, c, r, u, k, now) {
    const busy = m.act?.k === 'shoot'
    const spin = busy ? now / 22 : 0.4
    rrect(ctx, 0.04 * r - k, 0.24 * r, 0.46 * r, 0.4 * r, 0.1 * r, metal(ctx, c, 0.24 * r, 0.64 * r), INK, u)
    const bars = []
    for (let i = 0; i < 6; i++) bars.push(spin + (i / 6) * TAU)
    bars.sort((a, b) => Math.cos(a) - Math.cos(b))
    for (const a of bars) {
      const y = 0.44 * r + Math.sin(a) * 0.12 * r
      rrect(ctx, 0.46 * r - k, y - 0.04 * r, 0.66 * r, 0.08 * r, 0.03 * r, rgba(shade(c, 0.5 + 0.25 * (Math.cos(a) + 1))), INK, 0.7 * u)
    }
    for (const x of [0.62, 0.96]) rrect(ctx, x * r - k, 0.26 * r, 0.06 * r, 0.36 * r, 0.02 * r, '#1d2128', INK, 0.7 * u)
    for (let i = 0; i < 4; i++) rrect(ctx, (0.1 + i * 0.09) * r - k, 0.62 * r, 0.07 * r, 0.12 * r, 0.02 * r, '#d9b25a', INK, 0.5 * u)
    if (busy) glow(ctx, 1.16 * r - k, 0.44 * r, 0.32 * r, [255, 200, 110], 0.35 + 0.35 * hash(Math.floor(now / 30)))
  },
  flamer(ctx, m, c, r, u, k, now) {
    const h = health(m, 'rarm')
    const busy = m.act?.k === 'shoot'
    rrect(ctx, -0.26 * r, 0.66 * r, 0.54 * r, 0.24 * r, 0.12 * r, cyl(ctx, 0, 0.66 * r, 0, 0.9 * r, h === 3 ? STEEL[3] : FUEL), INK, u)
    ctx.fillStyle = '#e6b33a'
    ctx.fillRect(0.04 * r, 0.665 * r, 0.05 * r, 0.23 * r)
    ctx.strokeStyle = '#1b1e24'
    ctx.lineWidth = 0.05 * r
    ctx.beginPath()
    ctx.moveTo(0.2 * r, 0.7 * r)
    ctx.quadraticCurveTo(0.52 * r - k, 0.7 * r, 0.56 * r - k, 0.54 * r)
    ctx.stroke()
    rrect(ctx, 0.06 * r - k, 0.3 * r, 0.58 * r, 0.26 * r, 0.07 * r, metal(ctx, c, 0.3 * r, 0.56 * r), INK, u)
    ctx.beginPath()
    ctx.moveTo(0.62 * r - k, 0.33 * r)
    ctx.lineTo(1.0 * r - k, 0.27 * r)
    ctx.lineTo(1.0 * r - k, 0.59 * r)
    ctx.lineTo(0.62 * r - k, 0.53 * r)
    ctx.closePath()
    ctx.fillStyle = cyl(ctx, 0, 0.27 * r, 0, 0.59 * r, shade(c, 0.9))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.3)'
    ctx.beginPath()
    for (const x of [0.74, 0.86]) {
      const e = ((x - 0.62) / 0.38) * 0.06
      ctx.moveTo(x * r - k, (0.33 - e) * r)
      ctx.lineTo(x * r - k, (0.53 + e) * r)
    }
    ctx.stroke()
    rrect(ctx, 0.98 * r - k, 0.26 * r, 0.07 * r, 0.34 * r, 0.02 * r, '#1d2027', INK, u)
    if (h === 3) return
    const f = 0.8 + 0.2 * Math.sin(now / 45) * Math.sin(now / 71)
    glow(ctx, 1.1 * r - k, 0.43 * r, (busy ? 0.55 : 0.18) * r, busy ? [255, 150, 60] : [110, 170, 255], 0.75 * f)
    circle(ctx, 1.08 * r - k, 0.43 * r, 0.035 * r * f, busy ? '#fff0c8' : '#d6e6ff')
  },
  missiles(ctx, m, c, r, u, k) {
    const loaded = !m.cd?.shoot
    rrect(ctx, 0.02 * r - k, 0.18 * r, 0.86 * r, 0.52 * r, 0.08 * r, metal(ctx, c, 0.18 * r, 0.7 * r), INK, u)
    for (let i = 0; i < 4; i++) {
      const y = (0.235 + i * 0.11) * r
      rrect(ctx, 0.16 * r - k, y, 0.68 * r, 0.09 * r, 0.04 * r, '#1d2128', 'rgba(255,255,255,0.12)', 0.6 * u)
      if (!loaded && (i === 1 || i === 2)) continue
      ctx.fillStyle = '#eef0f4'
      ctx.fillRect(0.72 * r - k, y + 0.012 * r, 0.12 * r, 0.066 * r)
      ctx.beginPath()
      ctx.moveTo(0.84 * r - k, y + 0.005 * r)
      ctx.lineTo(0.98 * r - k, y + 0.045 * r)
      ctx.lineTo(0.84 * r - k, y + 0.085 * r)
      ctx.closePath()
      ctx.fillStyle = '#e0503c'
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = 0.6 * u
      ctx.stroke()
    }
    rrect(ctx, 0.06 * r - k, 0.18 * r, 0.07 * r, 0.52 * r, 0.02 * r, rgba(TEAM[m.id], 0.85))
    if (health(m, 'rarm') >= 1) crack(ctx, 0.3 * r - k, 0.44 * r, 0.4 * r, 0.12 * r, u)
  },
  mortar(ctx, m, c, r, u, k) {
    circle(ctx, 0.36 * r, 0.45 * r, 0.3 * r, lin(ctx, 0, 0.15 * r, 0, 0.75 * r, '#535b6b', '#1d2128'), INK, u)
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * TAU + Math.PI / 4
      circle(ctx, 0.36 * r + Math.cos(a) * 0.23 * r, 0.45 * r + Math.sin(a) * 0.23 * r, 0.03 * r, '#8a93a3')
    }
    rrect(ctx, 0.2 * r - k, 0.25 * r, 0.62 * r, 0.4 * r, 0.1 * r, cyl(ctx, 0, 0.25 * r, 0, 0.65 * r, c), INK, u)
    for (const x of [0.36, 0.6]) rrect(ctx, x * r - k, 0.24 * r, 0.05 * r, 0.42 * r, 0.02 * r, rgba(shade(c, 0.5)), INK, 0.6 * u)
    ctx.beginPath()
    ctx.ellipse(0.82 * r - k, 0.45 * r, 0.09 * r, 0.2 * r, 0, 0, TAU)
    ctx.fillStyle = '#0d0f13'
    ctx.fill()
    ctx.strokeStyle = rgba(shade(c, 1.15))
    ctx.lineWidth = 1.4 * u
    ctx.stroke()
    if (health(m, 'rarm') >= 1) crack(ctx, 0.24 * r - k, 0.4 * r, 0.3 * r, 0.1 * r, u)
  },
  laser(ctx, m, c, r, u, k, now, kickAt) {
    const h = health(m, 'rarm')
    const hot = h === 3 ? 0 : Math.max(0, 1 - (now - kickAt) / 700)
    const charge = m.act?.k === 'shoot' && m.act.ph === 'wind'
    rrect(ctx, 0.06 * r - k, 0.32 * r, 0.76 * r, 0.24 * r, 0.06 * r, cyl(ctx, 0, 0.32 * r, 0, 0.56 * r, c), INK, u)
    for (let i = 0; i < 6; i++) rrect(ctx, (0.18 + i * 0.09) * r - k, 0.24 * r, 0.04 * r, 0.4 * r, 0.015 * r, rgba(mix([58, 65, 78], [255, 130, 60], hot)), INK, 0.5 * u)
    if (hot > 0.2) glow(ctx, 0.42 * r - k, 0.44 * r, 0.5 * r, [255, 120, 50], 0.4 * hot)
    rrect(ctx, 0.8 * r - k, 0.27 * r, 0.14 * r, 0.34 * r, 0.04 * r, '#1d2128', INK, u)
    const lx = 0.95 * r - k
    if (h < 3) glow(ctx, lx, 0.44 * r, (charge ? 0.6 : 0.28) * r, LASER, charge ? 0.85 : 0.45)
    const g = ctx.createRadialGradient(lx - 0.01 * r, 0.42 * r, 0, lx, 0.44 * r, 0.12 * r)
    g.addColorStop(0, h === 3 ? '#3a2a30' : '#ffffff')
    g.addColorStop(0.4, rgba(h === 3 ? [70, 40, 50] : LASER))
    g.addColorStop(1, rgba(shade(LASER, 0.3)))
    ctx.beginPath()
    ctx.ellipse(lx, 0.44 * r, 0.05 * r, 0.12 * r, 0, 0, TAU)
    ctx.fillStyle = g
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
  },
  tesla(ctx, m, c, r, u, k, now) {
    const h = health(m, 'rarm')
    const busy = m.act?.k === 'shoot'
    rrect(ctx, 0.04 * r - k, 0.28 * r, 0.4 * r, 0.32 * r, 0.08 * r, metal(ctx, c, 0.28 * r, 0.6 * r), INK, u)
    rrect(ctx, 0.4 * r - k, 0.42 * r, 0.5 * r, 0.04 * r, 0.02 * r, '#2a2f38')
    for (let i = 0; i < 5; i++) {
      const hw = (0.15 - i * 0.014) * r
      rrect(ctx, (0.44 + i * 0.085) * r - k, 0.44 * r - hw, 0.065 * r, hw * 2, 0.03 * r, cyl(ctx, 0, 0.44 * r - hw, 0, 0.44 * r + hw, h === 3 ? STEEL[3] : COPPER), INK, 0.6 * u)
    }
    const sx = 0.94 * r - k
    if (h < 3) glow(ctx, sx, 0.44 * r, (busy ? 0.65 : 0.32) * r, ARC, busy ? 0.75 : 0.4)
    const g = ctx.createRadialGradient(sx - 0.03 * r, 0.41 * r, 0, sx, 0.44 * r, 0.1 * r)
    g.addColorStop(0, h === 3 ? '#5a606c' : '#ffffff')
    g.addColorStop(1, rgba(shade(c, 0.55)))
    circle(ctx, sx, 0.44 * r, 0.1 * r, g, INK, u)
    if (h === 3) return
    const t = Math.floor(now / 70)
    for (let i = 0; i < (busy ? 4 : 2); i++) {
      const a = hash(t * 7 + i) * TAU
      const len = (0.12 + 0.14 * hash(t * 13 + i)) * r * (busy ? 1.8 : 1)
      const ca = Math.cos(a)
      const sa = Math.sin(a)
      zap(ctx, sx + ca * 0.1 * r, 0.44 * r + sa * 0.1 * r, sx + ca * (0.1 * r + len), 0.44 * r + sa * (0.1 * r + len), t + i * 17, 4, 0.04 * r, 0.8 * u, ARC)
    }
  },
  ricochet(ctx, m, c, r, u, k) {
    const h = health(m, 'rarm')
    ctx.beginPath()
    ctx.moveTo(0.1 * r - k, 0.6 * r)
    ctx.lineTo(0.42 * r - k, 0.63 * r)
    ctx.lineTo(0.06 * r - k, 0.8 * r)
    ctx.closePath()
    ctx.fillStyle = rgba(shade(c, 0.6))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.beginPath()
    ctx.moveTo(0.06 * r - k, 0.26 * r)
    ctx.lineTo(0.66 * r - k, 0.22 * r)
    ctx.lineTo(1.04 * r - k, 0.35 * r)
    ctx.lineTo(1.04 * r - k, 0.53 * r)
    ctx.lineTo(0.66 * r - k, 0.66 * r)
    ctx.lineTo(0.06 * r - k, 0.62 * r)
    ctx.closePath()
    ctx.fillStyle = metal(ctx, c, 0.22 * r, 0.66 * r)
    ctx.fill()
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.3)'
    ctx.beginPath()
    ctx.moveTo(0.66 * r - k, 0.22 * r)
    ctx.lineTo(0.66 * r - k, 0.66 * r)
    ctx.stroke()
    rrect(ctx, 1.0 * r - k, 0.37 * r, 0.08 * r, 0.14 * r, 0.02 * r, '#1d2027', INK, u)
    if (h < 3) glow(ctx, 0.6 * r - k, 0.44 * r, 0.35 * r, RICO, 0.3)
    ctx.strokeStyle = rgba(h === 3 ? [46, 74, 54] : RICO)
    ctx.lineWidth = 0.05 * r
    ctx.beginPath()
    ctx.moveTo(0.14 * r - k, 0.44 * r)
    ctx.lineTo(0.96 * r - k, 0.44 * r)
    for (const x of [0.36, 0.5]) {
      ctx.moveTo(x * r - k, 0.34 * r)
      ctx.lineTo((x + 0.08) * r - k, 0.44 * r)
      ctx.lineTo(x * r - k, 0.54 * r)
    }
    ctx.stroke()
    if (h >= 1) crack(ctx, 0.2 * r - k, 0.32 * r, 0.36 * r, 0.1 * r, u)
  },
}

const TOP_BLADES = {
  claws(ctx, m, c, r, u, now, rc) {
    const open = Math.max(0, -rc)
    const hit = Math.max(0, rc)
    if (hit > 0.3) {
      ctx.save()
      ctx.globalCompositeOperation = 'lighter'
      ctx.strokeStyle = `rgba(255,235,220,${0.55 * hit})`
      ctx.lineWidth = 0.05 * r
      ctx.beginPath()
      for (const i of [-1, 0, 1]) {
        const cy = (-0.92 + i * 0.12) * r
        ctx.moveTo(0.1 * r + Math.cos(-0.55) * r, cy + Math.sin(-0.55) * r)
        ctx.arc(0.1 * r, cy, r, -0.55, 0.3)
      }
      ctx.stroke()
      ctx.restore()
    }
    for (const i of [-1, 0, 1]) {
      const L = (0.6 + 0.1 * hit - 0.06 * Math.abs(i)) * r
      ctx.save()
      ctx.translate(0.44 * r, (-0.92 + i * 0.1) * r)
      ctx.rotate(i * (0.12 + 0.34 * open))
      ctx.beginPath()
      ctx.moveTo(0, -0.05 * r)
      ctx.quadraticCurveTo(0.45 * L, -0.08 * r, L, 0.06 * r)
      ctx.quadraticCurveTo(0.5 * L, 0.01 * r, 0, 0.05 * r)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, 0, -0.08 * r, 0, 0.06 * r, rgba(shade(c, 1.25)), rgba(shade(c, 0.5)))
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = u
      ctx.stroke()
      ctx.restore()
    }
    rrect(ctx, 0.22 * r, -1.12 * r, 0.28 * r, 0.4 * r, 0.08 * r, metal(ctx, c, -1.12 * r, -0.72 * r), INK, u)
    for (const i of [-1, 0, 1]) circle(ctx, 0.44 * r, (-0.92 + i * 0.1) * r, 0.035 * r, '#3a414e')
  },
  whip(ctx, m, c, r, u, now, rc) {
    const e = ease(Math.max(0, rc))
    const coil = Math.max(0, -rc)
    const n = 12
    const pts = []
    for (let i = 0; i <= n; i++) {
      const s = i / n
      const rx = 0.42 + 0.3 * Math.sin(Math.PI * s) - 0.85 * s
      const ry = -0.92 - 0.32 * Math.sin(Math.PI * s) - 0.2 * s + (0.04 + 0.12 * coil) * Math.sin(now / 200 + s * 3) * s
      const ex = 0.42 + s * 2.5
      const ey = -0.92 + 0.14 * Math.sin(s * TAU * 1.25 - now / 35) * s
      pts.push([(rx + (ex - rx) * e) * r, (ry + (ey - ry) * e) * r])
    }
    ctx.strokeStyle = '#2a2f38'
    ctx.lineWidth = 0.03 * r
    ctx.beginPath()
    pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)))
    ctx.stroke()
    for (let i = 1; i < n; i++) circle(ctx, pts[i][0], pts[i][1], (0.07 - (0.025 * i) / n) * r, rgba(shade(c, i % 2 ? 0.7 : 1.05)), INK, 0.6 * u)
    const [tx, ty] = pts[n]
    ctx.save()
    ctx.translate(tx, ty)
    ctx.rotate(Math.atan2(ty - pts[n - 1][1], tx - pts[n - 1][0]))
    ctx.beginPath()
    ctx.moveTo(-0.04 * r, -0.07 * r)
    ctx.lineTo(0.2 * r, 0)
    ctx.lineTo(-0.04 * r, 0.07 * r)
    ctx.lineTo(0.03 * r, 0)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, 0, -0.07 * r, 0, 0.07 * r, rgba(shade(c, 1.25)), rgba(shade(c, 0.55)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.restore()
    if (e > 0.5) glow(ctx, tx, ty, 0.35 * r, [255, 240, 220], (e - 0.5) * 1.2)
    rrect(ctx, 0.24 * r, -1.02 * r, 0.24 * r, 0.2 * r, 0.05 * r, '#1d2128', INK, u)
    circle(ctx, 0.48 * r, -0.92 * r, 0.05 * r, rgba(TEAM[m.id]), INK, 0.6 * u)
  },
  bunker(ctx, m, c, r, u, now, rc) {
    const e = ease(Math.max(0, rc))
    const charge = Math.max(0, -rc)
    const L = (0.1 + 0.9 * e - 0.06 * charge) * r
    const x0 = 0.6 * r
    rrect(ctx, x0, -0.97 * r, L + 0.12 * r, 0.1 * r, 0.03 * r, lin(ctx, 0, -0.97 * r, 0, -0.87 * r, '#eef1f6', '#7c8492'), INK, u)
    ctx.beginPath()
    ctx.moveTo(x0 + L + 0.1 * r, -1.06 * r)
    ctx.lineTo(x0 + L + 0.38 * r, -0.92 * r)
    ctx.lineTo(x0 + L + 0.1 * r, -0.78 * r)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, 0, -1.06 * r, 0, -0.78 * r, rgba(shade(c, 1.25)), rgba(shade(c, 0.5)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    if (e > 0.5) glow(ctx, 0.74 * r, -0.92 * r, 0.55 * r, [255, 220, 160], (e - 0.5) * 1.4)
    rrect(ctx, 0.14 * r, -1.16 * r, 0.56 * r, 0.48 * r, 0.08 * r, metal(ctx, c, -1.16 * r, -0.68 * r), INK, u)
    hazard(ctx, 0.2 * r, -1.15 * r, 0.44 * r, 0.06 * r, 6)
    for (const x of [0.26, 0.36, 0.46]) rrect(ctx, x * r, -1.0 * r, 0.05 * r, 0.18 * r, 0.02 * r, rgba(mix([30, 34, 42], [255, 120, 50], charge)))
    if (charge > 0) glow(ctx, 0.38 * r, -0.91 * r, 0.45 * r, [255, 120, 50], 0.6 * charge)
    rrect(ctx, 0.66 * r, -1.1 * r, 0.08 * r, 0.36 * r, 0.02 * r, '#1d2027', INK, u)
    if (health(m, 'larm') >= 1) crack(ctx, 0.22 * r, -0.8 * r, 0.4 * r, 0.1 * r, u)
  },
  katana(ctx, m, c, r, u, now, rc) {
    const live = health(m, 'larm') < 3
    const e = Math.max(0, rc)
    const ang = -0.75 * Math.max(0, -rc) + 0.55 * ease(e)
    ctx.save()
    ctx.translate(0.4 * r, -0.92 * r)
    if (live && e > 0.2) {
      ctx.save()
      ctx.globalCompositeOperation = 'lighter'
      ctx.beginPath()
      ctx.moveTo(0, 0)
      ctx.arc(0, 0, 1.42 * r, -0.75, ang)
      ctx.closePath()
      ctx.fillStyle = rgba(BLADE, 0.2 * e)
      ctx.fill()
      ctx.restore()
    }
    ctx.rotate(ang)
    ctx.beginPath()
    ctx.moveTo(0.1 * r, -0.035 * r)
    ctx.quadraticCurveTo(0.75 * r, -0.075 * r, 1.42 * r, 0.03 * r)
    ctx.quadraticCurveTo(0.75 * r, 0.04 * r, 0.1 * r, 0.035 * r)
    ctx.closePath()
    if (live) {
      ctx.save()
      ctx.shadowColor = rgba(BLADE, 0.95)
      ctx.shadowBlur = 8 * u
      ctx.fillStyle = lin(ctx, 0, -0.06 * r, 0, 0.04 * r, '#ffffff', '#7fefff')
      ctx.fill()
      ctx.restore()
      ctx.strokeStyle = rgba(BLADE, 0.9)
    } else {
      ctx.fillStyle = '#3d5560'
      ctx.fill()
      ctx.strokeStyle = INK
    }
    ctx.lineWidth = 0.8 * u
    ctx.stroke()
    if (live) for (const x of [0.5, 1.0]) glow(ctx, x * r, 0, 0.3 * r, BLADE, 0.35)
    rrect(ctx, -0.16 * r, -0.04 * r, 0.24 * r, 0.08 * r, 0.02 * r, '#1a1d24', INK, u)
    rrect(ctx, 0.06 * r, -0.11 * r, 0.05 * r, 0.22 * r, 0.02 * r, '#c9a54a', INK, 0.8 * u)
    ctx.restore()
  },
  bash(ctx, m, c, r, u, now, rc) {
    const push = (Math.max(0, rc) * 0.32 - Math.max(0, -rc) * 0.12) * r
    const cx = -0.36 * r + push
    const cy = -0.92 * r
    rrect(ctx, 0.28 * r, cy - 0.06 * r, 0.3 * r + push, 0.12 * r, 0.03 * r, '#2a2f38', INK, u)
    ctx.beginPath()
    ctx.arc(cx, cy, 1.12 * r, -0.5, 0.5)
    ctx.arc(cx, cy, 0.86 * r, 0.5, -0.5, true)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, cx + 0.86 * r, 0, cx + 1.12 * r, 0, rgba(shade(c, 0.55)), rgba(shade(c, 1.15)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.lineWidth = 0.05 * r
    ctx.strokeStyle = rgba(TEAM[m.id], 0.9)
    ctx.beginPath()
    ctx.arc(cx, cy, 0.97 * r, -0.36, 0.36)
    ctx.stroke()
    ctx.lineWidth = 0.8 * u
    ctx.strokeStyle = 'rgba(255,255,255,0.4)'
    ctx.beginPath()
    ctx.arc(cx, cy, 1.09 * r, -0.46, 0.46)
    ctx.stroke()
    for (const a of [-0.42, 0.42]) circle(ctx, cx + Math.cos(a) * 0.98 * r, cy + Math.sin(a) * 0.98 * r, 0.035 * r, '#3a414e')
    if (health(m, 'larm') >= 1) crack(ctx, cx + 0.9 * r, cy - 0.26 * r, 0.16 * r, 0.3 * r, u)
    if (rc > 0.4) glow(ctx, cx + 1.16 * r, cy, 0.6 * r, [170, 215, 255], rc - 0.4)
  },
  fist(ctx, m, c, r, u, now, rc) {
    const e = ease(Math.max(0, rc))
    const w = Math.max(0, -rc)
    const cy = -0.92 * r
    const fx = 0.4 * r + e * 1.25 * r - w * 0.1 * r
    if (e > 0.02) {
      ctx.strokeStyle = '#1b1e24'
      ctx.lineWidth = 0.04 * r
      ctx.beginPath()
      ctx.moveTo(0.36 * r, cy)
      for (let i = 1; i <= 8; i++) ctx.lineTo(0.36 * r + ((fx - 0.36 * r) * i) / 8, cy + (i === 8 ? 0 : i % 2 ? 0.04 : -0.04) * r)
      ctx.stroke()
    }
    const fl = Math.max(e, w) * (0.85 + 0.15 * Math.sin(now / 25))
    if (health(m, 'larm') < 3 && fl > 0.05) {
      glow(ctx, fx - 0.1 * r, cy, 0.55 * r * fl, [255, 150, 60], 0.7)
      ctx.beginPath()
      ctx.moveTo(fx - 0.04 * r, cy - 0.07 * r)
      ctx.lineTo(fx - (0.1 + 0.45 * fl) * r, cy)
      ctx.lineTo(fx - 0.04 * r, cy + 0.07 * r)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, fx, 0, fx - 0.55 * r, 0, '#fff3c4', 'rgba(255,120,40,0)')
      ctx.fill()
    }
    rrect(ctx, fx - 0.07 * r, cy - 0.1 * r, 0.16 * r, 0.2 * r, 0.04 * r, '#2a2f38', INK, u)
    rrect(ctx, fx + 0.04 * r, cy - 0.24 * r, 0.4 * r, 0.48 * r, 0.12 * r, metal(ctx, c, cy - 0.24 * r, cy + 0.24 * r), INK, u)
    for (let i = 0; i < 4; i++) rrect(ctx, fx + 0.36 * r, cy + (-0.22 + i * 0.112) * r, 0.1 * r, 0.1 * r, 0.035 * r, rgba(shade(c, 1.1)), INK, 0.7 * u)
    rrect(ctx, fx + 0.14 * r, cy + 0.17 * r, 0.2 * r, 0.11 * r, 0.04 * r, rgba(shade(c, 0.8)), INK, 0.7 * u)
    rrect(ctx, fx + 0.1 * r, cy - 0.06 * r, 0.18 * r, 0.12 * r, 0.03 * r, rgba(TEAM[m.id], 0.9))
    if (health(m, 'larm') >= 1) crack(ctx, fx + 0.08 * r, cy - 0.12 * r, 0.3 * r, 0.1 * r, u)
  },
  flail(ctx, m, c, r, u, now, rc) {
    const hx = 0.44 * r
    const hy = -0.92 * r
    const w = Math.max(0, -rc)
    const e = Math.max(0, rc)
    let a = -0.9 + 0.15 * Math.sin(now / 420)
    let R = 0.62 * r
    if (w > 0) {
      a = now / 70
      R = (0.45 + 0.2 * w) * r
    } else if (e > 0) {
      a = -0.9 + 1.5 * ease(e)
      R = (0.62 + 0.38 * e) * r
    }
    const bx = hx + Math.cos(a) * R
    const by = hy + Math.sin(a) * R
    if (e > 0.3) for (let i = 1; i <= 4; i++) glow(ctx, hx + Math.cos(a - i * 0.3) * R, hy + Math.sin(a - i * 0.3) * R, 0.24 * r, [255, 235, 210], 0.4 * e * (1 - i / 5))
    rrect(ctx, 0.24 * r, hy - 0.07 * r, 0.24 * r, 0.14 * r, 0.04 * r, '#2a2f38', INK, u)
    for (let i = 1; i <= 5; i++) circle(ctx, hx + ((bx - hx) * i) / 6, hy + ((by - hy) * i) / 6, 0.035 * r, rgba(shade(c, i % 2 ? 0.7 : 1.0)), INK, 0.5 * u)
    ctx.save()
    ctx.translate(bx, by)
    ctx.rotate(now / (w || e ? 80 : 900))
    teeth(ctx, 0.25 * r, 9, 0.7)
    ctx.fillStyle = rgba(shade(c, 0.8))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.restore()
    const g = ctx.createRadialGradient(bx - 0.05 * r, by - 0.05 * r, 0.01 * r, bx, by, 0.17 * r)
    g.addColorStop(0, rgba(shade(c, 1.3)))
    g.addColorStop(1, rgba(shade(c, 0.45)))
    circle(ctx, bx, by, 0.17 * r, g, INK, u)
  },
}

const TOP_FEET = {
  spider(ctx, m, lg, c, r, u) {
    for (const side of [-1, 1]) {
      for (let i = 0; i < 3; i++) {
        const base = side * (0.62 + i * 0.95)
        const sw = Math.sin(lg.phase * 1.2 + ((i + (side > 0 ? 1 : 0)) % 2) * Math.PI) * 0.22
        const af = base - side * sw
        const ak = base - side * sw * 0.4
        const knee = [Math.cos(ak) * 0.68 * r, Math.sin(ak) * 0.68 * r]
        const foot = [Math.cos(af) * 1.1 * r, Math.sin(af) * 1.1 * r]
        limb(ctx, [[Math.cos(base) * 0.25 * r, Math.sin(base) * 0.25 * r], knee], 0.12 * r, rgba(shade(c, 0.95)), u)
        limb(ctx, [knee, foot], 0.075 * r, rgba(shade(c, 0.7)), u)
        circle(ctx, knee[0], knee[1], 0.07 * r, rgba(TEAM[m.id]), INK, u)
        circle(ctx, foot[0], foot[1], 0.045 * r, '#1b1e24')
      }
    }
    hub(ctx, r, u)
  },
  wheels(ctx, m, lg, c, r, u) {
    rrect(ctx, -0.07 * r, -0.6 * r, 0.14 * r, 1.2 * r, 0.04 * r, '#2a2f38', INK, u)
    for (const side of [-1, 1]) {
      const ty = side * 0.64 * r
      tire(ctx, -0.46 * r, ty - 0.16 * r, 0.92 * r, 0.32 * r, lg.phase * 0.5 * r, u)
      rrect(ctx, -0.22 * r, ty - 0.18 * r, 0.44 * r, 0.36 * r, 0.1 * r, metal(ctx, c, ty - 0.18 * r, ty + 0.18 * r), INK, u)
      rrect(ctx, -0.18 * r, ty + side * 0.1 * r - 0.025 * r, 0.36 * r, 0.05 * r, 0.02 * r, rgba(TEAM[m.id], 0.85))
    }
    hub(ctx, r, u)
  },
  jets(ctx, m, lg, c, r, u, now, fast) {
    const st = Math.sin(lg.phase) * 0.14 * r
    for (const side of [-1, 1]) {
      const off = side * st
      const ty = side * 0.4 * r
      const fl = (fast ? 1 : 0.35) * (0.8 + 0.2 * Math.sin(now / 30 + side))
      const tip = -(0.6 + 0.5 * fl) * r + off
      glow(ctx, -0.62 * r + off, ty, (0.25 + 0.35 * fl) * r, [120, 190, 255], 0.55)
      ctx.beginPath()
      ctx.moveTo(-0.48 * r + off, ty - 0.09 * r)
      ctx.lineTo(tip, ty)
      ctx.lineTo(-0.48 * r + off, ty + 0.09 * r)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, -0.48 * r + off, 0, tip, 0, 'rgba(235,248,255,0.95)', 'rgba(80,150,255,0)')
      ctx.fill()
      rrect(ctx, -0.44 * r + off, ty - 0.19 * r, 0.74 * r, 0.38 * r, 0.14 * r, metal(ctx, c, ty - 0.19 * r, ty + 0.19 * r), INK, u)
      rrect(ctx, -0.53 * r + off, ty - 0.13 * r, 0.12 * r, 0.26 * r, 0.04 * r, '#1b1e24', 'rgba(140,200,255,0.8)', u)
      rrect(ctx, 0.14 * r + off, ty - 0.14 * r, 0.14 * r, 0.28 * r, 0.06 * r, rgba(shade(c, 0.6)))
      ctx.fillStyle = 'rgba(0,0,0,0.3)'
      for (const x of [-0.24, -0.12]) ctx.fillRect(x * r + off, ty - 0.12 * r, 0.04 * r, 0.24 * r)
    }
    hub(ctx, r, u)
  },
  stompers(ctx, m, lg, c, r, u) {
    const mv = Math.min(1, Math.hypot(m.vx, m.vy) / 3)
    for (const side of [-1, 1]) {
      const p = lg.phase * 0.8 + (side > 0 ? Math.PI : 0)
      const k = 1 + 0.08 * Math.max(0, Math.cos(p)) * mv
      ctx.save()
      ctx.translate(Math.sin(p) * 0.2 * r, side * 0.56 * r)
      ctx.scale(k, k)
      for (const y of [-0.19, 0, 0.19]) {
        ctx.beginPath()
        ctx.moveTo(0.44 * r, (y - 0.08) * r)
        ctx.lineTo(0.66 * r, y * r)
        ctx.lineTo(0.44 * r, (y + 0.08) * r)
        ctx.closePath()
        ctx.fillStyle = '#2a2f38'
        ctx.fill()
        ctx.strokeStyle = INK
        ctx.lineWidth = u
        ctx.stroke()
      }
      rrect(ctx, -0.52 * r, -0.31 * r, 1.0 * r, 0.62 * r, 0.14 * r, metal(ctx, c, -0.31 * r, 0.31 * r), INK, u)
      hazard(ctx, -0.48 * r, -0.2 * r, 0.08 * r, 0.4 * r, 5)
      ctx.fillStyle = 'rgba(0,0,0,0.3)'
      for (const x of [-0.22, 0, 0.22]) ctx.fillRect(x * r, -0.27 * r, 0.05 * r, 0.54 * r)
      circle(ctx, 0, 0, 0.12 * r, '#1b1e24', rgba(TEAM[m.id], 0.9), u)
      ctx.restore()
    }
    hub(ctx, r, u)
  },
  skates(ctx, m, lg, c, r, u, now, fast) {
    for (const side of [-1, 1]) {
      const s = Math.sin(lg.phase * 0.7 + (side > 0 ? Math.PI : 0))
      ctx.save()
      ctx.translate(s * 0.18 * r, side * (0.46 + 0.06 * Math.max(0, s)) * r)
      ctx.rotate(side * 0.12 * Math.max(0, s))
      if (fast) glow(ctx, -0.4 * r, 0, 0.45 * r, TEAM[m.id], 0.4)
      rrect(ctx, -0.64 * r, -0.04 * r, 1.28 * r, 0.08 * r, 0.03 * r, '#2a2f38', INK, u)
      for (const x of [-0.55, -0.3, 0.3, 0.55]) rrect(ctx, (x - 0.09) * r, -0.06 * r, 0.18 * r, 0.12 * r, 0.05 * r, rgba(TEAM_LIGHT[m.id]), INK, 0.7 * u)
      rrect(ctx, -0.3 * r, -0.13 * r, 0.54 * r, 0.26 * r, 0.11 * r, metal(ctx, c, -0.13 * r, 0.13 * r), INK, u)
      ctx.fillStyle = 'rgba(0,0,0,0.35)'
      for (const x of [-0.16, -0.02]) ctx.fillRect(x * r, -0.12 * r, 0.04 * r, 0.24 * r)
      rrect(ctx, 0.12 * r, -0.1 * r, 0.12 * r, 0.2 * r, 0.06 * r, rgba(shade(c, 0.6)))
      ctx.restore()
    }
    hub(ctx, r, u)
  },
  quad(ctx, m, lg, c, r, u) {
    for (const side of [-1, 1]) {
      for (const front of [1, 0]) {
        const base = side * (front ? 0.78 : 2.3)
        const sw = Math.sin(lg.phase + ((front + (side > 0 ? 1 : 0)) % 2) * Math.PI) * 0.26
        const af = base - side * sw
        const ak = (base + af) / 2 + side * (front ? 0.18 : -0.18)
        const knee = [Math.cos(ak) * 0.74 * r, Math.sin(ak) * 0.74 * r]
        const foot = [Math.cos(af) * 1.04 * r, Math.sin(af) * 1.04 * r]
        limb(ctx, [[Math.cos(base) * 0.3 * r, Math.sin(base) * 0.3 * r], knee], 0.17 * r, rgba(shade(c, 1.0)), u)
        limb(ctx, [knee, foot], 0.11 * r, rgba(shade(c, 0.72)), u)
        circle(ctx, knee[0], knee[1], 0.09 * r, rgba(TEAM[m.id]), INK, u)
        circle(ctx, foot[0], foot[1], 0.09 * r, '#1b1e24', rgba(shade(c, 0.9)), u)
      }
    }
    hub(ctx, r, u)
  },
  mono(ctx, m, lg, c, r, u, now, fast) {
    for (const side of [-1, 1]) {
      ctx.beginPath()
      ctx.moveTo(-0.1 * r, side * 0.28 * r)
      ctx.lineTo(-0.72 * r, side * 0.74 * r)
      ctx.lineTo(-0.86 * r, side * 0.62 * r)
      ctx.lineTo(-0.52 * r, side * 0.24 * r)
      ctx.closePath()
      ctx.fillStyle = metal(ctx, c, side * 0.24 * r, side * 0.74 * r)
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = u
      ctx.stroke()
      ctx.strokeStyle = rgba(TEAM[m.id], 0.9)
      ctx.lineWidth = 0.04 * r
      ctx.beginPath()
      ctx.moveTo(-0.34 * r, side * 0.4 * r)
      ctx.lineTo(-0.74 * r, side * 0.66 * r)
      ctx.stroke()
    }
    if (fast) glow(ctx, -0.7 * r, 0, 0.5 * r, TEAM[m.id], 0.35)
    tire(ctx, -0.6 * r, -0.17 * r, 1.2 * r, 0.34 * r, lg.phase * 0.35 * r, u)
    for (const side of [-1, 1]) rrect(ctx, -0.2 * r, side * 0.2 * r - 0.06 * r, 0.4 * r, 0.12 * r, 0.04 * r, metal(ctx, c, side * 0.2 * r - 0.06 * r, side * 0.2 * r + 0.06 * r), INK, u)
    rrect(ctx, -0.07 * r, -0.26 * r, 0.14 * r, 0.52 * r, 0.04 * r, rgba(shade(c, 0.8)), INK, u)
  },
}

const TOP_HEADS = {
  crest: {
    under(ctx, m, r, u, now, charging) {
      if (charging) glow(ctx, 0.2 * r, 0, 0.7 * r, [255, 220, 80], 0.7)
      for (const side of [-1, 1]) {
        ctx.beginPath()
        ctx.moveTo(0.42 * r, side * 0.1 * r)
        ctx.quadraticCurveTo(0.1 * r, side * 0.32 * r, -0.5 * r, side * 0.56 * r)
        ctx.lineTo(-0.3 * r, side * 0.34 * r)
        ctx.quadraticCurveTo(0.06 * r, side * 0.18 * r, 0.26 * r, side * 0.02 * r)
        ctx.closePath()
        ctx.fillStyle = lin(ctx, 0.42 * r, 0, -0.5 * r, 0, '#fff1a0', '#c8901a')
        ctx.fill()
        ctx.strokeStyle = INK
        ctx.lineWidth = u
        ctx.stroke()
      }
    },
    over(ctx, m, r, u) {
      ctx.beginPath()
      ctx.moveTo(0.64 * r, 0)
      ctx.quadraticCurveTo(0.2 * r, -0.1 * r, -0.34 * r, 0)
      ctx.quadraticCurveTo(0.2 * r, 0.1 * r, 0.64 * r, 0)
      ctx.fillStyle = lin(ctx, 0, -0.08 * r, 0, 0.08 * r, '#fff1a0', '#c8901a')
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = 0.8 * u
      ctx.stroke()
    },
  },
  dish: {
    over(ctx, m, r, u, now, charging) {
      const c = STEEL[health(m, 'head')]
      if (charging) circle(ctx, 0.06 * r, 0, (0.3 + 0.6 * ((now / 300) % 1)) * r, null, rgba(ARC, 1 - ((now / 300) % 1)), 1.2 * u)
      circle(ctx, 0.06 * r, 0, 0.07 * r, '#2a2f38', INK, u)
      ctx.save()
      ctx.translate(0.06 * r, 0)
      ctx.rotate(now / (charging ? 120 : 600))
      ctx.beginPath()
      ctx.ellipse(0, 0, 0.13 * r, 0.36 * r, 0, 0, TAU)
      ctx.fillStyle = lin(ctx, -0.13 * r, 0, 0.13 * r, 0, rgba(shade(c, 1.2)), rgba(shade(c, 0.5)))
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = u
      ctx.stroke()
      ctx.beginPath()
      ctx.ellipse(0.03 * r, 0, 0.075 * r, 0.28 * r, 0, 0, TAU)
      ctx.fillStyle = 'rgba(0,0,0,0.3)'
      ctx.fill()
      ctx.strokeStyle = '#2a2f38'
      ctx.lineWidth = 1.2 * u
      ctx.beginPath()
      ctx.moveTo(0, 0)
      ctx.lineTo(0.2 * r, 0)
      ctx.stroke()
      led(ctx, 0.21 * r, 0, 0.035 * r, true, [255, 90, 80])
      ctx.restore()
    },
  },
  visor: {
    over(ctx, m, r, u, now, charging) {
      glow(ctx, 0.44 * r, 0, 0.3 * r, [255, 60, 60], charging ? 0.8 : 0.4)
      ctx.save()
      ctx.lineCap = 'round'
      ctx.beginPath()
      ctx.arc(0.3 * r, 0, 0.19 * r, -0.85, 0.85)
      ctx.strokeStyle = 'rgba(255,70,60,0.8)'
      ctx.lineWidth = 0.09 * r
      ctx.stroke()
      ctx.beginPath()
      ctx.arc(0.3 * r, 0, 0.215 * r, -0.6, 0.15)
      ctx.strokeStyle = 'rgba(255,225,215,0.6)'
      ctx.lineWidth = 0.02 * r
      ctx.stroke()
      ctx.restore()
      rrect(ctx, 0.2 * r, 0.15 * r, 0.7 * r, 0.11 * r, 0.04 * r, lin(ctx, 0, 0.15 * r, 0, 0.26 * r, '#4a5262', '#14171c'), INK, u)
      for (const x of [0.36, 0.7]) rrect(ctx, x * r, 0.135 * r, 0.06 * r, 0.14 * r, 0.02 * r, '#2a2f38', INK, 0.6 * u)
      glow(ctx, 0.92 * r, 0.205 * r, (charging ? 0.4 : 0.16) * r, [255, 60, 50], charging ? 0.9 : 0.55)
      circle(ctx, 0.91 * r, 0.205 * r, 0.04 * r, '#ff5040')
    },
  },
  medic: {
    over(ctx, m, r, u, now, charging) {
      if (charging) glow(ctx, 0.2 * r, 0, 0.6 * r, [90, 255, 140], 0.7)
      for (const side of [-1, 1]) led(ctx, 0.3 * r, side * 0.26 * r, 0.045 * r, true, side < 0 ? [255, 90, 80] : [125, 255, 154])
      const g = ctx.createRadialGradient(0.15 * r, -0.07 * r, 0.01 * r, 0.2 * r, 0, 0.21 * r)
      g.addColorStop(0, '#ffffff')
      g.addColorStop(1, '#a9b2bf')
      circle(ctx, 0.2 * r, 0, 0.2 * r, g, INK, u)
      ctx.fillStyle = charging ? '#b6ffc8' : '#3fd16a'
      ctx.fillRect(0.165 * r, -0.13 * r, 0.07 * r, 0.26 * r)
      ctx.fillRect(0.07 * r, -0.035 * r, 0.26 * r, 0.07 * r)
    },
  },
  orb: {
    over(ctx, m, r, u, now, charging) {
      const b = Math.sin(now / 320 + m.id)
      const x = -0.12 * r
      const R = (0.18 + 0.015 * b) * r
      ctx.beginPath()
      ctx.ellipse(x + (0.06 + 0.03 * b) * r, (0.06 + 0.03 * b) * r, 0.13 * r, 0.1 * r, 0, 0, TAU)
      ctx.fillStyle = `rgba(0,0,0,${0.32 - 0.1 * b})`
      ctx.fill()
      glow(ctx, x, 0, R * 3, ORB, charging ? 0.8 : 0.45)
      if (charging) circle(ctx, x, 0, R * 2.2, null, rgba(ORB, 0.6), 1.2 * u)
      const g = ctx.createRadialGradient(x - 0.04 * r, -0.04 * r, 0.01 * r, x, 0, R)
      g.addColorStop(0, '#f2dcff')
      g.addColorStop(0.45, rgba(ORB))
      g.addColorStop(1, 'rgb(70,20,120)')
      circle(ctx, x, 0, R, g, 'rgba(230,200,255,0.8)', 0.8 * u)
    },
  },
  antenna: {
    over(ctx, m, r, u, now, charging) {
      for (let i = 0; i < 3; i++) {
        const a = Math.PI + (i - 1) * 0.55 + 0.06 * Math.sin(now / 380 + i * 2)
        const L = (i === 1 ? 0.82 : 0.62) * r
        const x1 = 0.26 * r + Math.cos(a) * L
        const y1 = Math.sin(a) * L
        ctx.strokeStyle = INK
        ctx.lineWidth = 0.065 * r
        ctx.beginPath()
        ctx.moveTo(0.26 * r, 0)
        ctx.lineTo(x1, y1)
        ctx.stroke()
        ctx.strokeStyle = '#8a93a3'
        ctx.lineWidth = 0.035 * r
        ctx.stroke()
        led(ctx, x1, y1, 0.05 * r, charging || Math.sin(now / 260 + i * 2.1) > 0.3, i === 1 ? [255, 90, 80] : [125, 255, 154])
      }
      circle(ctx, 0.26 * r, 0, 0.07 * r, '#2a2f38', INK, u)
    },
  },
  dispenser: {
    over(ctx, m, r, u, now, charging) {
      const c = STEEL[health(m, 'head')]
      const open = charging ? 1 : 0
      rrect(ctx, -0.16 * r, -0.26 * r, 0.44 * r, 0.52 * r, 0.06 * r, metal(ctx, c, -0.26 * r, 0.26 * r), INK, u)
      rrect(ctx, -0.1 * r, -0.18 * r, 0.3 * r, 0.36 * r, 0.03 * r, '#14171c', INK, 0.7 * u)
      if (open) led(ctx, 0.05 * r, 0, 0.06 * r, true, [255, 80, 60])
      ctx.save()
      ctx.beginPath()
      ctx.rect(-0.1 * r, -0.18 * r, 0.3 * r, 0.36 * r)
      ctx.clip()
      hazard(ctx, -0.1 * r - open * 0.2 * r, -0.18 * r, 0.3 * r, 0.36 * r, 6)
      ctx.restore()
      led(ctx, 0.24 * r, -0.22 * r, 0.03 * r, true, [255, 200, 80])
    },
  },
  demon: {
    under(ctx, m, r, u, now, charging) {
      if (charging) glow(ctx, 0.5 * r, 0, 0.7 * r, [255, 40, 30], 0.8)
      for (const side of [-1, 1]) {
        ctx.beginPath()
        ctx.moveTo(0.22 * r, side * 0.13 * r)
        ctx.quadraticCurveTo(0.32 * r, side * 0.58 * r, 0.98 * r, side * 0.5 * r)
        ctx.quadraticCurveTo(0.5 * r, side * 0.36 * r, 0.42 * r, side * 0.06 * r)
        ctx.closePath()
        ctx.fillStyle = lin(ctx, 0.22 * r, 0, 0.98 * r, 0, charging ? '#ff8a6a' : '#e0352a', '#2a0606')
        ctx.fill()
        ctx.strokeStyle = INK
        ctx.lineWidth = u
        ctx.stroke()
      }
    },
  },
}
const headKind = k => (k === 'pincer' || Object.hasOwn(TOP_HEADS, k) ? k : 'horn')

function legs(ctx, m, lg, r, u, now) {
  const c = STEEL[health(m, 'legs')]
  const kind = m.loadout.legs
  const fast = Math.hypot(m.vx, m.vy) > 4
  const feet = art(TOP_FEET, kind)
  if (feet) return feet(ctx, m, lg, c, r, u, now, fast)
  if (kind === 'hover') {
    glow(ctx, 0, 0, r * 1.3, [110, 220, 255], 0.28 + 0.1 * Math.sin(now / 110))
    circle(ctx, 0, 0, 0.72 * r, lin(ctx, 0, -0.7 * r, 0, 0.7 * r, rgba(shade(c, 0.8)), rgba(shade(c, 0.4))), 'rgba(140,225,255,0.9)', 1.5 * u)
    ctx.strokeStyle = 'rgba(0,0,0,0.35)'
    ctx.lineWidth = u
    ctx.beginPath()
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * TAU
      ctx.moveTo(Math.cos(a) * 0.45 * r, Math.sin(a) * 0.45 * r)
      ctx.lineTo(Math.cos(a) * 0.72 * r, Math.sin(a) * 0.72 * r)
    }
    ctx.stroke()
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * TAU + Math.PI / 4
      const px = Math.cos(a) * 0.56 * r
      const py = Math.sin(a) * 0.56 * r
      glow(ctx, px, py, 0.3 * r, [140, 235, 255], 0.6)
      circle(ctx, px, py, 0.1 * r, '#dff8ff')
    }
    return
  }
  if (kind === 'treads') {
    for (const side of [-1, 1]) {
      const ty = side * 0.46 * r
      rrect(ctx, -0.66 * r, ty - 0.2 * r, 1.32 * r, 0.4 * r, 0.18 * r, '#1f232a', INK, u)
      ctx.save()
      ctx.beginPath()
      ctx.roundRect(-0.66 * r, ty - 0.2 * r, 1.32 * r, 0.4 * r, 0.18 * r)
      ctx.clip()
      ctx.strokeStyle = rgba(shade(c, 0.6))
      ctx.lineWidth = 0.07 * r
      ctx.beginPath()
      const off = ((lg.phase * 0.35) % 0.22) * r
      for (let x = -0.7 * r + off; x < 0.7 * r; x += 0.22 * r) {
        ctx.moveTo(x, ty - 0.2 * r)
        ctx.lineTo(x, ty + 0.2 * r)
      }
      ctx.stroke()
      ctx.restore()
      for (const sx of [-0.48, 0.48]) circle(ctx, sx * r, ty, 0.12 * r, rgba(shade(c, 0.85)), INK, u)
      rrect(ctx, -0.5 * r, ty + side * 0.17 * r - 0.03 * r, r, 0.06 * r, 0.02 * r, rgba(TEAM[m.id], 0.85))
    }
    circle(ctx, 0, 0, 0.42 * r, '#262b35')
    return
  }
  const st = Math.sin(lg.phase) * 0.32 * r
  for (const side of [-1, 1]) {
    const off = side * st
    const ty = side * 0.4 * r
    if (fast) glow(ctx, -0.38 * r + off, ty, 0.3 * r, [255, 160, 70], 0.5)
    rrect(ctx, -0.34 * r + off, ty - 0.17 * r, 0.66 * r, 0.34 * r, 0.12 * r, metal(ctx, c, ty - 0.17 * r, ty + 0.17 * r), INK, u)
    rrect(ctx, 0.16 * r + off, ty - 0.13 * r, 0.16 * r, 0.26 * r, 0.06 * r, rgba(shade(c, 0.6)))
    circle(ctx, -0.34 * r + off, ty, 0.08 * r, '#1b1e24', 'rgba(255,170,90,0.7)', u)
  }
  circle(ctx, 0, 0, 0.4 * r, '#262b35', 'rgba(255,255,255,0.08)', u)
}

function forearm(ctx, m, part, r, u) {
  const c = STEEL[health(m, part)]
  const y0 = part === 'larm' ? -0.94 * r : 0.62 * r
  rrect(ctx, -0.3 * r, y0, 0.64 * r, 0.32 * r, 0.11 * r, metal(ctx, c, y0, y0 + 0.32 * r), INK, u)
  if (health(m, part) >= 1) crack(ctx, -0.24 * r, y0 + 0.16 * r, 0.5 * r, 0.1 * r, 1.1 * u)
  if (health(m, part) === 3) {
    ctx.strokeStyle = 'rgba(255,140,60,0.9)'
    ctx.lineWidth = 1.2 * u
    ctx.beginPath()
    ctx.moveTo(0.05 * r, y0 + 0.05 * r)
    ctx.lineTo(0.2 * r, y0 + 0.28 * r)
    ctx.stroke()
  }
}

function gunArm(ctx, m, r, u, kickAt, now) {
  const c = STEEL[health(m, 'rarm')]
  const k = Math.max(0, 1 - (now - kickAt) / 90) * 0.2 * r
  ctx.save()
  droop(ctx, m, 'rarm', r)
  forearm(ctx, m, 'rarm', r, u)
  const kind = m.loadout.rarm
  if (kind === 'needle') {
    for (const y of [0.33, 0.47]) rrect(ctx, 0.08 * r - k, y * r, 1.6 * r, 0.07 * r, 0.03 * r, metal(ctx, c, y * r, (y + 0.07) * r), INK, u)
    ctx.fillStyle = 'rgba(120,205,255,0.55)'
    ctx.fillRect(0.12 * r - k, 0.4 * r, 1.5 * r, 0.07 * r)
    for (const x of [0.45, 0.85, 1.25]) {
      glow(ctx, x * r - k, 0.435 * r, 0.22 * r, [120, 210, 255], 0.5)
      rrect(ctx, x * r - k - 0.04 * r, 0.3 * r, 0.08 * r, 0.27 * r, 0.02 * r, '#9fe0ff')
    }
    rrect(ctx, 0.24 * r - k, 0.15 * r, 0.5 * r, 0.13 * r, 0.05 * r, '#1d2128', INK, u)
    circle(ctx, 0.72 * r - k, 0.215 * r, 0.05 * r, '#8fdcff')
  } else if (kind === 'scatter') {
    rrect(ctx, 0.06 * r - k, 0.2 * r, 0.82 * r, 0.46 * r, 0.11 * r, metal(ctx, c, 0.2 * r, 0.66 * r), INK, u)
    ctx.fillStyle = 'rgba(0,0,0,0.25)'
    ctx.fillRect(0.12 * r - k, 0.42 * r, 0.66 * r, 0.03 * r)
    for (const y of [0.31, 0.55]) circle(ctx, 0.88 * r - k, y * r, 0.09 * r, '#14171c', rgba(shade(c, 1.1)), u)
    for (let i = 0; i < 3; i++) {
      rrect(ctx, (0.18 + i * 0.14) * r - k, 0.68 * r, 0.09 * r, 0.16 * r, 0.02 * r, '#b8402f')
      ctx.fillStyle = '#d9b25a'
      ctx.fillRect((0.18 + i * 0.14) * r - k, 0.78 * r, 0.09 * r, 0.06 * r)
    }
  } else if (art(TOP_GUNS, kind)) {
    TOP_GUNS[kind](ctx, m, c, r, u, k, now, kickAt)
  } else {
    rrect(ctx, 0.12 * r - k, 0.3 * r, 0.9 * r, 0.24 * r, 0.07 * r, metal(ctx, shade(c, 0.85), 0.3 * r, 0.54 * r), INK, u)
    rrect(ctx, 0.95 * r - k, 0.26 * r, 0.16 * r, 0.32 * r, 0.04 * r, '#1d2027', INK, u)
    ctx.strokeStyle = 'rgba(255,255,255,0.18)'
    ctx.lineWidth = u
    ctx.beginPath()
    ctx.moveTo(1.0 * r - k, 0.29 * r)
    ctx.lineTo(1.0 * r - k, 0.55 * r)
    ctx.moveTo(1.05 * r - k, 0.29 * r)
    ctx.lineTo(1.05 * r - k, 0.55 * r)
    ctx.stroke()
    circle(ctx, 0.1 * r, 0.7 * r, 0.18 * r, metal(ctx, c, 0.52 * r, 0.88 * r), INK, u)
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * TAU
      circle(ctx, 0.1 * r + Math.cos(a) * 0.12 * r, 0.7 * r + Math.sin(a) * 0.12 * r, 0.025 * r, '#3a414e')
    }
  }
  ctx.restore()
}

function meleeArm(ctx, m, r, u, now) {
  const c = STEEL[health(m, 'larm')]
  const busy = m.act?.k === 'melee'
  const kind = m.loadout.larm
  ctx.save()
  droop(ctx, m, 'larm', r)
  forearm(ctx, m, 'larm', r, u)
  if (kind === 'drill') {
    const tip = (busy ? 1.62 : 1.32) * r
    rrect(ctx, 0.24 * r, -1.1 * r, 0.12 * r, 0.38 * r, 0.03 * r, '#1d2027', INK, u)
    ctx.beginPath()
    ctx.moveTo(0.34 * r, -0.74 * r)
    ctx.lineTo(tip, -0.92 * r)
    ctx.lineTo(0.34 * r, -1.1 * r)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, 0, -1.1 * r, 0, -0.74 * r, rgba(shade(c, 1.15)), rgba(shade(c, 0.55)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.4)'
    ctx.beginPath()
    for (let i = 0; i < 5; i++) {
      const f = (now / (busy ? 35 : 220) + i / 5) % 1
      const x = 0.34 * r + f * (tip - 0.34 * r)
      const hw = 0.18 * r * (1 - f)
      ctx.moveTo(x, -0.92 * r - hw)
      ctx.lineTo(x + 0.07 * r, -0.92 * r + hw)
    }
    ctx.stroke()
    if (busy) glow(ctx, tip, -0.92 * r, 0.3 * r, [255, 230, 180], 0.7)
  } else if (kind === 'hammer') {
    rrect(ctx, 0.22 * r, -0.97 * r, 0.48 * r, 0.1 * r, 0.03 * r, '#3a414e')
    if (busy) glow(ctx, 0.84 * r, -0.92 * r, 0.9 * r, [140, 205, 255], 0.55)
    rrect(ctx, 0.64 * r, -1.22 * r, 0.42 * r, 0.62 * r, 0.07 * r, metal(ctx, c, -1.22 * r, -0.6 * r), INK, u)
    ctx.save()
    ctx.beginPath()
    ctx.rect(0.98 * r, -1.22 * r, 0.08 * r, 0.62 * r)
    ctx.clip()
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = i % 2 ? '#1b1e24' : '#e6b33a'
      ctx.fillRect(0.98 * r, -1.22 * r + i * 0.11 * r, 0.08 * r, 0.11 * r)
    }
    ctx.restore()
    for (const y of [-1.08, -0.92, -0.76]) {
      ctx.fillStyle = busy ? '#dff4ff' : 'rgba(140,205,255,0.85)'
      ctx.fillRect(0.68 * r, y * r - 0.02 * r, 0.28 * r, 0.04 * r)
    }
  } else if (art(TOP_BLADES, kind)) {
    TOP_BLADES[kind](ctx, m, c, r, u, now, reach(m))
  } else {
    ctx.strokeStyle = '#2a2f38'
    ctx.lineWidth = 0.09 * r
    ctx.beginPath()
    ctx.arc(0.56 * r, -0.94 * r, 0.4 * r, Math.PI * 0.55, Math.PI * 1.45)
    ctx.stroke()
    sawDisc(ctx, 0.56 * r, -0.94 * r, 0.32 * r, now / (busy ? 16 : 90), c, busy, u)
  }
  ctx.restore()
}

function shell(ctx, m, r, u) {
  const id = m.id
  const outline = () => {
    ctx.beginPath()
    ctx.moveTo(0.42 * r, 0)
    ctx.bezierCurveTo(0.42 * r, 0.44 * r, 0.05 * r, 0.62 * r, -0.32 * r, 0.6 * r)
    ctx.bezierCurveTo(-0.66 * r, 0.58 * r, -0.86 * r, 0.32 * r, -0.86 * r, 0)
    ctx.bezierCurveTo(-0.86 * r, -0.32 * r, -0.66 * r, -0.58 * r, -0.32 * r, -0.6 * r)
    ctx.bezierCurveTo(0.05 * r, -0.62 * r, 0.42 * r, -0.44 * r, 0.42 * r, 0)
    ctx.closePath()
  }
  const g = ctx.createRadialGradient(0, -0.25 * r, 0.05 * r, -0.15 * r, 0, 0.85 * r)
  g.addColorStop(0, rgba(TEAM_LIGHT[id]))
  g.addColorStop(0.45, rgba(TEAM[id]))
  g.addColorStop(1, rgba(TEAM_DARK[id]))
  outline()
  ctx.fillStyle = g
  ctx.fill()
  ctx.save()
  ctx.shadowColor = rgba(TEAM[id], 0.9)
  ctx.shadowBlur = 7 * u
  ctx.strokeStyle = rgba(TEAM_LIGHT[id], 0.75)
  ctx.lineWidth = 1.4 * u
  ctx.stroke()
  ctx.restore()
  ctx.strokeStyle = INK
  ctx.lineWidth = u
  ctx.stroke()
  for (const side of [-1, 1]) {
    ctx.fillStyle = 'rgba(255,255,255,0.13)'
    ctx.beginPath()
    ctx.ellipse(-0.32 * r, side * 0.3 * r, 0.36 * r, 0.12 * r, side * 0.18, 0, TAU)
    ctx.fill()
    ctx.strokeStyle = rgba(shade(TEAM_DARK[id], 0.8), 0.9)
    ctx.lineWidth = 0.07 * r
    ctx.beginPath()
    ctx.moveTo(-0.12 * r, side * 0.2 * r)
    ctx.lineTo(-0.7 * r, side * 0.42 * r)
    ctx.stroke()
  }
  ctx.strokeStyle = 'rgba(0,0,0,0.55)'
  ctx.lineWidth = 1.6 * u
  ctx.beginPath()
  ctx.moveTo(0.08 * r, 0)
  ctx.lineTo(-0.86 * r, 0)
  ctx.stroke()
  ctx.strokeStyle = 'rgba(255,255,255,0.18)'
  ctx.lineWidth = 0.6 * u
  ctx.beginPath()
  ctx.moveTo(0.08 * r, -1.2 * u)
  ctx.lineTo(-0.84 * r, -1.2 * u)
  ctx.stroke()
  ctx.beginPath()
  ctx.ellipse(0.2 * r, 0, 0.2 * r, 0.44 * r, 0, 0, TAU)
  ctx.fillStyle = rgba(shade(TEAM_DARK[id], 0.85))
  ctx.fill()
  ctx.strokeStyle = INK
  ctx.lineWidth = u
  ctx.stroke()
  const gem = coreC(m.loadout)
  glow(ctx, 0.14 * r, 0, 0.26 * r, gem, 0.7)
  circle(ctx, 0.14 * r, 0, 0.08 * r, rgba(gem), '#ffffff', 0.6 * u)
  for (const side of [-1, 1]) {
    glow(ctx, 0.18 * r, side * 0.33 * r, 0.14 * r, gem, 0.6)
    circle(ctx, 0.18 * r, side * 0.33 * r, 0.045 * r, rgba(gem), 'rgba(255,255,255,0.7)', 0.5 * u)
  }
  const vc = m.overheat > 0 ? [255, 70, 50] : m.heat >= HEAT.hot ? [255, 150, 50] : [95, 75, 65]
  const va = m.overheat > 0 ? 1 : Math.max(0.35, m.heat / HEAT.max)
  for (const side of [-1, 1]) {
    if (m.heat >= HEAT.hot || m.overheat > 0) glow(ctx, -0.84 * r, side * 0.2 * r, 0.25 * r, vc, 0.6 * va)
    rrect(ctx, -0.9 * r, side * 0.2 * r - 0.08 * r, 0.14 * r, 0.16 * r, 0.04 * r, rgba(vc, va), INK, 0.6 * u)
  }
}

const SERIES_K = { light: 0.8, standard: 1, heavy: 1.25 }

function asHand(m, hand, gun) {
  const part = gun ? 'rarm' : 'larm'
  const k = gun ? 'shoot' : 'melee'
  const act = m.act?.k === hand ? { ...m.act, k } : m.act?.k in ARM_OF ? null : m.act
  return { ...m, act, loadout: { ...m.loadout, [part]: m.loadout[hand] }, armor: { ...m.armor, [part]: m.armor[ARM_OF[hand]] }, max: { ...m.max, [part]: m.max[ARM_OF[hand]] }, cd: { ...m.cd, [k]: m.cd[hand] } }
}

function hands(ctx, m, r, u, kickAt, now) {
  for (const hand of HANDS) {
    const gun = isGun(WEAPONS[m.loadout[hand]])
    ctx.save()
    if ((hand === 'right') !== gun) ctx.scale(1, -1)
    if (gun) gunArm(ctx, asHand(m, hand, true), r, u, kickAt?.[hand] ?? -1e9, now)
    else meleeArm(ctx, asHand(m, hand, false), r, u, now)
    ctx.restore()
  }
}

function pack(ctx, m, r, u, now) {
  const b = BOOSTERS[m.loadout.booster]
  const k = SERIES_K[b.series]
  const burn = m.act?.k === 'dash' && m.act.ph === 'go'
  const ys = m.loadout.booster === 'flicker' || m.loadout.booster === 'comet' ? [0] : [-0.24, 0.24]
  for (const y of ys) {
    if (burn) glow(ctx, -1.25 * r, y * r, 0.45 * k * r, [255, 170, 70], 0.8 + 0.2 * Math.sin(now / 25))
    rrect(ctx, -1.02 * r, (y - 0.11 * k) * r, 0.26 * r, 0.22 * k * r, 0.06 * r, '#2a2f38', INK, u)
    circle(ctx, -1.03 * r, y * r, 0.07 * k * r, burn ? '#ffd9a0' : rgba(TEAM[m.id], 0.85))
  }
}

function pauldron(ctx, m, part, r, u) {
  const side = part === 'larm' ? -1 : 1
  const h = health(m, part)
  const c = h === 3 ? STEEL[3] : TEAM[m.id]
  const k = SERIES_K[ARMS[m.loadout.arms]?.series] ?? 1
  const g = ctx.createRadialGradient(0.05 * r, side * 0.56 * r, 0.02 * r, 0, side * 0.6 * r, 0.3 * k * r)
  g.addColorStop(0, rgba(shade(c, 1.35)))
  g.addColorStop(1, rgba(shade(c, 0.6)))
  ctx.beginPath()
  ctx.ellipse(-0.04 * r, side * 0.6 * r, 0.28 * k * r, 0.2 * k * r, 0, 0, TAU)
  ctx.fillStyle = g
  ctx.fill()
  ctx.strokeStyle = rgba(STEEL[h])
  ctx.lineWidth = 1.2 * u
  ctx.stroke()
  if (h >= 1) crack(ctx, -0.2 * r, side * 0.6 * r, 0.3 * r, 0.12 * r, u)
}

function head(ctx, m, r, u, now) {
  const id = m.id
  const hh = health(m, 'head')
  const charging = m.act?.k === 'ult' && m.act.ph === 'wind'
  const kind = headKind(m.loadout.head)
  if (kind === 'horn') {
    ctx.beginPath()
    ctx.moveTo(0.36 * r, -0.11 * r)
    ctx.quadraticCurveTo(0.82 * r, -0.15 * r, 1.14 * r, -0.02 * r)
    ctx.lineTo(1.12 * r, 0.03 * r)
    ctx.quadraticCurveTo(0.82 * r, 0.13 * r, 0.36 * r, 0.11 * r)
    ctx.closePath()
    ctx.fillStyle = charging ? lin(ctx, 0.36 * r, 0, 1.14 * r, 0, '#ffd2a0', '#ff4a2a') : lin(ctx, 0, -0.15 * r, 0, 0.13 * r, BONE[0], BONE[1])
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = u
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.2)'
    ctx.beginPath()
    ctx.moveTo(0.42 * r, 0)
    ctx.lineTo(1.08 * r, 0)
    ctx.stroke()
    if (charging) glow(ctx, 1.1 * r, 0, 0.4 * r, [255, 110, 70], 0.8)
  } else if (kind === 'pincer') {
    for (const side of [-1, 1]) {
      ctx.beginPath()
      ctx.moveTo(0.4 * r, side * 0.12 * r)
      ctx.bezierCurveTo(0.68 * r, side * 0.46 * r, 1.02 * r, side * 0.4 * r, 1.1 * r, side * 0.12 * r)
      ctx.lineTo(1.0 * r, side * 0.1 * r)
      ctx.lineTo(0.92 * r, side * 0.2 * r)
      ctx.bezierCurveTo(0.78 * r, side * 0.26 * r, 0.62 * r, side * 0.24 * r, 0.48 * r, side * 0.05 * r)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, 0, side * 0.05 * r, 0, side * 0.42 * r, '#4a5262', '#1d2128')
      ctx.fill()
      ctx.strokeStyle = rgba(TEAM_LIGHT[id], 0.85)
      ctx.lineWidth = u
      ctx.stroke()
    }
    if (charging) glow(ctx, 1.04 * r, 0, 0.45 * r, [140, 220, 255], 0.85)
  } else TOP_HEADS[kind].under?.(ctx, m, r, u, now, charging)
  const g = ctx.createRadialGradient(0.36 * r, -0.08 * r, 0.02 * r, 0.3 * r, 0, 0.24 * r)
  g.addColorStop(0, '#3c4352')
  g.addColorStop(1, '#14171d')
  circle(ctx, 0.3 * r, 0, 0.23 * r, g, rgba(STEEL[hh]), 1.5 * u)
  if (hh >= 1) crack(ctx, 0.16 * r, -0.06 * r, 0.26 * r, 0.1 * r, u)
  const blink = Math.sin(now / 900 + id * 3) > 0.985 ? 0.15 : 1
  for (const side of [-1, 1]) {
    glow(ctx, 0.44 * r, side * 0.09 * r, 0.14 * r, EYES[id], 0.8 * blink)
    circle(ctx, 0.44 * r, side * 0.09 * r, 0.045 * r, rgba(EYES[id], blink))
  }
  art(TOP_HEADS, kind)?.over?.(ctx, m, r, u, now, charging)
}

export function drawMech(ctx, m, { X, Y, S, u, now }, lg, kickAt) {
  const r = MECH_R * S
  const x = X(m.x)
  const y = Y(m.y)
  const id = m.id
  const fx = Math.cos(m.aim)
  const fy = Math.sin(m.aim)
  if (!m.ko && !m.preview) {
    ctx.strokeStyle = rgba(TEAM[id], 0.6)
    ctx.lineWidth = 0.07 * S
    ctx.beginPath()
    ctx.ellipse(x, y + 0.06 * r, 1.3 * r, 1.15 * r, 0, 0, TAU)
    ctx.stroke()
  }
  ctx.save()
  if (m.ko) ctx.globalAlpha = 0.45
  if (m.surge >= SURGE.max && !m.ko) glow(ctx, x, y, r * (2.1 + 0.2 * Math.sin(now / 110)), SURGE_C, 0.4)
  if (m.overheat > 0) glow(ctx, x - fx * 0.5 * r, y - fy * 0.5 * r, r * 1.6, [255, 60, 40], 0.45 + 0.2 * Math.sin(now / 50))
  else if (m.heat >= HEAT.hot) glow(ctx, x - fx * 0.5 * r, y - fy * 0.5 * r, r * 1.3, [255, 130, 40], 0.15 + (0.35 * (m.heat - HEAT.hot)) / (HEAT.max - HEAT.hot))
  ctx.translate(x, y)
  ctx.save()
  ctx.rotate(lg.heading)
  legs(ctx, m, lg, r, u, now)
  ctx.restore()
  ctx.translate(m.vx * 0.012 * S, m.vy * 0.012 * S)
  const breath = 1 + 0.015 * Math.sin(now / 260 + id * 2)
  ctx.scale(breath, breath)
  ctx.rotate(m.aim)
  pack(ctx, m, r, u, now)
  hands(ctx, m, r, u, kickAt, now)
  shell(ctx, m, r, u)
  pauldron(ctx, m, 'larm', r, u)
  pauldron(ctx, m, 'rarm', r, u)
  head(ctx, m, r, u, now)
  led(ctx, 0.02 * r, -0.6 * r, 0.06 * r, m.cd.left === 0)
  led(ctx, 0.02 * r, 0.6 * r, 0.06 * r, m.cd.right === 0)
  led(ctx, -0.62 * r, -0.08 * r, 0.05 * r, m.dashes > 0 || m.cd.dash === 0, [255, 200, 110])
  led(ctx, -0.62 * r, 0.08 * r, 0.05 * r, m.cd.shield === 0, [150, 215, 255])
  if (m.stagger > 0 && Math.floor(now / 50) % 2) circle(ctx, -0.1 * r, 0, 0.72 * r, 'rgba(255,255,255,0.5)')
  ctx.restore()
  shieldArc(ctx, m, x, y, r, S)
}

export function shieldArc(ctx, m, x, y, r, S) {
  if (m.act?.k !== 'shield' || m.act.ph !== 'up') return
  const c = m.act.t < SHIELD.perfect ? [255, 255, 255] : [150, 215, 255]
  ctx.save()
  ctx.lineCap = 'round'
  ctx.globalCompositeOperation = 'lighter'
  for (const [w, a] of [[0.36, 0.15], [0.18, 0.4], [0.06, 1]]) {
    ctx.beginPath()
    ctx.arc(x, y, r * 1.6, m.act.angle - SHIELD.arc, m.act.angle + SHIELD.arc)
    ctx.strokeStyle = rgba(c, a)
    ctx.lineWidth = w * S
    ctx.stroke()
  }
  ctx.restore()
}

const FRONT_GUNS = {
  gatling(ctx, x, side, c, id, now, lw) {
    rrect(ctx, x - 0.3, 0.86, 0.6, 0.62, 0.12, metal(ctx, c, 0.86, 1.48), INK, lw)
    const bars = []
    for (let i = 0; i < 6; i++) bars.push(0.3 + (i / 6) * TAU)
    bars.sort((a, b) => Math.cos(a) - Math.cos(b))
    for (const a of bars) {
      const bx = x + Math.sin(a) * 0.17
      rrect(ctx, bx - 0.065, 1.4, 0.13, 1.35, 0.04, cyl(ctx, bx - 0.065, 0, bx + 0.065, 0, shade(c, 0.55 + 0.25 * (Math.cos(a) + 1))), INK, lw)
    }
    for (const y of [1.75, 2.42]) rrect(ctx, x - 0.3, y, 0.6, 0.12, 0.04, '#1d2128', INK, lw)
    for (let i = 0; i < 5; i++) rrect(ctx, x + side * 0.36 - 0.08, 0.95 + i * 0.12, 0.16, 0.09, 0.02, '#d9b25a', INK, lw * 0.6)
  },
  flamer(ctx, x, side, c, id, now, lw) {
    const tx = x + side * 0.44
    rrect(ctx, tx - 0.17, 0.3, 0.34, 1.0, 0.17, cyl(ctx, tx - 0.17, 0, tx + 0.17, 0, FUEL), INK, lw)
    ctx.fillStyle = '#e6b33a'
    ctx.fillRect(tx - 0.165, 0.72, 0.33, 0.07)
    ctx.strokeStyle = '#1b1e24'
    ctx.lineWidth = 0.07
    ctx.beginPath()
    ctx.moveTo(tx, 1.28)
    ctx.quadraticCurveTo(tx, 1.62, x + side * 0.12, 1.66)
    ctx.stroke()
    rrect(ctx, x - 0.22, 0.9, 0.44, 0.8, 0.1, metal(ctx, c, 0.9, 1.7), INK, lw)
    ctx.beginPath()
    ctx.moveTo(x - 0.16, 1.68)
    ctx.lineTo(x + 0.16, 1.68)
    ctx.lineTo(x + 0.28, 2.38)
    ctx.lineTo(x - 0.28, 2.38)
    ctx.closePath()
    ctx.fillStyle = cyl(ctx, x - 0.28, 0, x + 0.28, 0, shade(c, 0.9))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.3)'
    ctx.beginPath()
    for (const y of [1.9, 2.12]) {
      const e = ((y - 1.68) / 0.7) * 0.12
      ctx.moveTo(x - 0.16 - e, y)
      ctx.lineTo(x + 0.16 + e, y)
    }
    ctx.stroke()
    ctx.beginPath()
    ctx.ellipse(x, 2.38, 0.28, 0.07, 0, 0, TAU)
    ctx.fillStyle = '#0d0f13'
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    const f = 0.8 + 0.2 * Math.sin(now / 45) * Math.sin(now / 71)
    glow(ctx, x, 2.55, 0.32, [110, 170, 255], 0.65 * f)
    ctx.beginPath()
    ctx.ellipse(x, 2.55, 0.05, 0.09 * f, 0, 0, TAU)
    ctx.fillStyle = '#d6e6ff'
    ctx.fill()
  },
  missiles(ctx, x, side, c, id, now, lw) {
    rrect(ctx, x - 0.44, 0.84, 0.88, 1.02, 0.12, metal(ctx, c, 0.84, 1.86), INK, lw)
    rrect(ctx, x - 0.4, 0.88, 0.8, 0.08, 0.03, rgba(TEAM[id], 0.85))
    for (let i = 0; i < 4; i++) {
      const tx = x + (i % 2 ? 0.2 : -0.2)
      const ty = 1.22 + (i > 1 ? 0.42 : 0)
      circle(ctx, tx, ty, 0.16, '#14171c', rgba(shade(c, 1.15)), lw)
      const g = ctx.createRadialGradient(tx - 0.04, ty - 0.04, 0.01, tx, ty, 0.11)
      g.addColorStop(0, '#ff9a80')
      g.addColorStop(1, '#a8281c')
      circle(ctx, tx, ty, 0.1, g, INK, lw * 0.6)
    }
  },
  mortar(ctx, x, side, c, id, now, lw) {
    ctx.save()
    ctx.translate(x, 1.95)
    ctx.rotate(side * 0.12)
    rrect(ctx, -0.3, -1.05, 0.6, 1.0, 0.14, cyl(ctx, -0.3, 0, 0.3, 0, c), INK, lw)
    for (const y of [-0.8, -0.42]) rrect(ctx, -0.32, y, 0.64, 0.09, 0.03, rgba(shade(c, 0.55)), INK, lw * 0.6)
    ctx.beginPath()
    ctx.ellipse(0, -1.05, 0.3, 0.1, 0, 0, TAU)
    ctx.fillStyle = '#0d0f13'
    ctx.fill()
    ctx.strokeStyle = rgba(shade(c, 1.15))
    ctx.lineWidth = lw * 1.4
    ctx.stroke()
    ctx.restore()
    ctx.beginPath()
    ctx.ellipse(x, 2.0, 0.58, 0.15, 0, 0, TAU)
    ctx.fillStyle = lin(ctx, 0, 1.85, 0, 2.15, '#5a6272', '#1d2128')
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    for (const dx of [-0.4, 0, 0.4]) circle(ctx, x + dx, 2.0, 0.04, '#8a93a3')
  },
  laser(ctx, x, side, c, id, now, lw) {
    rrect(ctx, x - 0.2, 0.9, 0.4, 1.2, 0.08, cyl(ctx, x - 0.2, 0, x + 0.2, 0, c), INK, lw)
    for (let i = 0; i < 7; i++) rrect(ctx, x - 0.36, 1.0 + i * 0.13, 0.72, 0.06, 0.02, '#3a414e', INK, lw * 0.6)
    rrect(ctx, x - 0.17, 2.05, 0.34, 0.26, 0.05, '#1d2128', INK, lw)
    glow(ctx, x, 2.38, 0.5, LASER, 0.5 + 0.15 * Math.sin(now / 200))
    const g = ctx.createRadialGradient(x - 0.03, 2.35, 0, x, 2.38, 0.14)
    g.addColorStop(0, '#ffffff')
    g.addColorStop(0.4, rgba(LASER))
    g.addColorStop(1, rgba(shade(LASER, 0.3)))
    circle(ctx, x, 2.38, 0.14, g, INK, lw)
  },
  tesla(ctx, x, side, c, id, now, lw) {
    rrect(ctx, x - 0.26, 0.88, 0.52, 0.4, 0.1, metal(ctx, c, 0.88, 1.28), INK, lw)
    rrect(ctx, x - 0.05, 1.2, 0.1, 1.1, 0.03, '#2a2f38')
    for (let i = 0; i < 6; i++) {
      const w = 0.32 - i * 0.025
      rrect(ctx, x - w, 1.3 + i * 0.15, w * 2, 0.11, 0.05, cyl(ctx, x - w, 0, x + w, 0, COPPER), INK, lw * 0.7)
    }
    glow(ctx, x, 2.38, 0.7, ARC, 0.4)
    const g = ctx.createRadialGradient(x - 0.06, 2.32, 0, x, 2.38, 0.2)
    g.addColorStop(0, '#ffffff')
    g.addColorStop(1, '#7c8492')
    circle(ctx, x, 2.38, 0.2, g, INK, lw)
    const t = Math.floor(now / 80)
    for (let i = 0; i < 3; i++) {
      const a = hash(t * 5 + i) * TAU
      const len = 0.3 + 0.25 * hash(t * 11 + i)
      const ca = Math.cos(a)
      const sa = Math.sin(a)
      zap(ctx, x + ca * 0.2, 2.38 + sa * 0.2, x + ca * (0.2 + len), 2.38 + sa * (0.2 + len), t + i * 17, 4, 0.08, lw * 1.2, ARC)
    }
  },
  ricochet(ctx, x, side, c, id, now, lw) {
    for (const s of [-1, 1]) {
      ctx.beginPath()
      ctx.moveTo(x + s * 0.28, 1.15)
      ctx.lineTo(x + s * 0.5, 0.98)
      ctx.lineTo(x + s * 0.32, 1.65)
      ctx.closePath()
      ctx.fillStyle = rgba(shade(c, 0.6))
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = lw
      ctx.stroke()
    }
    ctx.beginPath()
    ctx.moveTo(x - 0.28, 0.9)
    ctx.lineTo(x + 0.28, 0.9)
    ctx.lineTo(x + 0.32, 1.9)
    ctx.lineTo(x + 0.16, 2.5)
    ctx.lineTo(x - 0.16, 2.5)
    ctx.lineTo(x - 0.32, 1.9)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, x - 0.32, 0, x + 0.32, 0, rgba(shade(c, 1.15)), rgba(shade(c, 0.5)))
    ctx.fill()
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.35)'
    ctx.beginPath()
    ctx.moveTo(x - 0.32, 1.9)
    ctx.lineTo(x + 0.32, 1.9)
    ctx.stroke()
    rrect(ctx, x - 0.12, 2.45, 0.24, 0.12, 0.03, '#1d2027', INK, lw)
    glow(ctx, x, 1.7, 0.6, RICO, 0.3)
    ctx.strokeStyle = rgba(RICO)
    ctx.lineWidth = 0.08
    ctx.beginPath()
    ctx.moveTo(x, 1.0)
    ctx.lineTo(x, 2.4)
    for (const y of [1.3, 1.55]) {
      ctx.moveTo(x - 0.16, y)
      ctx.lineTo(x, y + 0.12)
      ctx.lineTo(x + 0.16, y)
    }
    ctx.stroke()
  },
}

const FRONT_BLADES = {
  claws(ctx, x, side, c, id, now, lw) {
    for (const i of [-1, 0, 1]) {
      const bx = x + i * 0.19
      ctx.beginPath()
      ctx.moveTo(bx - 0.08, 1.2)
      ctx.quadraticCurveTo(bx - 0.1 + i * 0.05, 1.9, bx + i * 0.14 - side * 0.12, 2.45)
      ctx.quadraticCurveTo(bx + 0.06, 1.85, bx + 0.08, 1.2)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, bx - 0.1, 0, bx + 0.1, 0, rgba(shade(c, 1.25)), rgba(shade(c, 0.5)))
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = lw
      ctx.stroke()
    }
    rrect(ctx, x - 0.34, 0.96, 0.68, 0.34, 0.1, metal(ctx, c, 0.96, 1.3), INK, lw)
    for (const i of [-1, 0, 1]) circle(ctx, x + i * 0.19, 1.13, 0.04, '#3a414e')
  },
  whip(ctx, x, side, c, id, now, lw) {
    const n = 11
    const pts = []
    for (let i = 0; i <= n; i++) {
      const s = i / n
      pts.push([x + 0.25 * Math.sin(s * TAU * 0.9 + 0.4 * Math.sin(now / 500)) * s, 1.34 + s * 1.5])
    }
    ctx.strokeStyle = '#2a2f38'
    ctx.lineWidth = 0.04
    ctx.beginPath()
    pts.forEach(([px, py], i) => (i ? ctx.lineTo(px, py) : ctx.moveTo(px, py)))
    ctx.stroke()
    for (let i = 1; i < n; i++) circle(ctx, pts[i][0], pts[i][1], 0.085 - (0.03 * i) / n, rgba(shade(c, i % 2 ? 0.7 : 1.05)), INK, lw * 0.6)
    const [tx, ty] = pts[n]
    ctx.save()
    ctx.translate(tx, ty)
    ctx.rotate(Math.atan2(ty - pts[n - 1][1], tx - pts[n - 1][0]))
    ctx.beginPath()
    ctx.moveTo(-0.05, -0.1)
    ctx.lineTo(0.3, 0)
    ctx.lineTo(-0.05, 0.1)
    ctx.lineTo(0.04, 0)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, 0, -0.1, 0, 0.1, rgba(shade(c, 1.25)), rgba(shade(c, 0.55)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    ctx.restore()
    rrect(ctx, x - 0.1, 0.98, 0.2, 0.38, 0.05, '#1d2128', INK, lw)
    circle(ctx, x, 1.36, 0.07, rgba(TEAM[id]), INK, lw * 0.6)
  },
  bunker(ctx, x, side, c, id, now, lw) {
    rrect(ctx, x - 0.07, 1.7, 0.14, 0.58, 0.03, lin(ctx, x - 0.07, 0, x + 0.07, 0, '#eef1f6', '#7c8492'), INK, lw)
    ctx.beginPath()
    ctx.moveTo(x - 0.17, 2.25)
    ctx.lineTo(x, 2.78)
    ctx.lineTo(x + 0.17, 2.25)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, x - 0.17, 0, x + 0.17, 0, rgba(shade(c, 1.25)), rgba(shade(c, 0.5)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    rrect(ctx, x - 0.38, 0.92, 0.76, 0.9, 0.12, metal(ctx, c, 0.92, 1.82), INK, lw)
    hazard(ctx, x - 0.34, 1.62, 0.68, 0.1, 7)
    for (const y of [1.08, 1.24, 1.4]) rrect(ctx, x - 0.24, y, 0.48, 0.07, 0.03, '#14171c')
    glow(ctx, x, 1.25, 0.4, [255, 120, 50], 0.2)
    rrect(ctx, x - 0.22, 1.78, 0.44, 0.1, 0.03, '#1d2027', INK, lw)
  },
  katana(ctx, x, side, c, id, now, lw) {
    for (const y of [1.8, 2.3, 2.8]) glow(ctx, x, y, 0.45, BLADE, 0.35)
    ctx.beginPath()
    ctx.moveTo(x - 0.07, 1.45)
    ctx.quadraticCurveTo(x - 0.08, 2.4, x + side * 0.14, 3.05)
    ctx.quadraticCurveTo(x + 0.08, 2.3, x + 0.07, 1.45)
    ctx.closePath()
    ctx.save()
    ctx.shadowColor = rgba(BLADE, 0.95)
    ctx.shadowBlur = 10
    ctx.fillStyle = lin(ctx, x - 0.08, 0, x + 0.08, 0, '#7fefff', '#ffffff')
    ctx.fill()
    ctx.restore()
    ctx.strokeStyle = rgba(BLADE, 0.9)
    ctx.lineWidth = lw
    ctx.stroke()
    rrect(ctx, x - 0.07, 0.98, 0.14, 0.4, 0.03, '#1a1d24', INK, lw)
    ctx.strokeStyle = 'rgba(200,210,225,0.35)'
    ctx.lineWidth = 0.025
    ctx.beginPath()
    for (const y of [1.06, 1.16, 1.26]) {
      ctx.moveTo(x - 0.06, y)
      ctx.lineTo(x + 0.06, y + 0.07)
      ctx.moveTo(x + 0.06, y)
      ctx.lineTo(x - 0.06, y + 0.07)
    }
    ctx.stroke()
    rrect(ctx, x - 0.22, 1.36, 0.44, 0.09, 0.03, '#c9a54a', INK, lw)
  },
  bash(ctx, x, side, c, id, now, lw) {
    rrect(ctx, x - 0.56, 0.2, 1.12, 2.05, 0.2, lin(ctx, x - 0.56, 0, x + 0.56, 0, rgba(shade(c, 1.15)), rgba(shade(c, 0.5))), INK, lw)
    ctx.save()
    ctx.beginPath()
    ctx.roundRect(x - 0.56, 0.2, 1.12, 2.05, 0.2)
    ctx.clip()
    hazard(ctx, x - 0.56, 2.06, 1.12, 0.19, 8)
    ctx.fillStyle = rgba(TEAM[id], 0.9)
    ctx.fillRect(x - 0.56, 1.25, 1.12, 0.12)
    ctx.restore()
    rrect(ctx, x - 0.46, 0.3, 0.92, 1.72, 0.14, null, 'rgba(255,255,255,0.18)', lw)
    rrect(ctx, x - 0.38, 0.5, 0.76, 0.18, 0.05, 'rgba(120,190,255,0.35)', INK, lw)
    rrect(ctx, x - 0.32, 0.53, 0.3, 0.04, 0.02, 'rgba(230,245,255,0.6)')
    for (const [dx, dy] of [[-0.42, 0.34], [0.42, 0.34], [-0.42, 1.9], [0.42, 1.9]]) circle(ctx, x + dx, dy, 0.04, '#3a414e')
  },
  fist(ctx, x, side, c, id, now, lw) {
    const bx = x + side * 0.42
    const f = 0.85 + 0.15 * Math.sin(now / 40)
    glow(ctx, bx, 0.12, 0.45, [255, 150, 60], 0.45 * f)
    ctx.beginPath()
    ctx.moveTo(bx - 0.11, 0.26)
    ctx.lineTo(bx, 0.26 - 0.3 * f)
    ctx.lineTo(bx + 0.11, 0.26)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, 0, 0.26, 0, -0.04, '#fff3c4', 'rgba(255,120,40,0)')
    ctx.fill()
    rrect(ctx, bx - 0.15, 0.36, 0.3, 0.95, 0.12, cyl(ctx, bx - 0.15, 0, bx + 0.15, 0, [70, 76, 88]), INK, lw)
    rrect(ctx, bx - 0.12, 0.6, 0.24, 0.06, 0.02, rgba(TEAM[id], 0.9))
    rrect(ctx, bx - 0.18, 0.24, 0.36, 0.16, 0.05, '#1b1e24', INK, lw)
    rrect(ctx, x - 0.48, 0.95, 0.96, 0.9, 0.22, metal(ctx, c, 0.95, 1.85), INK, lw)
    for (let i = 0; i < 4; i++) rrect(ctx, x - 0.47 + i * 0.235, 1.56, 0.23, 0.36, 0.09, metal(ctx, shade(c, 1.1), 1.56, 1.92), INK, lw * 0.8)
    rrect(ctx, x - side * 0.44 - 0.14, 1.12, 0.28, 0.46, 0.12, rgba(shade(c, 0.85)), INK, lw)
    rrect(ctx, x - 0.26, 1.08, 0.52, 0.26, 0.07, rgba(TEAM[id], 0.9), INK, lw * 0.6)
  },
  flail(ctx, x, side, c, id, now, lw) {
    const a = 0.18 * Math.sin(now / 520)
    const bx = x + Math.sin(a) * 1.25
    const by = 1.25 + Math.cos(a) * 1.25
    rrect(ctx, x - 0.12, 0.98, 0.24, 0.34, 0.05, '#2a2f38', INK, lw)
    for (let i = 1; i <= 6; i++) circle(ctx, x + ((bx - x) * i) / 7, 1.25 + ((by - 1.25) * i) / 7, 0.065, rgba(shade(c, i % 2 ? 0.7 : 1.0)), INK, lw * 0.6)
    ctx.save()
    ctx.translate(bx, by)
    ctx.rotate(a * 2)
    teeth(ctx, 0.5, 9, 0.66)
    ctx.fillStyle = rgba(shade(c, 0.8))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    ctx.restore()
    const g = ctx.createRadialGradient(bx - 0.1, by - 0.1, 0.02, bx, by, 0.36)
    g.addColorStop(0, rgba(shade(c, 1.3)))
    g.addColorStop(1, rgba(shade(c, 0.45)))
    circle(ctx, bx, by, 0.34, g, INK, lw)
  },
}

const FRONT_FEET = {
  spider(ctx, c, id, now, lw) {
    for (let i = 2; i >= 0; i--) {
      const k = 1 - i * 0.18
      for (const side of [-1, 1]) {
        const knee = [side * (1.3 + i * 0.3), 0.8 + i * 0.1 + 0.03 * Math.sin(now / 300 + i + side)]
        const foot = [side * (0.85 + i * 0.5), 2.85 - i * 0.12]
        limb(ctx, [[side * 0.4, 1.12], knee], 0.17 - i * 0.02, rgba(shade(c, k)), lw)
        limb(ctx, [knee, foot], 0.12 - i * 0.015, rgba(shade(c, 0.75 * k)), lw)
        circle(ctx, knee[0], knee[1], 0.1, rgba(shade(TEAM[id], k)), INK, lw)
        circle(ctx, foot[0], foot[1], 0.05, '#1b1e24')
      }
    }
    rrect(ctx, -0.55, 0.92, 1.1, 0.45, 0.16, metal(ctx, c, 0.92, 1.37), INK, lw)
    ctx.beginPath()
    ctx.ellipse(0, 1.42, 0.42, 0.22, 0, 0, TAU)
    ctx.fillStyle = '#262b35'
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    led(ctx, 0, 1.45, 0.06, true, TEAM_LIGHT[id])
  },
  wheels(ctx, c, id, now, lw) {
    rrect(ctx, -0.85, 1.95, 1.7, 0.16, 0.05, JOINT, INK, lw)
    for (const side of [-1, 1]) {
      const x = side * 0.72
      rrect(ctx, side * 0.45 - 0.1, 1.2, 0.2, 0.85, 0.05, rgba(shade(c, 0.8)), INK, lw)
      tire(ctx, x - 0.26, 1.35, 0.52, 1.5, now / 350, lw)
      rrect(ctx, x - 0.32, 1.28, 0.64, 0.3, 0.1, metal(ctx, c, 1.28, 1.58), INK, lw)
      rrect(ctx, x - 0.26, 1.48, 0.52, 0.05, 0.02, rgba(TEAM[id], 0.9))
    }
    rrect(ctx, -0.6, 0.92, 1.2, 0.4, 0.12, metal(ctx, c, 0.92, 1.32), INK, lw)
  },
  jets(ctx, c, id, now, lw) {
    for (const side of [-1, 1]) {
      const bx = side * 0.56
      const f = 0.8 + 0.2 * Math.sin(now / 40 + side)
      rrect(ctx, side * 0.42 - 0.2, 0.95, 0.4, 0.75, 0.14, metal(ctx, c, 0.95, 1.7), INK, lw)
      glow(ctx, bx, 3.0, 0.7, [120, 190, 255], 0.5)
      ctx.beginPath()
      ctx.moveTo(bx - 0.26, 2.78)
      ctx.lineTo(bx, 2.78 + 0.6 * f)
      ctx.lineTo(bx + 0.26, 2.78)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, 0, 2.78, 0, 2.78 + 0.6 * f, 'rgba(235,248,255,0.95)', 'rgba(80,150,255,0)')
      ctx.fill()
      rrect(ctx, bx - 0.44, 1.7, 0.88, 0.95, 0.24, metal(ctx, c, 1.7, 2.65), INK, lw)
      rrect(ctx, bx - 0.3, 1.86, 0.6, 0.08, 0.03, rgba(TEAM[id], 0.9))
      circle(ctx, side * 0.45, 1.68, 0.2, rgba(TEAM[id]), INK, lw)
      ctx.beginPath()
      ctx.moveTo(bx - 0.28, 2.6)
      ctx.lineTo(bx + 0.28, 2.6)
      ctx.lineTo(bx + 0.36, 2.82)
      ctx.lineTo(bx - 0.36, 2.82)
      ctx.closePath()
      ctx.fillStyle = '#1b1e24'
      ctx.fill()
      ctx.strokeStyle = 'rgba(140,200,255,0.8)'
      ctx.lineWidth = lw
      ctx.stroke()
      ctx.fillStyle = 'rgba(0,0,0,0.3)'
      for (const y of [2.12, 2.28]) ctx.fillRect(bx - 0.32, y, 0.64, 0.05)
    }
  },
  stompers(ctx, c, id, now, lw) {
    for (const side of [-1, 1]) {
      const px = side * 0.55
      rrect(ctx, side * 0.42 - 0.24, 0.95, 0.48, 0.7, 0.14, metal(ctx, c, 0.95, 1.65), INK, lw)
      rrect(ctx, side * 0.5 - 0.32, 1.72, 0.64, 0.8, 0.12, metal(ctx, c, 1.72, 2.52), INK, lw)
      rrect(ctx, side * 0.78 - 0.04, 1.8, 0.08, 0.65, 0.02, '#cfd5de', INK, lw * 0.6)
      circle(ctx, side * 0.45, 1.66, 0.22, rgba(TEAM[id]), INK, lw)
      rrect(ctx, px - 0.52, 2.45, 1.04, 0.45, 0.12, '#2a2f38', INK, lw)
      ctx.save()
      ctx.beginPath()
      ctx.roundRect(px - 0.52, 2.45, 1.04, 0.45, 0.12)
      ctx.clip()
      hazard(ctx, px - 0.52, 2.76, 1.04, 0.14, 8)
      ctx.fillStyle = 'rgba(255,255,255,0.12)'
      ctx.fillRect(px - 0.52, 2.47, 1.04, 0.07)
      ctx.restore()
    }
  },
  skates(ctx, c, id, now, lw) {
    for (const side of [-1, 1]) {
      const bx = side * 0.46
      rrect(ctx, side * 0.4 - 0.19, 0.95, 0.38, 0.8, 0.13, metal(ctx, c, 0.95, 1.75), INK, lw)
      rrect(ctx, side * 0.44 - 0.19, 1.82, 0.38, 0.62, 0.12, metal(ctx, c, 1.82, 2.44), INK, lw)
      circle(ctx, side * 0.42, 1.78, 0.19, rgba(TEAM[id]), INK, lw)
      glow(ctx, bx, 2.95, 0.3, TEAM[id], 0.35)
      rrect(ctx, bx - 0.06, 2.64, 0.12, 0.14, 0.02, JOINT)
      rrect(ctx, bx - 0.08, 2.74, 0.16, 0.3, 0.07, rgba(TEAM_LIGHT[id]), INK, lw)
      rrect(ctx, bx - 0.26, 2.3, 0.52, 0.4, 0.12, metal(ctx, shade(c, 0.8), 2.3, 2.7), INK, lw)
      ctx.fillStyle = 'rgba(0,0,0,0.4)'
      for (const y of [2.4, 2.52]) ctx.fillRect(bx - 0.24, y, 0.48, 0.05)
    }
  },
  quad(ctx, c, id, now, lw) {
    for (const [hy, kx, ky, fx, fy, w, k] of [[1.1, 1.1, 1.25, 0.95, 2.6, 0.16, 0.7], [1.15, 0.85, 1.75, 0.6, 2.8, 0.24, 1]]) {
      for (const side of [-1, 1]) {
        const knee = [side * kx, ky]
        const foot = [side * fx, fy]
        limb(ctx, [[side * 0.4, hy], knee], w, rgba(shade(c, k)), lw)
        limb(ctx, [knee, foot], w * 0.72, rgba(shade(c, 0.75 * k)), lw)
        circle(ctx, knee[0], knee[1], w * 0.6, rgba(shade(TEAM[id], k)), INK, lw)
        rrect(ctx, foot[0] - w, fy - 0.06, w * 2, 0.16, 0.06, '#20242c', INK, lw)
      }
    }
    rrect(ctx, -0.62, 0.92, 1.24, 0.45, 0.16, metal(ctx, c, 0.92, 1.37), INK, lw)
  },
  mono(ctx, c, id, now, lw) {
    for (const side of [-1, 1]) {
      ctx.beginPath()
      ctx.moveTo(side * 0.4, 1.1)
      ctx.lineTo(side * 1.05, 1.55)
      ctx.lineTo(side * 1.0, 1.75)
      ctx.lineTo(side * 0.38, 1.5)
      ctx.closePath()
      ctx.fillStyle = metal(ctx, c, 1.1, 1.75)
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = lw
      ctx.stroke()
      ctx.strokeStyle = rgba(TEAM[id], 0.9)
      ctx.lineWidth = 0.06
      ctx.beginPath()
      ctx.moveTo(side * 0.55, 1.3)
      ctx.lineTo(side * 0.98, 1.6)
      ctx.stroke()
    }
    glow(ctx, 0, 2.9, 0.6, TEAM[id], 0.3)
    tire(ctx, -0.3, 1.4, 0.6, 1.5, now / 350, lw)
    for (const side of [-1, 1]) rrect(ctx, side * 0.36 - 0.08, 1.2, 0.16, 1.1, 0.05, rgba(shade(c, 0.85)), INK, lw)
    rrect(ctx, -0.42, 2.0, 0.84, 0.18, 0.06, JOINT, INK, lw)
    for (const side of [-1, 1]) led(ctx, side * 0.36, 2.09, 0.05, true, TEAM_LIGHT[id])
    rrect(ctx, -0.5, 0.92, 1.0, 0.42, 0.14, metal(ctx, c, 0.92, 1.34), INK, lw)
  },
}

const FRONT_HEADS = {
  crest: {
    under(ctx, id, now, lw) {
      const fill = () => {
        ctx.fillStyle = lin(ctx, 0, -2.95, 0, -1.8, '#fff1a0', '#c8901a')
        ctx.fill()
        ctx.strokeStyle = INK
        ctx.lineWidth = lw
        ctx.stroke()
      }
      for (const side of [-1, 1]) {
        ctx.beginPath()
        ctx.moveTo(side * 0.22, -1.78)
        ctx.quadraticCurveTo(side * 0.62, -1.95, side * 1.02, -2.55)
        ctx.quadraticCurveTo(side * 0.62, -2.2, side * 0.3, -2.02)
        ctx.closePath()
        fill()
      }
      ctx.beginPath()
      ctx.moveTo(-0.1, -1.95)
      ctx.quadraticCurveTo(-0.06, -2.55, 0.12, -2.95)
      ctx.quadraticCurveTo(0.08, -2.45, 0.1, -1.95)
      ctx.closePath()
      fill()
    },
  },
  dish: {
    under(ctx, id, now, lw) {
      rrect(ctx, -0.07, -2.4, 0.14, 0.52, 0.03, JOINT, INK, lw)
      const w = 0.8 * (0.4 + 0.6 * Math.abs(Math.cos(now / 900)))
      ctx.beginPath()
      ctx.ellipse(0, -2.5, w, 0.3, 0, 0, TAU)
      ctx.fillStyle = lin(ctx, -w, 0, w, 0, '#e6ebf2', '#6c7482')
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = lw
      ctx.stroke()
      ctx.beginPath()
      ctx.ellipse(0, -2.46, w * 0.72, 0.18, 0, 0, TAU)
      ctx.fillStyle = 'rgba(0,0,0,0.25)'
      ctx.fill()
      ctx.strokeStyle = '#2a2f38'
      ctx.lineWidth = 0.05
      ctx.beginPath()
      ctx.moveTo(0, -2.48)
      ctx.lineTo(0, -2.9)
      ctx.stroke()
      led(ctx, 0, -2.92, 0.06, true, [255, 90, 80])
    },
  },
  visor: {
    over(ctx, id, now, lw) {
      glow(ctx, 0, -1.5, 0.6, [255, 60, 50], 0.4)
      rrect(ctx, -0.4, -1.67, 0.8, 0.34, 0.14, lin(ctx, 0, -1.67, 0, -1.33, 'rgba(255,120,100,0.6)', 'rgba(170,20,20,0.7)'), INK, lw)
      rrect(ctx, -0.3, -1.62, 0.5, 0.05, 0.02, 'rgba(255,230,220,0.55)')
      rrect(ctx, 0.34, -1.72, 0.2, 0.42, 0.06, '#1d2128', INK, lw)
      circle(ctx, 0.44, -1.5, 0.11, '#14171c', INK, lw)
      glow(ctx, 0.44, -1.5, 0.3, [255, 60, 50], 0.7)
      circle(ctx, 0.44, -1.5, 0.065, '#ff5040')
    },
  },
  medic: {
    over(ctx, id, now, lw) {
      ctx.beginPath()
      ctx.ellipse(0, -1.78, 0.36, 0.3, 0, Math.PI, TAU)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, 0, -2.08, 0, -1.78, '#ffffff', '#b8c0cc')
      ctx.fill()
      ctx.strokeStyle = INK
      ctx.lineWidth = lw
      ctx.stroke()
      glow(ctx, 0, -1.92, 0.3, [90, 255, 140], 0.35)
      ctx.fillStyle = '#3fd16a'
      ctx.fillRect(-0.045, -2.03, 0.09, 0.22)
      ctx.fillRect(-0.11, -1.965, 0.22, 0.09)
    },
  },
  orb: {
    over(ctx, id, now, lw) {
      const y = -2.5 + 0.09 * Math.sin(now / 320 + id)
      ctx.beginPath()
      ctx.ellipse(0, -2.08, 0.3, 0.07, 0, 0, TAU)
      ctx.strokeStyle = rgba(ORB, 0.5)
      ctx.lineWidth = lw
      ctx.stroke()
      glow(ctx, 0, y, 0.75, ORB, 0.45)
      const g = ctx.createRadialGradient(-0.07, y - 0.08, 0.02, 0, y, 0.25)
      g.addColorStop(0, '#f2dcff')
      g.addColorStop(0.45, rgba(ORB))
      g.addColorStop(1, 'rgb(70,20,120)')
      circle(ctx, 0, y, 0.24, g, 'rgba(230,200,255,0.8)', lw)
    },
  },
  antenna: {
    under(ctx, id, now, lw) {
      for (const i of [-1, 0, 1]) {
        const tx = i * 0.55 + 0.04 * Math.sin(now / 380 + i)
        const ty = i ? -2.6 : -2.95
        ctx.strokeStyle = INK
        ctx.lineWidth = 0.1
        ctx.beginPath()
        ctx.moveTo(i * 0.24, -1.9)
        ctx.lineTo(tx, ty)
        ctx.stroke()
        ctx.strokeStyle = '#8a93a3'
        ctx.lineWidth = 0.05
        ctx.stroke()
        rrect(ctx, i * 0.24 - 0.07, -2.02, 0.14, 0.14, 0.03, JOINT, INK, lw)
        led(ctx, tx, ty, 0.07, Math.sin(now / 260 + i * 2.1) > -0.3, i ? [125, 255, 154] : [255, 90, 80])
      }
    },
  },
  dispenser: {
    under(ctx, id, now, lw) {
      rrect(ctx, -0.44, -2.42, 0.88, 0.6, 0.08, metal(ctx, STEEL[0], -2.42, -1.82), INK, lw)
      ctx.save()
      ctx.beginPath()
      ctx.roundRect(-0.3, -2.34, 0.6, 0.3, 0.04)
      ctx.clip()
      hazard(ctx, -0.3, -2.34, 0.6, 0.3, 8)
      ctx.restore()
      rrect(ctx, -0.3, -2.34, 0.6, 0.3, 0.04, null, INK, lw)
      led(ctx, 0.36, -2.32, 0.04, true, [255, 200, 80])
    },
  },
  demon: {
    under(ctx, id, now, lw) {
      for (const side of [-1, 1]) {
        ctx.beginPath()
        ctx.moveTo(side * 0.3, -1.85)
        ctx.quadraticCurveTo(side * 0.95, -1.95, side * 0.82, -2.75)
        ctx.quadraticCurveTo(side * 0.7, -2.15, side * 0.2, -2.0)
        ctx.closePath()
        ctx.fillStyle = lin(ctx, 0, -2.75, 0, -1.85, '#2a0606', '#c8241e')
        ctx.fill()
        ctx.strokeStyle = INK
        ctx.lineWidth = lw
        ctx.stroke()
      }
    },
  },
}

function frontLegs(ctx, kind, c, id, now, lw) {
  const feet = art(FRONT_FEET, kind)
  if (feet) return feet(ctx, c, id, now, lw)
  if (kind === 'hover') {
    rrect(ctx, -0.24, 0.95, 0.48, 0.6, 0.1, JOINT, INK, lw)
    const pulse = 0.5 + 0.5 * Math.sin(now / 140)
    glow(ctx, 0, 2.05, 1.3, [120, 225, 255], 0.35 + 0.15 * pulse)
    for (const x of [-0.6, 0, 0.6]) {
      const h = 0.45 + 0.15 * Math.sin(now / 60 + x * 5)
      ctx.beginPath()
      ctx.moveTo(x - 0.12, 1.85)
      ctx.lineTo(x, 1.85 + h)
      ctx.lineTo(x + 0.12, 1.85)
      ctx.closePath()
      ctx.fillStyle = 'rgba(170,240,255,0.75)'
      ctx.fill()
    }
    ctx.beginPath()
    ctx.ellipse(0, 1.68, 1.1, 0.32, 0, 0, TAU)
    ctx.fillStyle = lin(ctx, 0, 1.36, 0, 2, rgba(shade(c, 1.1)), rgba(shade(c, 0.45)))
    ctx.fill()
    ctx.strokeStyle = 'rgba(140,225,255,0.9)'
    ctx.lineWidth = lw * 1.5
    ctx.stroke()
    return
  }
  if (kind === 'treads') {
    rrect(ctx, -0.6, 0.95, 1.2, 0.38, 0.1, JOINT, INK, lw)
    for (const side of [-1, 1]) {
      const x = side * 0.66 - 0.32
      rrect(ctx, x, 1.22, 0.64, 1.62, 0.3, '#1f232a', INK, lw)
      ctx.save()
      ctx.beginPath()
      ctx.roundRect(x, 1.22, 0.64, 1.62, 0.3)
      ctx.clip()
      ctx.strokeStyle = rgba(shade(c, 0.6))
      ctx.lineWidth = 0.08
      const off = (now / 400) % 0.24
      ctx.beginPath()
      for (let y = 1.2 + off; y < 2.9; y += 0.24) {
        ctx.moveTo(x, y)
        ctx.lineTo(x + 0.64, y)
      }
      ctx.stroke()
      ctx.restore()
      rrect(ctx, side * 0.66 - 0.36 + (side > 0 ? 0.64 : 0), 1.4, 0.08, 1.2, 0.03, rgba(TEAM[id]))
    }
    return
  }
  for (const side of [-1, 1]) {
    rrect(ctx, side * 0.42 - 0.21, 0.95, 0.42, 0.82, 0.14, lin(ctx, 0, 0.95, 0, 1.77, rgba(shade(c, 1.1)), rgba(shade(c, 0.6))), INK, lw)
    rrect(ctx, side * 0.47 - 0.23, 1.82, 0.46, 0.76, 0.13, lin(ctx, 0, 1.82, 0, 2.58, rgba(shade(c, 1.05)), rgba(shade(c, 0.55))), INK, lw)
    circle(ctx, side * 0.45, 1.8, 0.21, rgba(TEAM[id]), INK, lw)
    rrect(ctx, side * 0.5 - 0.34, 2.56, 0.68, 0.3, 0.1, '#20242c', INK, lw)
    glow(ctx, side * 0.86, 2.7, 0.25, [255, 160, 70], 0.5)
  }
}

function frontArm(ctx, slot, kind, side, c, id, now, lw) {
  const x = side * 1.18
  rrect(ctx, x - 0.2, -0.75, 0.4, 0.92, 0.15, lin(ctx, 0, -0.75, 0, 0.17, rgba(shade(c, 1.1)), rgba(shade(c, 0.6))), INK, lw)
  circle(ctx, x, 0.2, 0.2, JOINT, INK, lw)
  rrect(ctx, x - 0.25, 0.22, 0.5, 0.86, 0.16, lin(ctx, 0, 0.22, 0, 1.08, rgba(shade(c, 1.05)), rgba(shade(c, 0.55))), INK, lw)
  if (slot === 'gun') {
    if (kind === 'needle') {
      for (const dx of [-0.09, 0.09]) rrect(ctx, x + dx - 0.06, 0.9, 0.12, 1.95, 0.04, rgba(shade(c, 0.85)), INK, lw)
      for (const y of [1.3, 1.8, 2.3]) {
        glow(ctx, x, y, 0.3, [120, 210, 255], 0.55)
        rrect(ctx, x - 0.2, y - 0.04, 0.4, 0.08, 0.03, '#9fe0ff')
      }
      rrect(ctx, x + side * 0.28 - 0.09, 0.4, 0.18, 0.55, 0.06, '#1d2128', INK, lw)
      circle(ctx, x + side * 0.28, 0.95, 0.07, '#8fdcff')
    } else if (kind === 'scatter') {
      rrect(ctx, x - 0.32, 0.9, 0.64, 0.7, 0.12, lin(ctx, 0, 0.9, 0, 1.6, rgba(shade(c, 1.1)), rgba(shade(c, 0.55))), INK, lw)
      for (const dx of [-0.14, 0.14]) circle(ctx, x + dx, 1.62, 0.11, '#14171c', rgba(shade(c, 1.1)), lw)
      for (let i = 0; i < 3; i++) {
        rrect(ctx, x + side * 0.36 - 0.06, 0.95 + i * 0.19, 0.12, 0.15, 0.03, '#b8402f')
      }
    } else if (art(FRONT_GUNS, kind)) {
      FRONT_GUNS[kind](ctx, x, side, c, id, now, lw)
    } else {
      rrect(ctx, x - 0.17, 0.9, 0.34, 0.95, 0.08, lin(ctx, 0, 0.9, 0, 1.85, rgba(shade(c, 0.95)), rgba(shade(c, 0.5))), INK, lw)
      rrect(ctx, x - 0.22, 1.78, 0.44, 0.17, 0.04, '#1d2027', INK, lw)
      circle(ctx, x + side * 0.36, 0.72, 0.25, lin(ctx, 0, 0.47, 0, 0.97, rgba(shade(c, 1.1)), rgba(shade(c, 0.5))), INK, lw)
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * TAU
        circle(ctx, x + side * 0.36 + Math.cos(a) * 0.16, 0.72 + Math.sin(a) * 0.16, 0.03, '#3a414e')
      }
    }
    return
  }
  if (kind === 'drill') {
    const tip = 2.65
    rrect(ctx, x - 0.32, 0.98, 0.64, 0.16, 0.05, '#1d2027', INK, lw)
    ctx.beginPath()
    ctx.moveTo(x - 0.3, 1.12)
    ctx.lineTo(x, tip)
    ctx.lineTo(x + 0.3, 1.12)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, x - 0.3, 0, x + 0.3, 0, rgba(shade(c, 1.15)), rgba(shade(c, 0.5)))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    ctx.strokeStyle = 'rgba(0,0,0,0.4)'
    ctx.beginPath()
    for (let i = 0; i < 6; i++) {
      const f = (now / 400 + i / 6) % 1
      const y = 1.12 + f * (tip - 1.12)
      const hw = 0.3 * (1 - f)
      ctx.moveTo(x - hw, y)
      ctx.lineTo(x + hw, y + 0.1)
    }
    ctx.stroke()
  } else if (kind === 'hammer') {
    rrect(ctx, x - 0.07, 1.0, 0.14, 0.85, 0.04, '#3a414e', INK, lw)
    glow(ctx, x, 2.05, 0.8, [140, 205, 255], 0.3 + 0.15 * Math.sin(now / 90))
    rrect(ctx, x - 0.52, 1.78, 1.04, 0.56, 0.08, lin(ctx, 0, 1.78, 0, 2.34, rgba(shade(c, 1.1)), rgba(shade(c, 0.5))), INK, lw)
    for (const dy of [1.9, 2.04, 2.18]) {
      ctx.fillStyle = 'rgba(160,215,255,0.9)'
      ctx.fillRect(x - 0.4, dy - 0.02, 0.8, 0.04)
    }
    for (let i = 0; i < 5; i++) {
      ctx.fillStyle = i % 2 ? '#1b1e24' : '#e6b33a'
      ctx.fillRect(x - 0.52 + i * 0.208, 2.27, 0.208, 0.07)
    }
  } else if (art(FRONT_BLADES, kind)) {
    FRONT_BLADES[kind](ctx, x, side, c, id, now, lw)
  } else {
    ctx.strokeStyle = '#2a2f38'
    ctx.lineWidth = 0.1
    ctx.beginPath()
    ctx.arc(x + side * 0.05, 1.4, 0.68, -Math.PI * 0.95, -Math.PI * 0.05)
    ctx.stroke()
    sawDisc(ctx, x + side * 0.05, 1.4, 0.6, now / 140, c, false, lw)
  }
}

function frontTorso(ctx, id, core, now, lw) {
  ctx.beginPath()
  ctx.moveTo(-0.98, -0.95)
  ctx.quadraticCurveTo(0, -1.28, 0.98, -0.95)
  ctx.lineTo(0.72, 0.38)
  ctx.quadraticCurveTo(0, 0.62, -0.72, 0.38)
  ctx.closePath()
  ctx.fillStyle = lin(ctx, 0, -1.25, 0, 0.6, rgba(TEAM_LIGHT[id]), rgba(TEAM_DARK[id]))
  ctx.fill()
  ctx.save()
  ctx.shadowColor = rgba(TEAM[id], 0.9)
  ctx.shadowBlur = 10
  ctx.strokeStyle = rgba(TEAM_LIGHT[id], 0.8)
  ctx.lineWidth = lw * 1.3
  ctx.stroke()
  ctx.restore()
  ctx.strokeStyle = INK
  ctx.lineWidth = lw
  ctx.stroke()
  ctx.strokeStyle = 'rgba(0,0,0,0.45)'
  ctx.lineWidth = lw * 1.4
  ctx.beginPath()
  ctx.moveTo(0, -1.12)
  ctx.lineTo(0, 0.5)
  ctx.stroke()
  for (const side of [-1, 1]) {
    ctx.fillStyle = 'rgba(255,255,255,0.14)'
    ctx.beginPath()
    ctx.ellipse(side * 0.44, -0.55, 0.26, 0.42, side * 0.2, 0, TAU)
    ctx.fill()
    ctx.strokeStyle = rgba(shade(TEAM_DARK[id], 0.8))
    ctx.lineWidth = 0.08
    ctx.beginPath()
    ctx.moveTo(side * 0.2, -0.95)
    ctx.lineTo(side * 0.55, 0.25)
    ctx.stroke()
  }
  const gem = coreC({ core })
  glow(ctx, 0, -0.32, 0.6, gem, 0.75)
  circle(ctx, 0, -0.32, 0.22, '#14171c', rgba(gem), lw * 1.5)
  if (core === 'flywheel') {
    circle(ctx, 0, -0.32, 0.15, null, rgba(gem), 0.06)
    ctx.strokeStyle = rgba(gem, 0.8)
    ctx.lineWidth = 0.03
    ctx.beginPath()
    for (let i = 0; i < 6; i++) {
      const a = now / 300 + (i / 6) * TAU
      ctx.moveTo(Math.cos(a) * 0.04, -0.32 + Math.sin(a) * 0.04)
      ctx.lineTo(Math.cos(a) * 0.13, -0.32 + Math.sin(a) * 0.13)
    }
    ctx.stroke()
    circle(ctx, 0, -0.32, 0.045, '#ffffff')
  } else circle(ctx, 0, -0.32, 0.12, rgba(gem), '#ffffff', lw * 0.6)
  rrect(ctx, -0.5, 0.44, 1.0, 0.17, 0.05, '#2a2f38', INK, lw)
  rrect(ctx, -0.42, 0.64, 0.84, 0.16, 0.05, '#2a2f38', INK, lw)
  rrect(ctx, -0.46, 0.82, 0.92, 0.2, 0.06, JOINT, INK, lw)
}

function frontShoulders(ctx, id, lw) {
  for (const side of [-1, 1]) {
    ctx.beginPath()
    ctx.ellipse(side * 1.14, -0.92, 0.5, 0.37, 0, 0, TAU)
    ctx.fillStyle = lin(ctx, 0, -1.29, 0, -0.55, rgba(TEAM_LIGHT[id]), rgba(TEAM_DARK[id]))
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    ctx.strokeStyle = 'rgba(255,255,255,0.3)'
    ctx.lineWidth = 0.06
    ctx.beginPath()
    ctx.ellipse(side * 1.14, -0.95, 0.36, 0.22, 0, Math.PI * 1.1, Math.PI * 1.9)
    ctx.stroke()
  }
}

function frontHead(ctx, kind, id, now, lw) {
  rrect(ctx, -0.16, -1.34, 0.32, 0.24, 0.06, JOINT, INK, lw)
  if (kind === 'horn') {
    ctx.beginPath()
    ctx.moveTo(-0.16, -1.92)
    ctx.quadraticCurveTo(-0.26, -2.62, 0.1, -3.1)
    ctx.quadraticCurveTo(0.0, -2.55, 0.16, -1.92)
    ctx.closePath()
    ctx.fillStyle = lin(ctx, -0.2, 0, 0.16, 0, BONE[0], BONE[1])
    ctx.fill()
    ctx.strokeStyle = INK
    ctx.lineWidth = lw
    ctx.stroke()
    ctx.beginPath()
    ctx.moveTo(0.22, -1.88)
    ctx.quadraticCurveTo(0.3, -2.05, 0.4, -2.2)
    ctx.quadraticCurveTo(0.38, -2.0, 0.34, -1.84)
    ctx.closePath()
    ctx.fillStyle = BONE[1]
    ctx.fill()
    ctx.stroke()
  } else if (kind === 'pincer') {
    for (const side of [-1, 1]) {
      ctx.beginPath()
      ctx.moveTo(side * 0.28, -1.72)
      ctx.bezierCurveTo(side * 0.82, -1.95, side * 1.02, -2.5, side * 0.64, -2.9)
      ctx.lineTo(side * 0.56, -2.72)
      ctx.lineTo(side * 0.66, -2.55)
      ctx.bezierCurveTo(side * 0.7, -2.3, side * 0.56, -2.05, side * 0.18, -1.9)
      ctx.closePath()
      ctx.fillStyle = lin(ctx, 0, -2.9, 0, -1.7, '#4a5262', '#1d2128')
      ctx.fill()
      ctx.strokeStyle = rgba(TEAM_LIGHT[id], 0.85)
      ctx.lineWidth = lw
      ctx.stroke()
    }
  } else FRONT_HEADS[kind].under?.(ctx, id, now, lw)
  ctx.beginPath()
  ctx.ellipse(0, -1.62, 0.47, 0.42, 0, 0, TAU)
  ctx.fillStyle = lin(ctx, 0, -2.04, 0, -1.2, rgba(TEAM_LIGHT[id]), rgba(TEAM_DARK[id]))
  ctx.fill()
  ctx.strokeStyle = INK
  ctx.lineWidth = lw
  ctx.stroke()
  rrect(ctx, -0.34, -1.64, 0.68, 0.3, 0.12, '#12151a', INK, lw)
  const blink = Math.sin(now / 1100 + id * 3) > 0.985 ? 0.15 : 1
  for (const side of [-1, 1]) {
    glow(ctx, side * 0.15, -1.49, 0.22, EYES[id], 0.8 * blink)
    ctx.beginPath()
    ctx.ellipse(side * 0.15, -1.49, 0.08, 0.05, 0, 0, TAU)
    ctx.fillStyle = rgba(EYES[id], blink)
    ctx.fill()
  }
  art(FRONT_HEADS, kind)?.over?.(ctx, id, now, lw)
}

export function drawPortrait(ctx, loadout, id, x, y, s, now) {
  const c = STEEL[0]
  const lw = 1.5 / s
  ctx.save()
  ctx.translate(x, y + Math.sin(now / 520 + id) * 0.06 * s)
  ctx.scale(s, s)
  glow(ctx, 0, -0.3, 3.2, TEAM[id], 0.22)
  frontLegs(ctx, loadout.legs, c, id, now, lw)
  for (const [hand, side] of [['right', -1], ['left', 1]]) frontArm(ctx, isGun(WEAPONS[loadout[hand]]) ? 'gun' : 'melee', loadout[hand], side, c, id, now, lw)
  frontTorso(ctx, id, loadout.core, now, lw)
  frontShoulders(ctx, id, lw)
  frontHead(ctx, headKind(loadout.head), id, now, lw)
  ctx.restore()
}
