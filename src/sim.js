export const TICKS = 60
export const DT = 1 / TICKS
const TAU = Math.PI * 2
const DEG = Math.PI / 180

export const ARENA = { w: 76, h: 60, cut: 18 }
const CX = ARENA.w / 2
const CY = ARENA.h / 2
export const MECH_R = 0.8
export const PILLARS = [
  { x: CX - 6.5, y: CY - 5.5, r: 1.5 },
  { x: CX + 6.5, y: CY - 5.5, r: 1.5 },
  { x: CX - 6.5, y: CY + 5.5, r: 1.5 },
  { x: CX + 6.5, y: CY + 5.5, r: 1.5 },
  { x: CX - 17, y: CY - 14, r: 2 },
  { x: CX + 17, y: CY - 14, r: 2 },
  { x: CX - 17, y: CY + 14, r: 2 },
  { x: CX + 17, y: CY + 14, r: 2 },
]
export const SPAWNS = [{ x: CX - 15, y: CY, aim: 0 }, { x: CX + 15, y: CY, aim: Math.PI }]
export const FORMATS = { '1v1': [0, 1], ffa: [0, 1, 2, 3], '2v2': [0, 1, 0, 1] }
const CORNERS = [[-15, -10], [15, 10], [15, -10], [-15, 10]]
export function spawnsOf(teams) {
  if (teams.length === 2) return SPAWNS
  const duo = new Set(teams).size === 2
  return teams.map((team, i) => {
    const [dx, dy] = duo ? [team ? 15 : -15, teams.indexOf(team) === i ? -6 : 6] : CORNERS[i]
    return { x: CX + dx, y: CY + dy, aim: Math.atan2(-dy, -dx) }
  })
}
const Q = Math.SQRT1_2
export const WALLS = [
  [0, -1, 0],
  [Q, -Q, (ARENA.w - ARENA.cut) * Q],
  [1, 0, ARENA.w],
  [Q, Q, (ARENA.w + ARENA.h - ARENA.cut) * Q],
  [0, 1, ARENA.h],
  [-Q, Q, (ARENA.h - ARENA.cut) * Q],
  [-1, 0, 0],
  [-Q, -Q, -ARENA.cut * Q],
].map(([nx, ny, d]) => ({ nx, ny, d }))

export function arenaCorners(o = 0) {
  return WALLS.map((a, i) => {
    const b = WALLS[(i + 1) % WALLS.length]
    const det = a.nx * b.ny - a.ny * b.nx
    return { x: ((a.d + o) * b.ny - (b.d + o) * a.ny) / det, y: (a.nx * (b.d + o) - b.nx * (a.d + o)) / det }
  })
}

export function clampArena(x, y, pad = 0) {
  for (let pass = 0; pass < 2; pass++) {
    for (const w of WALLS) {
      const o = x * w.nx + y * w.ny - (w.d - pad)
      if (o > 0) {
        x -= w.nx * o
        y -= w.ny * o
      }
    }
  }
  return { x, y }
}
export const HEAD_ARMOR = 300
export const DECEL = 6.5 / 0.12
export const MOVE = { cast: 0.7, shield: 0.6, overheat: 0.7, jammed: 0.7, brake: 0.7, slow: 0.4 }
export const BUFFER = 6
export const MUZZLE = 0.25
export const JAM = { cd: 2, dmg: 0.6, dash: 0.6, dashCd: 1.5 }
export const HIT = { rear: 1.25, rearArc: 135 * DEG, split: 15 * DEG }
export const STAGGER = { perPoint: 12, knockback: 0.6 }
export const HEAT = { vent: 15, ventDelay: 30, hot: 60, max: 100, overheat: 60, hotDmg: 1.3 }
export const SURGE = { max: 100, perHit: 6, dealt: 0.08, taken: 0.12, perfect: 15, carry: 0.5 }

