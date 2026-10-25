import { SURGE, SHIELD, HOOK, LANCE, HEAL, MECH_R, PILLARS, WALLS, PADS, TRAPS, HAZARDS, TICKS, CATALOG, HANDS, TRAILS, weapon, isGun, ult, moveOf, hidden, untilSlam, untilZap, ventPhase, vents, foes } from './sim.js'

export const BOT = { aimError: 0.9, guard: 0.35, dodge: 0.25, reaction: 0.3, jukeMin: 18, jukeMax: 70, close: [1.6, 2.6], heatCap: 82, rhythm: 18, healAt: 0.6, grab: 14, stick: 1.3 }

export function createBrain(seed = 1) {
  return { seed: seed >>> 0, side: 1, nextJuke: 0, lastFlip: 0, guard: 0, threat: 0, guardRoll: false, dodgeRoll: false, nextShot: { left: 0, right: 0 } }
}

const meleeReady = m => HANDS.some(h => !isGun(weapon(m, h)) && m.cd[h] === 0)

function rand(b) {
  b.seed = (b.seed + 0x6d2b79f5) >>> 0
  let t = b.seed
  t = Math.imul(t ^ (t >>> 15), t | 1)
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

export function randomLoadout(brain) {
  const pick = o => {
    const k = Object.keys(o)
    return k[Math.floor(rand(brain) * k.length)]
  }
  return Object.fromEntries(Object.entries(CATALOG).map(([slot, parts]) => [slot, pick(parts)]))
}

function segDist(x0, y0, x1, y1, px, py) {
  const dx = x1 - x0
  const dy = y1 - y0
  const k = Math.max(0, Math.min(1, ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy || 1)))
  return Math.hypot(x0 + dx * k - px, y0 + dy * k - py)
}

const clearLine = (x0, y0, x1, y1) => PILLARS.every(p => segDist(x0, y0, x1, y1, p.x, p.y) > p.r + 0.3)
const health = m => Object.keys(m.armor).reduce((s, p) => s + Math.max(0, m.armor[p]) / m.max[p], 0) / 4

const ally = (state, m, id) => state.mechs[id].team === m.team

function pick(state, brain, m) {
  const d = t => Math.hypot(t.x - m.x, t.y - m.y)
  const list = foes(state, m.id)
  const near = list.reduce((a, t) => (!a || d(t) < d(a) ? t : a), null)
  const cur = list.find(t => t.id === brain.target)
  if (cur && d(cur) < d(near) * BOT.stick + 2) return cur
  if (near) brain.target = near.id
  return near ?? state.mechs.find(t => t.team !== m.team) ?? m
}

function incoming(state, m) {
  let best = null
  for (const s of state.shots) {
    if (ally(state, m, s.owner)) continue
    const t = ((m.x - s.x) * s.vx + (m.y - s.y) * s.vy) / (s.vx * s.vx + s.vy * s.vy)
    if (t <= 0 || t > BOT.reaction) continue
    const miss = Math.hypot(s.x + s.vx * t - m.x, s.y + s.vy * t - m.y)
    if (miss < MECH_R + s.r + 0.35 && (!best || t < best.t)) best = { t, s }
  }
  return best
}

function hazards(state, m) {
  let x = 0
  let y = 0
  const away = (hx, hy, r) => {
    const d = Math.hypot(m.x - hx, m.y - hy) || 1
    if (d > r) return
    x += (m.x - hx) / d
    y += (m.y - hy) / d
  }
  for (const l of state.lobs) if (!ally(state, m, l.owner) && l.t < 40) away(l.x, l.y, l.r + MECH_R + 0.6)
  for (const mi of state.mines) if (!ally(state, m, mi.owner)) away(mi.x, mi.y, 2.2)
  for (const f of state.fields) if (!ally(state, m, f.owner)) away(f.x, f.y, f.r + 0.5)
  for (const tr of state.trails) {
    if (ally(state, m, tr.owner) || tr.kind === 'smoke') continue
    const dx = tr.x2 - tr.x1
    const dy = tr.y2 - tr.y1
    const k = Math.max(0, Math.min(1, ((m.x - tr.x1) * dx + (m.y - tr.y1) * dy) / (dx * dx + dy * dy || 1)))
    away(tr.x1 + dx * k, tr.y1 + dy * k, TRAILS[tr.kind].width + MECH_R + 0.4)
  }
  TRAPS.crush.at.forEach((p, i) => untilSlam(state, i) < TRAPS.crush.warn + 20 && away(p.x, p.y, TRAPS.crush.half * 1.42 + MECH_R + 0.4))
  TRAPS.tesla.at.forEach((p, i) => untilZap(state, i) < TRAPS.tesla.warn + 20 && away(p.x, p.y, TRAPS.tesla.reach + MECH_R + 0.5))
  const v = ventPhase(state)
  if (v?.warn || v?.burn) {
    const r = HAZARDS.reach / 2
    vents(state.shrink).forEach(g => g.wall % 2 === v.set && away(g.x + g.dx * r, g.y + g.dy * r, r + HAZARDS.half + MECH_R + 0.4))
  }
  return { x, y }
}

