import { step, TICKS, MATCH } from './sim.js'

export const KILLCAM = { secs: 5, live: 60, slow: 0.25, slowTicks: 36, hold: 18, grace: 30 }

export const recorder = () => ({ round: 0, snaps: [] })

export function record(rec, state, ins) {
  if (state.phase !== 'fight') return
  if (rec.round !== state.round) {
    rec.round = state.round
    rec.snaps = []
  }
  if (!rec.snaps.length || state.tick % TICKS === 0) rec.snaps.push({ state: structuredClone(state), ins: [] })
  rec.snaps.at(-1).ins.push(ins)
  if (rec.snaps.length > KILLCAM.secs + 2) rec.snaps.shift()
}

export const wantsReplay = state => state.phase === 'ko' && state.timer === MATCH.ko - KILLCAM.live && state.mechs.some(m => m.ko)

export function replay(rec, focus) {
  const all = rec.snaps.flatMap(s => s.ins)
  const from = Math.max(0, all.length - KILLCAM.secs * TICKS)
  const state = structuredClone(rec.snaps[0].state)
  for (const ins of all.slice(0, from)) step(state, ins)
  state.fx = []
  return { state, ins: all.slice(from), i: 0, acc: 0, focus }
}

export function advance(r) {
  step(r.state, r.ins[r.i] ?? [])
  return ++r.i < r.ins.length + KILLCAM.hold
}

export const speed = r => (r.i >= r.ins.length - KILLCAM.slowTicks ? KILLCAM.slow : 1)

export function play(r) {
  r.acc += speed(r)
  for (; r.acc >= 1; r.acc--) if (!advance(r)) return false
  return true
}

export const progress = r => r.i / (r.ins.length + KILLCAM.hold)