export const WEAPONS = {
  rivet: { kind: 'bolt', shot: 'bolt', pellets: 1, spread: 0, jitter: 0, speed: 60, radius: 0.3, range: 40, dmg: 65, impact: 1, windup: 6, recovery: 12, cd: 48, load: 16, recoil: 0.2, band: [12, 16], fan: { pellets: 3, spread: 12 * DEG, dmg: 45 } },
  needle: { kind: 'bolt', shot: 'bolt', pellets: 1, spread: 0, jitter: 0, speed: 95, radius: 0.22, range: 40, dmg: 115, impact: 2, windup: 14, recovery: 16, cd: 96, load: 26, recoil: 0.5, band: [16, 22], fan: { pellets: 1, spread: 0, dmg: 170 } },
  scatter: { kind: 'bolt', shot: 'bolt', pellets: 5, spread: 7 * DEG, jitter: 0, speed: 48, radius: 0.25, range: 12, dmg: 26, impact: 1, windup: 8, recovery: 14, cd: 54, load: 18, recoil: 0.4, band: [4, 7], fan: { pellets: 8, spread: 6 * DEG, dmg: 22 } },
  gatling: { kind: 'bolt', auto: true, shot: 'bolt', pellets: 1, spread: 0, jitter: 5 * DEG, speed: 55, radius: 0.2, range: 30, dmg: 12, impact: 0, windup: 2, recovery: 4, cd: 10, load: 7, recoil: 0.05, band: [8, 13], fan: { pellets: 4, spread: 4 * DEG, dmg: 14 } },
  flamer: { kind: 'bolt', auto: true, shot: 'flame', pellets: 2, spread: 9 * DEG, jitter: 6 * DEG, speed: 16, radius: 0.45, range: 6.5, dmg: 8, impact: 0, windup: 2, recovery: 4, cd: 8, load: 5, recoil: 0, band: [3, 5.5], fan: { pellets: 6, spread: 8 * DEG, dmg: 7 } },
  missiles: { kind: 'bolt', shot: 'missile', pellets: 2, spread: 10 * DEG, jitter: 0, speed: 24, radius: 0.3, range: 40, dmg: 42, impact: 1, windup: 10, recovery: 14, cd: 108, load: 20, recoil: 0.3, band: [10, 15], homing: 3.2, fan: { pellets: 4, spread: 14 * DEG, dmg: 40 } },
  mortar: { kind: 'lob', range: 16, dmg: 110, impact: 2, windup: 10, recovery: 16, cd: 108, load: 22, recoil: 0.6, band: [9, 15], delay: 36, splash: 1.8, fan: { pellets: 3, spread: 2.6, dmg: 70 } },
  laser: { kind: 'ray', range: 18, halfWidth: 0.3, dmg: 40, impact: 1, windup: 8, recovery: 12, cd: 40, load: 18, recoil: 0.1, band: [11, 17], fan: { pellets: 3, spread: 8 * DEG, dmg: 34 } },
  tesla: { kind: 'cone', range: 7, arc: 22 * DEG, dmg: 62, impact: 2, windup: 10, recovery: 14, cd: 54, load: 20, recoil: 0, band: [4, 6.5], fan: { pellets: 1, spread: 0, dmg: 80 } },
  ricochet: { kind: 'bolt', shot: 'bolt', pellets: 1, spread: 0, jitter: 0, speed: 45, radius: 0.28, range: 40, dmg: 55, impact: 1, windup: 6, recovery: 12, cd: 52, load: 16, recoil: 0.2, band: [10, 15], bounces: 2, fan: { pellets: 3, spread: 12 * DEG, dmg: 40 } },
  saw: { kind: 'melee', range: 2.8, arc: 60 * DEG, dmg: 70, spinDmg: 60, impact: 2, windup: 8, recovery: 16, cd: 42, load: 14, lunge: 0.8 },
  drill: { kind: 'melee', range: 4.2, arc: 24 * DEG, dmg: 105, spinDmg: 70, impact: 3, windup: 10, recovery: 18, cd: 60, load: 16, lunge: 1.4 },
  hammer: { kind: 'melee', range: 2.5, arc: 85 * DEG, dmg: 65, spinDmg: 55, impact: 4, windup: 14, recovery: 20, cd: 72, load: 18, lunge: 0.4 },
  claws: { kind: 'melee', range: 2.3, arc: 50 * DEG, dmg: 38, spinDmg: 30, impact: 1, windup: 6, recovery: 12, cd: 34, load: 12, lunge: 0.6, hits: 2, gap: 7 },
  whip: { kind: 'melee', range: 5, arc: 26 * DEG, dmg: 80, spinDmg: 55, impact: 2, windup: 8, recovery: 16, cd: 48, load: 14, lunge: 0.3, yank: 2.5 },
  bunker: { kind: 'melee', range: 1.9, arc: 30 * DEG, dmg: 150, spinDmg: 90, impact: 4, windup: 16, recovery: 26, cd: 100, load: 24, lunge: 2 },
  katana: { kind: 'melee', range: 3, arc: 70 * DEG, dmg: 56, spinDmg: 55, impact: 2, windup: 6, recovery: 12, cd: 34, load: 12, lunge: 1 },
  bash: { kind: 'melee', range: 2.2, arc: 95 * DEG, dmg: 54, spinDmg: 35, impact: 3, windup: 10, recovery: 16, cd: 50, load: 12, lunge: 1.2 },
  fist: { kind: 'melee', range: 4.4, arc: 34 * DEG, dmg: 90, spinDmg: 60, impact: 3, windup: 9, recovery: 18, cd: 66, load: 16, lunge: 3 },
  flail: { kind: 'melee', range: 3.4, arc: Math.PI, dmg: 72, spinDmg: 72, impact: 2, windup: 9, recovery: 18, cd: 66, load: 16, lunge: 0.2 },
}
export const ARMS = {
  wire: { series: 'light', armor: 155, handling: 0.88 },
  reed: { series: 'light', armor: 168, handling: 0.93 },
  frame: { series: 'standard', armor: 190, handling: 1 },
  brace: { series: 'standard', armor: 205, handling: 1.04 },
  bulwark: { series: 'heavy', armor: 230, handling: 1.08 },
  anvil: { series: 'heavy', armor: 258, handling: 1.13 },
}
export const LEG_PARTS = {
  greaves: { series: 'standard', move: 'dash', armor: 190, top: 6.5, accel: 0.12, poise: 2 },
  hover: { series: 'light', move: 'glide', armor: 175, top: 8, accel: 0.22, poise: 1 },
  treads: { series: 'heavy', move: 'ram', armor: 235, top: 5.2, accel: 0.1, poise: 3 },
  spider: { series: 'standard', move: 'skitter', armor: 185, top: 6.8, accel: 0.07, poise: 2 },
  wheels: { series: 'light', move: 'drift', armor: 185, top: 9, accel: 0.35, poise: 1 },
  jets: { series: 'light', move: 'leap', armor: 180, top: 7.6, accel: 0.16, poise: 1 },
  stompers: { series: 'heavy', move: 'slam', armor: 270, top: 4.6, accel: 0.12, poise: 4 },
  skates: { series: 'light', move: 'double', armor: 190, top: 8.5, accel: 0.3, poise: 1 },
  quad: { series: 'standard', move: 'pounce', armor: 195, top: 7.4, accel: 0.1, poise: 2 },
  mono: { series: 'standard', move: 'roll', armor: 185, top: 7.8, accel: 0.22, poise: 1 },
}
export const BOOSTERS = {
  flicker: { series: 'light', trail: 'arc', dash: 3.8, dashCd: 200 },
  wisp: { series: 'light', trail: 'frost', dash: 4.5, dashCd: 240 },
  thruster: { series: 'standard', trail: 'flame', dash: 5, dashCd: 300 },
  twin: { series: 'standard', trail: 'smoke', dash: 6, dashCd: 320 },
  comet: { series: 'heavy', trail: 'magnet', dash: 7, dashCd: 330 },
  rocket: { series: 'heavy', trail: 'clean', dash: 8.5, dashCd: 390 },
}
export const HEADS = {
  horn: { series: 'standard', armor: 300, surge: 1 },
  pincer: { series: 'standard', armor: 292, surge: 1.08 },
  crest: { series: 'light', armor: 285, surge: 1.3 },
  dish: { series: 'standard', armor: 296, surge: 1.04 },
  visor: { series: 'light', armor: 278, surge: 1.4 },
  medic: { series: 'heavy', armor: 325, surge: 0.86 },
  orb: { series: 'standard', armor: 308, surge: 0.92 },
  antenna: { series: 'standard', armor: 290, surge: 1.12 },
  dispenser: { series: 'standard', armor: 304, surge: 0.94 },
  demon: { series: 'heavy', armor: 335, surge: 0.8 },
}
export const ULTS = {
  lance: { kind: 'lance', windup: 36 },
  swarm: { kind: 'swarm', windup: 12, count: 8, spread: 80 * DEG, dmg: 28, speed: 20, homing: 3 },
  overdrive: { kind: 'overdrive', windup: 6, time: 540 },
  emp: { kind: 'emp', windup: 24, radius: 6, dmg: 60, jam: 120 },
  orbital: { kind: 'orbital', windup: 10, range: 20, delay: 36, radius: 4.2, dmg: 160, impact: 3 },
  repair: { kind: 'repair', windup: 18, amount: 90 },
  bubble: { kind: 'bubble', windup: 6, time: 240, absorb: 180 },
  stasis: { kind: 'stasis', windup: 12, range: 14, radius: 4.5, time: 240, dmg: 50 },
  mines: { kind: 'mines', windup: 14, count: 6, ring: 2.5, dmg: 55, impact: 2, arm: 30, life: 720, trigger: 1 },
  berserk: { kind: 'berserk', windup: 6, time: 360, meleeDmg: 1.6, speed: 1.25, meleeCd: 0.6 },
  blink: { kind: 'blink', windup: 6, range: 9, delay: 36, radius: 2.2, dmg: 70, impact: 2 },
  well: { kind: 'well', windup: 12, range: 14, radius: 5, time: 240, dmg: 40, pull: 4 },
  wall: { kind: 'wall', windup: 8, len: 4, dist: 2.5, time: 240 },
  meltdown: { kind: 'meltdown', windup: 10, radius: 3.5, base: 40, perHeat: 1.4, impact: 3 },
  deflect: { kind: 'deflect', windup: 6, time: 180, radius: 3, turn: 0.4 },
  mirror: { kind: 'mirror', windup: 4, time: 120, arc: 70 * DEG },
  rail: { kind: 'rail', windup: 30, length: 40, halfWidth: 0.35, dmg: 130, impact: 3 },
  shroud: { kind: 'shroud', windup: 6, radius: 4, time: 240 },
}
export const CORES = {
  furnace: { series: 'standard', ult: 'lance', hotAt: 45 },
  coolant: { series: 'standard', ult: 'stasis', vent: 2, heatGain: 0.6 },
  reactor: { series: 'standard', ult: 'overdrive', surgeGain: 1.8, surgeStart: 60 },
  leech: { series: 'standard', ult: 'repair', leech: 0.12 },
  titan: { series: 'heavy', ult: 'mines', armor: 1.18, speed: 0.92 },
  volt: { series: 'light', ult: 'emp', dashCd: 0.45, dashVentAll: true, dashDist: 1.3 },
  fury: { series: 'standard', ult: 'berserk', fury: 0.5 },
  flywheel: { series: 'light', ult: 'swarm', momentum: 0.2 },
  aegis: { series: 'heavy', ult: 'bubble', shieldCd: 0.5, absorb: 260, armor: 1.05 },
  glass: { series: 'light', ult: 'orbital', dmg: 1.3, armor: 0.8 },
  phantom: { series: 'light', ult: 'blink', afterburn: 2 },
  gravity: { series: 'standard', ult: 'well', hookRange: 1.4 },
  bastion: { series: 'heavy', ult: 'wall', absorb: 210, armor: 1.08 },
  meltdown: { series: 'standard', ult: 'meltdown', hotDmg: 1.5 },
  deflector: { series: 'standard', ult: 'deflect', perfect: 1.5 },
  mirror: { series: 'standard', ult: 'mirror', reflectDmg: 1.3 },
  rail: { series: 'standard', ult: 'rail', boltSpeed: 1.15 },
  shroud: { series: 'light', ult: 'shroud', speed: 1.08 },
}
export const SERIES = { light: 1, standard: 2, heavy: 3 }
export const WEIGHT = { base: 10, speed: 0.025 }
export const BODY = ['head', 'core', 'arms', 'legs', 'booster']
export const HANDS = ['left', 'right']
export const ARM_OF = { left: 'larm', right: 'rarm' }
export const CATALOG = { head: HEADS, core: CORES, arms: ARMS, legs: LEG_PARTS, booster: BOOSTERS, left: WEAPONS, right: WEAPONS }
export const DEFAULT_LOADOUT = { head: 'horn', core: 'furnace', arms: 'frame', legs: 'greaves', booster: 'thruster', left: 'rivet', right: 'saw' }
export const SETS = {
  duelist: { head: 'horn', core: 'furnace', arms: 'frame', legs: 'greaves', booster: 'twin', left: 'rivet', right: 'drill' },
  sniper: { head: 'visor', core: 'rail', arms: 'reed', legs: 'hover', booster: 'wisp', left: 'needle', right: 'laser' },
  brawler: { head: 'demon', core: 'fury', arms: 'brace', legs: 'quad', booster: 'comet', left: 'claws', right: 'katana' },
  tank: { head: 'medic', core: 'aegis', arms: 'anvil', legs: 'stompers', booster: 'rocket', left: 'scatter', right: 'hammer' },
  speedster: { head: 'crest', core: 'volt', arms: 'wire', legs: 'wheels', booster: 'flicker', left: 'gatling', right: 'saw' },
  artillery: { head: 'antenna', core: 'coolant', arms: 'bulwark', legs: 'treads', booster: 'thruster', left: 'mortar', right: 'missiles' },
}
export const GUN = WEAPONS.rivet
export const SAW = WEAPONS.saw
export const DASH = { ticks: 10, endLag: 6, slide: 0.4, vent: 25, afterburn: 48, feintRefund: 0.7 }
export const TRAILS = {
  arc: { life: 72, width: 0.5, dmg: 25, impact: 1, jam: 30 },
  flame: { life: 120, width: 0.55, dmg: 8, every: 15, heat: 6 },
  frost: { life: 150, width: 0.7 },
  smoke: { life: 180, width: 1.6 },
  magnet: { reach: 7, pull: 2.5 },
  clean: {},
}
export const DASH_MOVES = {
  dash: {},
  glide: { time: 1.6, dist: 1.4, steer: 0.09 },
  ram: { hit: { dmg: 45, impact: 3, push: 2.5 } },
  skitter: { dist: 0.6, charges: 2, cd: 0.65 },
  drift: { dist: 1.1, steer: 0.06, slide: 0.85 },
  leap: { time: 2.2, dist: 1.1, air: 1.6, land: { r: 2.2, dmg: 20, stun: 30, lift: true } },
  slam: { time: 1.6, dist: 0.5, air: 0.9, land: { r: 3, dmg: 30, impact: 3, stun: 36 } },
  double: { dist: 0.85, charges: 2, cd: 1 },
  pounce: { time: 2, dist: 1.3, air: 1.4, toCursor: true, land: { r: 1.6, dmg: 40, impact: 4 } },
  roll: { hit: { dmg: 35, impact: 2, push: 1.2, through: true } },
}
export const SHIELD = { arc: 50 * DEG, turn: (540 * DEG) / TICKS, perfect: 8, minHold: 20, maxHold: 90, recovery: 10, cd: 240, perfectCd: 120, absorb: 160, breakStagger: 24, breakCd: 540, load: 20 }
export const HOOK = { range: 13, speed: 40, radius: 0.4, dmg: 30, windup: 6, recovery: 14, cd: 480, load: 10, pull: 24, pullSpeed: 22, stop: 1.8, stun: 12 }
export const LANCE = { windup: 36, turn: (120 * DEG) / TICKS, length: 16, halfWidth: 0.7, base: 100, perHeat: 2, impact: 4, poise: 1, recoil: 2, recovery: 24, stuffRefund: 50, perfectCut: 0.5 }
export const ULT_RECOVERY = 20
export const HEAL = { x: ARENA.w / 2, y: ARENA.h / 2, radius: 0.9, amount: 60, first: 8 * TICKS, respawn: 15 * TICKS }
export const PICKUP = { first: 5 * TICKS, every: 12 * TICKS, warn: 2 * TICKS, radius: 0.7 }
export const PADS = [
  { x: CX - 23, y: CY - 10 }, { x: CX + 23, y: CY - 10 },
  { x: CX - 23, y: CY + 10 }, { x: CX + 23, y: CY + 10 },
  { x: CX, y: CY - 12 }, { x: CX, y: CY + 12 },
  { x: CX - 28, y: CY }, { x: CX + 28, y: CY },
]
export const ITEMS = {
  repair: { amount: 40 },
  shield: { absorb: 120, time: 8 * TICKS },
  speed: { time: 6 * TICKS, speed: 1.35, dashCd: 0.5 },
  power: { time: 6 * TICKS, dmg: 1.25 },
  coolant: { time: 5 * TICKS },
  surge: { amount: 35 },
}
export const TRAPS = {
  crush: { at: [{ x: CX - 10, y: 8 }, { x: CX + 10, y: ARENA.h - 8 }, { x: CX + 10, y: 8 }, { x: CX - 10, y: ARENA.h - 8 }], half: 1.5, every: 6 * TICKS, warn: TICKS, dmg: 55, impact: 3 },
  tesla: { at: [{ x: CX, y: CY - 5.5 }, { x: CX, y: CY + 5.5 }, { x: CX, y: CY - 18 }, { x: CX, y: CY + 18 }], r: 0.45, reach: 3, every: 4 * TICKS, warn: 48, dmg: 40, impact: 1 },
  oil: { at: [{ x: CX - 6.5, y: CY }, { x: CX + 6.5, y: CY }], r: 2, grip: 0.2 },
}
export const HAZARDS = { vents: 20 * TICKS, slot: 3 * TICKS, warn: TICKS, burn: 90, reach: 5, half: 1, dmg: 12, heat: 8, every: 30, close: 45 * TICKS, shrink: 18, wallDmg: 4, wallEvery: 15 }
const SOLIDS = [...PILLARS, ...TRAPS.tesla.at.map(p => ({ ...p, r: TRAPS.tesla.r }))]

