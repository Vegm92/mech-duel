import test from 'node:test'
import assert from 'node:assert/strict'
import { createState, step, hashState, FORMATS, ARENA, PILLARS, SPAWNS, PICKUP, PADS, ITEMS, TRAPS, HAZARDS, ventPhase, GUN, DASH, LANCE, HEAT, MECH_R, SAW, ARMOR, MATCH, HOOK, HEAL, DEFAULT_LOADOUT, WEAPONS, ARMS, BOOSTERS, LEG_PARTS, HEADS, CORES, ULTS, SETS, speedOf, ultOf, normalize, hidden } from './sim.js'
import { dummyInput } from './dummy.js'
import { botInput, createBrain, randomLoadout } from './bot.js'

const MID = ARENA.h / 2
const GOLDEN = 0xDE5BF746

function duel(bx = 16, by = MID, lo0 = {}, lo1 = {}) {
  const s = createState([{ ...DEFAULT_LOADOUT, ...lo0 }, { ...DEFAULT_LOADOUT, ...lo1 }])
  s.phase = 'fight'
  const [a, b] = s.mechs
  Object.assign(a, { x: 5, y: by, aim: 0 })
  Object.assign(b, { x: bx, y: by, aim: Math.PI })
  return s
}
const input = (o = {}) => ({ mx: 0, my: 0, ax: 0, ay: 0, ...o })
const run = (s, ticks, fa, fb) => {
  for (let i = 0; i < ticks; i++) step(s, [fa(i), fb(i)])
}
const arms = m => m.armor.larm + m.armor.rarm
const FULL = ARMOR.larm + ARMOR.rarm
const lead = (a, b) => ({ ax: b.x, ay: b.y + (b.vy * (Math.abs(b.x - a.x) - MECH_R)) / GUN.speed })

test('a max-range Q hits a standing target that reacts after 0.22 s', () => {
  const s = duel()
  const [a, b] = s.mechs
  run(s, 60, i => input({ ax: b.x, ay: b.y, left: i === 0 }), i => input({ ax: a.x, ay: a.y, my: i >= GUN.windup + 13 ? -1 : 0 }))
  assert.ok(arms(b) < FULL)
})

test('a led Q hits a target that keeps strafing', () => {
  const s = duel()
  const [a, b] = s.mechs
  run(s, 90, i => input({ ...lead(a, b), left: i === 10 }), () => input({ ax: a.x, ay: a.y, my: -1 }))
  assert.ok(arms(b) < FULL)
})

test('a juke at release dodges a led Q from 15 m, but not from 11 m', () => {
  for (const [distance, dodged] of [[15, true], [11, false]]) {
    const s = duel(3 + distance)
    const [a, b] = s.mechs
    a.x = 3
    run(s, 90, i => input({ ...lead(a, b), left: i === 10 }), i => input({ ax: a.x, ay: a.y, my: i < 10 + GUN.windup ? -1 : 1 }))
    assert.equal(arms(b) === FULL, dodged, `${distance} m`)
  }
})

test('spamming Q runs hot after 5 shots and overheats on the 9th', () => {
  const s = duel(25)
  const a = s.mechs[0]
  let shots = 0
  let hotAt = 0
  for (let i = 0; i < 1200 && !a.overheat; i++) {
    const before = s.nextCast
    step(s, [input({ ax: 5, ay: 0, left: i % 2 === 0 }), input({ ax: 5, ay: MID })])
    if (s.nextCast > before) shots++
    if (!hotAt && a.heat >= HEAT.hot) hotAt = shots
  }
  assert.equal(hotAt, 5)
  assert.equal(shots, 9)
})

test('a Perfect Guard reflects the shot back at the shooter', () => {
  const s = duel()
  const [a, b] = s.mechs
  const contact = GUN.windup + Math.floor(9.5 / (GUN.speed / 60))
  run(s, 80, i => input({ ax: b.x, ay: b.y, left: i === 0 }), i => input({ ax: a.x, ay: a.y, shield: i >= contact - 4 }))
  assert.equal(arms(b), FULL)
  assert.ok(arms(a) < FULL)
  assert.ok(b.surge >= 15)
})

test('a late plate blocks and absorbs the shot', () => {
  const s = duel()
  const [a, b] = s.mechs
  run(s, 40, i => input({ ax: b.x, ay: b.y, left: i === 0 }), () => input({ ax: a.x, ay: a.y, shield: true }))
  assert.equal(arms(b), FULL)
  assert.equal(b.act.absorbed, GUN.dmg)
})

