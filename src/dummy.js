import { MECH_R, weapon } from './sim.js'

export const DUMMY_MODES = ['idle', 'strafe', 'fight', 'rush']

export function dummyInput(state, mode, me = 1) {
  const m = state.mechs[me]
  const o = state.mechs[1 - me]
  const dx = o.x - m.x
  const dy = o.y - m.y
  const d = Math.hypot(dx, dy) || 1
  const inp = { mx: 0, my: 0, ax: o.x, ay: o.y, left: false, right: false, hook: false, shield: false, dash: false, ult: false }
  if (mode === 'idle') return inp
  const side = Math.floor(state.tick / 75) % 2 ? 1 : -1
  if (mode === 'rush') {
    const radial = d > 2.2 ? 1 : d < 1.4 ? -1 : 0
    inp.mx = (dx / d) * radial + (-dy / d) * side * 0.35
    inp.my = (dy / d) * radial + (dx / d) * side * 0.35
    inp.right = d < weapon(m, 'right').range + MECH_R && state.tick % 60 < 2
    inp.dash = d > 5 && d < 8 && state.tick % 150 < 2
    return inp
  }
  const radial = d > 10 ? 1 : d < 7 ? -1 : 0
  inp.mx = (-dy / d) * side + (dx / d) * radial
  inp.my = (dx / d) * side + (dy / d) * radial
  if (mode === 'fight') inp.left = state.tick % 90 < 3
  return inp
}
