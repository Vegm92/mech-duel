import { ARENA, HEAD_ARMOR } from './sim.js'
import { hype, mood } from './hype.js'

const MUTE_KEY = 'mech-duel/muted'
const MUSIC_KEY = 'mech-duel/music'
const VOL_KEY = 'mech-duel/volume'
const VOL_DEFAULT = { master: 1, music: 1, sfx: 1, env: 0.5, crowd: 0.8 }
const ENV = new Set(['crush', 'crushWarn', 'pylon', 'pylonWarn', 'vent', 'ventsOn', 'closing', 'padsUp', 'healUp'])
const MUSIC_VOL = 0.16
const BPM = 112
const STEP = 60 / BPM / 4
const BARS = [
  { root: 110, third: 1.189 },
  { root: 87.31, third: 1.26 },
  { root: 130.81, third: 1.26 },
  { root: 98, third: 1.26 },
]
const set = (base, n) => Array.from({ length: n }, (_, i) => `${base}_${String(i).padStart(3, '0')}`)
const BANK = {
  zap: set('laserSmall', 5),
  laser: set('laserLarge', 5),
  crunch: set('explosionCrunch', 5),
  field: set('forceField', 5),
  thruster: set('thrusterFire', 2),
  rumble: set('lowFrequency_explosion', 2),
  launch: set('doorOpen', 3),
  whine: set('engineCircular', 1),
  hover: set('spaceEngineSmall', 1),
  tread: set('spaceEngineLow', 1),
  plate: set('impactPlate_heavy', 5),
  clank: set('impactMetal_heavy', 5),
  ting: set('impactMetal_light', 5),
  tin: set('impactTin_medium', 5),
  punch: set('impactPunch_heavy', 5),
  punchMid: set('impactPunch_medium', 5),
  thud: set('impactSoft_medium', 5),
  scrape: set('impactMining', 5),
  click: set('impactGeneric_light', 3),
  step: set('footstep_concrete', 5),
  crowdGasp: set('crowdGasp', 3),
  crowdOoh: set('crowdOoh', 1),
  crowdCheer: set('crowdCheer', 3),
  crowdRoar: set('crowdRoar', 3),
  crowdBed: set('crowdBed', 1),
  crowdChant: set('crowdChant', 1),
}

const read = (key, fallback) => {
  try {
    const v = localStorage.getItem(key)
    return v === null ? fallback : v === '1'
  } catch {
    return fallback
  }
}
const write = (key, on) => {
  try {
    localStorage.setItem(key, on ? '1' : '0')
  } catch {}
}

function readVol() {
  try {
    const o = JSON.parse(localStorage.getItem(VOL_KEY)) ?? {}
    return Object.fromEntries(Object.entries(o).filter(([k, v]) => k in VOL_DEFAULT && Number.isFinite(v)))
  } catch {
    return {}
  }
}

let muted = read(MUTE_KEY, false)
let musicOn = read(MUSIC_KEY, true)
const vol = { ...VOL_DEFAULT, ...readVol() }
let ac = null
let master = null
let sfxBus = null
let envBus = null
let crowdBus = null
let musicBus = null
let verbSend = null
let noiseBuf = null
let nextStep = 0
let stepIndex = 0
let lastFrame = 0
let lastState = null
let alarmAt = 0
const buffers = new Map()
const last = new Map()
const seen = new WeakSet()
const curves = new Map()
const engines = new Map()
const was = new Map()

export const isMuted = () => muted
export const isMusicOn = () => musicOn

export const volumes = () => ({ ...vol })

export function toggleMute() {
  muted = !muted
  write(MUTE_KEY, muted)
  if (ac) applyVolumes()
}

export function toggleMusic() {
  musicOn = !musicOn
  write(MUSIC_KEY, musicOn)
  if (ac) applyVolumes()
}

export function setVolume(key, v) {
  vol[key] = clamp(v, 0, 1)
  try {
    localStorage.setItem(VOL_KEY, JSON.stringify(vol))
  } catch {}
  if (ac) applyVolumes()
}

function applyVolumes() {
  const at = (param, v) => param.setTargetAtTime(v, ac.currentTime, 0.08)
  at(master.gain, muted ? 0 : 0.9 * vol.master)
  for (const bus of [sfxBus, envBus, crowdBus, musicBus]) {
    const v = bus === musicBus ? (musicOn ? vol.music : 0) : vol[bus.key]
    at(bus.gain, bus === musicBus ? v * MUSIC_VOL : v)
    at(bus.verb.gain, v)
  }
}

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
const vary = (k = 0.08) => 1 + (Math.random() - 0.5) * k
const panOf = x => (x === undefined ? 0 : clamp((x / ARENA.w) * 2 - 1, -1, 1) * 0.7)

