import { HEADS, CORES, ARMS, LEG_PARTS, BOOSTERS, WEAPONS, SETS, HEAT, TICKS, isGun, maxArmor, weightOf, speedOf, normalize, ultOf } from './sim.js'
import { t } from './i18n.js'
import { SURGE_C, HOLO, UI_C as C, rgba, rrect, font, glow, plate } from './paint.js'

const rate = cd => Math.log(120 / cd) / Math.log(12)
const weaponStats = p =>
  isGun(p)
    ? [['stDamage', ((p.pellets ?? 1) * p.dmg) / 120], ['stRange', Math.min(p.range, 30) / 30], ['stRate', rate(p.cd)]]
    : [['stDamage', (p.dmg * (p.hits ?? 1)) / 150], ['stReach', p.range / 5], ['stSpeed', rate(p.cd + p.windup)]]

export const SLOTS = [
  { slot: 'head', title: 'gHead', parts: HEADS, stats: p => [['stArmor', p.armor / 345], ['stCharge', (p.surge - 0.7) / 0.65]] },
  { slot: 'core', title: 'gCore', parts: CORES, stats: () => [] },
  { slot: 'arms', title: 'gArms', parts: ARMS, stats: p => [['stArmor', p.armor / 250], ['stHandling', (1.3 - p.handling) / 0.46]] },
  { slot: 'legs', title: 'gLegs', parts: LEG_PARTS, stats: p => [['stSpeed', p.top / 9], ['stArmor', p.armor / 270]] },
  { slot: 'booster', title: 'gBooster', parts: BOOSTERS, stats: p => [['stDash', p.dash / 8.5], ['stRecharge', 200 / p.dashCd]] },
  { slot: 'left', title: 'gLeftHand', parts: WEAPONS, stats: weaponStats },
  { slot: 'right', title: 'gRightHand', parts: WEAPONS, stats: weaponStats },
  { slot: 'set', title: 'gSets', parts: SETS, sets: true, stats: () => [] },
]
const MAIN = [{ label: 'mainParts', first: 0, last: 4 }, { label: 'mainWeapons', first: 5, last: 6 }, { label: 'mainSets', first: 7, last: 7 }]
const isSet = (lo, key) => Object.keys(SETS[key]).every(k => SETS[key][k] === lo[k])
const setOf = lo => Object.keys(SETS).find(k => isSet(lo, k))
const nextLoadout = ui => (ui.hover?.set ? SETS[ui.hover.set] : ui.hover?.key && ui.hover.slot ? normalize({ ...ui.loadout, [ui.hover.slot]: ui.hover.key }) : ui.loadout)
const SERIES_C = { light: '#7ef0ff', standard: '#c6d4e8', heavy: '#ffb45f' }
const UNIT = { siSpeed: 'vMs', siDash: 'vM', siDashCd: 'vS', siHandling: 'vPct', siCharge: 'vPct', siVent: 'vPs' }

let rects = []

export const garageHit = (px, py) => rects.find(r => px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h) ?? null

function wrap(ctx, text, x, y, w, lh, rows) {
  let line = ''
  let row = 0
  for (const word of text.split(' ')) {
    const next = line ? `${line} ${word}` : word
    if (ctx.measureText(next).width > w && line) {
      ctx.fillText(line, x, y + row * lh)
      line = word
      if (++row === rows) return
    } else line = next
  }
  if (line) ctx.fillText(line, x, y + row * lh)
}

function fit(ctx, text, size, g, weight, w) {
  font(ctx, size, g, weight)
  const k = Math.min(1, w / ctx.measureText(text).width)
  if (k < 1) font(ctx, size * k, g, weight)
}

function label(ctx, text, x, y, size, g, color, weight = 800, align = 'left') {
  ctx.textAlign = align
  ctx.textBaseline = 'middle'
  font(ctx, size, g, weight)
  ctx.fillStyle = color
  ctx.fillText(text, x, y)
}

