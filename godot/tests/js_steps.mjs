import { createState, step, SETS, FORMATS, HEADS, CORES, ARMS, LEG_PARTS, BOOSTERS, WEAPONS } from '../../src/sim.js'
import { botInput, createBrain, randomLoadout } from '../../src/bot.js'

const nth = (o, i) => Object.keys(o)[i % Object.keys(o).length]
const sweep = Array.from({ length: 9 }, (_, k) => ({
  format: '1v1',
  seed: 20 + k,
  loadouts: [2 * k, 2 * k + 1].map(i => ({ head: nth(HEADS, i), core: nth(CORES, i), arms: nth(ARMS, i), legs: nth(LEG_PARTS, i), booster: nth(BOOSTERS, i), left: nth(WEAPONS, i), right: nth(WEAPONS, i + 9) })),
}))

const CASES = [
  ...sweep,
  { format: '1v1', sets: ['duelist', 'sniper'], seed: 1 },
  { format: '1v1', sets: ['brawler', 'artillery'], seed: 2 },
  { format: '1v1', sets: ['speedster', 'tank'], seed: 3 },
  { format: 'ffa', seed: 4 },
  { format: '2v2', seed: 5 },
  { format: '1v1', seed: 6 },
  { format: '1v1', seed: 7 },
  { format: 'ffa', seed: 8 },
]
const EVERY = Number(process.argv[2] ?? 41)
const lines = []
const dv = new DataView(new ArrayBuffer(8))
const exact = (k, v) => {
  if (typeof v !== 'number' || Number.isInteger(v)) return v
  dv.setFloat64(0, v)
  return `~${dv.getUint32(0).toString(16).padStart(8, '0')}${dv.getUint32(4).toString(16).padStart(8, '0')}`
}
const json = v => JSON.stringify(v, exact)

CASES.forEach((c, n) => {
  const teams = FORMATS[c.format]
  const loadouts = c.loadouts ?? (c.sets ? c.sets.map(k => SETS[k]) : teams.map((_, i) => randomLoadout(createBrain(c.seed * 10 + i))))
  const s = createState(loadouts, teams)
  const brains = s.mechs.map(m => createBrain(c.seed * 100 + m.id))
  lines.push(`{"case":${n},"init":${json(s)},"loadouts":${json(loadouts)},"teams":${json(teams)}}`)
  for (let i = 0; i < 40000 && s.phase !== 'over'; i++) {
    const before = json({ state: s, brains })
    const seen = new Set(s.fx)
    const round = s.round
    const inputs = s.mechs.map(m => botInput(s, brains[m.id], m.id))
    step(s, inputs)
    const fresh = s.fx.some(f => !seen.has(f) && f.k !== 'hit')
    if (i % EVERY === 0 || (fresh && i % 4 === 0) || s.round !== round) lines.push(`{"case":${n},"tick":${i},"before":${before},"inputs":${json(inputs)},"after":${json(s)}}`)
  }
})
process.stdout.write(lines.join('\n'))
