import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createState, MATCH, TICKS } from './sim.js'
import { next, mood, HYPE } from './hype.js'

const fight = () => Object.assign(createState(), { phase: 'fight' })

test('big moments add hype, quiet time cools it, a K.O. maxes it', () => {
  const s = fight()
  const h = next(0, s, [{ k: 'hooked' }, { k: 'hit', n: 40, head: true }, { k: 'break' }], 0)
  assert.equal(h, 15 + 40 * HYPE.hit * 2 + 25)
  assert.equal(next(h, s, [], HYPE.half), h / 2)
  assert.equal(next(h, s, [{ k: 'ko' }], 0), 100)
  assert.deepEqual([0, 29, 30, 69, 70].map(mood), [0, 0, 1, 1, 2])
})

test('tension keeps hype from cooling below a floor', () => {
  const s = fight()
  s.mechs[1].armor.head = s.mechs[1].max.head * 0.2
  assert.equal(next(0, s, [], 60), HYPE.danger)
  const late = Object.assign(fight(), { clock: 5 * TICKS, score: [MATCH.wins - 1, 0] })
  assert.equal(next(0, late, [], 60), HYPE.clutch + HYPE.matchPoint)
  assert.equal(next(0, Object.assign(late, { phase: 'countdown' }), [], 60), 0)
})
