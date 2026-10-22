import { createState, step, TICKS, normalize, SETS } from './sim.js'
import { dummyInput, DUMMY_MODES } from './dummy.js'
import { botInput, createBrain, randomLoadout } from './bot.js'
import { draw, toWorld } from './render.js'
import { garageHit, SLOTS, verdict } from './garage.js'
import { applyLang, toggleLang } from './i18n.js'
import { sounds, toggleMute, isMuted, toggleMusic, isMusicOn, unlock, uiSound } from './sfx.js'

const MODES = ['bot', ...DUMMY_MODES]
const LOADOUT_KEY = 'mech-duel/loadout'
const canvas = document.querySelector('canvas')
const ctx = canvas.getContext('2d')
const keys = new Set()
const buttons = new Set()
const tapped = new Set()
const mouse = { x: 0, y: 0 }
let brain = createBrain(Date.now())
let pilot = createBrain(Date.now() + 1)
let state = demo()
let loadout = savedLoadout()
let screen = 'title'
let hover = null
let tab = 0
let mode = 0
let paused = false
let autopilot = false
let pixel = true
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
  paused = false
  uiSound('select')
}

function fight() {
  uiSound('start')
  try {
    localStorage.setItem(LOADOUT_KEY, JSON.stringify(loadout))
  } catch {}
  brain = createBrain(Date.now())
  pilot = createBrain(Date.now() + 1)
  state = createState([loadout, randomLoadout(brain)])
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

const rivalInput = () => (MODES[mode] === 'bot' ? botInput(state, brain) : dummyInput(state, MODES[mode]))

function tick(input) {
  if (screen !== 'match') {
    step(state, [botInput(state, pilot, 0), botInput(state, brain, 1)])
    if (state.phase === 'over') state = demo()
    return
  }
  step(state, [input ?? (autopilot ? botInput(state, pilot, 0) : playerInput()), rivalInput()])
}

const render = () => {
  sounds(state, screen, paused)
  draw(ctx, state, { screen, mode: MODES[mode], paused, mouse, hover, loadout, tab, muted: isMuted(), music: isMusicOn(), pixel })
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
  else if (state.phase === 'over') toGarage()
}

addEventListener('resize', resize)
addEventListener('keydown', e => {
  if (e.code === 'Space' || e.code === 'Tab') e.preventDefault()
  unlock()
  if (e.repeat) return
  keys.add(e.code)
  tapped.add(e.code)
  if (e.code === 'Escape' && screen === 'match') paused = !paused
  if (e.code === 'Escape' && screen === 'garage') screen = 'title'
  if (e.code === 'Tab' && screen === 'garage') {
    tab = (tab + (e.shiftKey ? SLOTS.length - 1 : 1)) % SLOTS.length
    uiSound('tab')
  }
  if (e.code === 'KeyL') toggleLang()
  if (e.code === 'KeyM') toggleMute()
  if (e.code === 'KeyN') toggleMusic()
  if (e.code === 'KeyV') pixel = !pixel
  if (e.code === 'Enter' || e.code === 'NumpadEnter') confirm()
  const n = ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5'].indexOf(e.code)
  if (n >= 0) mode = n
})
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
  if (next && (next.fight !== hover?.fight || next.key !== hover?.key || next.slot !== hover?.slot || next.tab !== hover?.tab || next.set !== hover?.set)) uiSound(['down', 'hover', 'up'][verdict(next, loadout) + 1])
  hover = next
}
canvas.addEventListener('mousemove', aimAt)
canvas.addEventListener('mousedown', e => {
  e.preventDefault()
  unlock()
  aimAt(e)
  if (screen === 'title') return toGarage()
  if (screen === 'garage') {
    if (hover?.fight) fight()
    else if (hover?.tab !== undefined) {
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
  tick,
  render,
  toGarage,
  fight,
  setLoadout: l => (loadout = normalize({ ...loadout, ...l })),
  setTab: n => (tab = n),
  setMode: n => (mode = n),
  setPaused: p => (paused = p),
  setAutopilot: on => (autopilot = on),
  setPixel: on => (pixel = on),
}

applyLang()
resize()
requestAnimationFrame(frame)