const wantsItem = (kind, m) => (kind === 'repair' ? health(m) < 0.85 : kind === 'coolant' ? m.heat > 40 : kind === 'surge' ? m.surge < SURGE.max - 20 : true)

function goal(state, m, o) {
  if (state.heal.ready && health(m) < BOT.healAt) return HEAL
  let best = null
  state.pads.forEach((kind, i) => {
    const p = PADS[i]
    if (!kind || !wantsItem(kind, m) || WALLS.some(w => p.x * w.nx + p.y * w.ny > w.d - state.shrink - MECH_R)) return
    const d = Math.hypot(p.x - m.x, p.y - m.y)
    if (d < BOT.grab && d < Math.hypot(p.x - o.x, p.y - o.y) + 2 && (!best || d < best.d)) best = { x: p.x, y: p.y, d }
  })
  return best
}

function wantsUlt(kind, d, sight, open, hurt, threat, h, heat) {
  if (kind === 'lance') return sight && d < LANCE.length - 1 && (open || d < 6)
  if (kind === 'swarm') return d < 18
  if (kind === 'overdrive') return d < 9 && sight
  if (kind === 'berserk') return d < 6
  if (kind === 'emp') return d < h.radius + MECH_R - 0.5
  if (kind === 'orbital') return d < h.range && (open || d > 6)
  if (kind === 'repair') return hurt
  if (kind === 'bubble') return !!threat || d < 7
  if (kind === 'stasis') return d < h.range - 1
  if (kind === 'mines') return d < 4
  if (kind === 'blink') return d > 10 && d < 24
  if (kind === 'well') return d < h.range - 1
  if (kind === 'wall') return !!threat || (d > 9 && d < 20)
  if (kind === 'meltdown') return d < h.radius + 0.4 && heat > 45
  if (kind === 'deflect') return !!threat || d > 7
  if (kind === 'mirror') return !!threat
  if (kind === 'rail') return d < h.length - 2
  if (kind === 'shroud') return hurt || d < 6
  return false
}

function flip(brain, tick) {
  brain.side = -brain.side
  brain.lastFlip = tick
}