function gainNode(v, to) {
  const g = ac.createGain()
  g.gain.value = v
  if (to) g.connect(to)
  return g
}

function impulse(seconds, decay) {
  const len = Math.floor(ac.sampleRate * seconds)
  const buf = ac.createBuffer(2, len, ac.sampleRate)
  for (let c = 0; c < 2; c++) {
    const d = buf.getChannelData(c)
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay)
  }
  return buf
}

const NAMES = [...new Set(Object.values(BANK).flat())]
const raw = new Map(NAMES.map(n => [n, fetch(`sounds/${n}.ogg`).then(r => r.arrayBuffer()).catch(() => null)]))

async function load() {
  await Promise.all(NAMES.map(async name => {
    try {
      const data = await raw.get(name)
      if (data) buffers.set(name, await ac.decodeAudioData(data))
    } catch {}
  }))
}

export function unlock() {
  if (ac) {
    if (ac.state === 'suspended') ac.resume()
    return
  }
  ac = new AudioContext()
  const comp = ac.createDynamicsCompressor()
  comp.threshold.value = -14
  comp.knee.value = 8
  comp.ratio.value = 3.5
  comp.attack.value = 0.004
  comp.release.value = 0.2
  master = gainNode(0)
  master.connect(comp).connect(ac.destination)
  const verb = ac.createConvolver()
  verb.buffer = impulse(1.6, 3.4)
  verbSend = gainNode(0.3)
  verbSend.connect(verb).connect(master)
  const bus = key => Object.assign(gainNode(0, master), { key, verb: gainNode(0, verbSend) })
  sfxBus = bus('sfx')
  envBus = bus('env')
  crowdBus = bus('crowd')
  musicBus = bus('music')
  applyVolumes()
  noiseBuf = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate)
  const d = noiseBuf.getChannelData(0)
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1
  nextStep = ac.currentTime + 0.1
  load()
}

function route(node, o) {
  const p = ac.createStereoPanner()
  p.pan.value = clamp(o.pan ?? 0, -1, 1)
  const bus = o.bus ?? sfxBus
  node.connect(p).connect(bus)
  if (o.verb) p.connect(gainNode(o.verb, bus.verb))
}

function play(group, o = {}) {
  const names = BANK[group]
  const pick = names.length > 1 ? (((last.get(group) ?? 0) + 1 + Math.floor(Math.random() * (names.length - 1))) % names.length) : 0
  last.set(group, pick)
  const buf = buffers.get(names[pick])
  if (!buf) return
  const t = o.at ?? ac.currentTime
  const rate = (o.rate ?? 1) * vary(o.vary ?? 0.1)
  const src = ac.createBufferSource()
  src.buffer = buf
  src.playbackRate.value = rate
  const g = gainNode(o.vol ?? 1)
  let node = src
  if (o.lowpass || o.highpass) {
    const b = ac.createBiquadFilter()
    b.type = o.lowpass ? 'lowpass' : 'highpass'
    b.frequency.value = o.lowpass ?? o.highpass
    node.connect(b)
    node = b
  }
  node.connect(g)
  const offset = o.offset === 'random' ? Math.random() * Math.max(0, buf.duration - (o.dur ?? 0) * rate - 0.05) : (o.offset ?? 0)
  if (o.dur) {
    g.gain.setValueAtTime(o.vol ?? 1, t + o.dur * 0.6)
    g.gain.linearRampToValueAtTime(0, t + o.dur)
  }
  route(g, o)
  src.start(t, offset, o.dur ? o.dur * rate + 0.02 : undefined)
}

function curve(k) {
  if (!curves.has(k)) {
    const c = new Float32Array(1024)
    for (let i = 0; i < 1024; i++) {
      const x = i / 511.5 - 1
      c[i] = ((1 + k) * x) / (1 + k * Math.abs(x))
    }
    curves.set(k, c)
  }
  return curves.get(k)
}