function sheet(lo) {
  const max = maxArmor(lo)
  const c = CORES[lo.core]
  const legs = LEG_PARTS[lo.legs]
  const b = BOOSTERS[lo.booster]
  return [
    ['siHead', max.head, 0],
    ['siArms', max.rarm, 0],
    ['siLegs', max.legs, 0],
    ['siTotal', max.head + max.rarm + max.larm + max.legs, 0],
    ['siPoise', legs.poise, 0],
    ['siCharge', 100 * HEADS[lo.head].surge * (c.surgeGain ?? 1), 0],
    ['siSpeed', legs.top * speedOf(lo) * (c.speed ?? 1), 1],
    ['siDash', b.dash * (c.dashDist ?? 1), 1],
    ['siDashCd', (b.dashCd * (c.dashCd ?? 1)) / TICKS, 1, true],
    ['siHandling', 100 / ARMS[lo.arms].handling, 0],
    ['siVent', HEAT.vent * (c.vent ?? 1), 0],
    ['siWeight', weightOf(lo), 0, true],
  ]
}

const ECHO = new Set(['siTotal', 'siWeight'])
const trend = (d, dec, low) => (Math.abs(d) < (dec ? 0.05 : 0.5) ? 0 : (low ? d < 0 : d > 0) ? 1 : -1)

export function verdict(hover, loadout) {
  const now = sheet(loadout)
  const next = sheet(nextLoadout({ hover, loadout }))
  return Math.sign(now.reduce((s, [key, v, dec, low], i) => (ECHO.has(key) ? s : s + trend(next[i][1] - v, dec, low)), 0))
}

const fmt = (key, v, dec) => (UNIT[key] ? t(UNIT[key], { n: v.toFixed(dec) }) : v.toFixed(dec))

function card(ctx, ui, tab, key, p, x, y, w, h, g, thumb) {
  const lo = ui.loadout
  const sel = tab.sets ? isSet(lo, key) : lo[tab.slot] === key
  const hov = tab.sets ? ui.hover?.set === key : ui.hover?.slot === tab.slot && ui.hover.key === key
  ctx.save()
  if (sel) {
    ctx.shadowColor = rgba(HOLO, 0.7)
    ctx.shadowBlur = 14 * g
  }
  plate(ctx, x, y, w, h, 10 * g, sel ? C.sel : hov ? C.hov : C.card, sel ? C.hi : hov ? 'rgba(150,210,255,0.7)' : C.line, (sel ? 2 : 1.2) * g)
  ctx.restore()
  const wide = w > 200 * g
  const ts = wide ? h - 12 * g : h * 0.48
  const pics = tab.sets ? [p.left, p.right] : null
  const tx = x + w - (pics ? 2 * ts * 0.8 + 4 * g : ts) - 6 * g
  if (pics) {
    pics.forEach((k, i) => {
      const bx = tx + i * (ts * 0.8 + 4 * g)
      rrect(ctx, bx, y + 6 * g, ts * 0.8, ts, 4 * g, 'rgba(0,10,30,0.45)', 'rgba(80,150,230,0.2)', g)
      thumb(ctx, 'left', k, bx + ts * 0.4, y + 6 * g + ts / 2, ts * 0.8)
    })
  } else {
    rrect(ctx, tx, y + 6 * g, ts, ts, 4 * g, 'rgba(0,10,30,0.45)', 'rgba(80,150,230,0.2)', g)
    thumb(ctx, tab.slot, key, tx + ts / 2, y + 6 * g + ts / 2, ts)
  }
  const tw = tx - x - 16 * g
  const title = t(tab.sets ? `set_${key}` : `p_${key}`)
  ctx.textAlign = 'left'
  ctx.textBaseline = 'top'
  fit(ctx, title, 12, g, 800, tw)
  ctx.fillStyle = sel ? '#ffffff' : C.text
  ctx.fillText(title, x + 10 * g, y + 8 * g)
  const [name, value, color] = pics
    ? [t('setSkill'), t(`u_${ultOf(p)}`), '#e6c8ff']
    : 'series' in p
      ? [t('seriesLabel'), t(`series_${p.series}`), SERIES_C[p.series]]
      : [t('typeLabel'), t(isGun(p) ? 'typeGun' : 'typeMelee'), isGun(p) ? '#ffd27a' : '#ff9c86']
  font(ctx, 9.5, g, 600)
  ctx.fillStyle = C.label
  ctx.fillText(name, x + 10 * g, y + 25 * g)
  const nw = ctx.measureText(name).width
  fit(ctx, value, 9.5, g, 800, tw - nw - 6 * g)
  ctx.fillStyle = color
  ctx.fillText(value, x + 16 * g + nw, y + 25 * g)
  const stats = tab.stats(p)
  const extra = p.ult ? t('titleSkill', { name: t(`u_${p.ult}`) }) : p.move ? t('dashMove', { name: t(`dm_${p.move}`) }) : p.trail ? t('trailLine', { name: t(`tr_${p.trail}`) }) : null
  if (extra) label(ctx, extra, x + 10 * g, y + 44 * g, 9.5, g, p.ult ? '#e6c8ff' : '#ffd27a', 800)
  if (!stats.length) {
    font(ctx, 9, g, 500)
    ctx.fillStyle = C.dim
    ctx.textBaseline = 'top'
    wrap(ctx, t(pics ? `sd_${key}` : `d_${key}`), x + 10 * g, y + (p.ult ? 54 : 41) * g, tw, 11 * g, p.ult ? 2 : 3)
  }
  const sw = wide ? tw : w - 20 * g
  stats.forEach(([name, frac], i) => {
    const ry = y + h - (stats.length - i) * 12 * g - 5 * g
    font(ctx, 8.5, g, 600)
    ctx.fillStyle = C.dim
    ctx.textBaseline = 'top'
    ctx.fillText(t(name), x + 10 * g, ry)
    const bx = x + 58 * g
    const bw = sw - 48 * g
    rrect(ctx, bx, ry + 2 * g, bw, 5 * g, 2.5 * g, 'rgba(120,180,255,0.1)')
    rrect(ctx, bx, ry + 2 * g, Math.max(5 * g, bw * Math.max(0, Math.min(1, frac))), 5 * g, 2.5 * g, sel ? '#bfe4ff' : rgba(HOLO, 0.85))
  })
  rects.push(pics ? { set: key, x, y, w, h } : { slot: tab.slot, key, x, y, w, h })
}

