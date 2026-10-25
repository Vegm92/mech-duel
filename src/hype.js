import { MATCH, TICKS } from './sim.js'

export const HYPE = { half: 4, hit: 0.1, calm: 30, wild: 70, danger: 40, clutch: 30, matchPoint: 10 }
const POINTS = { hooked: 15, ult: 15, parry: 20, break: 25, ko: 100 }

export function gain(f) {
  if (f.k === 'hit') return f.n * HYPE.hit * (f.head ? 2 : 1)
  if (f.k === 'boom') return f.big ? 15 : 0
  return POINTS[f.k] ?? 0
}

export function floor(state) {
  if (state.phase !== 'fight') return 0
  let f = state.mechs.some(m => !m.ko && m.armor.head < m.max.head * 0.25) ? HYPE.danger : 0
  if (state.clock <= 10 * TICKS) f = Math.max(f, HYPE.clutch)
  if (Math.max(...state.score) === MATCH.wins - 1) f += HYPE.matchPoint
  return f
}

export function next(h, state, events, dt) {
  h *= Math.pow(0.5, dt / HYPE.half)
  for (const f of events) h += gain(f)
  return Math.min(100, Math.max(h, floor(state)))
}

export const mood = h => (h >= HYPE.wild ? 2 : h >= HYPE.calm ? 1 : 0)

const seen = new WeakSet()
let level = 0
let lastState = null
let lastTick = 0

export function trackHype(state) {
  if (state !== lastState) {
    lastState = state
    lastTick = state.tick
    level = 0
  }
  const fresh = state.fx.filter(f => !seen.has(f))
  for (const f of fresh) seen.add(f)
  level = next(level, state, fresh, (state.tick - lastTick) / TICKS)
  lastTick = state.tick
  return level
}

export const hype = () => level