function chain(src, t0, o) {
  let node = src
  if (o.filter) {
    const b = ac.createBiquadFilter()
    b.type = o.filter.type
    b.frequency.setValueAtTime(o.filter.f, t0)
    if (o.filter.to) b.frequency.exponentialRampToValueAtTime(o.filter.to, t0 + (o.a ?? 0.004) + o.dur)
    b.Q.value = o.filter.q ?? 1
    node.connect(b)
    node = b
  }
  if (o.drive) {
    const ws = ac.createWaveShaper()
    ws.curve = curve(o.drive)
    node.connect(ws)
    node = ws
  }
  const g = ac.createGain()
  const a = o.a ?? 0.004
  g.gain.setValueAtTime(0.0001, t0)
  g.gain.exponentialRampToValueAtTime(Math.max(0.0002, o.vol), t0 + a)
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + a + o.dur)
  node.connect(g)
  route(g, o)
  return a + o.dur + 0.05
}

function tone(t0, o) {
  const osc = ac.createOscillator()
  osc.type = o.type ?? 'sine'
  osc.frequency.setValueAtTime(o.f, t0)
  if (o.to) osc.frequency.exponentialRampToValueAtTime(o.to, t0 + (o.a ?? 0.004) + o.dur)
  if (o.detune) osc.detune.value = o.detune
  const end = chain(osc, t0, o)
  osc.start(t0)
  osc.stop(t0 + end)
}

const CROWD = {
  gasp: { rank: 1, group: 'crowdGasp', vol: 0.25, len: 1.4 },
  ooh: { rank: 1, group: 'crowdOoh', vol: 0.18, len: 1.6 },
  cheer: { rank: 2, group: 'crowdCheer', vol: 0.3, len: 1.8 },
  roar: { rank: 3, group: 'crowdRoar', vol: 0.5, len: 3.5 },
  ko: { rank: 4, group: 'crowdRoar', vol: 0.5, len: 3.5 },
}
let crowdUntil = 0
let crowdRank = 0
let stackAt = 0
let bed = null
let wildSince = null
let chantAt = 0

function crowdBed(on) {
  if (!bed) {
    const buf = buffers.get(BANK.crowdBed[0])
    if (!buf) return
    const src = ac.createBufferSource()
    src.buffer = buf
    src.loop = true
    bed = gainNode(0)
    src.connect(bed)
    route(bed, { bus: crowdBus })
    src.start(ac.currentTime, Math.random() * buf.duration)
    bed.level = 0
  }
  const level = on ? 0.06 + 0.08 * (hype() / 100) : 0
  if (Math.abs(level - bed.level) < 0.004) return
  bed.level = level
  bed.gain.setTargetAtTime(level, ac.currentTime, on ? 0.8 : 0.3)
}

function chant(live) {
  const t = ac.currentTime
  if (!live || mood(hype()) < 2) {
    wildSince = null
    return
  }
  wildSince ??= t
  if (t - wildSince < 3 || t < chantAt) return
  chantAt = t + 22
  play('crowdChant', { vol: 0.16, bus: crowdBus, verb: 0.3, vary: 0.02 })
}

function react(kind, t, k = 1, stack = false) {
  const o = CROWD[kind]
  if (stack ? t < stackAt : t < crowdUntil && o.rank <= crowdRank) return
  stackAt = t + 0.6
  if (t >= crowdUntil || o.rank >= crowdRank) {
    crowdUntil = t + o.len
    crowdRank = o.rank
  }
  play(o.group, { vol: o.vol * k, at: t, bus: crowdBus, verb: 0.3, vary: 0.06 })
}

function moment(t, big) {
  const m = mood(hype())
  if (m < 2) return react(big ? 'cheer' : 'gasp', t, big || m ? 1 : 0.6)
  react(big ? 'roar' : 'cheer', t, 1, true)
  if (Math.random() < 0.5) react(big ? 'cheer' : 'gasp', t + 0.6 + Math.random() * 0.4, 0.7, true)
}

function noise(t0, o) {
  const src = ac.createBufferSource()
  src.buffer = noiseBuf
  src.loop = true
  const end = chain(src, t0, o)
  src.start(t0, Math.random() * 1.5)
  src.stop(t0 + end)
}

function whoosh(t0, dur, f0, f1, vol, pan) {
  noise(t0, { dur, a: dur * 0.35, vol, pan, filter: { type: 'bandpass', f: f0, to: f1, q: 1.4 } })
}

let chipAt = 0