function turntable(ctx, ui, x, y, w, h, g, now, preview, thumb) {
  const lo = ui.loadout
  plate(ctx, x, y, w, h, 14 * g, 'rgba(6,18,40,0.94)', C.line, 1.5 * g)
  const cx = x + (w - 70 * g) / 2
  const cy = y + h * 0.52
  glow(ctx, cx, cy + 6 * g, 120 * g, HOLO, 0.18)
  ctx.save()
  ctx.lineWidth = 2 * g
  for (const [k, a] of [[1, 0.9], [0.78, 0.5], [1.2, 0.25]]) {
    ctx.strokeStyle = rgba([120, 210, 255], a)
    ctx.setLineDash(k === 0.78 ? [10 * g, 6 * g] : [])
    ctx.lineDashOffset = -now / 40
    ctx.beginPath()
    ctx.ellipse(cx, cy + 6 * g, 92 * g * k, 24 * g * k, 0, 0, Math.PI * 2)
    ctx.stroke()
  }
  ctx.restore()
  preview(ctx, nextLoadout(ui), cx, cy, (ui.pixel ? 46 : 30) * g, now, g)
  const sx = x + w - 66 * g
  label(ctx, t('weaponsLabel'), sx + 29 * g, y + 20 * g, 9, g, C.dim)
  ;[['left', 'L', 5], ['right', 'R', 6]].forEach(([hand, tag, tab], i) => {
    const by = y + 32 * g + i * 64 * g
    const hov = ui.hover?.tab === tab && ui.hover.hand
    plate(ctx, sx, by, 58 * g, 58 * g, 8 * g, ui.tab === tab ? C.sel : hov ? C.hov : C.card, ui.tab === tab ? C.hi : C.line, 1.2 * g)
    thumb(ctx, hand, lo[hand], sx + 29 * g, by + 29 * g, 50 * g)
    label(ctx, tag, sx + 50 * g, by + 50 * g, 10, g, C.hi, 900, 'center')
    rects.push({ tab, hand: true, x: sx, y: by, w: 58 * g, h: 58 * g })
  })
  const ky = y + 172 * g
  ctx.textAlign = 'center'
  fit(ctx, t('skillLabel'), 9, g, 800, 62 * g)
  ctx.fillStyle = C.dim
  ctx.fillText(t('skillLabel'), sx + 29 * g, ky)
  const hov = ui.hover?.tab === 1 && ui.hover.skill
  const next = ultOf(nextLoadout(ui))
  const changing = next !== ultOf(lo)
  plate(ctx, sx, ky + 12 * g, 58 * g, 58 * g, 8 * g, ui.tab === 1 ? C.sel : hov ? C.hov : C.card, rgba(SURGE_C, changing ? 1 : 0.7), (changing ? 2 : 1.2) * g)
  glow(ctx, sx + 29 * g, ky + 41 * g, 30 * g, SURGE_C, changing ? 0.5 + 0.2 * Math.sin(now / 90) : 0.25)
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  fit(ctx, t(`u_${next}`), 11, g, 900, 52 * g)
  ctx.fillStyle = changing ? '#ffffff' : '#f1e4ff'
  ctx.fillText(t(`u_${next}`), sx + 29 * g, ky + 41 * g)
  rects.push({ tab: 1, skill: true, x: sx, y: ky + 12 * g, w: 58 * g, h: 58 * g })
}