export function botInput(state, brain, me = 1) {
  const m = state.mechs[me]
  const o = pick(state, brain, m)
  const inp = { mx: 0, my: 0, ax: o.x, ay: o.y, left: false, right: false, hook: false, shield: false, dash: false, ult: false }
  if (state.phase !== 'fight' || m.ko || o.ko) return inp
  const tick = state.tick
  const guns = HANDS.filter(h => isGun(weapon(m, h)))
  const melees = HANDS.filter(h => !guns.includes(h))
  const shooter = guns.find(h => m.cd[h] === 0 && tick >= brain.nextShot[h]) ?? guns[0]
  const g = shooter && weapon(m, shooter)
  const dx = o.x - m.x
  const dy = o.y - m.y
  const d = Math.hypot(dx, dy) || 1
  const ux = dx / d
  const uy = dy / d
  const px = -uy
  const py = ux
  const threat = incoming(state, m)
  if (threat && threat.s.cast !== brain.threat) {
    brain.threat = threat.s.cast
    brain.guardRoll = rand(brain) < BOT.guard
    brain.dodgeRoll = rand(brain) < BOT.dodge
  }
  const veiled = hidden(state, o)
  const sight = !veiled && clearLine(m.x, m.y, o.x, o.y)
  const open = (o.dashes === 0 && o.cd.dash > 40) || o.stagger > 0 || o.overheat > 0
  const aggressive = open || o.armor.head < m.armor.head * 0.6
  const [lo, hi] = aggressive || !g ? BOT.close : g.band
  const target = goal(state, m, o)
  const avoid = hazards(state, m)

  if (tick >= brain.nextJuke) {
    flip(brain, tick)
    brain.nextJuke = tick + BOT.jukeMin + Math.floor(rand(brain) * (BOT.jukeMax - BOT.jukeMin))
  }
  if (threat && !brain.guardRoll && tick - brain.lastFlip > 12) flip(brain, tick)
  let wx = 0
  let wy = 0
  for (const w of WALLS) {
    if (w.d - state.shrink - (m.x * w.nx + m.y * w.ny) > 2.5) continue
    wx -= w.nx
    wy -= w.ny
  }
  if ((px * wx + py * wy) * brain.side < -0.3 && tick - brain.lastFlip > 12) flip(brain, tick)
  if (target) {
    const hx = target.x - m.x
    const hy = target.y - m.y
    const hd = Math.hypot(hx, hy) || 1
    inp.mx = hx / hd + px * brain.side * 0.3
    inp.my = hy / hd + py * brain.side * 0.3
  } else {
    const radial = d > hi ? 1 : d < lo ? -1 : 0
    inp.mx = px * brain.side + ux * radial + wx * 0.8
    inp.my = py * brain.side + uy * radial + wy * 0.8
  }
  inp.mx += avoid.x * 1.5
  inp.my += avoid.y * 1.5

  const h = ult(m)
  const ulting = m.act?.k === 'ult' || (m.surge >= SURGE.max && h.kind === 'orbital')
  const travelOf = dist => (ulting && h.kind === 'orbital' ? (h.delay + h.windup) / TICKS : g?.kind === 'lob' ? (g.delay + g.windup) / TICKS : g?.kind === 'bolt' && !g.homing ? dist / g.speed : 0)
  let tx = o.x
  let ty = o.y
  for (let i = 0; i < 2; i++) {
    const travel = travelOf(Math.hypot(tx - m.x, ty - m.y))
    tx = o.x + o.vx * travel
    ty = o.y + o.vy * travel
  }
  const err = (rand(brain) - 0.5) * 2 * BOT.aimError * (veiled ? 4 : 1)
  inp.ax = tx + px * err
  inp.ay = ty + py * err

  if (brain.guard > 0) {
    brain.guard--
    inp.shield = true
  } else if (threat && brain.guardRoll && m.cd.shield === 0 && threat.t * TICKS <= SHIELD.perfect - 2) {
    brain.guard = SHIELD.minHold
    inp.shield = true
  }
  if (inp.shield) {
    if (threat) {
      inp.ax = threat.s.x
      inp.ay = threat.s.y
    }
    return inp
  }

  const swing = melees.find(h => m.cd[h] === 0 && d < weapon(m, h).range * 0.75 + MECH_R)
  if (swing && o.pull === null) {
    inp[swing] = true
    inp.ax = o.x
    inp.ay = o.y
    return inp
  }
  if (o.pull?.by === me) return inp

  if (m.dashes > 0 && !target) {
    if (aggressive && d > 4 && d < 8.5 && sight) {
      inp.dash = true
      inp.mx = ux
      inp.my = uy
    } else if (!aggressive && d < 3.2 && meleeReady(o)) {
      inp.dash = true
      inp.mx = -ux + px * brain.side
      inp.my = -uy + py * brain.side
    } else if (threat && brain.dodgeRoll && threat.t < 0.12) {
      inp.dash = true
      inp.mx = px * brain.side
      inp.my = py * brain.side
    }
    if (inp.dash && moveOf(m).toCursor && !(aggressive && d < 8.5)) {
      inp.ax = m.x + inp.mx * 6
      inp.ay = m.y + inp.my * 6
    }
  }

  const facing = o.act?.k === 'shield' && o.act.ph === 'up' && Math.cos(o.act.angle - Math.atan2(-dy, -dx)) > Math.cos(SHIELD.arc)
  const heatOk = m.heat < BOT.heatCap || o.armor.head <= (g?.dmg ?? 0)
  const lob = g?.kind === 'lob'
  if (m.surge >= SURGE.max && wantsUlt(h.kind, d, sight, open, health(m) < 0.55, threat, h, m.heat)) inp.ult = true
  else if (m.cd.hook === 0 && (!melees.length || meleeReady(m)) && sight && !facing && d > 4 && d < HOOK.range - 1) {
    inp.hook = true
    const travel = d / HOOK.speed
    inp.ax = o.x + o.vx * travel
    inp.ay = o.y + o.vy * travel
  } else if (g && m.cd[shooter] === 0 && (sight || lob) && heatOk && (!facing || lob) && d > 2 && d < g.range && tick >= brain.nextShot[shooter]) {
    inp[shooter] = true
    brain.nextShot[shooter] = tick + g.cd + Math.floor(rand(brain) * Math.min(BOT.rhythm, g.cd))
  }
  return inp
}