const SOUNDS = {
  muzzle(f, t, p, v) {
    if (f.gun === 'needle') {
      play('laser', { vol: 0.5 * v, pan: p, verb: 0.25 })
      play('thud', { vol: 0.5 * v, pan: p, rate: 0.7 })
    } else if (f.gun === 'scatter') {
      play('crunch', { vol: 0.4 * v, pan: p, rate: 1.25, dur: 0.32 })
      play('punchMid', { vol: 0.45 * v, pan: p, rate: 0.9 })
    } else if (f.gun === 'gatling') {
      play('zap', { vol: 0.32 * v, pan: p, rate: 1.7, dur: 0.12 })
      play('click', { vol: 0.25 * v, pan: p, rate: 0.8 })
    } else if (f.gun === 'flamer') {
      play('thruster', { vol: 0.2 * v, pan: p, rate: 1.3, dur: 0.2, offset: 'random' })
    } else if (f.gun === 'missiles') {
      play('launch', { vol: 0.4 * v, pan: p, rate: 1.8, dur: 0.3 })
      whoosh(t, 0.35, 400, 2400, 0.18 * v, p)
    } else if (f.gun === 'mortar') {
      play('punch', { vol: 0.7 * v, pan: p, rate: 0.6 })
      play('thud', { vol: 0.5 * v, pan: p, rate: 0.5, verb: 0.3 })
    } else if (f.gun === 'laser') {
      play('laser', { vol: 0.5 * v, pan: p, rate: 1.4, dur: 0.4 })
    } else if (f.gun === 'tesla') {
      play('field', { vol: 0.35 * v, pan: p, rate: 2.6, dur: 0.25 })
      noise(t, { a: 0.002, dur: 0.15, vol: 0.22 * v, pan: p, filter: { type: 'highpass', f: 3000 } })
    } else if (f.gun === 'ricochet') {
      play('zap', { vol: 0.55 * v, pan: p, rate: 0.85 })
      play('ting', { vol: 0.2 * v, pan: p, rate: 1.6 })
    } else {
      play('zap', { vol: 0.65 * v, pan: p, rate: 1.1 })
      play('thud', { vol: 0.4 * v, pan: p })
    }
  },
  slash(f, t, p, v) {
    if (f.blade === 'drill') {
      play('whine', { vol: 0.22 * v, pan: p, rate: 1.2, dur: 0.35, offset: 'random' })
      whoosh(t, 0.25, 500, 1800, 0.15 * v, p)
    } else if (f.blade === 'hammer') {
      whoosh(t, 0.25, 250, 1200, 0.3 * v, p)
      play('field', { vol: 0.25 * v, pan: p, rate: 2, dur: 0.3, offset: 0.1 })
    } else if (f.blade === 'claws') {
      whoosh(t, 0.12, 1500, 5000, 0.22 * v, p)
      play('scrape', { vol: 0.15 * v, pan: p, rate: 1.8 })
    } else if (f.blade === 'whip') {
      whoosh(t, 0.3, 600, 3500, 0.25 * v, p)
      play('tin', { vol: 0.3 * v, pan: p, at: t + 0.15, rate: 1.4 })
    } else if (f.blade === 'bunker') {
      play('punch', { vol: 0.75 * v, pan: p, rate: 0.75 })
      play('clank', { vol: 0.5 * v, pan: p, rate: 0.8, at: t + 0.04 })
    } else if (f.blade === 'katana') {
      whoosh(t, 0.18, 1200, 5200, 0.22 * v, p)
      play('field', { vol: 0.2 * v, pan: p, rate: 3, dur: 0.25 })
    } else if (f.blade === 'bash') {
      play('plate', { vol: 0.5 * v, pan: p, rate: 0.9 })
      play('thud', { vol: 0.5 * v, pan: p, rate: 0.7 })
    } else if (f.blade === 'fist') {
      play('thruster', { vol: 0.35 * v, pan: p, dur: 0.25, offset: 'random', rate: 1.2 })
      play('punch', { vol: 0.6 * v, pan: p, at: t + 0.06 })
    } else if (f.blade === 'flail') {
      whoosh(t, 0.4, 200, 900, 0.3 * v, p)
      play('clank', { vol: 0.25 * v, pan: p, rate: 0.7, at: t + 0.1 })
    } else {
      whoosh(t, 0.2, 900, 4200, 0.25 * v, p)
      play('whine', { vol: 0.14 * v, pan: p, rate: 2.2, dur: 0.22, offset: 'random' })
    }
  },
  hit(f, t, p) {
    if (f.n < 15 && !f.head) {
      if (t - chipAt < 0.09) return
      chipAt = t
    }
    if (f.head) {
      tone(t, { type: 'sawtooth', f: 90, to: 45, a: 0.002, dur: 0.35, vol: 0.12, pan: p })
      noise(t, { a: 0.002, dur: 0.3, vol: 0.35, pan: p, filter: { type: 'bandpass', f: 600 } })
    } else {
      tone(t, { type: 'square', f: 320, to: 192, a: 0.002, dur: 0.07, vol: 0.06, pan: p })
      noise(t, { a: 0.002, dur: 0.06, vol: 0.2, pan: p, filter: { type: 'bandpass', f: 2500 } })
    }
  },
  break(f, t, p, v) {
    play('plate', { vol: 0.9 * v, pan: p, verb: 0.3 })
    play('crunch', { vol: 0.35 * v, pan: p, rate: 1.3, dur: 0.45 })
    play('scrape', { vol: 0.35 * v, pan: p, at: t + 0.08, rate: 1.2 })
    moment(t + 0.1, true)
  },
  parry(f, t, p) {
    play('field', { vol: 0.3, pan: p, rate: 1.5, dur: 0.45, verb: 0.4 })
    tone(t, { f: 1760, dur: 0.5, vol: 0.08, pan: p, verb: 0.5 })
    moment(t + 0.05)
  },
  blink(f, t, p, v) {
    play('launch', { vol: 0.4 * v, pan: p, rate: 1.8, dur: 0.3 })
    play('field', { vol: 0.25 * v, pan: p, rate: 2, dur: 0.3 })
  },
  magnet(f, t, p, v) {
    play('field', { vol: 0.35 * v, pan: p, rate: 0.8, dur: 0.4 })
  },
  land(f, t, p, v) {
    play('thud', { vol: 0.75 * v, pan: p, rate: 0.85 })
    play('rumble', { vol: 0.35 * v, pan: p, dur: 0.5 })
  },
  dash(f, t, p, v) {
    play('thruster', { vol: 0.55 * v, pan: p, dur: 0.35, offset: 'random' })
  },
  hookOut(f, t, p, v) {
    play('launch', { vol: 0.3 * v, pan: p, rate: 1.5, dur: 0.3 })
  },
  hooked(f, t, p, v) {
    play('clank', { vol: 0.8 * v, pan: p, verb: 0.2 })
    play('tin', { vol: 0.4 * v, pan: p, at: t + 0.05 })
    moment(t + 0.05)
  },
  charge(f, t, p, v) {
    play('field', { vol: 0.35 * v, pan: p, rate: 1.55 })
  },
  beam(f) {
    const p = panOf((f.x1 + f.x2) / 2)
    play('laser', { vol: 0.75, pan: p, rate: 0.55, verb: 0.4 })
    play('rumble', { vol: 0.7, pan: p, dur: 1.2 })
    play('crunch', { vol: 0.35, pan: p, rate: 0.8 })
  },
  boom(f, t, p) {
    play('crunch', { vol: f.big ? 0.75 : 0.5, pan: p, rate: f.big ? 0.7 : 1, verb: 0.3 })
    play('rumble', { vol: f.big ? 0.9 : 0.45, pan: p, dur: f.big ? 1.2 : 0.6 })
    if (f.big) moment(t + 0.1)
  },
  emp(f, t, p) {
    play('field', { vol: 0.5, pan: p, rate: 0.7, verb: 0.4 })
    play('rumble', { vol: 0.4, pan: p, dur: 0.6 })
    noise(t, { a: 0.002, dur: 0.3, vol: 0.2, pan: p, filter: { type: 'highpass', f: 2500 } })
  },
  soak(f, t, p) {
    play('field', { vol: 0.15, pan: p, rate: 2.2, dur: 0.2 })
  },
  ult(f, t, p) {
    play('field', { vol: 0.4, pan: p, rate: 1.1, verb: 0.4 })
    for (const k of [1, 1.5]) tone(t, { type: 'sawtooth', f: 330 * k, a: 0.01, dur: 0.4, vol: 0.035, pan: p, filter: { type: 'lowpass', f: 2000 }, verb: 0.4 })
    react('ooh', t)
  },
  ko(f, t, p) {
    play('rumble', { vol: 0.9, pan: p, verb: 0.4 })
    play('crunch', { vol: 0.55, pan: p, rate: 0.7, verb: 0.4 })
    play('plate', { vol: 0.6, pan: p, at: t + 0.15 })
    react('ko', t + 0.1)
    react('cheer', t + 1, 0.7, true)
  },
  ping(f, t, p) {
    play('ting', { vol: 0.18, pan: p, rate: 1.4, vary: 0.3 })
  },
  count(f, t) {
    tone(t, { type: 'square', f: f.n === 1 ? 990 : 660, dur: 0.14, vol: 0.05, filter: { type: 'lowpass', f: 3000 }, verb: 0.3 })
  },
  fight(f, t) {
    for (const k of [1, 1.26, 1.5, 2]) tone(t, { type: 'sawtooth', f: 220 * k, a: 0.02, dur: 0.7, vol: 0.04, filter: { type: 'lowpass', f: 900, to: 3500 }, verb: 0.4 })
    play('punch', { vol: 0.6 })
    react('cheer', t + 0.15)
  },
  time(f, t) {
    for (const k of [1, 1.06]) tone(t, { type: 'square', f: 180 * k, dur: 0.8, vol: 0.045, filter: { type: 'lowpass', f: 1200 } })
  },
  heal(f, t, p) {
    ;[523, 659, 784, 1047, 1319].forEach((fr, i) => tone(t + i * 0.06, { f: fr, dur: 0.5, vol: 0.05, pan: p, verb: 0.6 }))
    play('field', { vol: 0.15, pan: p, rate: 2.2, dur: 0.5 })
  },
  pickup(f, t, p) {
    ;[784, 988, 1319].forEach((fr, i) => tone(t + i * 0.05, { f: fr, dur: 0.3, vol: 0.045, pan: p, verb: 0.5 }))
    play('field', { vol: 0.12, pan: p, rate: 2.6, dur: 0.3 })
  },
  crush(f, t, p, v) {
    play('thud', { vol: 0.5 * v, pan: p, rate: 0.7, bus: envBus })
    play('rumble', { vol: 0.25 * v, pan: p, dur: 0.6, bus: envBus })
    play('plate', { vol: 0.25 * v, pan: p, rate: 0.8, at: t + 0.04, bus: envBus })
  },
  crushWarn(f, t, p, v) {
    for (const k of [0, 1, 2]) tone(t + k * 0.3, { type: 'square', f: 520, dur: 0.1, vol: 0.03 * v, pan: p, filter: { type: 'lowpass', f: 2000 }, bus: envBus })
  },
  pylon(f, t, p, v) {
    play('zap', { vol: 0.35 * v, pan: p, rate: 0.85, bus: envBus })
  },
  pylonWarn(f, t, p, v) {
    play('whine', { vol: 0.12 * v, pan: p, rate: 1.3, dur: 0.8, bus: envBus })
  },
  vent(f, t) {
    play('thruster', { vol: 0.25, dur: 1.4, bus: envBus })
  },
  ventsOn(f, t) {
    for (const k of [0, 1]) tone(t + k * 0.22, { type: 'square', f: 740, dur: 0.16, vol: 0.04, filter: { type: 'lowpass', f: 2500 }, bus: envBus })
  },
  closing(f, t) {
    for (const k of [0, 1, 2, 3]) tone(t + k * 0.25, { type: 'square', f: k % 2 ? 620 : 880, dur: 0.18, vol: 0.05, filter: { type: 'lowpass', f: 2500 }, verb: 0.3, bus: envBus })
  },
  padsUp(f, t) {
    tone(t, { f: 880, dur: 0.18, vol: 0.03, verb: 0.5, bus: envBus })
    tone(t + 0.07, { f: 1320, dur: 0.22, vol: 0.025, verb: 0.5, bus: envBus })
  },
  healUp(f, t) {
    tone(t, { f: 1175, dur: 0.4, vol: 0.045, verb: 0.6, bus: envBus })
    tone(t + 0.08, { f: 1568, dur: 0.5, vol: 0.035, verb: 0.6, bus: envBus })
  },
}