test('hits land on the side facing the shooter, frontal hits pile on the weaker arm, broken parts spill to Head', () => {
  const side = duel()
  run(side, 40, i => input({ ax: 16, ay: MID, left: i === 0 }), () => input({ ax: 16, ay: 0 }))
  assert.deepEqual(side.mechs[1].armor, { ...ARMOR, larm: ARMOR.larm - GUN.dmg })

  const front = duel()
  run(front, 40, i => input({ ax: 16, ay: MID, left: i === 0 }), () => input({ ax: 5, ay: MID }))
  assert.deepEqual(front.mechs[1].armor, { ...ARMOR, rarm: ARMOR.rarm - GUN.dmg })

  const spill = duel()
  spill.mechs[1].armor.larm = 0
  run(spill, 40, i => input({ ax: 16, ay: MID, left: i === 0 }), () => input({ ax: 16, ay: 0 }))
  assert.equal(spill.mechs[1].armor.head, ARMOR.head - GUN.dmg)
})

test('the lance deals 100 + 2 x Heat to the Head and stops at pillars', () => {
  for (const [y, head] of [[MID, ARMOR.head - (LANCE.base + LANCE.perHeat * 50)], [PILLARS[0].y, ARMOR.head]]) {
    const s = duel(PILLARS[0].x + 5, y)
    const [a, b] = s.mechs
    a.x = PILLARS[0].x - 6
    Object.assign(a, { surge: 100, heat: 50, ventDelay: 999 })
    run(s, 50, i => input({ ax: b.x, ay: b.y, ult: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    assert.equal(b.armor.head, head)
  }
})

test('three Q hits break a component', () => {
  const s = duel()
  const [a, b] = s.mechs
  run(s, 150, i => input({ ax: b.x, ay: b.y, left: i % GUN.cd === 0 }), () => input({ ax: a.x, ay: a.y }))
  assert.equal(b.armor.rarm, 0)
  assert.ok(3 * GUN.dmg >= ARMOR.larm && 3 * GUN.dmg >= ARMOR.legs)
})

test('the saw cuts under a raised shield, hits Legs and staggers', () => {
  const s = duel(7)
  const [a, b] = s.mechs
  run(s, 12, i => input({ ax: b.x, ay: b.y, right: i === 0 }), () => input({ ax: a.x, ay: a.y, shield: true }))
  assert.equal(b.armor.legs, ARMOR.legs - SAW.dmg)
  assert.ok(b.stagger > 0)
})

test('gun and saw have their own cooldowns: shoot, then slash right away', () => {
  const s = duel(7)
  const [a, b] = s.mechs
  run(s, 34, i => input({ ax: b.x, ay: b.y, left: i === 0, right: i === 19 }), () => input({ ax: a.x, ay: a.y }))
  assert.equal(arms(b), FULL - GUN.dmg)
  assert.equal(b.armor.legs, ARMOR.legs - SAW.dmg)
})

test('the hook pulls the target in and stuns it, a raised shield blocks it', () => {
  for (const shield of [false, true]) {
    const s = duel(14)
    const [a, b] = s.mechs
    run(s, 40, i => input({ ax: b.x, ay: b.y, hook: i === 0 }), () => input({ ax: a.x, ay: a.y, shield }))
    const d = Math.hypot(a.x - b.x, a.y - b.y)
    if (shield) assert.ok(d > 8, `blocked, still ${d.toFixed(1)} m away`)
    else assert.ok(d < HOOK.stop + 1.2 && b.stagger > 0, `pulled to ${d.toFixed(1)} m`)
  }
})

test('the heal pad repairs every part once, then comes back', () => {
  const s = duel(25)
  const a = s.mechs[0]
  Object.assign(a, { x: HEAL.x, y: HEAL.y })
  Object.assign(a.armor, { head: 100, rarm: 0, larm: 50 })
  s.heal.timer = 1
  run(s, 3, () => input({ ax: 30, ay: MID }), () => input({ ax: 5, ay: MID }))
  assert.deepEqual(a.armor, { head: 100 + HEAL.amount, rarm: HEAL.amount, larm: 50 + HEAL.amount, legs: ARMOR.legs })
  assert.equal(s.heal.ready, false)
  a.x = 5
  run(s, HEAL.respawn + 2, () => input({ ax: 30, ay: MID }), () => input({ ax: 5, ay: MID }))
  assert.equal(s.heal.ready, true)
})

test('parts change the mech: armor, damage and speed come from the loadout', () => {
  const heavy = createState([{ arms: 'anvil', legs: 'treads' }, DEFAULT_LOADOUT])
  assert.deepEqual(heavy.mechs[0].max, { head: HEADS.horn.armor, rarm: ARMS.anvil.armor, larm: ARMS.anvil.armor, legs: LEG_PARTS.treads.armor })

  const s = createState([{ ...DEFAULT_LOADOUT, left: 'scatter' }, DEFAULT_LOADOUT])
  s.phase = 'fight'
  const [a, b] = s.mechs
  Object.assign(b, { x: a.x + 3 })
  run(s, 20, i => input({ ax: b.x, ay: b.y, left: i === 0 }), () => input({ ax: a.x, ay: a.y }))
  assert.equal(arms(b), FULL - WEAPONS.scatter.pellets * WEAPONS.scatter.dmg)

  const race = lo => {
    const r = createState([{ ...DEFAULT_LOADOUT, ...lo }, DEFAULT_LOADOUT])
    r.phase = 'fight'
    for (let i = 0; i < 60; i++) step(r, [input({ mx: 0, my: 1, ax: 5, ay: 30 }), input()])
    return r.mechs[0].y
  }
  assert.ok(race({ legs: 'hover' }) > race({}) && race({}) > race({ legs: 'treads' }))
  const light = { head: 'visor', core: 'glass', arms: 'wire', booster: 'flicker' }
  const heavier = { head: 'medic', core: 'titan', arms: 'anvil', booster: 'rocket' }
  assert.ok(speedOf({ ...DEFAULT_LOADOUT, ...light }) > 1 && speedOf({ ...DEFAULT_LOADOUT, ...heavier }) < 1)
  assert.ok(race(light) > race({}) && race({}) > race(heavier))
})

test('either hand takes any weapon: two guns fire from their own side on their own cooldowns', () => {
  const s = duel(12, MID, { left: 'rivet', right: 'rivet' })
  const [a, b] = s.mechs
  const muzzles = []
  for (let i = 0; i < 60; i++) {
    step(s, [input({ ax: b.x, ay: b.y, left: i === 0, right: i === 20 }), input({ ax: a.x, ay: a.y })])
    muzzles.push(...s.fx.filter(f => f.k === 'muzzle' && f.t === 8))
  }
  assert.deepEqual(muzzles.map(f => f.hand), ['left', 'right'])
  assert.ok(muzzles[0].y < MID && muzzles[1].y > MID)
  assert.equal(arms(b), FULL - 2 * GUN.dmg)
  assert.ok(a.cd.left === 0 && a.cd.right > 0)
})

test('the booster sets the dash: heavier boosters go further, lighter ones come back sooner', () => {
  const dash = booster => {
    const s = duel(25, MID, { booster })
    const a = s.mechs[0]
    run(s, 40, i => input({ ax: 30, ay: MID, mx: 1, dash: i === 0 }), () => input({ ax: 5, ay: MID }))
    return { x: a.x, cd: a.cd.dash }
  }
  const [lite, std, big] = ['flicker', 'thruster', 'rocket'].map(dash)
  assert.ok(lite.x < std.x && std.x < big.x)
  assert.ok(lite.cd < std.cd && std.cd < big.cd)
  assert.ok(BOOSTERS.rocket.dash > BOOSTERS.flicker.dash)
})

test('each leg has its own dash move that does its job', () => {
  const play = (legs, bx, ticks, fa, lo1 = {}) => {
    const s = duel(bx, MID, { legs }, lo1)
    const [a, b] = s.mechs
    let dashes = 0
    for (let i = 0; i < ticks; i++) {
      step(s, [input({ ax: b.x, ay: b.y, ...fa(i, a, b) }), input({ ax: a.x, ay: a.y })])
      dashes += s.fx.filter(f => f.k === 'dash' && f.t === 6).length
    }
    return { a, b, dashes }
  }
  const steered = play('hover', 25, 20, i => ({ ax: 30, ay: MID, mx: i ? 0 : 1, my: i ? -1 : 0, dash: i === 0 }))
  assert.ok(steered.a.y < MID - 0.3, 'glide steers')
  const ram = play('treads', 7.8, 20, i => ({ mx: 1, dash: i === 0 }))
  assert.ok(total(ram.b) < maxTotal(ram.b), 'ram hits on contact')
  for (const [legs, n] of [['spider', 2], ['skates', 2], ['greaves', 1]]) assert.equal(play(legs, 25, 24, i => ({ ax: 30, ay: MID, my: 1, dash: i === 0 || i === 20 })).dashes, n, legs)
  const speed = legs => {
    const { a } = play(legs, 25, Math.round(DASH.ticks * 1) + 1, i => ({ ax: 30, ay: MID, mx: 1, dash: i === 0 }))
    return Math.hypot(a.vx, a.vy)
  }
  assert.ok(speed('wheels') > speed('greaves') * 1.5, 'drift keeps its speed')
  const shooter = duel(16, MID, { legs: 'jets' })
  const [a, b] = shooter.mechs
  a.x = 8
  run(shooter, 40, i => input({ ax: 0, ay: MID, mx: -1, dash: i === 0 }), i => input({ ax: a.x, ay: a.y, left: i === 0 }))
  assert.equal(total(a), maxTotal(a), 'bolts pass under a leap')
  const knock = play('jets', 9, 40, i => ({ mx: 1, dash: i === 0 }))
  assert.ok(knock.b.lift > 0 || knock.b.armor.legs < knock.b.max.legs, 'leap landing knocks up')
  const slam = play('stompers', 8, 30, i => ({ mx: 1, dash: i === 0 }))
  assert.ok(slam.b.armor.legs < slam.b.max.legs, 'slam quake hits')
  const pounce = play('quad', 11, 30, i => ({ dash: i === 0 }))
  assert.ok(pounce.b.armor.legs < pounce.b.max.legs, 'pounce lands on the cursor')
  const roll = play('mono', 8, 20, i => ({ mx: 1, dash: i === 0 }))
  assert.ok(total(roll.b) < maxTotal(roll.b), 'roll hurts on contact')
})

test('each booster leaves its dash trail and the trail does its job', () => {
  const go = (booster, bx, by, mx, my, after = 0, then = null) => {
    const s = duel(25, MID, { booster })
    const [a, b] = s.mechs
    Object.assign(b, { x: bx, y: by })
    run(s, 14, i => input({ ax: 30, ay: MID, mx, my, dash: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    if (then) Object.assign(b, then)
    run(s, after, () => input({ ax: 30, ay: MID }), () => input({ ax: a.x, ay: a.y }))
    return { s, a, b }
  }
  const arc = go('flicker', 40, 10, 1, 0, 3, { x: 7, y: MID, vx: 0, vy: 0 })
  assert.ok(arc.b.buffs.jam > 0 && total(arc.b) < maxTotal(arc.b), 'arc zaps and locks skills')
  const flame = go('thruster', 40, 10, 1, 0, 40, { x: 7.5, y: MID, vx: 0, vy: 0 })
  assert.ok(flame.b.armor.legs < flame.b.max.legs && flame.b.heat > 0, 'flame burns')
  const frost = go('wisp', 40, 10, 1, 0, 3, { x: 7, y: MID, vx: 0, vy: 0 })
  assert.ok(frost.b.buffs.slow > 0, 'frost slows')
  const smoke = go('twin', 40, 10, 1, 0)
  assert.ok(hidden(smoke.s, smoke.a), 'smoke hides')
  const magnet = go('comet', 8, MID + 3, 1, 0, 4)
  assert.ok(magnet.b.y < MID + 2.6, 'magnet pulls')
  assert.equal(go('rocket', 40, 10, 1, 0).s.trails.length, 0, 'clean leaves nothing')
})

test('light arms work the hands faster, heavy arms slower', () => {
  const cd = arms => {
    const s = duel(25, MID, { arms })
    run(s, 2, i => input({ ax: 30, ay: MID, left: i === 0 }), () => input({ ax: 5, ay: MID }))
    return s.mechs[0].cd.left
  }
  assert.ok(cd('wire') < cd('frame') && cd('frame') < cd('anvil'))
})

test('the bot can fight with any build', () => {
  for (const seed of [3, 11, 42, 77]) {
    const pick = createBrain(seed)
    const s = createState([randomLoadout(pick), randomLoadout(pick)])
    const b0 = createBrain(seed + 1)
    const b1 = createBrain(seed + 2)
    for (let i = 0; i < 40000 && s.phase !== 'over'; i++) step(s, [botInput(s, b0, 0), botInput(s, b1, 1)])
    assert.equal(s.phase, 'over', `seed ${seed}`)
    assert.ok(s.mechs.every(m => Number.isFinite(m.x) && Number.isFinite(m.y)))
  }
})

test('a dash pressed while staggered fires as soon as the stagger ends', () => {
  const s = duel()
  const a = s.mechs[0]
  a.stagger = 20
  run(s, 25, i => input({ ax: 16, ay: MID, dash: i === 1, my: -1 }), () => input({ ax: 5, ay: MID }))
  assert.ok(a.cd.dash > 0)
})

test('E during a Q windup feints: no shot, 70% of the cooldown back', () => {
  const s = duel()
  const a = s.mechs[0]
  run(s, 3, i => input({ ax: 16, ay: MID, left: i === 0, dash: i === 2, my: -1 }), () => input({ ax: 5, ay: MID }))
  assert.equal(a.act.k, 'dash')
  assert.ok(a.cd.left > 0 && a.cd.left <= Math.floor(GUN.cd * (1 - DASH.feintRefund)))
  run(s, 30, () => input({ ax: 16, ay: MID }), () => input({ ax: 5, ay: MID }))
  assert.equal(s.nextCast, 1)
})

test('the countdown holds both mechs, then the round starts', () => {
  const s = createState()
  const a = s.mechs[0]
  const push = () => step(s, [input({ mx: 1, ax: 30, ay: MID }), input()])
  for (let i = 0; i < MATCH.countdown; i++) push()
  assert.equal(s.phase, 'countdown')
  assert.equal(a.x, SPAWNS[0].x)
  for (let i = 0; i < 20; i++) push()
  assert.equal(s.phase, 'fight')
  assert.ok(a.x > SPAWNS[0].x)
})

test('first to three round wins takes the match', () => {
  const s = createState()
  for (let r = 0; r < MATCH.wins; r++) {
    while (s.phase !== 'fight') step(s, [])
    s.mechs[1].armor.head = 0
    step(s, [])
    assert.equal(s.phase, 'ko')
  }
  while (s.phase === 'ko') step(s, [])
  assert.equal(s.phase, 'over')
  assert.deepEqual(s.score, [MATCH.wins, 0])
})

test('when time runs out the healthier head wins the round', () => {
  const s = duel()
  s.clock = 1
  s.mechs[0].armor.head = 100
  step(s, [])
  assert.equal(s.phase, 'ko')
  assert.deepEqual(s.score, [0, 1])
})

const match = (other, seed = 1) => {
  const ticks = 5 * (MATCH.time + MATCH.countdown + MATCH.ko + 60)
  const s = createState()
  const brain = createBrain(seed)
  let trail = ''
  let parries = 0
  for (let i = 0; i < ticks && s.phase !== 'over'; i++) {
    step(s, [dummyInput(s, other, 0), botInput(s, brain, 1)])
    parries += s.fx.filter(f => f.k === 'parry' && f.t === 13).length
    if (i % 60 === 0) trail += hashState(s)
  }
  return { s, parries, hash: hashState({ trail }) }
}

test('the bot beats the strafing dummy', () => {
  const { s } = match('strafe')
  assert.equal(s.phase, 'over')
  assert.equal(s.score[1], MATCH.wins)
})

test('the bot shields some of the shots fired at it', () => {
  assert.ok([1, 2, 3].reduce((n, seed) => n + match('fight', seed).parries, 0) > 0)
})

test('bot vs dummy is deterministic (golden hash)', () => {
  const play = () => match('fight').hash
  const h = play()
  assert.equal(play(), h)
  if (h !== GOLDEN) console.log(`golden hash is 0x${h.toString(16).toUpperCase().padStart(8, '0')}`)
  assert.equal(h, GOLDEN)
})

const total = m => Object.values(m.armor).reduce((n, v) => n + v, 0)
const maxTotal = m => Object.values(m.max).reduce((n, v) => n + v, 0)

test('homing missiles catch a target that strafes away from the cursor', () => {
  const s = duel(14, MID, { left: 'missiles' })
  const [a, b] = s.mechs
  run(s, 90, i => input({ ax: 14, ay: MID, left: i === 0 }), () => input({ ax: a.x, ay: a.y, my: -1 }))
  assert.ok(total(b) < maxTotal(b))
})

test('the mortar lands on the cursor after its delay and hits Legs through a raised shield', () => {
  const g = WEAPONS.mortar
  const s = duel(14, MID, { left: 'mortar' })
  const [a, b] = s.mechs
  run(s, g.windup + g.delay - 2, i => input({ ax: 14, ay: MID, left: i === 0 }), () => input({ ax: a.x, ay: a.y, shield: true }))
  assert.equal(b.armor.legs, b.max.legs)
  run(s, 6, () => input({ ax: 14, ay: MID }), () => input({ ax: a.x, ay: a.y, shield: true }))
  assert.equal(b.armor.legs, b.max.legs - g.dmg)
})

test('the laser hits on release and stops at pillars', () => {
  const g = WEAPONS.laser
  for (const [y, hurt] of [[MID, true], [PILLARS[0].y, false]]) {
    const s = duel(PILLARS[0].x + 5, y, { left: 'laser' })
    const [a, b] = s.mechs
    a.x = PILLARS[0].x - 6
    run(s, g.windup + 1, i => input({ ax: b.x, ay: b.y, left: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    assert.equal(total(b) < maxTotal(b), hurt, `y ${y}`)
  }
})

test('ricochet bolts bounce off walls, plain bolts stop there', () => {
  for (const [left, hurt] of [['ricochet', true], ['rivet', false]]) {
    const s = duel(ARENA.w / 2 + 2, 6, { left })
    const [a, b] = s.mechs
    a.x = ARENA.w / 2 - 2
    run(s, 60, i => input({ ax: ARENA.w / 2, ay: 0, left: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    assert.equal(total(b) < maxTotal(b), hurt, left)
  }
})

test('claws hit twice per swing', () => {
  const c = WEAPONS.claws
  const s = duel(7.5, MID, { right: 'claws' })
  const [a, b] = s.mechs
  run(s, c.windup + c.gap + 2, i => input({ ax: b.x, ay: b.y, right: i === 0 }), () => input({ ax: a.x, ay: a.y }))
  assert.equal(b.armor.legs, b.max.legs - 2 * c.dmg)
})

const ULT_JOB = {
  lance: (a, b) => b.armor.head < b.max.head,
  swarm: (a, b) => total(b) < maxTotal(b),
  overdrive: a => a.buffs.overdrive > 0,
  emp: (a, b) => b.buffs.jam > 0 && total(b) < maxTotal(b),
  orbital: (a, b) => b.armor.legs < b.max.legs,
  repair: a => a.armor.rarm === 50 + ULTS.repair.amount,
  bubble: a => a.buffs.bubble > 0 && a.buffs.bubbleHp === ULTS.bubble.absorb,
  stasis: (a, b) => b.buffs.slow > 0 && total(b) < maxTotal(b),
  mines: (a, b) => b.armor.legs < b.max.legs,
  berserk: a => a.buffs.berserk > 0,
  blink: (a, b, s) => a.x > 6.5 && s.lobs.length === 0,
  well: (a, b, s) => total(b) < maxTotal(b) && s.fields.some(f => f.kind === 'well'),
  wall: (a, b, s) => s.walls.length === 1,
  meltdown: (a, b) => total(b) < maxTotal(b) && a.heat === 0,
  deflect: a => a.buffs.deflect > 0,
  mirror: a => a.buffs.mirror > 0,
  rail: (a, b) => total(b) < maxTotal(b),
  shroud: (a, b, s) => hidden(s, a),
}

test('every core has an R skill that does its job', () => {
  for (const [key, c] of Object.entries(CORES)) {
    const u = ULTS[c.ult]
    const s = duel(8, MID, { core: key })
    const [a, b] = s.mechs
    a.surge = 100
    a.armor.rarm = 50
    run(s, u.windup + 60, i => input({ ax: b.x, ay: b.y, ult: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    assert.ok(ULT_JOB[c.ult](a, b, s), key)
  }
})

test('the core picks the R skill, one skill per core; sets are full, valid builds', () => {
  const ults = Object.values(CORES).map(c => c.ult)
  assert.ok(ults.every(k => k in ULTS && k in ULT_JOB))
  assert.equal(new Set(ults).size, ults.length)
  assert.equal(ultOf(DEFAULT_LOADOUT), 'lance')
  assert.equal(ultOf({ ...DEFAULT_LOADOUT, left: 'katana', right: 'claws' }), 'lance')
  for (const [key, set] of Object.entries(SETS)) assert.deepEqual(normalize(set), set, key)
})

test('heads are stat parts: armor for the K.O. pool and how fast the R meter fills', () => {
  assert.equal(createState([{ head: 'demon' }]).mechs[0].max.head, HEADS.demon.armor)
  const meter = h => {
    const s = duel(16, MID, { head: h })
    const [a, b] = s.mechs
    run(s, 40, i => input({ ax: b.x, ay: b.y, left: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    return a.surge
  }
  assert.ok(meter('visor') > meter('horn') && meter('horn') > meter('demon'))
})

test('cores change the mech: armor, damage, heat and lifesteal', () => {
  const plain = createState().mechs[0]
  assert.equal(createState([{ core: 'titan' }]).mechs[0].max.head, Math.round(plain.max.head * CORES.titan.armor))
  const shot = core => {
    const s = duel(16, MID, { core })
    const [a, b] = s.mechs
    a.armor.rarm = 100
    run(s, 40, i => input({ ax: b.x, ay: b.y, left: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    return { dealt: maxTotal(b) - total(b), heat: a.heat, rarm: a.armor.rarm }
  }
  const base = shot('furnace')
  assert.equal(shot('glass').dealt, Math.floor(GUN.dmg * CORES.glass.dmg))
  assert.ok(shot('coolant').heat < base.heat)
  assert.ok(shot('leech').rarm > base.rarm)
})

test('unknown or missing parts fall back to the default build', () => {
  assert.deepEqual(createState([{ left: 'nope', legs: 'hover' }]).mechs[0].loadout, { ...DEFAULT_LOADOUT, legs: 'hover' })
})

test('overheating locks skills for 1 s while the heat drains to 0', () => {
  const s = duel(25)
  const a = s.mechs[0]
  a.heat = HEAT.max - 1
  let i = 0
  while (!a.overheat && i++ < 60) step(s, [input({ ax: 5, ay: 0, left: i === 1 }), input({ ax: 5, ay: MID })])
  assert.equal(a.overheat, HEAT.overheat)
  run(s, HEAT.overheat / 2, () => input({ ax: 5, ay: 0 }), () => input({ ax: 5, ay: MID }))
  assert.equal(Math.round(a.heat), HEAT.max / 2)
  run(s, HEAT.overheat / 2, () => input({ ax: 5, ay: 0 }), () => input({ ax: 5, ay: MID }))
  assert.equal(a.overheat, 0)
  assert.equal(a.heat, 0)
})

test('pickup pads fill on each wave, mirrored pads get the same item, touching one takes it', () => {
  const s = duel(25)
  run(s, PICKUP.first, () => input({ ax: 30, ay: MID }), () => input({ ax: 5, ay: MID }))
  assert.ok(s.pads.every(Boolean))
  assert.equal(s.pads[0], s.pads[1])
  assert.equal(s.pads[2], s.pads[3])
  assert.notEqual(s.pads[0], s.pads[2])
  Object.assign(s.mechs[0], { x: PADS[0].x, y: PADS[0].y })
  step(s, [input(), input()])
  assert.equal(s.pads[0], null)
  assert.ok(s.pads[1])
})

test('each pickup does its job', () => {
  const take = (kind, setup = () => {}) => {
    const s = duel(25)
    const a = s.mechs[0]
    setup(a)
    s.pads[0] = kind
    Object.assign(a, { x: PADS[0].x, y: PADS[0].y })
    step(s, [input(), input()])
    return a
  }
  const fixed = take('repair', a => Object.assign(a.armor, { head: 100, rarm: 0 }))
  assert.deepEqual(fixed.armor, { ...ARMOR, head: 100 + ITEMS.repair.amount, rarm: ITEMS.repair.amount })
  const cool = take('coolant', a => (a.heat = 90))
  assert.equal(cool.heat, 0)
  assert.ok(cool.buffs.cool > 0)
  assert.equal(take('surge', a => (a.surge = 10)).surge, 10 + ITEMS.surge.amount)
  assert.equal(take('shield').buffs.bubbleHp, ITEMS.shield.absorb)
})

test('speed and power boosts: faster legs, harder hits, no heat while cooled', () => {
  const race = boost => {
    const s = duel(25)
    const a = s.mechs[0]
    a.buffs.speed = boost ? ITEMS.speed.time : 0
    run(s, 60, () => input({ my: 1, ax: 5, ay: 30 }), () => input({ ax: 5, ay: MID }))
    return a.y
  }
  assert.ok(race(true) > race(false) + 1)
  const shot = (buff, time) => {
    const s = duel()
    const [a, b] = s.mechs
    a.buffs[buff] = time
    run(s, 40, i => input({ ax: b.x, ay: b.y, left: i === 0 }), () => input({ ax: a.x, ay: a.y }))
    return { dealt: FULL - arms(b), heat: a.heat }
  }
  assert.equal(shot('power', 0).dealt, GUN.dmg)
  assert.equal(shot('power', ITEMS.power.time).dealt, Math.floor(GUN.dmg * ITEMS.power.dmg))
  assert.ok(shot('cool', 0).heat > 0)
  assert.equal(shot('cool', ITEMS.coolant.time).heat, 0)
})

test('the bot walks to a useful pickup near it', () => {
  const s = duel(25)
  const b = s.mechs[1]
  s.pads[1] = 'shield'
  Object.assign(b, { x: PADS[1].x + 3, y: PADS[1].y + 3 })
  const brain = createBrain(5)
  run(s, 120, () => input({ ax: 5, ay: MID }), () => botInput(s, brain, 1))
  assert.equal(s.pads[1], null)
  assert.ok(b.buffs.bubbleHp > 0)
})

const at = (s, ticks) => (s.clock = MATCH.time - ticks)

test('a crusher plate slams on its timer: Legs damage and a stagger for whoever is under it', () => {
  const s = duel()
  const [a, b] = s.mechs
  const p = TRAPS.crush.at[0]
  Object.assign(a, { x: p.x + 0.5, y: p.y })
  at(s, TRAPS.crush.every)
  step(s, [input(), input()])
  assert.equal(a.armor.legs, a.max.legs - TRAPS.crush.dmg)
  assert.ok(a.stagger > 0)
  assert.equal(b.armor.legs, b.max.legs)
})

test('a tesla pylon zaps everyone in reach, nobody outside it', () => {
  const s = duel()
  const [a, b] = s.mechs
  const p = TRAPS.tesla.at[0]
  Object.assign(a, { x: p.x + 2, y: p.y })
  at(s, TRAPS.tesla.every)
  step(s, [input(), input()])
  assert.equal(arms(a), FULL - TRAPS.tesla.dmg)
  assert.equal(arms(b), FULL)
})

test('oil slicks take the grip away, hover legs float over them', () => {
  const speedAfter = (legs, x, y) => {
    const s = duel(25, MID, { legs })
    Object.assign(s.mechs[0], { x, y })
    run(s, 10, () => input({ my: -1, ax: 30, ay: MID }), () => input({ ax: 5, ay: MID }))
    return Math.abs(s.mechs[0].vy)
  }
  const oil = TRAPS.oil.at[0]
  assert.ok(speedAfter('greaves', oil.x, oil.y) < speedAfter('greaves', 5, MID) * 0.5)
  assert.ok(Math.abs(speedAfter('hover', oil.x, oil.y) - speedAfter('hover', 5, MID)) < 0.01)
})

test('fire vents wake up at 20 s and burn whoever stands in the jet', () => {
  const s = duel()
  const a = s.mechs[0]
  Object.assign(a, { x: ARENA.w / 2, y: 2 })
  at(s, HAZARDS.vents - 1)
  assert.equal(ventPhase(s), null)
  at(s, HAZARDS.vents + HAZARDS.warn)
  step(s, [input(), input()])
  assert.equal(a.armor.legs, a.max.legs - HAZARDS.dmg)
  assert.ok(a.heat > 0)
})

test('sudden death: from 45 s the walls close in and push the mechs to the middle', () => {
  const s = duel()
  const a = s.mechs[0]
  Object.assign(a, { x: 1, y: MID })
  at(s, MATCH.time - 2)
  step(s, [input(), input()])
  assert.ok(s.shrink > HAZARDS.shrink * 0.9)
  assert.ok(a.x >= s.shrink + MECH_R - 0.01)
})

test('the bot steps off a crusher plate before it slams', () => {
  const s = duel()
  const b = s.mechs[1]
  const p = TRAPS.crush.at[0]
  Object.assign(b, { x: p.x, y: p.y })
  at(s, TRAPS.crush.every - TRAPS.crush.warn)
  const brain = createBrain(9)
  run(s, TRAPS.crush.warn + 1, () => input({ ax: 5, ay: MID }), () => botInput(s, brain, 1))
  assert.equal(b.armor.legs, b.max.legs)
})

const brawl = teams => {
  const s = createState([], teams)
  s.phase = 'fight'
  return s
}
const settle = s => {
  do step(s, []); while (s.hitstop > 0)
}

test('free-for-all: four mechs spawn apart, each scores for itself', () => {
  const s = createState([], FORMATS.ffa)
  assert.equal(s.mechs.length, 4)
  assert.deepEqual(s.score, [0, 0, 0, 0])
  for (const a of s.mechs) for (const b of s.mechs) if (a !== b) assert.ok(Math.hypot(a.x - b.x, a.y - b.y) >= 20)
})

test('free-for-all: a K.O. leaves a wreck and the fight goes on until one is left', () => {
  const s = brawl(FORMATS.ffa)
  s.mechs[1].armor.head = 0
  settle(s)
  assert.equal(s.phase, 'fight')
  assert.ok(s.mechs[1].ko)
  s.mechs[2].armor.head = 0
  s.mechs[3].armor.head = 0
  settle(s)
  assert.equal(s.phase, 'ko')
  assert.deepEqual(s.score, [1, 0, 0, 0])
  assert.deepEqual(s.fallen, [1, 2, 3])
})

test('2v2: a shot flies through your teammate and hits the enemy behind', () => {
  const s = brawl(FORMATS['2v2'])
  const [a, b, c, d] = s.mechs
  Object.assign(a, { x: 5, y: MID, aim: 0 })
  Object.assign(c, { x: 10, y: MID })
  Object.assign(b, { x: 16, y: MID, aim: Math.PI })
  Object.assign(d, { x: 60, y: 10 })
  for (let i = 0; i < 60; i++) step(s, [input({ ax: b.x, ay: b.y, left: i === 0 }), input(), input(), input()])
  assert.deepEqual(c.armor, c.max)
  assert.ok(arms(b) < FULL)
})

test('2v2: the round ends only when both mechs of a team are down', () => {
  const s = brawl(FORMATS['2v2'])
  s.mechs[1].armor.head = 0
  settle(s)
  assert.equal(s.phase, 'fight')
  s.mechs[3].armor.head = 0
  settle(s)
  assert.equal(s.phase, 'ko')
  assert.deepEqual(s.score, [1, 0])
})

test('bots finish a whole free-for-all and a whole 2v2', () => {
  for (const teams of [FORMATS.ffa, FORMATS['2v2']]) {
    const s = createState(Object.values(SETS), teams)
    const brains = s.mechs.map(m => createBrain(m.id + 7))
    for (let i = 0; i < 12 * (MATCH.time + MATCH.countdown + MATCH.ko) && s.phase !== 'over'; i++) step(s, s.mechs.map(m => botInput(s, brains[m.id], m.id)))
    assert.equal(s.phase, 'over')
    assert.equal(Math.max(...s.score), MATCH.wins)
  }
})