function info(ctx, ui, x, y, w, h, g) {
  const lo = ui.loadout
  plate(ctx, x, y, w, h, 12 * g, 'rgba(6,18,40,0.94)', C.line, 1.5 * g)
  label(ctx, t('mechInfo'), x + 14 * g, y + 16 * g, 11, g, C.hi, 900)
  const now = sheet(lo)
  const next = sheet(nextLoadout(ui))
  const colW = (w - 28 * g) / 2
  now.forEach(([key, v, dec, low], i) => {
    const cx = x + 14 * g + Math.floor(i / 6) * (colW + 6 * g)
    const ry = y + 36 * g + (i % 6) * 21 * g
    if (i % 6) {
      ctx.fillStyle = 'rgba(80,150,230,0.12)'
      ctx.fillRect(cx, ry - 10.5 * g, colW - 6 * g, g)
    }
    label(ctx, t(key), cx, ry, 9.5, g, C.dim, 600)
    const text = fmt(key, v, dec)
    label(ctx, text, cx + colW - 8 * g, ry, 12.5, g, C.text, 800, 'right')
    const d = next[i][1] - v
    const s = trend(d, dec, low)
    if (!s) return
    font(ctx, 12.5, g, 800)
    const vw = ctx.measureText(text).width
    const good = s > 0
    label(ctx, `${d > 0 ? '▲' : '▼'}${Math.abs(d).toFixed(dec)}`, cx + colW - 14 * g - vw, ry, 9.5, g, good ? '#7dffa8' : '#ff7a6a', 800, 'right')
  })
}

function about(ctx, ui, tab, x, y, w, h, g) {
  const lo = ui.loadout
  const set = ui.hover?.set ?? (ui.hover?.slot ? null : tab.sets ? setOf(lo) : null)
  const slot = ui.hover?.slot ?? tab.slot
  const key = set ?? ui.hover?.key ?? lo[slot]
  plate(ctx, x, y, w, h, 10 * g, 'rgba(6,18,40,0.94)', C.line, 1.2 * g)
  if (!key) return
  const skill = set ? ultOf(SETS[set]) : slot === 'core' ? CORES[key].ult : null
  label(ctx, t(set ? `set_${key}` : `p_${key}`), x + 12 * g, y + 13 * g, 11, g, C.hi, 800)
  ctx.textAlign = 'left'
  ctx.textBaseline = 'top'
  font(ctx, 9.5, g, 500)
  ctx.fillStyle = C.dim
  wrap(ctx, t(set ? `sd_${key}` : `d_${key}`), x + 12 * g, y + 26 * g, w - 24 * g, 13 * g, skill ? 1 : 3)
  if (!skill) return
  font(ctx, 9, g, 700)
  ctx.fillStyle = '#e6c8ff'
  wrap(ctx, t('skillDesc', { name: t('titleSkill', { name: t(`u_${skill}`) }), desc: t(`ud_${skill}`) }), x + 12 * g, y + 40 * g, w - 24 * g, 12 * g, 2)
}