export function preview(key) {
  if (!ac || muted) return
  const t = ac.currentTime
  if (key === 'env') SOUNDS.crush({}, t, 0, 1)
  else if (key === 'crowd') react('cheer', t)
  else if (key !== 'music') play('ting', { vol: 0.35, rate: 1.25 })
}

const servo = (t, f, to, dur) => tone(t, { type: 'sawtooth', f, to, a: 0.005, dur, vol: 0.05, filter: { type: 'bandpass', f: f * 3, q: 3 } })

const UI = {
  hover: t => tone(t, { type: 'square', f: 600, to: 900, a: 0.003, dur: 0.035, vol: 0.03, filter: { type: 'bandpass', f: 1800, q: 3 } }),
  up: t => servo(t, 400, 800, 0.06),
  down: t => servo(t, 600, 300, 0.07),
  tab(t) {
    whoosh(t, 0.08, 2500, 6000, 0.05)
    tone(t + 0.03, { f: 1568, dur: 0.05, vol: 0.035 })
  },
  equip(t) {
    servo(t, 200, 500, 0.12)
    play('clank', { vol: 0.35, rate: 1.5, at: t + 0.12 })
    noise(t + 0.13, { dur: 0.1, vol: 0.04, filter: { type: 'highpass', f: 4000 } })
  },
  set(t) {
    play('launch', { vol: 0.25, rate: 1.3, dur: 0.35, at: t })
    play('plate', { vol: 0.5, at: t + 0.18 })
    play('clank', { vol: 0.3, rate: 1.4, at: t + 0.26 })
  },
  select: () => play('ting', { vol: 0.35, rate: 1.25 }),
  start() {
    play('punch', { vol: 0.7 })
    play('field', { vol: 0.3, rate: 1.2, dur: 0.7 })
  },
}

