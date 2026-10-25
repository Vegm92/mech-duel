import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createState, step, TICKS } from './sim.js'
import { botInput, createBrain, randomLoadout } from './bot.js'
import { KILLCAM, recorder, record, wantsReplay, replay, advance } from './killcam.js'

test('the replay re-runs the last 5 s and lands on the same K.O.', () => {
  const b0 = createBrain(11)
  const b1 = createBrain(12)
  const s = createState([randomLoadout(b0), randomLoadout(b1)])
  const rec = recorder()
  let ko = null
  for (let i = 0; i < 40000 && !wantsReplay(s); i++) {
    const ins = [botInput(s, b0, 0), botInput(s, b1, 1)]
    record(rec, s, ins)
    step(s, ins)
    if (s.phase === 'ko' && !ko) ko = { tick: s.tick, mechs: structuredClone(s.mechs) }
    if (s.phase === 'countdown') ko = null
  }
  assert.ok(wantsReplay(s), 'a round ends in a K.O.')
  const r = replay(rec)
  assert.equal(r.ins.length, KILLCAM.secs * TICKS)
  assert.equal(r.state.tick, ko.tick - r.ins.length)
  while (r.i < r.ins.length) advance(r)
  assert.equal(r.state.phase, 'ko')
  assert.equal(r.state.tick, ko.tick)
  assert.deepEqual(r.state.mechs, ko.mechs)
  let more = 0
  while (advance(r)) more++
  assert.equal(more, KILLCAM.hold - 1)
})
