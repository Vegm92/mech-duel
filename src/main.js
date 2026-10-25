import { createState, step, TICKS, normalize, SETS, FORMATS } from './sim.js'
import { dummyInput, DUMMY_MODES } from './dummy.js'
import { botInput, createBrain, randomLoadout } from './bot.js'
import { draw, toWorld, cut } from './render.js'
import { KILLCAM, recorder, record, wantsReplay, replay as startReplay, play, speed, progress } from './killcam.js'
import { garageHit, SLOTS, verdict } from './garage.js'
import { t, applyLang, toggleLang } from './i18n.js'
import { trackHype, hype } from './hype.js'
import { sounds, toggleMute, isMuted, toggleMusic, isMusicOn, unlock, uiSound, volumes, setVolume, preview, setSlow, rewind } from './sfx.js'

const MODES = ['bot', ...DUMMY_MODES]
const LOADOUT_KEY = 'mech-duel/loadout'
const FORMAT_KEY = 'mech-duel/format'
const canvas = document.querySelector('canvas')
const ctx = canvas.getContext('2d')
const menu = document.getElementById('menu')
const keys = new Set()
const buttons = new Set()
const tapped = new Set()
const mouse = { x: 0, y: 0 }
let brain = createBrain(Date.now())
let pilot = createBrain(Date.now() + 1)
let crew = []
let state = demo()
let loadout = savedLoadout()
let format = savedFormat()
let screen = 'title'
let hover = null
let tab = 0
let mode = 0
let paused = false
let options = false
let autopilot = false
let pixel = true
let rec = recorder()
let replay = null
let acc = 0
let last = performance.now()

function savedLoadout() {
  try {
    const lo = JSON.parse(localStorage.getItem(LOADOUT_KEY))
    return normalize({ left: lo?.rarm, right: lo?.larm, ...lo })
  } catch {
    return normalize()
  }
}

function savedFormat() {
  try {
    const f = localStorage.getItem(FORMAT_KEY)
    return f in FORMATS ? f : '1v1'
  } catch {
    return '1v1'
  }
}

function setFormat(f) {
  format = f
  try {
    localStorage.setItem(FORMAT_KEY, f)
  } catch {}
}

function demo() {
  return createState([randomLoadout(pilot), randomLoadout(brain)])
}

function resize() {
  const dpr = window.devicePixelRatio || 1
  canvas.width = Math.round(innerWidth * dpr)
  canvas.height = Math.round(innerHeight * dpr)
}

function toGarage() {
  screen = 'garage'
  replay = null
  paused = false
  options = false
  uiSound('select')
}

function fillMenu() {
  const inMatch = screen === 'match'
  menu.querySelector('h2').textContent = t(inMatch ? 'mPaused' : 'mOptions')
  menu.querySelector('[data-act=resume]').textContent = t(inMatch ? 'mResume' : 'mBack')
  menu.querySelector('[data-act=lang]').textContent = t('mLang')
  menu.querySelector('[data-act=view]').textContent = t('mView', { v: t(pixel ? 'mPixel' : 'mFlat') })
  for (const el of menu.querySelectorAll('[data-t]')) el.textContent = t(el.dataset.t)
  for (const el of menu.querySelectorAll('.match')) el.hidden = !inMatch
  const v = volumes()
  for (const el of menu.querySelectorAll('input')) {
    el.value = Math.round(v[el.dataset.vol] * 100)
    el.nextElementSibling.textContent = `${el.value}%`
  }
}

function syncMenu() {
  const open = (screen === 'match' && paused) || (screen === 'title' && options)
  if (open === !menu.hidden) return
  menu.hidden = !open
  document.body.classList.toggle('menu', open)
  if (!open) return document.activeElement?.blur()
  fillMenu()
  menu.querySelector('button').focus()
}

function fight() {
  uiSound('start')
  try {
    localStorage.setItem(LOADOUT_KEY, JSON.stringify(loadout))
  } catch {}
  brain = createBrain(Date.now())
  pilot = createBrain(Date.now() + 1)
  crew = [pilot, brain, createBrain(Date.now() + 2), createBrain(Date.now() + 3)]
  const teams = FORMATS[format]
  state = createState(teams.map((_, i) => (i ? randomLoadout(brain) : loadout)), teams)
  rec = recorder()
  replay = null
  screen = 'match'
  paused = false
}

function playerInput() {
  const a = toWorld(mouse.x, mouse.y)
  const key = c => keys.has(c) || tapped.has(c)
  const btn = b => buttons.has(b) || tapped.has(`Mouse${b}`)
  const input = {
    mx: keys.has('KeyD') - keys.has('KeyA'),
    my: keys.has('KeyS') - keys.has('KeyW'),
    ax: a.x,
    ay: a.y,
    left: btn(0),
    right: btn(2),
    shield: key('KeyQ'),
    hook: key('KeyE'),
    dash: key('Space'),
    ult: key('KeyR') || btn(3),
  }
  tapped.clear()
  return input
}

const isDuel = () => state.mechs.length === 2
const rivalInput = () => (MODES[mode] === 'bot' || !isDuel() ? botInput(state, brain) : dummyInput(state, MODES[mode]))

function tick(input) {
  if (screen !== 'match') {
    step(state, [botInput(state, pilot, 0), botInput(state, brain, 1)])
    if (state.phase === 'over') state = demo()
    return
  }
  if (replay) return play(replay) || endReplay()
  const ins = [input ?? (autopilot ? botInput(state, pilot, 0) : playerInput()), rivalInput(), ...state.mechs.slice(2).map(m => botInput(state, crew[m.id], m.id))]
  record(rec, state, ins)
  step(state, ins)
  if (wantsReplay(state)) {
    replay = startReplay(rec, state.finalKo)
    cut()
    rewind()
  }
}