export function uiSound(kind) {
  if (!ac || muted) return
  UI[kind]?.(ac.currentTime)
}

const LOOPS = { hover: 'hover', jets: 'hover', treads: 'tread', wheels: 'tread', skates: 'tread', mono: 'tread' }
const STEPS = { greaves: { stride: 1.15, rate: 0.65, vol: 1 }, spider: { stride: 0.55, rate: 1.1, vol: 0.45 }, quad: { stride: 0.8, rate: 0.9, vol: 0.7 }, stompers: { stride: 1.5, rate: 0.45, vol: 1.4 } }

function engine(m) {
  const kind = m.loadout.legs
  const key = `${m.id}${kind}`
  let e = engines.get(m.id)
  if (e && e.key === key) return e
  const group = LOOPS[kind] ?? null
  const buf = group ? buffers.get(BANK[group][0]) : null
  if (group && !buf) return null
  if (e) e.stop()
  const out = gainNode(0)
  const pan = ac.createStereoPanner()
  out.connect(pan).connect(sfxBus)
  let src = null
  if (buf) {
    src = ac.createBufferSource()
    src.buffer = buf
    src.loop = true
    src.connect(out)
    src.start(ac.currentTime, Math.random() * buf.duration)
  }
  e = {
    key, kind, group, out, pan, src, dist: 0,
    stop() {
      out.gain.setTargetAtTime(0, ac.currentTime, 0.05)
      src?.stop(ac.currentTime + 0.3)
    },
  }
  engines.set(m.id, e)
  return e
}