export const elapsed = state => MATCH.time - state.clock
const cycle = (state, every, i) => (elapsed(state) + (i * every) / 2) % every
export const untilSlam = (state, i) => TRAPS.crush.every - cycle(state, TRAPS.crush.every, i)
export const untilZap = (state, i) => TRAPS.tesla.every - cycle(state, TRAPS.tesla.every, i)
export const shrinkOf = state => Math.max(0, Math.min(1, (elapsed(state) - HAZARDS.close) / (MATCH.time - HAZARDS.close))) * HAZARDS.shrink
export const onOil = m => m.loadout.legs !== 'hover' && TRAPS.oil.at.some(p => Math.hypot(m.x - p.x, m.y - p.y) < TRAPS.oil.r)

export function ventPhase(state) {
  const e = elapsed(state) - HAZARDS.vents
  if (e < 0) return null
  const p = e % HAZARDS.slot
  return { set: Math.floor(e / HAZARDS.slot) % 2, p, warn: p < HAZARDS.warn, burn: p >= HAZARDS.warn && p < HAZARDS.warn + HAZARDS.burn }
}

export function vents(shrink = 0) {
  const c = arenaCorners(-shrink)
  return WALLS.flatMap((w, i) => {
    const a = c[(i + WALLS.length - 1) % WALLS.length]
    return [0.25, 0.5, 0.75].map(f => ({ wall: i, x: a.x + (c[i].x - a.x) * f, y: a.y + (c[i].y - a.y) * f, dx: -w.nx, dy: -w.ny }))
  })
}
export const MATCH = { wins: 3, countdown: 3 * TICKS, time: 60 * TICKS, ko: 150, hitstop: 5, breakStop: 7, koStop: 24 }
export const IDLE = { mx: 0, my: 0, ax: 0, ay: 0, left: false, right: false, hook: false, shield: false, dash: false, ult: false }