export function drawGarage(ctx, L, ui, now, preview, thumb) {
  const g = Math.min(L.w / 960, L.h / 600)
  const ti = ui.tab ?? 0
  const tab = SLOTS[ti]
  rects = []
  const bg = ctx.createLinearGradient(0, 0, 0, L.h)
  bg.addColorStop(0, '#03091a')
  bg.addColorStop(1, '#0a1c3a')
  ctx.fillStyle = bg
  ctx.fillRect(0, 0, L.w, L.h)
  ctx.fillStyle = 'rgba(120,190,255,0.035)'
  for (let y = 0; y < L.h; y += 4 * g) ctx.fillRect(0, y, L.w, Math.max(1, g))

  const pad = 24 * g
  const rightW = 300 * g
  const rx = L.w - pad - rightW
  const x0 = pad
  const areaW = rx - 16 * g - x0
  plate(ctx, x0, 14 * g, 190 * g, 34 * g, 10 * g, 'rgba(14,40,80,0.95)', C.hi, 1.5 * g)
  ctx.save()
  ctx.shadowColor = rgba(HOLO, 0.9)
  ctx.shadowBlur = 14 * g
  label(ctx, t('garage'), x0 + 18 * g, 31 * g, 20, g, C.text, 900)
  ctx.restore()
  label(ctx, t('garageHint'), x0 + 204 * g, 31 * g, 11, g, C.dim, 600)

  MAIN.forEach((mt, i) => {
    const x = x0 + i * 156 * g
    const sel = ti >= mt.first && ti <= mt.last
    const hov = ui.hover?.main && ui.hover.tab === mt.first
    plate(ctx, x, 58 * g, 150 * g, 30 * g, 8 * g, sel ? C.sel : hov ? C.hov : C.card, sel ? C.hi : C.line, (sel ? 2 : 1.2) * g)
    label(ctx, t(mt.label), x + 75 * g, 73 * g, 13, g, sel ? '#ffffff' : C.dim, 900, 'center')
    rects.push({ tab: mt.first, main: true, x, y: 58 * g, w: 150 * g, h: 30 * g })
  })
  const main = MAIN.find(mt => ti >= mt.first && ti <= mt.last)
  const subs = SLOTS.slice(main.first, main.last + 1)
  const subW = (areaW - 6 * g * (subs.length - 1)) / subs.length
  subs.forEach((s, j) => {
    const i = main.first + j
    const x = x0 + j * (subW + 6 * g)
    const sel = i === ti
    const hov = !ui.hover?.main && !ui.hover?.hand && !ui.hover?.skill && ui.hover?.tab === i
    plate(ctx, x, 94 * g, subW, 34 * g, 6 * g, sel ? C.sel : hov ? C.hov : C.card, sel ? C.hi : C.line, (sel ? 2 : 1.2) * g)
    label(ctx, t(`tab_${s.slot}`), x + subW / 2, 105 * g, 11, g, sel ? '#ffffff' : C.text, 800, 'center')
    const cur = s.sets ? t(setOf(ui.loadout) ? `set_${setOf(ui.loadout)}` : 'setCustom') : t(`p_${ui.loadout[s.slot]}`)
    fit(ctx, cur, 9, g, 600, subW - 12 * g)
    ctx.fillStyle = sel ? '#bfe4ff' : C.label
    ctx.fillText(cur, x + subW / 2, 119 * g)
    rects.push({ tab: i, x, y: 94 * g, w: subW, h: 34 * g })
  })
  label(ctx, t(tab.title), x0, 141 * g, 10.5, g, rgba(HOLO), 800)

  const items = Object.entries(tab.parts)
  const cols = items.length > 10 ? 4 : 2
  const rows = Math.ceil(items.length / cols)
  const gap = 8 * g
  const gridTop = 152 * g
  const cardW = (areaW - gap * (cols - 1)) / cols
  const cardH = Math.min(84 * g, (590 * g - gridTop - gap * (rows - 1)) / rows)
  items.forEach(([key, p], n) => card(ctx, ui, tab, key, p, x0 + (n % cols) * (cardW + gap), gridTop + Math.floor(n / cols) * (cardH + gap), cardW, cardH, g, thumb))

  turntable(ctx, ui, rx, 14 * g, rightW, 270 * g, g, now, preview, thumb)
  info(ctx, ui, rx, 292 * g, rightW, 166 * g, g)
  about(ctx, ui, tab, rx, 466 * g, rightW, 70 * g, g)

  const by = 544 * g
  const bh = 46 * g
  const hov = ui.hover?.fight
  ctx.save()
  ctx.shadowColor = 'rgba(255,122,47,0.9)'
  ctx.shadowBlur = (hov ? 24 : 12) * g
  const grad = ctx.createLinearGradient(rx, by, rx, by + bh)
  grad.addColorStop(0, hov ? '#ffae6e' : '#ff9447')
  grad.addColorStop(1, '#c4521a')
  plate(ctx, rx, by, rightW, bh, 12 * g, grad, '#ffd2a8', 2 * g)
  ctx.restore()
  label(ctx, t('fightBtn'), rx + rightW / 2, by + bh / 2, 18, g, '#1a0d05', 900, 'center')
  rects.push({ fight: true, x: rx, y: by, w: rightW, h: bh })
}