function engineSounds(state, dt, live) {
  for (const m of state.mechs) {
    const e = engine(m)
    if (!e) continue
    const sp = Math.hypot(m.vx, m.vy)
    const on = live && !m.ko
    const v = (m.id === 0 ? 1 : 0.7) * (on ? 1 : 0)
    const target = e.group === 'hover' ? 0.05 + sp * 0.012 : e.group === 'tread' ? 0.03 + sp * 0.018 : 0
    e.out.gain.setTargetAtTime(target * v, ac.currentTime, 0.08)
    e.pan.pan.value = panOf(m.x)
    if (e.src) e.src.playbackRate.setTargetAtTime(0.8 + sp * 0.05, ac.currentTime, 0.1)
    const st = STEPS[e.kind]
    if (!on || sp < 0.5 || !st) continue
    e.dist += sp * dt
    if (e.dist < st.stride) continue
    e.dist = 0
    play('step', { vol: 0.4 * v * st.vol, pan: panOf(m.x), rate: st.rate })
    play('thud', { vol: 0.2 * v * st.vol, pan: panOf(m.x), rate: st.rate + 0.15 })
  }
}

function alarms(state, now) {
  for (const m of state.mechs) {
    const t = ac.currentTime
    if (m.overheat > 0 && !(was.get(m.id) > 0)) {
      play('thruster', { vol: 0.35, pan: panOf(m.x), dur: 0.9, offset: 'random', highpass: 2500 })
      if (m.id === 0) for (let i = 0; i < 3; i++) tone(t + i * 0.16, { type: 'square', f: 880, dur: 0.07, vol: 0.035, filter: { type: 'lowpass', f: 2000 } })
    }
    if (m.id === 0 && !(m.overheat > 0) && was.get(m.id) > 0) {
      play('click', { vol: 0.45, rate: 1.3 })
      tone(t + 0.03, { f: 1320, dur: 0.09, vol: 0.04, verb: 0.2 })
    }
    was.set(m.id, m.overheat)
  }
  const me = state.mechs[0]
  if (state.phase === 'fight' && !me.ko && me.armor.head < HEAD_ARMOR * 0.25 && now - alarmAt > 900) {
    alarmAt = now
    tone(ac.currentTime, { f: 740, dur: 0.12, vol: 0.03, verb: 0.2 })
  }
}