export const normalize = lo => Object.fromEntries(Object.entries(DEFAULT_LOADOUT).map(([slot, def]) => [slot, lo && lo[slot] in CATALOG[slot] ? lo[slot] : def]))
export const maxArmor = lo => {
  const l = normalize(lo)
  const k = CORES[l.core].armor ?? 1
  const r = v => Math.round(v * k)
  return { head: r(HEADS[l.head].armor), rarm: r(ARMS[l.arms].armor), larm: r(ARMS[l.arms].armor), legs: r(LEG_PARTS[l.legs].armor) }
}
export const weightOf = lo => BODY.reduce((n, slot) => n + SERIES[CATALOG[slot][lo[slot]].series], 0)
export const speedOf = lo => 1 + (WEIGHT.base - weightOf(lo)) * WEIGHT.speed
export const ARMOR = maxArmor(DEFAULT_LOADOUT)
export const weapon = (m, hand) => WEAPONS[m.loadout[hand]]
export const isGun = w => w.kind !== 'melee'
export const arms = m => ARMS[m.loadout.arms]
export const feet = m => LEG_PARTS[m.loadout.legs]
export const booster = m => BOOSTERS[m.loadout.booster]
export const moveOf = m => DASH_MOVES[feet(m).move]
export const hidden = (state, m) => state.trails.some(tr => tr.kind === 'smoke' && segDist(tr.x1, tr.y1, tr.x2, tr.y2, m.x, m.y) < (tr.w ?? TRAILS.smoke.width))
export const airborne = m => m.act?.k === 'dash' && m.act.ph === 'go' && !!DASH_MOVES[m.act.move].air
export const heightOf = m => (airborne(m) ? Math.sin(Math.PI * (1 - m.act.t / m.act.T)) * DASH_MOVES[m.act.move].air : m.lift > 0 ? Math.sin((Math.PI * m.lift) / m.liftT) * 0.9 : 0)
const charges = lo => DASH_MOVES[LEG_PARTS[lo.legs].move].charges ?? 1
export const head = m => HEADS[m.loadout.head]
export const core = m => CORES[m.loadout.core]
export const ultOf = lo => CORES[lo.core].ult
export const ult = m => ULTS[core(m).ult]
const surgeK = m => (core(m).surgeGain ?? 1) * head(m).surge

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
const angleDiff = (a, b) => {
  let d = (a - b) % TAU
  if (d > Math.PI) d -= TAU
  if (d < -Math.PI) d += TAU
  return d
}
const turnToward = (from, to, max) => from + clamp(angleDiff(to, from), -max, max)
const inArc = (center, half, dx, dy) => Math.abs(angleDiff(Math.atan2(dy, dx), center)) <= half
const segDist = (x0, y0, x1, y1, px, py) => {
  const dx = x1 - x0
  const dy = y1 - y0
  const k = clamp(((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy || 1), 0, 1)
  return Math.hypot(x0 + dx * k - px, y0 + dy * k - py)
}
const clearLine = (x0, y0, x1, y1) => PILLARS.every(p => segDist(x0, y0, x1, y1, p.x, p.y) > p.r)
const jammed = (m, part) => m.armor[part] <= 0
const armCd = (m, part, cd) => (jammed(m, part) ? cd * JAM.cd : cd)
const skillCd = (m, k) => {
  if (k === 'hook') return HOOK.cd
  const w = weapon(m, k)
  return Math.round(armCd(m, ARM_OF[k], w.cd * arms(m).handling) * (!isGun(w) && m.buffs.berserk > 0 ? ULTS.berserk.meleeCd : 1))
}
const handTime = (m, ticks) => Math.round(ticks * arms(m).handling)
const windupOf = (m, k) => (k in ARM_OF ? handTime(m, weapon(m, k).windup) : k === 'hook' ? HOOK.windup : ult(m).windup)
const recoveryOf = (m, k) => (k in ARM_OF ? handTime(m, weapon(m, k).recovery) : k === 'hook' ? HOOK.recovery : ult(m).kind === 'lance' ? LANCE.recovery : ULT_RECOVERY)
const shieldUp = m => m.act?.k === 'shield' && m.act.ph === 'up'
const lancing = m => m.act?.k === 'ult' && m.act.ph === 'wind' && ult(m).kind === 'lance'
const poiseOf = m => feet(m).poise + (lancing(m) ? LANCE.poise : 0)
const hotOf = m => m.heat >= (core(m).hotAt ?? HEAT.hot)

function rng(state) {
  state.seed = (state.seed + 0x6d2b79f5) >>> 0
  let t = state.seed
  t = Math.imul(t ^ (t >>> 15), t | 1)
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

function power(m, melee) {
  const c = core(m)
  let k = (c.dmg ?? 1) * (m.buffs.power > 0 ? ITEMS.power.dmg : 1)
  if (c.fury) k *= 1 + c.fury * clamp((1 - m.armor.head / m.max.head) / 0.75, 0, 1)
  if (c.momentum) k *= 1 + c.momentum * Math.min(1, Math.hypot(m.vx, m.vy) / feet(m).top)
  if (melee && m.buffs.berserk > 0) k *= ULTS.berserk.meleeDmg
  return k
}

function makeMech(id, loadout, team, s) {
  const lo = normalize(loadout)
  const max = maxArmor(lo)
  return {
    id, team, loadout: lo, max, x: s.x, y: s.y, vx: 0, vy: 0, aim: s.aim, tx: s.x, ty: s.y,
    armor: { ...max }, heat: 0, ventDelay: 0, overheat: 0, surge: CORES[lo.core].surgeStart ?? 0,
    cd: { left: 0, right: 0, hook: 0, shield: 0, dash: 0 },
    buf: { left: 0, right: 0, hook: 0, dash: 0, ult: 0 },
    held: { left: false, right: false, hook: false, shield: false, dash: false, ult: false },
    buffs: { overdrive: 0, berserk: 0, bubble: 0, bubbleHp: 0, jam: 0, slow: 0, speed: 0, power: 0, cool: 0, deflect: 0, mirror: 0 },
    act: null, stagger: 0, pull: null, afterburn: 0, lastHitCast: 0, ko: false, dashes: charges(lo), lift: 0, liftT: 1,
  }
}

export function createState(loadouts = [], teams = FORMATS['1v1']) {
  const spawns = spawnsOf(teams)
  const state = {
    tick: 0, seed: 0x2545f491, mechs: teams.map((team, i) => makeMech(i, loadouts[i], team, spawns[i])),
    shots: [], lobs: [], mines: [], fields: [], trails: [], walls: [], fx: [],
    phase: 'countdown', timer: MATCH.countdown, clock: MATCH.time, round: 1, hitstop: 0,
    heal: { ready: false, timer: HEAL.first },
    score: Array(Math.max(...teams) + 1).fill(0), winner: -1, nextCast: 1, shrink: 0, finalKo: -1,
  }
  return resetPads(state)
}

export const foes = (state, id) => state.mechs.filter(t => !t.ko && t.team !== state.mechs[id].team)
const turns = state => state.mechs.map((_, i) => state.mechs[(i + state.tick) % state.mechs.length])

function resetPads(state) {
  state.pads = PADS.map(() => null)
  state.wave = { t: PICKUP.first, next: rollWave(state) }
  return state
}

function rollWave(state) {
  const kinds = Object.keys(ITEMS)
  return PADS.filter((_, i) => i % 2 === 0).map(() => kinds.splice(Math.floor(rng(state) * kinds.length), 1)[0])
}

export function step(state, inputs) {
  state.tick++
  state.fx = state.fx.filter(f => --f.t > 0)
  const ins = state.mechs.map((m, i) => inputs[i] ?? IDLE)
  if (state.hitstop > 0) {
    state.hitstop--
    state.mechs.forEach((m, i) => readButtons(m, ins[i], false))
    return state
  }
  if (state.phase === 'countdown') {
    if (state.timer % TICKS === 0) state.fx.push(state.timer > 0 ? { k: 'count', n: state.timer / TICKS, t: 50 } : { k: 'fight', t: 50 })
    state.mechs.forEach((m, i) => {
      readButtons(m, ins[i], true)
      m.tx = ins[i].ax
      m.ty = ins[i].ay
      m.aim = Math.atan2(m.ty - m.y, m.tx - m.x)
    })
    if (state.timer-- === 0) state.phase = 'fight'
    return state
  }
  if (state.phase === 'ko') {
    if (--state.timer > 0) return state
    if (Math.max(...state.score) >= MATCH.wins) state.phase = 'over'
    else resetRound(state)
    return state
  }
  if (state.phase === 'over') return state
  state.shrink = shrinkOf(state)
  for (const m of turns(state)) if (!m.ko) think(state, m, ins[m.id])
  moveShots(state)
  updateLobs(state)
  updateMines(state)
  updateFields(state)
  updateTrails(state)
  state.walls = state.walls.filter(w => --w.t > 0)
  for (const m of state.mechs) collide(m, state.shrink)
  const live = state.mechs.filter(m => !m.ko)
  live.forEach((a, i) => live.slice(i + 1).forEach(b => separate(a, b)))
  pickups(state)
  traps(state)
  checkKo(state)
  if (state.phase === 'fight' && --state.clock <= 0) timeUp(state)
  return state
}

export function hashState(state) {
  const s = JSON.stringify(state)
  let h = 0x811c9dc5
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return h
}

function readButtons(m, inp, decay) {
  for (const k in m.buf) {
    if (inp[k] && !m.held[k]) m.buf[k] = BUFFER
    else if (decay && m.buf[k] > 0 && m.stagger === 0) m.buf[k]--
  }
  for (const k in m.held) m.held[k] = !!inp[k]
}

function think(state, m, inp) {
  readButtons(m, inp, true)
  m.tx = inp.ax
  m.ty = inp.ay
  tickTimers(m)
  const aimTo = Math.atan2(inp.ay - m.y, inp.ax - m.x)
  if (!lancing(m)) m.aim = aimTo
  advance(state, m, inp, aimTo)
  start(state, m, inp)
  if (lancing(m)) m.aim = m.act.angle
  move(state, m, inp)
}

function tickTimers(m) {
  const n = m.buffs.overdrive > 0 ? 2 : 1
  for (const k in m.cd) m.cd[k] = Math.max(0, m.cd[k] - n)
  if (m.cd.dash === 0 && m.dashes < charges(m.loadout) && ++m.dashes < charges(m.loadout)) m.cd.dash = dashRecharge(m)
  if (m.lift > 0) m.lift--
  for (const k in m.buffs) if (k !== 'bubbleHp' && m.buffs[k] > 0) m.buffs[k]--
  if (m.afterburn > 0) m.afterburn--
  if (m.stagger > 0) m.stagger--
  if (m.overheat > 0) m.heat = (HEAT.max * --m.overheat) / HEAT.overheat
  else if (m.ventDelay > 0) m.ventDelay--
  else m.heat = Math.max(0, m.heat - HEAT.vent * (core(m).vent ?? 1) * DT)
}

function addHeat(m, n) {
  if (m.buffs.overdrive > 0 || m.buffs.cool > 0) return
  m.heat += n * (core(m).heatGain ?? 1)
  m.ventDelay = HEAT.ventDelay
  if (m.heat >= HEAT.max) {
    m.heat = HEAT.max
    m.overheat = HEAT.overheat
  }
}

function push(m, dx, dy, meters) {
  const v = Math.sqrt(2 * DECEL * meters)
  m.vx += dx * v
  m.vy += dy * v
}

function advance(state, m, inp, aimTo) {
  const a = m.act
  if (!a) return
  if (shieldUp(m)) {
    a.t++
    a.angle = turnToward(a.angle, aimTo, SHIELD.turn)
    if ((!inp.shield && a.t >= SHIELD.minHold) || a.t >= SHIELD.maxHold) {
      m.cd.shield = Math.round((a.perfect ? SHIELD.perfectCd : SHIELD.cd) * (core(m).shieldCd ?? 1))
      m.act = { k: 'shield', ph: 'rec', t: SHIELD.recovery }
    }
    return
  }
  if (lancing(m)) a.angle = turnToward(a.angle, aimTo, LANCE.turn)
  if (a.k === 'dash' && a.ph === 'go') {
    const mv = DASH_MOVES[a.move]
    if (mv.steer && (inp.mx || inp.my)) {
      const ang = turnToward(Math.atan2(a.dy, a.dx), Math.atan2(inp.my, inp.mx), mv.steer)
      a.dx = Math.cos(ang)
      a.dy = Math.sin(ang)
    }
    m.vx = a.dx * a.speed
    m.vy = a.dy * a.speed
    if (a.trail) Object.assign(a.trail, { x2: m.x, y2: m.y })
    if (mv.hit && !a.hit) bump(state, m, a, mv.hit)
  }
  if (--a.t > 0) return
  if (a.ph === 'wind') {
    const w = a.k in ARM_OF ? weapon(m, a.k) : null
    if (a.k === 'hook') throwHook(state, m)
    else if (!w) fireUlt(state, m, a)
    else if (isGun(w)) fire(state, m, a.k, a.follow)
    else swing(state, m, a.k, a.follow)
    const more = w && !isGun(w) && !a.follow ? (w.hits ?? 1) - 1 : 0
    m.act = more > 0 ? { k: a.k, ph: 'combo', t: w.gap, n: more } : { k: a.k, ph: 'rec', t: recoveryOf(m, a.k) }
  } else if (a.ph === 'combo') {
    swing(state, m, a.k, false)
    m.act = a.n > 1 ? { k: a.k, ph: 'combo', t: weapon(m, a.k).gap, n: a.n - 1 } : { k: a.k, ph: 'rec', t: recoveryOf(m, a.k) }
  } else if (a.k === 'dash' && a.ph === 'go') {
    const mv = DASH_MOVES[a.move]
    m.vx *= mv.slide ?? DASH.slide
    m.vy *= mv.slide ?? DASH.slide
    if (mv.land) land(state, m, mv.land)
    if (booster(m).trail === 'magnet') magnetize(state, m)
    m.act = { k: 'dash', ph: 'lag', t: DASH.endLag }
  } else {
    if (a.k === 'dash') m.afterburn = Math.round(DASH.afterburn * (core(m).afterburn ?? 1))
    m.act = null
  }
}

function start(state, m, inp) {
  if (m.stagger > 0 || m.overheat > 0 || m.pull || m.buffs.jam > 0) return
  const a = m.act
  const windup = a?.ph === 'wind'
  const attackRec = a?.ph === 'rec' && (a.k in ARM_OF || a.k === 'hook')
  if (m.buf.dash && m.dashes > 0 && m.buffs.slow === 0 && (!a || windup || attackRec)) return dash(state, m, inp, windup ? a : null)
  if (a) return
  if (m.buf.ult && m.surge >= SURGE.max) {
    m.buf.ult = 0
    m.surge -= SURGE.max
    m.act = { k: 'ult', ph: 'wind', t: ult(m).windup, angle: m.aim }
    state.fx.push({ k: 'charge', id: m.id, ult: ult(m).kind, x: m.x, y: m.y, t: ult(m).windup })
    return
  }
  if (inp.shield && m.cd.shield === 0) {
    addHeat(m, SHIELD.load)
    m.act = { k: 'shield', ph: 'up', t: 0, angle: m.aim, absorbed: 0, perfect: false }
    return
  }
  const guns = HANDS.filter(h => isGun(weapon(m, h)))
  for (const k of [...HANDS.filter(h => !guns.includes(h)), 'hook', ...guns]) {
    if (!(m.buf[k] || (k !== 'hook' && weapon(m, k).auto && m.held[k])) || m.cd[k] > 0) continue
    m.buf[k] = 0
    m.cd[k] = skillCd(m, k)
    m.act = { k, ph: 'wind', t: windupOf(m, k), follow: k !== 'hook' && m.afterburn > 0 }
    if (k !== 'hook') m.afterburn = 0
    return
  }
}

const dashRecharge = m => Math.round(booster(m).dashCd * (moveOf(m).cd ?? 1) * (jammed(m, 'legs') ? JAM.dashCd : 1) * (core(m).dashCd ?? 1) * (m.buffs.speed > 0 ? ITEMS.speed.dashCd : 1))

function dash(state, m, inp, feinted) {
  if (feinted?.k === 'ult') m.surge += SURGE.max * DASH.feintRefund
  else if (feinted) m.cd[feinted.k] = Math.floor(skillCd(m, feinted.k) * (1 - DASH.feintRefund))
  const mv = moveOf(m)
  let dx = mv.toCursor ? 0 : inp.mx
  let dy = mv.toCursor ? 0 : inp.my
  let len = Math.hypot(dx, dy)
  if (len === 0) {
    dx = inp.ax - m.x
    dy = inp.ay - m.y
    len = Math.hypot(dx, dy) || 1
  }
  const legs = jammed(m, 'legs')
  m.buf.dash = 0
  m.dashes--
  if (m.cd.dash === 0) m.cd.dash = dashRecharge(m)
  m.heat = core(m).dashVentAll ? 0 : Math.max(0, m.heat - DASH.vent)
  const ticks = Math.round(DASH.ticks * (mv.time ?? 1))
  let dist = booster(m).dash * (core(m).dashDist ?? 1) * (mv.dist ?? 1) * (legs ? JAM.dash : 1)
  if (mv.toCursor) dist = Math.min(dist, Math.max(1, len))
  const ux = dx / len
  const uy = dy / len
  const end = clampArena(m.x + ux * dist, m.y + uy * dist, MECH_R + state.shrink)
  const kind = booster(m).trail
  const trail = TRAILS[kind].life ? { kind, owner: m.id, x1: m.x, y1: m.y, x2: m.x, y2: m.y, t: TRAILS[kind].life, T: TRAILS[kind].life, cast: 0, hit: false } : null
  if (trail) state.trails.push(trail)
  m.act = { k: 'dash', ph: 'go', t: ticks, T: ticks, move: feet(m).move, dx: ux, dy: uy, speed: (dist / ticks) * TICKS, lx: end.x, ly: end.y, hit: false, trail }
  state.fx.push({ k: 'dash', id: m.id, x: m.x, y: m.y, t: 6 })
}

function magnetize(state, m) {
  const M = TRAILS.magnet
  for (const t of foes(state, m.id)) {
    const d = Math.hypot(m.x - t.x, m.y - t.y)
    if (airborne(t) || d > M.reach || d < 2 * MECH_R) continue
    push(t, (m.x - t.x) / d, (m.y - t.y) / d, M.pull)
    state.fx.push({ k: 'magnet', id: m.id, x: m.x, y: m.y, x1: m.x, y1: m.y, x2: t.x, y2: t.y, t: 18 })
  }
}

function updateTrails(state) {
  state.trails = state.trails.filter(tr => {
    const T = TRAILS[tr.kind]
    const atk = state.mechs[tr.owner]
    for (const t of foes(state, tr.owner)) {
      if (airborne(t) || segDist(tr.x1, tr.y1, tr.x2, tr.y2, t.x, t.y) >= T.width + MECH_R) continue
      const from = Math.atan2((tr.y1 + tr.y2) / 2 - t.y, (tr.x1 + tr.x2) / 2 - t.x)
      tr.cast ||= state.nextCast++
      if (tr.kind === 'arc' && !tr.hit) {
        tr.hit = true
        hit(state, atk, t, Math.floor(T.dmg * power(atk, false)), 'ARMS', T.impact, from, tr.cast)
        t.buffs.jam = Math.max(t.buffs.jam, T.jam)
        state.fx.push({ k: 'zap', kind: 'tesla', id: atk.id, x1: (tr.x1 + tr.x2) / 2, y1: (tr.y1 + tr.y2) / 2, x2: t.x, y2: t.y, t: 10 })
      } else if (tr.kind === 'flame' && tr.t % T.every === 0) {
        hit(state, atk, t, Math.floor(T.dmg * power(atk, false)), 'LEGS', 0, from, tr.cast)
        addHeat(t, T.heat)
      } else if (tr.kind === 'frost') t.buffs.slow = Math.max(t.buffs.slow, 2)
    }
    return --tr.t > 0
  })
}

function bump(state, m, a, h) {
  const t = foes(state, m.id).find(t => !airborne(t) && Math.hypot(t.x - m.x, t.y - m.y) <= 2 * MECH_R + 0.25)
  if (!t) return
  a.hit = true
  hit(state, m, t, Math.floor(h.dmg * power(m, true)), 'ARMS', h.impact, Math.atan2(m.y - t.y, m.x - t.x), state.nextCast++)
  push(t, a.dx, a.dy, h.push)
  if (!h.through) a.t = 1
}

function land(state, m, L) {
  state.fx.push({ k: 'land', id: m.id, x: m.x, y: m.y, r: L.r, t: 20 })
  for (const t of foes(state, m.id)) {
    if (airborne(t) || Math.hypot(t.x - m.x, t.y - m.y) > L.r + MECH_R) continue
    hit(state, m, t, Math.floor(L.dmg * power(m, true)), 'LEGS', L.impact ?? 0, Math.atan2(m.y - t.y, m.x - t.x), state.nextCast++)
    if (!L.stun) continue
    interrupt(t)
    t.stagger = Math.max(t.stagger, L.stun)
    if (L.lift) Object.assign(t, { lift: L.stun, liftT: L.stun })
  }
}

function aimFrom(m, x, y) {
  return Math.hypot(m.tx - x, m.ty - y) > 1.5 ? Math.atan2(m.ty - y, m.tx - x) : m.aim
}

function fire(state, m, hand, follow) {
  const g = weapon(m, hand)
  const p = follow ? g.fan : g
  const cast = state.nextCast++
  const jam = jammed(m, ARM_OF[hand]) ? JAM.dmg : 1
  const hot = hotOf(m)
  const dmg = Math.floor(p.dmg * (hot ? core(m).hotDmg ?? HEAT.hotDmg : 1) * jam * power(m, false))
  const impact = g.impact + (hot ? 1 : 0)
  const fx = Math.cos(m.aim)
  const fy = Math.sin(m.aim)
  const side = hand === 'right' ? MUZZLE : -MUZZLE
  const mx = m.x + fx * MECH_R - fy * side
  const my = m.y + fy * MECH_R + fx * side
  const dir = aimFrom(m, mx, my)
  const n = p.pellets ?? 1
  const spread = p.spread ?? 0
  if (g.kind === 'lob') {
    const d = Math.min(g.range, Math.hypot(m.tx - m.x, m.ty - m.y))
    const a = Math.atan2(m.ty - m.y, m.tx - m.x)
    for (let i = 0; i < n; i++) {
      const off = (i - (n - 1) / 2) * spread
      const { x, y } = clampArena(m.x + Math.cos(a) * d - Math.sin(a) * off, m.y + Math.sin(a) * d + Math.cos(a) * off, state.shrink)
      state.lobs.push({ kind: 'shell', owner: m.id, sx: mx, sy: my, x, y, t: g.delay, T: g.delay, r: g.splash, dmg, impact, cast })
    }
  } else if (g.kind === 'ray') {
    for (let i = 0; i < n; i++) lineAttack(state, m, mx, my, dir + (i - (n - 1) / 2) * spread, g.range, g.halfWidth, dmg, impact, 'ARMS', cast, 'laser', { perfectCut: 0 })
  } else if (g.kind === 'cone') {
    coneAttack(state, m, dir, g, dmg, impact, cast)
  } else {
    for (let i = 0; i < n; i++) {
      const off = (i - (n - 1) / 2) * spread + (g.jitter ? (rng(state) - 0.5) * 2 * g.jitter : 0)
      spawnShot(state, m, cast, mx, my, dir + off, core(m).boltSpeed ? { ...g, speed: g.speed * core(m).boltSpeed } : g, dmg, impact, g.shot, { homing: g.homing, bounces: g.bounces })
    }
  }
  state.fx.push({ k: 'muzzle', id: m.id, hand, gun: m.loadout[hand], x: mx, y: my, a: dir, t: 8 })
  addHeat(m, g.load)
  push(m, -fx, -fy, g.recoil)
}

function throwHook(state, m) {
  const fx = Math.cos(m.aim)
  const fy = Math.sin(m.aim)
  const x = m.x + fx * MECH_R
  const y = m.y + fy * MECH_R
  spawnShot(state, m, state.nextCast++, x, y, aimFrom(m, x, y), { ...HOOK, range: HOOK.range * (core(m).hookRange ?? 1) }, HOOK.dmg, 0, 'hook')
  state.fx.push({ k: 'hookOut', id: m.id, x, y, t: 6 })
  addHeat(m, HOOK.load)
}

function spawnShot(state, m, cast, x, y, angle, spec, dmg, impact, kind, extra = {}) {
  state.shots.push({
    kind, owner: m.id, cast, x, y, vx: Math.cos(angle) * spec.speed, vy: Math.sin(angle) * spec.speed,
    r: spec.radius, left: spec.range - MECH_R, dmg, impact, reflected: false,
    homing: extra.homing ?? 0, bounces: extra.bounces ?? 0,
  })
}

function swing(state, m, hand, spin) {
  const b = weapon(m, hand)
  const cast = state.nextCast++
  const hot = hotOf(m)
  const jam = jammed(m, ARM_OF[hand]) ? JAM.dmg : 1
  const arc = spin ? Math.PI : b.arc
  for (const t of foes(state, m.id)) {
    const dx = t.x - m.x
    const dy = t.y - m.y
    if (airborne(t) || Math.hypot(dx, dy) > b.range + MECH_R || !inArc(m.aim, arc, dx, dy)) continue
    const dmg = Math.floor((spin ? b.spinDmg : b.dmg) * (hot ? core(m).hotDmg ?? HEAT.hotDmg : 1) * jam * power(m, true))
    hit(state, m, t, dmg, 'LEGS', b.impact + (hot ? 1 : 0), Math.atan2(-dy, -dx), cast)
    if (b.yank) push(t, -dx / Math.hypot(dx, dy), -dy / Math.hypot(dx, dy), b.yank)
  }
  state.fx.push({ k: 'slash', id: m.id, hand, blade: m.loadout[hand], x: m.x, y: m.y, a: m.aim, arc, range: b.range, t: 12 })
  addHeat(m, b.load)
  push(m, Math.cos(m.aim), Math.sin(m.aim), b.lunge)
}

function fireUlt(state, m, a) {
  const h = ult(m)
  const near = (x, y, r) => foes(state, m.id).filter(t => Math.hypot(t.x - x, t.y - y) <= r)
  const cast = state.nextCast++
  const target = range => {
    const d = Math.min(range, Math.hypot(m.tx - m.x, m.ty - m.y))
    const ang = Math.atan2(m.ty - m.y, m.tx - m.x)
    return clampArena(m.x + Math.cos(ang) * d, m.y + Math.sin(ang) * d, state.shrink)
  }
  state.fx.push({ k: 'ult', id: m.id, ult: h.kind, x: m.x, y: m.y, t: 30 })
  if (h.kind === 'lance') return fireLance(state, m, a.angle)
  if (h.kind === 'swarm') {
    for (let i = 0; i < h.count; i++) {
      const ang = m.aim + (i / (h.count - 1) - 0.5) * h.spread
      spawnShot(state, m, cast, m.x + Math.cos(ang) * MECH_R, m.y + Math.sin(ang) * MECH_R, ang, { speed: h.speed, radius: 0.3, range: 40 }, Math.floor(h.dmg * power(m, false)), 1, 'missile', { homing: h.homing })
    }
  } else if (h.kind === 'overdrive') m.buffs.overdrive = h.time
  else if (h.kind === 'berserk') m.buffs.berserk = h.time
  else if (h.kind === 'bubble') {
    m.buffs.bubble = h.time
    m.buffs.bubbleHp = h.absorb
  } else if (h.kind === 'repair') {
    for (const p in m.armor) m.armor[p] = Math.min(m.max[p], Math.max(0, m.armor[p]) + h.amount)
    m.heat = 0
    state.fx.push({ k: 'heal', id: m.id, x: m.x, y: m.y, n: h.amount, t: 40 })
  } else if (h.kind === 'emp') {
    state.fx.push({ k: 'emp', id: m.id, x: m.x, y: m.y, r: h.radius, t: 24 })
    for (const t of near(m.x, m.y, h.radius + MECH_R)) {
      hit(state, m, t, Math.floor(h.dmg * power(m, false)), 'ARMS', 0, Math.atan2(m.y - t.y, m.x - t.x), cast)
      interrupt(t)
      t.buffs.jam = h.jam
    }
  } else if (h.kind === 'orbital') {
    const p = target(h.range)
    state.lobs.push({ kind: 'strike', owner: m.id, sx: m.x, sy: m.y, x: p.x, y: p.y, t: h.delay, T: h.delay, r: h.radius, dmg: Math.floor(h.dmg * power(m, false)), impact: h.impact, cast })
  } else if (h.kind === 'stasis') {
    const p = target(h.range)
    state.fields.push({ kind: 'stasis', owner: m.id, x: p.x, y: p.y, r: h.radius, t: h.time, T: h.time })
    for (const t of near(p.x, p.y, h.radius)) hit(state, m, t, Math.floor(h.dmg * power(m, false)), 'ARMS', 0, Math.atan2(p.y - t.y, p.x - t.x), cast)
  } else if (h.kind === 'mines') {
    for (let i = 0; i < h.count; i++) {
      const ang = (i / h.count) * TAU
      state.mines.push({ owner: m.id, ...clampArena(m.x + Math.cos(ang) * h.ring, m.y + Math.sin(ang) * h.ring, 1 + state.shrink), arm: h.arm, life: h.life, dmg: Math.floor(h.dmg * power(m, false)), cast: state.nextCast++ })
    }
  } else if (h.kind === 'blink') {
    const p = target(h.range)
    state.lobs.push({ kind: 'decoy', owner: m.id, sx: m.x, sy: m.y, x: m.x, y: m.y, t: h.delay, T: h.delay, r: h.radius, dmg: Math.floor(h.dmg * power(m, false)), impact: h.impact, cast })
    state.fx.push({ k: 'blink', id: m.id, x: m.x, y: m.y, x2: p.x, y2: p.y, a: m.aim, t: 20 })
    Object.assign(m, { x: p.x, y: p.y, vx: 0, vy: 0 })
  } else if (h.kind === 'well') {
    const p = target(h.range)
    state.fields.push({ kind: 'well', owner: m.id, x: p.x, y: p.y, r: h.radius, t: h.time, T: h.time })
    for (const t of near(p.x, p.y, h.radius)) hit(state, m, t, Math.floor(h.dmg * power(m, false)), 'ARMS', 0, Math.atan2(p.y - t.y, p.x - t.x), cast)
  } else if (h.kind === 'wall') {
    const fx = Math.cos(m.aim)
    const fy = Math.sin(m.aim)
    const cx = m.x + fx * h.dist
    const cy = m.y + fy * h.dist
    state.walls.push({ owner: m.id, x1: cx - (fy * h.len) / 2, y1: cy + (fx * h.len) / 2, x2: cx + (fy * h.len) / 2, y2: cy - (fx * h.len) / 2, t: h.time, T: h.time })
  } else if (h.kind === 'meltdown') {
    state.fx.push({ k: 'boom', x: m.x, y: m.y, r: h.radius, big: true, t: 22 })
    for (const t of near(m.x, m.y, h.radius + MECH_R)) hit(state, m, t, Math.floor((h.base + h.perHeat * m.heat) * power(m, false)), 'ARMS', h.impact, Math.atan2(m.y - t.y, m.x - t.x), cast)
    Object.assign(m, { heat: 0, overheat: 0, ventDelay: 0 })
  } else if (h.kind === 'deflect') m.buffs.deflect = h.time
  else if (h.kind === 'mirror') m.buffs.mirror = h.time
  else if (h.kind === 'rail') {
    lineAttack(state, m, m.x + Math.cos(m.aim) * MECH_R, m.y + Math.sin(m.aim) * MECH_R, m.aim, h.length, h.halfWidth, Math.floor(h.dmg * power(m, false)), h.impact, 'ARMS', cast, 'rail', { perfectCut: 0.5, through: true })
  } else if (h.kind === 'shroud') state.trails.push({ kind: 'smoke', owner: m.id, x1: m.x, y1: m.y, x2: m.x, y2: m.y, t: h.time, T: h.time, cast: 0, hit: false, w: h.radius })
}

const crossT = (ax, ay, bx, by, w) => {
  const rx = bx - ax
  const ry = by - ay
  const sx = w.x2 - w.x1
  const sy = w.y2 - w.y1
  const den = rx * sy - ry * sx
  if (Math.abs(den) < 1e-9) return null
  const qx = w.x1 - ax
  const qy = w.y1 - ay
  const k = (qx * sy - qy * sx) / den
  const j = (qx * ry - qy * rx) / den
  return k >= 0 && k <= 1 && j >= 0 && j <= 1 ? k : null
}
const perfectOf = t => SHIELD.perfect * (core(t).perfect ?? 1)

function reflect(state, s, t) {
  Object.assign(s, { owner: t.id, vx: -s.vx, vy: -s.vy, left: 40, homing: 0, reflected: true, cast: state.nextCast++, dmg: Math.floor(s.dmg * (core(t).reflectDmg ?? 1)) })
  state.fx.push({ k: 'parry', x: s.x, y: s.y, t: 14 })
}

const enemyMissile = (state, s, team) => s.kind === 'missile' && state.mechs[s.owner].team !== team

function shootDown(state, s) {
  state.fx.push({ k: 'boom', x: s.x, y: s.y, r: 0.7, big: false, t: 22 })
  return false
}

function intercept(state, from) {
  const dead = new Set()
  for (const m of state.shots) {
    if (m.kind !== 'missile' || dead.has(m)) continue
    const [mx, my] = from.get(m)
    const b = state.shots.find(b => b !== m && b.kind !== 'hook' && !dead.has(b) && enemyMissile(state, m, state.mechs[b.owner].team) && segDist(from.get(b)[0] - mx, from.get(b)[1] - my, b.x - m.x, b.y - m.y, 0, 0) < m.r + b.r)
    if (!b) continue
    dead.add(m).add(b)
    shootDown(state, m)
  }
  if (dead.size) state.shots = state.shots.filter(s => !dead.has(s))
}

function moveShots(state) {
  const from = new Map(state.shots.map(s => [s, [s.x, s.y]]))
  state.shots = state.shots.filter(s => {
    const enemies = foes(state, s.owner)
    const dist = t => Math.hypot(t.x - s.x, t.y - s.y)
    const prey = enemies.reduce((a, t) => (!a || dist(t) < dist(a) ? t : a), null)
    if (s.homing && prey) {
      const sp = Math.hypot(s.vx, s.vy)
      const a = turnToward(Math.atan2(s.vy, s.vx), Math.atan2(prey.y - s.y, prey.x - s.x), s.homing * DT)
      s.vx = Math.cos(a) * sp
      s.vy = Math.sin(a) * sp
    }
    for (const t of enemies) {
      if (!(t.buffs.deflect > 0 && dist(t) < ULTS.deflect.radius)) continue
      const sp = Math.hypot(s.vx, s.vy)
      const a = turnToward(Math.atan2(s.vy, s.vx), Math.atan2(s.y - t.y, s.x - t.x), ULTS.deflect.turn)
      s.vx = Math.cos(a) * sp
      s.vy = Math.sin(a) * sp
    }
    const x0 = s.x
    const y0 = s.y
    s.x += s.vx * DT
    s.y += s.vy * DT
    s.left -= Math.hypot(s.vx, s.vy) * DT
    if (state.walls.some(w => crossT(x0, y0, s.x, s.y, w) !== null)) {
      state.fx.push({ k: 'ping', x: s.x, y: s.y, a: Math.atan2(s.vy, s.vx), t: 8 })
      return false
    }
    const from0 = t => Math.hypot(t.x - x0, t.y - y0)
    const touched = enemies.filter(t => !airborne(t) && segDist(x0, y0, s.x, s.y, t.x, t.y) < MECH_R + s.r)
    if (touched.length) return shotHits(state, s, touched.reduce((a, t) => (from0(t) < from0(a) ? t : a)))
    const wall = WALLS.find(w => s.x * w.nx + s.y * w.ny >= w.d - state.shrink)
    const pillar = PILLARS.find(p => segDist(x0, y0, s.x, s.y, p.x, p.y) < p.r + s.r)
    if (wall || pillar) {
      state.fx.push({ k: 'ping', ...clampArena(s.x, s.y, state.shrink), a: Math.atan2(s.vy, s.vx), t: 8 })
      if (s.bounces <= 0) return false
      s.bounces--
      if (wall) {
        const dot = s.vx * wall.nx + s.vy * wall.ny
        s.vx -= 2 * dot * wall.nx
        s.vy -= 2 * dot * wall.ny
      }
      if (pillar) {
        const nx = (s.x - pillar.x) / (Math.hypot(s.x - pillar.x, s.y - pillar.y) || 1)
        const ny = (s.y - pillar.y) / (Math.hypot(s.x - pillar.x, s.y - pillar.y) || 1)
        const dot = s.vx * nx + s.vy * ny
        s.vx -= 2 * dot * nx
        s.vy -= 2 * dot * ny
        s.x = pillar.x + nx * (pillar.r + s.r + 0.05)
        s.y = pillar.y + ny * (pillar.r + s.r + 0.05)
      }
      Object.assign(s, clampArena(s.x, s.y, 0.01 + state.shrink))
      return true
    }
    return s.left > 0
  })
  intercept(state, from)
}

function shotHits(state, s, t) {
  const atk = state.mechs[s.owner]
  const from = Math.atan2(-s.vy, -s.vx)
  const mirror = t.buffs.mirror > 0 && inArc(t.aim, ULTS.mirror.arc, -s.vx, -s.vy)
  if (mirror || (shieldUp(t) && inArc(t.act.angle, SHIELD.arc, -s.vx, -s.vy))) {
    if (s.kind === 'hook' || s.kind === 'flame') {
      state.fx.push({ k: 'ping', x: s.x, y: s.y, a: Math.atan2(s.vy, s.vx), t: 8 })
      return false
    }
    if (mirror || t.act.t < perfectOf(t)) {
      if (!mirror) perfectGuard(t)
      reflect(state, s, t)
      return true
    }
    const through = block(t, s.dmg)
    if (through > 0) hit(state, atk, t, through, 'ARMS', s.impact, from, s.cast)
    return false
  }
  hit(state, atk, t, s.dmg, 'ARMS', s.impact, from, s.cast)
  if (s.kind === 'hook' && !t.ko) {
    interrupt(t)
    t.pull = { by: atk.id, t: HOOK.pull }
    t.stagger = Math.max(t.stagger, HOOK.pull + HOOK.stun)
    state.fx.push({ k: 'hooked', id: t.id, by: atk.id, x: t.x, y: t.y, t: 12 })
  }
  return false
}

function perfectGuard(t) {
  t.act.perfect = true
  t.surge = Math.min(SURGE.max, t.surge + SURGE.perfect)
}

function block(t, dmg) {
  const cap = core(t).absorb ?? SHIELD.absorb
  t.act.absorbed += dmg
  if (t.act.absorbed <= cap) return 0
  const through = t.act.absorbed - cap
  guardBreak(t)
  return through
}

function guardBreak(t) {
  t.act = null
  t.cd.shield = Math.round(SHIELD.breakCd * (core(t).shieldCd ?? 1))
  t.stagger = Math.max(t.stagger, SHIELD.breakStagger)
}

function lineAttack(state, m, sx, sy, angle, length, halfWidth, dmg, impact, tag, cast, kind, guard) {
  const dx = Math.cos(angle)
  const dy = Math.sin(angle)
  let len = length
  for (const p of guard.through ? [] : PILLARS) {
    const d = rayCircle(sx, sy, dx, dy, p)
    if (d !== null && d < len) len = d
  }
  for (const w of guard.through ? [] : state.walls) {
    const k = crossT(sx, sy, sx + dx * len, sy + dy * len, w)
    if (k !== null) len *= k
  }
  for (const t of foes(state, m.id)) {
    const px = t.x - sx
    const py = t.y - sy
    const along = px * dx + py * dy
    if (airborne(t) || along <= -MECH_R || along - MECH_R >= len || Math.abs(px * dy - py * dx) >= halfWidth + MECH_R) continue
    let d = dmg
    if (t.buffs.mirror > 0 && inArc(t.aim, ULTS.mirror.arc, -dx, -dy)) d = 0
    else if (shieldUp(t) && inArc(t.act.angle, SHIELD.arc, -dx, -dy)) {
      if (t.act.t < perfectOf(t)) {
        perfectGuard(t)
        d *= guard.perfectCut
      } else {
        d = block(t, d)
        if (guard.breaks && shieldUp(t)) guardBreak(t)
      }
    }
    if (d > 0) hit(state, m, t, d, tag, impact, Math.atan2(-dy, -dx), cast)
  }
  state.shots = state.shots.filter(s => !enemyMissile(state, s, m.team) || segDist(sx, sy, sx + dx * len, sy + dy * len, s.x, s.y) >= halfWidth + s.r || shootDown(state, s))
  state.fx.push({ k: kind === 'laser' ? 'zap' : 'beam', kind, id: m.id, x1: sx, y1: sy, x2: sx + dx * len, y2: sy + dy * len, t: kind === 'laser' ? 10 : 18 })
}

function coneAttack(state, m, dir, g, dmg, impact, cast) {
  const inside = foes(state, m.id).filter(t => {
    const dx = t.x - m.x
    const dy = t.y - m.y
    return !airborne(t) && Math.hypot(dx, dy) <= g.range + MECH_R && inArc(dir, g.arc, dx, dy) && clearLine(m.x, m.y, t.x, t.y) && !state.walls.some(w => crossT(m.x, m.y, t.x, t.y, w) !== null) && !(t.buffs.mirror > 0 && inArc(t.aim, ULTS.mirror.arc, -dx, -dy))
  })
  for (const t of inside) {
    const dx = t.x - m.x
    const dy = t.y - m.y
    const from = Math.atan2(-dy, -dx)
    if (shieldUp(t) && inArc(t.act.angle, SHIELD.arc, -dx, -dy)) {
      const through = t.act.t < perfectOf(t) ? 0 : block(t, dmg)
      if (t.act?.t < perfectOf(t)) perfectGuard(t)
      if (through > 0) hit(state, m, t, through, 'ARMS', impact, from, cast)
    } else hit(state, m, t, dmg, 'ARMS', impact, from, cast)
  }
  const ends = inside.length ? inside : [{ x: m.x + Math.cos(dir) * g.range, y: m.y + Math.sin(dir) * g.range }]
  for (const e of ends) state.fx.push({ k: 'zap', kind: 'tesla', id: m.id, x1: m.x, y1: m.y, x2: e.x, y2: e.y, t: 10 })
}

function fireLance(state, m, angle) {
  const sx = m.x + Math.cos(angle) * MECH_R
  const sy = m.y + Math.sin(angle) * MECH_R
  lineAttack(state, m, sx, sy, angle, LANCE.length, LANCE.halfWidth, (LANCE.base + LANCE.perHeat * m.heat) * power(m, false), LANCE.impact, 'HEAD', state.nextCast++, 'lance', { perfectCut: LANCE.perfectCut, breaks: true })
  m.heat = 0
  m.ventDelay = 0
  push(m, -Math.cos(angle), -Math.sin(angle), LANCE.recoil)
}

function rayCircle(sx, sy, dx, dy, p) {
  const fx = sx - p.x
  const fy = sy - p.y
  const b = fx * dx + fy * dy
  const disc = b * b - (fx * fx + fy * fy - p.r * p.r)
  if (disc < 0) return null
  const d = -b - Math.sqrt(disc)
  return d >= 0 ? d : null
}

function hit(state, atk, t, raw, tag, impact, from, cast) {
  const rel = angleDiff(from, t.aim)
  let dmg = Math.round(raw * (Math.abs(rel) >= HIT.rearArc ? HIT.rear : 1))
  dmg = soak(state, t, dmg)
  if (dmg <= 0) return
  const front = Math.abs(rel) <= HIT.split || Math.abs(rel) >= Math.PI - HIT.split
  const side = front ? (t.armor.larm < t.armor.rarm ? 'larm' : 'rarm') : rel < 0 ? 'larm' : 'rarm'
  hurt(state, t, tag === 'HEAD' ? 'head' : tag === 'LEGS' ? 'legs' : side, dmg)
  const c = core(atk)
  if (c.leech) {
    const worst = Object.keys(atk.armor).reduce((w, p) => (atk.armor[p] / atk.max[p] < atk.armor[w] / atk.max[w] ? p : w))
    atk.armor[worst] = Math.min(atk.max[worst], Math.max(0, atk.armor[worst]) + dmg * c.leech)
  }
  const gain = surgeK(atk)
  if (atk.lastHitCast !== cast) {
    atk.lastHitCast = cast
    atk.surge += SURGE.perHit * gain
  }
  atk.surge = Math.min(SURGE.max, atk.surge + dmg * SURGE.dealt * gain)
  t.surge = Math.min(SURGE.max, t.surge + dmg * SURGE.taken * surgeK(t))
  const poise = poiseOf(t)
  if (impact >= poise) {
    stagger(t, impact, poise, from)
    state.hitstop = Math.max(state.hitstop, MATCH.hitstop)
  }
  state.fx.push({ k: 'hit', id: t.id, x: t.x, y: t.y, n: dmg, head: tag === 'HEAD', from, t: 10 })
}

function soak(state, t, dmg) {
  if (!(t.buffs.bubble > 0 && t.buffs.bubbleHp > 0)) return dmg
  const n = Math.min(dmg, t.buffs.bubbleHp)
  t.buffs.bubbleHp -= n
  state.fx.push({ k: 'soak', id: t.id, x: t.x, y: t.y, t: 10 })
  return dmg - n
}

function envHit(state, t, raw, part, impact, from) {
  const dmg = soak(state, t, raw)
  if (dmg <= 0) return
  hurt(state, t, part === 'arms' ? (angleDiff(from, t.aim) < 0 ? 'larm' : 'rarm') : part, dmg)
  t.surge = Math.min(SURGE.max, t.surge + dmg * SURGE.taken * surgeK(t))
  const poise = poiseOf(t)
  if (impact >= poise) stagger(t, impact, poise, from)
  state.fx.push({ k: 'hit', id: t.id, x: t.x, y: t.y, n: dmg, head: false, from, t: 10 })
}

function hurt(state, t, part, n) {
  if (part !== 'head' && t.armor[part] <= 0) part = 'head'
  const was = t.armor[part]
  t.armor[part] -= n
  if (part === 'head' || t.armor[part] > 0) return
  t.armor.head += t.armor[part]
  t.armor[part] = 0
  if (was <= 0) return
  state.fx.push({ k: 'break', id: t.id, part, x: t.x, y: t.y, t: 70 })
  state.hitstop = Math.max(state.hitstop, MATCH.breakStop)
}

function interrupt(t) {
  const a = t.act
  if (!a) return
  if ((a.ph === 'wind' || a.ph === 'combo') && a.k !== 'ult') t.cd[a.k] = Math.floor(skillCd(t, a.k) / 2)
  if (lancing(t)) t.surge = Math.min(SURGE.max, t.surge + LANCE.stuffRefund)
  if (shieldUp(t)) t.cd.shield = SHIELD.cd
  t.act = null
}

function stagger(t, impact, poise, from) {
  t.stagger = Math.max(t.stagger, STAGGER.perPoint * (impact - poise + 1))
  push(t, -Math.cos(from), -Math.sin(from), STAGGER.knockback * impact)
  interrupt(t)
}

function move(state, m, inp) {
  const a = m.act
  if (m.pull) {
    const c = state.mechs[m.pull.by]
    const dx = c.x - m.x
    const dy = c.y - m.y
    const d = Math.hypot(dx, dy) || 1
    if (d <= HOOK.stop || --m.pull.t <= 0) {
      m.pull = null
      m.vx *= 0.2
      m.vy *= 0.2
    } else {
      m.vx = (dx / d) * HOOK.pullSpeed
      m.vy = (dy / d) * HOOK.pullSpeed
    }
  } else if (!(a?.k === 'dash' && a.ph === 'go')) {
    let mx = inp.mx
    let my = inp.my
    const len = Math.hypot(mx, my)
    if (len > 1) {
      mx /= len
      my /= len
    }
    const legs = feet(m)
    let top = legs.top * speedOf(m.loadout) * (jammed(m, 'legs') ? MOVE.jammed : 1) * (core(m).speed ?? 1) * (m.buffs.berserk > 0 ? ULTS.berserk.speed : 1) * (m.buffs.slow > 0 ? MOVE.slow : 1) * (m.buffs.speed > 0 ? ITEMS.speed.speed : 1)
    if (m.stagger > 0 || lancing(m) || a?.k === 'dash') top = 0
    else if (shieldUp(m)) top *= MOVE.shield
    else if (a) top *= MOVE.cast
    if (m.overheat > 0) top *= MOVE.overheat
    const dvx = mx * top - m.vx
    const dvy = my * top - m.vy
    const dv = Math.hypot(dvx, dvy)
    const rate = (top > 0 && len > 0 ? legs.top / legs.accel : legs.top / (legs.accel * MOVE.brake)) * DT * (onOil(m) ? TRAPS.oil.grip : 1)
    const k = dv <= rate ? 1 : rate / dv
    m.vx += dvx * k
    m.vy += dvy * k
  }
  m.x += m.vx * DT
  m.y += m.vy * DT
}

function updateLobs(state) {
  state.lobs = state.lobs.filter(l => {
    if (--l.t > 0) return true
    state.fx.push({ k: 'boom', x: l.x, y: l.y, r: l.r, big: l.kind === 'strike', t: 22 })
    for (const t of foes(state, l.owner)) if (Math.hypot(t.x - l.x, t.y - l.y) <= l.r + MECH_R) hit(state, state.mechs[l.owner], t, l.dmg, 'LEGS', l.impact, Math.atan2(l.sy - t.y, l.sx - t.x), l.cast)
    return false
  })
}

function updateMines(state) {
  const h = ULTS.mines
  state.mines = state.mines.filter(mi => {
    if (mi.arm > 0) mi.arm--
    if (--mi.life <= 0) return false
    const caught = mi.arm > 0 ? [] : foes(state, mi.owner).filter(t => !airborne(t) && Math.hypot(t.x - mi.x, t.y - mi.y) <= h.trigger + MECH_R)
    if (!caught.length) return true
    state.fx.push({ k: 'boom', x: mi.x, y: mi.y, r: 1.4, big: false, t: 22 })
    for (const t of caught) hit(state, state.mechs[mi.owner], t, mi.dmg, 'LEGS', h.impact, Math.atan2(mi.y - t.y, mi.x - t.x), mi.cast)
    return false
  })
}

function updateFields(state) {
  state.fields = state.fields.filter(f => {
    for (const t of foes(state, f.owner)) {
      const d = Math.hypot(t.x - f.x, t.y - f.y)
      if (airborne(t) || d > f.r) continue
      if (f.kind !== 'well') t.buffs.slow = Math.max(t.buffs.slow, 2)
      else if (d > 0.3) {
        t.x += ((f.x - t.x) / d) * ULTS.well.pull * DT
        t.y += ((f.y - t.y) / d) * ULTS.well.pull * DT
      }
    }
    return --f.t > 0
  })
}

function collide(m, shrink) {
  for (const p of SOLIDS) {
    const dx = m.x - p.x
    const dy = m.y - p.y
    const d = Math.hypot(dx, dy)
    const min = p.r + MECH_R
    if (d >= min || d === 0) continue
    const nx = dx / d
    const ny = dy / d
    m.x = p.x + nx * min
    m.y = p.y + ny * min
    const vn = m.vx * nx + m.vy * ny
    if (vn < 0) {
      m.vx -= vn * nx
      m.vy -= vn * ny
    }
  }
  for (const w of WALLS) {
    const o = m.x * w.nx + m.y * w.ny + MECH_R - (w.d - shrink)
    if (o <= 0) continue
    m.x -= w.nx * o
    m.y -= w.ny * o
    const vn = m.vx * w.nx + m.vy * w.ny
    if (vn > 0) {
      m.vx -= vn * w.nx
      m.vy -= vn * w.ny
    }
  }
}

function separate(a, b) {
  const dx = b.x - a.x
  const dy = b.y - a.y
  const d = Math.hypot(dx, dy)
  if (d >= MECH_R * 2 || d === 0) return
  const k = (MECH_R * 2 - d) / 2 / d
  a.x -= dx * k
  a.y -= dy * k
  b.x += dx * k
  b.y += dy * k
}

const repair = (m, n) => {
  for (const p in m.armor) m.armor[p] = Math.min(m.max[p], Math.max(0, m.armor[p]) + n)
}

function pickups(state) {
  const order = turns(state)
  const near = (x, y, r) => order.find(m => !m.ko && Math.hypot(m.x - x, m.y - y) <= r + MECH_R)
  const h = state.heal
  if (!h.ready && --h.timer <= 0) {
    h.ready = true
    state.fx.push({ k: 'healUp', t: 30 })
  }
  const healer = h.ready && near(HEAL.x, HEAL.y, HEAL.radius)
  if (healer) {
    repair(healer, HEAL.amount)
    h.ready = false
    h.timer = HEAL.respawn
    state.fx.push({ k: 'heal', id: healer.id, x: healer.x, y: healer.y, n: HEAL.amount, t: 40 })
  }
  const w = state.wave
  if (--w.t <= 0) {
    state.pads = state.pads.map((kind, i) => kind ?? w.next[i >> 1])
    w.next = rollWave(state)
    w.t = PICKUP.every
    state.fx.push({ k: 'padsUp', t: 30 })
  }
  state.pads.forEach((kind, i) => {
    const m = kind && near(PADS[i].x, PADS[i].y, PICKUP.radius)
    if (!m) return
    grab(m, kind)
    state.pads[i] = null
    state.fx.push({ k: 'pickup', id: m.id, item: kind, x: PADS[i].x, y: PADS[i].y, n: ITEMS.repair.amount, t: 40 })
  })
}

function grab(m, kind) {
  const it = ITEMS[kind]
  const b = m.buffs
  if (kind === 'repair') repair(m, it.amount)
  else if (kind === 'shield') {
    b.bubble = Math.max(b.bubble, it.time)
    b.bubbleHp = Math.max(b.bubbleHp, it.absorb)
  } else if (kind === 'coolant') {
    Object.assign(m, { heat: 0, overheat: 0, ventDelay: 0 })
    b.cool = it.time
  } else if (kind === 'surge') m.surge = Math.min(SURGE.max, m.surge + it.amount)
  else b[kind] = it.time
}

function traps(state) {
  const e = elapsed(state)
  const live = state.mechs.filter(m => !m.ko)
  if (e === HAZARDS.vents) state.fx.push({ k: 'ventsOn', t: 90 })
  if (e === HAZARDS.close) state.fx.push({ k: 'closing', t: 90 })
  const C = TRAPS.crush
  C.at.forEach((p, i) => {
    const u = untilSlam(state, i)
    if (u === C.warn) state.fx.push({ k: 'crushWarn', x: p.x, y: p.y, t: 20 })
    if (e === 0 || u !== C.every) return
    state.fx.push({ k: 'crush', x: p.x, y: p.y, t: 30 })
    for (const m of live) if (Math.abs(m.x - p.x) < C.half + MECH_R / 2 && Math.abs(m.y - p.y) < C.half + MECH_R / 2) envHit(state, m, C.dmg, 'legs', C.impact, Math.atan2(p.y - m.y, p.x - m.x))
  })
  const Z = TRAPS.tesla
  Z.at.forEach((p, i) => {
    const u = untilZap(state, i)
    if (u === Z.warn) state.fx.push({ k: 'pylonWarn', x: p.x, y: p.y, t: 20 })
    if (e === 0 || u !== Z.every) return
    state.fx.push({ k: 'pylon', x: p.x, y: p.y, t: 20 })
    for (const m of live) {
      if (Math.hypot(m.x - p.x, m.y - p.y) > Z.reach + MECH_R) continue
      state.fx.push({ k: 'zap', kind: 'tesla', x1: p.x, y1: p.y, x2: m.x, y2: m.y, t: 10 })
      envHit(state, m, Z.dmg, 'arms', Z.impact, Math.atan2(p.y - m.y, p.x - m.x))
    }
  })
  const v = ventPhase(state)
  if (v?.p === HAZARDS.warn) state.fx.push({ k: 'vent', set: v.set, t: 20 })
  if (v?.burn && (v.p - HAZARDS.warn) % HAZARDS.every === 0) {
    vents(state.shrink).forEach(g => {
      if (g.wall % 2 !== v.set) return
      for (const m of live) {
        const rx = m.x - g.x
        const ry = m.y - g.y
        const along = rx * g.dx + ry * g.dy
        if (along < -MECH_R || along > HAZARDS.reach + MECH_R || Math.abs(rx * g.dy - ry * g.dx) > HAZARDS.half + MECH_R) continue
        envHit(state, m, HAZARDS.dmg, 'legs', 0, Math.atan2(-g.dy, -g.dx))
        addHeat(m, HAZARDS.heat)
      }
    })
  }
  if (state.shrink <= 0 || state.tick % HAZARDS.wallEvery !== 0) return
  for (const m of live) {
    const w = WALLS.find(w => m.x * w.nx + m.y * w.ny + MECH_R >= w.d - state.shrink - 0.05)
    if (w) envHit(state, m, HAZARDS.wallDmg, 'legs', 0, Math.atan2(w.ny, w.nx))
  }
}

function checkKo(state) {
  const down = state.mechs.filter(m => !m.ko && m.armor.head <= 0)
  if (!down.length) return
  for (const m of down) {
    m.ko = true
    state.fx.push({ k: 'ko', id: m.id, x: m.x, y: m.y, t: MATCH.ko })
  }
  state.hitstop = MATCH.koStop
  const left = [...new Set(state.mechs.filter(m => !m.ko).map(m => m.team))]
  if (left.length < 2) {
    state.finalKo = down[0].id
    return endRound(state, left.length ? left[0] : -1)
  }
  for (const m of down) Object.assign(m, { act: null, vx: 0, vy: 0, pull: null })
}

function timeUp(state) {
  const total = m => Object.values(m.armor).reduce((s, v) => s + Math.max(0, v), 0)
  const rank = m => [m.armor.head / m.max.head, total(m)]
  const cmp = (a, b) => a[0] - b[0] || a[1] - b[1]
  const live = state.mechs.filter(m => !m.ko)
  const best = live.reduce((a, m) => (cmp(rank(m), rank(a)) > 0 ? m : a))
  const tie = live.some(m => m.team !== best.team && cmp(rank(m), rank(best)) === 0)
  state.fx.push({ k: 'time', t: MATCH.ko })
  endRound(state, tie ? -1 : best.team)
}

function endRound(state, winner) {
  state.winner = winner
  if (winner >= 0) state.score[winner]++
  state.phase = 'ko'
  state.timer = MATCH.ko
}

function resetRound(state) {
  const spawns = spawnsOf(state.mechs.map(m => m.team))
  state.mechs = state.mechs.map(old => {
    const m = makeMech(old.id, old.loadout, old.team, spawns[old.id])
    m.surge = Math.max(Math.floor(old.surge * SURGE.carry), core(m).surgeStart ?? 0)
    m.held = old.held
    return m
  })
  state.shots = []
  state.lobs = []
  state.mines = []
  state.fields = []
  state.trails = []
  state.walls = []
  state.heal = { ready: false, timer: HEAL.first }
  resetPads(state)
  state.shrink = 0
  state.winner = -1
  state.finalKo = -1
  state.round++
  state.phase = 'countdown'
  state.timer = MATCH.countdown
  state.clock = MATCH.time
}
