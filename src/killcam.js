import { step, TICKS, MATCH } from './sim.js'

export const KILLCAM = { secs: 5, live: 60, hold: 72, grace: 30 }

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

export function replay(rec) {
  const all = rec.snaps.flatMap(s => s.ins)
  const from = Math.max(0, all.length - KILLCAM.secs * TICKS)
  const state = structuredClone(rec.snaps[0].state)
  for (const ins of all.slice(0, from)) step(state, ins)
  state.fx = []
  return { state, ins: all.slice(from), i: 0 }
}

export function advance(r) {
  step(r.state, r.ins[r.i] ?? [])
  return ++r.i < r.ins.length + KILLCAM.hold
}

export const progress = r => r.i / (r.ins.length + KILLCAM.hold)