function drum(t, kind, level) {
  const bus = musicBus
  if (kind === 'kick') {
    tone(t, { f: 150, to: 42, dur: 0.16, vol: 0.9, bus })
    noise(t, { dur: 0.01, vol: 0.25, bus, filter: { type: 'highpass', f: 3000 } })
  } else if (kind === 'snare') {
    noise(t, { dur: 0.16, vol: 0.32, bus, filter: { type: 'bandpass', f: 1900, q: 0.7 } })
    tone(t, { type: 'triangle', f: 200, to: 140, dur: 0.08, vol: 0.25, bus })
  } else noise(t, { dur: level > 1 ? 0.04 : 0.025, vol: 0.09, bus, filter: { type: 'highpass', f: 7500 } })
}

function playStep(i, t, level) {
  const bar = BARS[Math.floor(i / 16) % BARS.length]
  const s = i % 16
  const bus = musicBus
  if (s === 0) {
    for (const det of [-9, 0, 9]) for (const k of [2, 2 * bar.third, 3]) tone(t, { type: 'sawtooth', f: bar.root * k, detune: det, a: 0.6, dur: STEP * 16, vol: 0.018, bus, filter: { type: 'lowpass', f: 900 } })
  }
  if (level >= 1 && s % 2 === 0) {
    const f = bar.root * (s % 8 === 6 ? 2 : 1) * 0.5
    tone(t, { type: 'sawtooth', f, dur: STEP * 1.6, vol: level >= 2 ? 0.16 : 0.1, bus, filter: { type: 'lowpass', f: level >= 2 ? 750 : 450 } })
  }
  const arp = [4, 4 * bar.third, 6, 8, 6, 4 * bar.third][s % 6]
  if (s % (level >= 2 ? 1 : 2) === 0) tone(t, { type: 'triangle', f: bar.root * arp, dur: STEP * 1.5, vol: level >= 2 ? 0.035 : 0.03, bus, verb: 0.3 })
  if (s % 4 === 2) drum(t, 'hat', level)
  if (level >= 2) {
    if (s % 4 === 0) drum(t, 'kick', level)
    if (s === 4 || s === 12) drum(t, 'snare', level)
    if (s % 2 === 1) noise(t, { dur: 0.015, vol: 0.035, bus, filter: { type: 'highpass', f: 9000 } })
  }
}

function music(level) {
  if (nextStep < ac.currentTime - 0.25) nextStep = ac.currentTime + 0.05
  while (nextStep < ac.currentTime + 0.12) {
    playStep(stepIndex, nextStep, level)
    nextStep += STEP
    stepIndex = (stepIndex + 1) % (16 * BARS.length)
  }
}

export function sounds(state, scene, paused) {
  if (!ac || ac.state !== 'running') return
  const now = performance.now()
  const dt = Math.min(0.1, lastFrame ? (now - lastFrame) / 1000 : 0)
  lastFrame = now
  if (state !== lastState) {
    for (const e of engines.values()) e.stop()
    engines.clear()
    was.clear()
    lastState = state
  }
  const live = scene === 'match' && !paused && state.phase === 'fight'
  const level = scene !== 'match' || paused ? 0 : state.phase === 'fight' ? 2 : 1
  music(level)
  crowdBed(scene === 'match' && !paused)
  chant(live && !muted)
  if (muted) return
  engineSounds(state, dt, live)
  if (scene === 'match') alarms(state, now)
  const me = state.mechs[0]
  const near = f => (f.x === undefined ? 1 : clamp(1.25 - Math.hypot(f.x - me.x, f.y - me.y) / 25, 0.1, 1))
  for (const f of state.fx) {
    if (seen.has(f)) continue
    seen.add(f)
    if (scene !== 'match') continue
    SOUNDS[f.k]?.(f, ac.currentTime, panOf(f.x), ENV.has(f.k) ? near(f) : f.id === 1 ? 0.75 : 1)
  }
}

export const audio = { play, tone, noise, whoosh, react, now: () => ac.currentTime }