function endReplay() {
  replay = null
  tapped.clear()
  while (state.phase === 'ko') step(state, [])
}

const skip = () => replay && replay.i >= KILLCAM.grace && endReplay()

const render = () => {
  syncMenu()
  trackHype(state)
  const view = replay?.state ?? state
  const slow = replay ? speed(replay) : 1
  setSlow(slow < 1)
  sounds(view, screen, paused)
  const menuW = menu.hidden ? 0 : (menu.getBoundingClientRect().right + 16) * (window.devicePixelRatio || 1)
  draw(ctx, view, { screen, mode: isDuel() ? MODES[mode] : 'bot', format, paused, mouse, hover, loadout, tab, muted: isMuted(), music: isMusicOn(), pixel, menuW, replay: replay && progress(replay), speed: slow, focus: slow < 1 ? replay.focus : null })
}

function frame(now) {
  acc = Math.min(acc + (now - last) / 1000, 0.25)
  last = now
  while (acc >= 1 / TICKS) {
    if (!paused) tick()
    acc -= 1 / TICKS
  }
  render()
  requestAnimationFrame(frame)
}

function confirm() {
  if (screen === 'title') toGarage()
  else if (screen === 'garage') fight()
  else if (replay) skip()
  else if (state.phase === 'over') toGarage()
}

addEventListener('resize', resize)
addEventListener('keydown', e => {
  if ((e.code === 'Space' || e.code === 'Tab') && menu.hidden) e.preventDefault()
  unlock()
  if (e.repeat) return
  keys.add(e.code)
  tapped.add(e.code)
  if (e.code === 'Escape') {
    if (screen === 'match') paused = !paused
    else if (screen === 'garage') screen = 'title'
    else options = !options
  }
  if (e.code === 'Tab' && screen === 'garage') {
    tab = (tab + (e.shiftKey ? SLOTS.length - 1 : 1)) % SLOTS.length
    uiSound('tab')
  }
  if (e.code === 'KeyL') toggleLang()
  if (e.code === 'KeyM') toggleMute()
  if (e.code === 'KeyN') toggleMusic()
  if (e.code === 'KeyV') pixel = !pixel
  if ((e.code === 'Enter' || e.code === 'NumpadEnter') && menu.hidden) confirm()
  const n = ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5'].indexOf(e.code)
  if (n >= 0) mode = n
  if (!menu.hidden) fillMenu()
})
menu.addEventListener('click', e => {
  const act = e.target.closest('[data-act]')?.dataset.act
  if (act === 'resume') {
    paused = false
    options = false
  } else if (act === 'restart') fight()
  else if (act === 'garage') toGarage()
  else if (act === 'lang') toggleLang()
  else if (act === 'view') pixel = !pixel
  if (act === 'lang' || act === 'view') uiSound('tab')
  fillMenu()
})
menu.addEventListener('pointerover', e => e.target.matches('button') && uiSound('hover'))
menu.addEventListener('input', e => {
  setVolume(e.target.dataset.vol, e.target.value / 100)
  e.target.nextElementSibling.textContent = `${e.target.value}%`
})
menu.addEventListener('change', e => preview(e.target.dataset.vol))
addEventListener('keyup', e => keys.delete(e.code))
addEventListener('blur', () => {
  keys.clear()
  buttons.clear()
  if (screen === 'match') paused = true
})
function aimAt(e) {
  mouse.x = e.offsetX * (canvas.width / canvas.clientWidth)
  mouse.y = e.offsetY * (canvas.height / canvas.clientHeight)
  const next = screen === 'garage' ? garageHit(mouse.x, mouse.y) : null
  if (next && (next.fight !== hover?.fight || next.key !== hover?.key || next.slot !== hover?.slot || next.tab !== hover?.tab || next.set !== hover?.set || next.format !== hover?.format)) uiSound(['down', 'hover', 'up'][verdict(next, loadout) + 1])
  hover = next
}
canvas.addEventListener('mousemove', aimAt)
canvas.addEventListener('mousedown', e => {
  e.preventDefault()
  unlock()
  if (!menu.hidden) return
  aimAt(e)
  if (screen === 'title') return toGarage()
  if (screen === 'garage') {
    if (hover?.fight) fight()
    else if (hover?.format) {
      setFormat(hover.format)
      uiSound('tab')
    } else if (hover?.tab !== undefined) {
      tab = hover.tab
      uiSound('tab')
    } else if (hover?.slot) {
      loadout = { ...loadout, [hover.slot]: hover.key }
      uiSound('equip')
    } else if (hover?.set) {
      loadout = { ...SETS[hover.set] }
      uiSound('set')
    }
    return
  }
  if (replay) return e.button === 0 && skip()
  if (state.phase === 'over' && e.button === 0) return toGarage()
  buttons.add(e.button)
  tapped.add(`Mouse${e.button}`)
})
addEventListener('mouseup', e => {
  if (e.button > 2) e.preventDefault()
  buttons.delete(e.button)
})
canvas.addEventListener('contextmenu', e => e.preventDefault())

window.duel = {
  get state() {
    return state
  },
  get screen() {
    return screen
  },
  get loadout() {
    return loadout
  },
  get hype() {
    return hype()
  },
  get replay() {
    return replay
  },
  tick,
  skip,
  render,
  toGarage,
  fight,
  setLoadout: l => (loadout = normalize({ ...loadout, ...l })),
  setTab: n => (tab = n),
  setMode: n => (mode = n),
  setFormat,
  setPaused: p => (paused = p),
  setAutopilot: on => (autopilot = on),
  setPixel: on => (pixel = on),
}

applyLang()
resize()
requestAnimationFrame(frame)
