import { HEAT, SURGE, MATCH, TICKS, CORES, LEG_PARTS, DASH_MOVES, ultOf } from './sim.js'
import { t } from './i18n.js'
import { TAU, TEAM, TEAM_LIGHT, SURGE_C, HP_C, VENT_C, ITEM_C, PARTS, HOLO, UI_C, rgba, health, circle, rrect, glow, heatGauge, font, plate, MONO } from './paint.js'
import { drawPortrait } from './mechart.js'

const CARD_W = 300
const cdMax = new Map()
const hitAt = new Map()
const prevArmor = new Map()

const flashOf = (id, part, now) => Math.max(0, 1 - (now - (hitAt.get(`${id}${part}`) ?? -1e9)) / 260)

export function hud(ctx, state, ui, L, now, preview) {
  const u = L.u
  if (ui.screen === 'title') {
    titleScreen(ctx, state, L, u, now, preview)
    return footer(ctx, ui, L, u)
  }
  for (const m of state.mechs) {
    for (const p of PARTS) {
      const key = `${m.id}${p}`
      const prev = prevArmor.get(key)
      if (prev !== undefined && m.armor[p] < prev) hitAt.set(key, now)
      prevArmor.set(key, m.armor[p])
    }
  }
  const rival = ui.mode === 'bot' ? t('rivalBot') : t('dummy')
  card(ctx, state.mechs[0], t('you'), 16 * u, 12 * u, u, now, false)
  card(ctx, state.mechs[1], rival, L.w - 16 * u - CARD_W * u, 12 * u, u, now, true)
  clock(ctx, state, L, u, now)
  abilities(ctx, state.mechs[0], L, u, now)
  footer(ctx, ui, L, u)
  if (ui.paused) {
    ctx.fillStyle = 'rgba(0,0,0,0.6)'
    ctx.fillRect(0, 0, L.w, L.h)
    const left = ui.menuW ?? 0
    controls(ctx, L, u, L.h / 2 - 107 * u, (left + L.w) / 2, L.w - left - 32 * u)
  } else banner(ctx, state, ui, L, u, now)
  if (ui.replay != null && !ui.paused) replayTag(ctx, L, u, ui.replay, now)
}

function replayTag(ctx, L, u, p, now) {
  const cx = L.w / 2
  const y = L.top + 18 * u
  font(ctx, 26, u, 900)
  const w = ctx.measureText(t('kcReplay')).width
  if (Math.floor(now / 450) % 2) circle(ctx, cx - w / 2 - 16 * u, y, 6 * u, '#ff3b30')
  shout(ctx, t('kcReplay'), cx, y, 26, '#ffffff', 'rgba(255,60,40,0.9)', u)
  ctx.fillStyle = 'rgba(255,255,255,0.15)'
  ctx.fillRect(cx - 90 * u, y + 20 * u, 180 * u, 3 * u)
  ctx.fillStyle = '#ff3b30'
  ctx.fillRect(cx - 90 * u, y + 20 * u, 180 * u * p, 3 * u)
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  font(ctx, 11, u, 700)
  ctx.fillStyle = UI_C.dim
  ctx.fillText(t('kcSkip'), cx, y + 36 * u)
}

function holoBackdrop(ctx, L, u) {
  const bg = ctx.createLinearGradient(0, 0, 0, L.h)
  bg.addColorStop(0, 'rgba(3,9,26,0.86)')
  bg.addColorStop(1, 'rgba(10,28,58,0.74)')
  ctx.fillStyle = bg
  ctx.fillRect(0, 0, L.w, L.h)
  ctx.fillStyle = 'rgba(120,190,255,0.035)'
  for (let y = 0; y < L.h; y += 4 * u) ctx.fillRect(0, y, L.w, Math.max(1, u))
}

function logo(ctx, x, y, u) {
  const w = 540 * u
  const h = 88 * u
  plate(ctx, x - w / 2, y - h / 2, w, h, 18 * u, 'rgba(10,30,64,0.92)', UI_C.hi, 2 * u)
  ;[0, 1].forEach(id => {
    const s = id ? 1 : -1
    ctx.fillStyle = rgba(TEAM[id])
    ctx.beginPath()
    ctx.moveTo(x + s * (w / 2 + 14 * u), y - h / 2)
    ctx.lineTo(x + s * (w / 2 + 34 * u), y - h / 2)
    ctx.lineTo(x + s * (w / 2 + 14 * u), y + h / 2)
    ctx.lineTo(x + s * (w / 2 - 6 * u), y + h / 2)
    ctx.closePath()
    ctx.fill()
  })
  shout(ctx, t('logo'), x, y + 2 * u, 58, '#ffffff', rgba(HOLO, 0.95), u)
  shout(ctx, t('tagline'), x, y + h / 2 + 22 * u, 14, UI_C.dim, 'rgba(0,0,0,0)', u)
}

function versus(ctx, x, y, u, now) {
  const r = 38 * u
  glow(ctx, x, y, r * 2.4, TEAM[Math.floor(now / 700) % 2], 0.3)
  ctx.save()
  ctx.translate(x, y)
  ctx.rotate(Math.PI / 4)
  rrect(ctx, -r / 1.42, -r / 1.42, r * 1.42, r * 1.42, 6 * u, 'rgba(10,30,64,0.95)', UI_C.hi, 2 * u)
  ctx.restore()
  shout(ctx, t('vs'), x, y + u, 26, '#ffffff', rgba(HOLO, 0.9), u)
}

function startButton(ctx, x, y, u, now) {
  ctx.textAlign = 'center'
  font(ctx, 15, u, 900)
  const w = ctx.measureText(t('start')).width + 70 * u
  const h = 44 * u
  const pulse = 0.5 + 0.5 * Math.sin(now / 260)
  ctx.save()
  ctx.shadowColor = 'rgba(255,122,47,0.9)'
  ctx.shadowBlur = (10 + 16 * pulse) * u
  const g = ctx.createLinearGradient(0, y - h / 2, 0, y + h / 2)
  g.addColorStop(0, '#ff9f58')
  g.addColorStop(1, '#c4521a')
  plate(ctx, x - w / 2, y - h / 2, w, h, 12 * u, g, '#ffd2a8', 2 * u)
  ctx.restore()
  ctx.textBaseline = 'middle'
  font(ctx, 15, u, 900)
  ctx.fillStyle = '#1a0d05'
  ctx.fillText(t('start'), x, y + u)
}

function fighter(ctx, lo, id, x, y, size, pw, u, now, preview) {
  const c = TEAM[id]
  const rw = size * 0.3
  glow(ctx, x, y, rw * 1.3, c, 0.22)
  ctx.save()
  ctx.lineWidth = 2 * u
  for (const [k, a] of [[1, 0.9], [0.74, 0.5], [1.22, 0.22]]) {
    ctx.strokeStyle = rgba(k === 1 ? c : [120, 210, 255], a)
    ctx.setLineDash(k === 0.74 ? [10 * u, 6 * u] : [])
    ctx.lineDashOffset = (id ? 1 : -1) * now / 40
    ctx.beginPath()
    ctx.ellipse(x, y, rw * k, rw * 0.26 * k, 0, 0, TAU)
    ctx.stroke()
  }
  ctx.restore()
  const face = (id ? Math.PI - 0.7 : 0.7) + 0.22 * Math.sin(now / 1500 + id * 2)
  if (preview) preview(ctx, lo, x, y, size / 4, now, u, { id, aim: face, N: 160, S: 42, cx: 0.5, cy: 0.7 })
  else drawPortrait(ctx, lo, id, x, y - size * 0.22, size / 9, now)
  const ph = 66 * u
  const py = y + rw * 0.4 + 14 * u
  plate(ctx, x - pw / 2, py, pw, ph, 12 * u, 'rgba(10,28,58,0.92)', rgba(c, 0.85), 1.5 * u)
  ctx.fillStyle = rgba(c)
  ctx.fillRect(x - pw / 2 + 12 * u, py + 4 * u, pw - 24 * u, 3 * u)
  shout(ctx, t(id ? 'nameTalon' : 'nameCinder'), x, py + 22 * u, 17, rgba(TEAM_LIGHT[id]), rgba(c, 0.8), u)
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  const arms = t('pairJoin', { a: t(`p_${lo.left}`), b: t(`p_${lo.right}`) })
  fitFont(ctx, arms, 10, u, 600, pw - 20 * u)
  ctx.fillStyle = UI_C.dim
  ctx.fillText(arms, x, py + 41 * u)
  font(ctx, 10.5, u, 800)
  ctx.fillStyle = rgba(SURGE_C)
  ctx.fillText(t('titleSkill', { name: t(`u_${ultOf(lo)}`) }), x, py + 55 * u)
}

function fitFont(ctx, text, size, u, weight, w) {
  font(ctx, size, u, weight)
  const k = Math.min(1, w / ctx.measureText(text).width)
  if (k < 1) font(ctx, size * k, u, weight)
}

function titleScreen(ctx, state, L, u, now, preview) {
  holoBackdrop(ctx, L, u)
  const cx = L.w / 2
  const panelW = controlsWidth(ctx, u)
  const free = cx - panelW / 2
  const size = Math.min(L.h * 0.5, free * 1.4)
  if (free > 150 * u) [0, 1].forEach(id => fighter(ctx, state.mechs[id].loadout, id, id ? L.w - free / 2 : free / 2, L.h * 0.55, size, Math.min(250 * u, free - 28 * u), u, now, preview))
  logo(ctx, cx, L.h * 0.13, u)
  versus(ctx, cx, L.h * 0.34, u, now)
  startButton(ctx, cx, L.h * 0.44, u, now)
  controls(ctx, L, u, L.h * 0.5)
}

function silhouette(ctx, m, x, y, u, now) {
  const fill = part => {
    const f = flashOf(m.id, part, now)
    return f > 0.5 ? '#ffffff' : HP_C[health(m, part)]
  }
  const part = (p, px, py, w, h, r) => {
    rrect(ctx, x + px * u, y + py * u, w * u, h * u, r * u, fill(p), 'rgba(0,0,0,0.55)', u)
    if (health(m, p) === 3) {
      ctx.strokeStyle = '#e0483a'
      ctx.lineWidth = 2 * u
      ctx.beginPath()
      ctx.moveTo(x + (px + 2) * u, y + (py + 2) * u)
      ctx.lineTo(x + (px + w - 2) * u, y + (py + h - 2) * u)
      ctx.moveTo(x + (px + w - 2) * u, y + (py + 2) * u)
      ctx.lineTo(x + (px + 2) * u, y + (py + h - 2) * u)
      ctx.stroke()
    }
  }
  rrect(ctx, x + 17 * u, y + 15 * u, 26 * u, 21 * u, 5 * u, '#2a313d', rgba(TEAM[m.id], 0.8), 1.5 * u)
  part('rarm', 4, 16, 11, 24, 4)
  part('larm', 45, 16, 11, 24, 4)
  part('legs', 18, 38, 10, 24, 3)
  part('legs', 32, 38, 10, 24, 3)
  part('head', 22, 0, 16, 13, 4)
  ctx.strokeStyle = rgba(TEAM_LIGHT[m.id])
  ctx.lineWidth = 2 * u
  ctx.beginPath()
  ctx.moveTo(x + 25 * u, y + 7 * u)
  ctx.lineTo(x + 35 * u, y + 7 * u)
  ctx.stroke()
}

function pips(ctx, m, x, y, u) {
  const list = [m.cd.left, m.cd.right, m.cd.shield, m.cd.hook, m.dashes > 0 ? 0 : m.cd.dash, m.surge >= SURGE.max ? 0 : 1]
  list.forEach((cd, i) => {
    const px = x - (list.length - 1 - i) * 13 * u
    const on = cd === 0
    if (on) glow(ctx, px, y, 7 * u, i === 4 ? SURGE_C : [125, 255, 154], 0.5)
    circle(ctx, px, y, 3.5 * u, on ? (i === 4 ? rgba(SURGE_C) : '#9dffb4') : '#2a303a')
  })
}

function card(ctx, m, name, x, y, u, now, mirror) {
  const id = m.id
  const w = CARD_W * u
  rrect(ctx, x, y, w, 84 * u, 10 * u, 'rgba(10,13,19,0.86)', rgba(TEAM[id], 0.45), 1.5 * u)
  silhouette(ctx, m, mirror ? x + w - 70 * u : x + 10 * u, y + 11 * u, u, now)
  const tx = mirror ? x + 14 * u : x + 82 * u
  ctx.textAlign = 'left'
  ctx.textBaseline = 'top'
  font(ctx, 14, u, 800)
  ctx.fillStyle = rgba(TEAM_LIGHT[id])
  ctx.fillText(name, tx, y + 9 * u)
  if (mirror) pips(ctx, m, tx + 200 * u, y + 17 * u, u)
  PARTS.forEach((p, i) => {
    const ry = y + 31 * u + i * 12.5 * u
    const h = health(m, p)
    const f = flashOf(id, p, now)
    ctx.textAlign = 'left'
    font(ctx, 9.5, u, 600)
    ctx.fillStyle = h === 3 ? '#e0603f' : '#8b95a6'
    ctx.fillText(t(p), tx, ry)
    rrect(ctx, tx + 56 * u, ry + 2 * u, 112 * u, 7 * u, 3.5 * u, 'rgba(255,255,255,0.07)')
    const frac = Math.max(0, m.armor[p]) / m.max[p]
    if (frac > 0) rrect(ctx, tx + 56 * u, ry + 2 * u, Math.max(7 * u, 112 * u * frac), 7 * u, 3.5 * u, f > 0.5 ? '#ffffff' : HP_C[h])
    font(ctx, 9, u, 600, MONO)
    ctx.fillStyle = '#6d7789'
    ctx.textAlign = 'right'
    ctx.fillText(String(Math.max(0, Math.round(m.armor[p]))), tx + 200 * u, ry + 1 * u)
  })
}

function clock(ctx, state, L, u, now) {
  const cx = L.w / 2
  rrect(ctx, cx - 74 * u, 8 * u, 148 * u, 66 * u, 10 * u, 'rgba(10,13,19,0.86)', 'rgba(140,155,180,0.3)', 1.5 * u)
  ctx.textAlign = 'center'
  ctx.textBaseline = 'top'
  font(ctx, 9.5, u, 700)
  ctx.fillStyle = '#7d8798'
  ctx.fillText(t('round', { n: state.round }), cx, 13 * u)
  const secs = Math.ceil(Math.max(0, state.clock) / TICKS)
  const low = secs <= 10 && state.phase === 'fight'
  font(ctx, 26, u, 800, MONO)
  ctx.fillStyle = low ? (Math.floor(now / 250) % 2 ? '#ff5a3c' : '#ffb3a3') : '#e6ebf2'
  ctx.fillText(`${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, '0')}`, cx, 25 * u)
  for (const side of [0, 1]) {
    for (let i = 0; i < MATCH.wins; i++) {
      const px = cx + (side ? 1 : -1) * (14 + i * 13) * u
      const won = state.score[side] > i
      if (won) glow(ctx, px, 62 * u, 8 * u, TEAM[side], 0.5)
      circle(ctx, px, 62 * u, 4 * u, won ? rgba(TEAM[side]) : 'rgba(255,255,255,0.06)', rgba(TEAM[side], 0.7), 1.2 * u)
    }
  }
}

function glyph(ctx, label, x, y, u) {
  if (label === 'rmb' || label === 'lmb') {
    const sx = label === 'lmb' ? -1 : 1
    rrect(ctx, x - 6 * u, y - 9 * u, 12 * u, 18 * u, 6 * u, null, ctx.fillStyle, 1.6 * u)
    ctx.beginPath()
    ctx.moveTo(x, y - 9 * u)
    ctx.arcTo(x + sx * 6 * u, y - 9 * u, x + sx * 6 * u, y, 6 * u)
    ctx.lineTo(x + sx * 6 * u, y - 2 * u)
    ctx.lineTo(x, y - 2 * u)
    ctx.closePath()
    ctx.fill()
  } else if (label === 'space') {
    rrect(ctx, x - 11 * u, y - 3.5 * u, 22 * u, 7 * u, 3 * u, null, ctx.fillStyle, 1.6 * u)
  } else {
    font(ctx, 17, u, 800)
    ctx.fillText(label, x, y)
  }
}

function slot(ctx, x, y, s, label, name, ready, frac, sub, rgb, u, fill = 0) {
  ctx.save()
  if (ready) {
    ctx.shadowColor = rgba(rgb, 0.9)
    ctx.shadowBlur = 12 * u
  }
  rrect(ctx, x, y, s, s, 8 * u, ready ? 'rgba(28,36,50,0.96)' : 'rgba(15,19,27,0.96)', ready ? rgba(rgb, 0.95) : 'rgba(70,80,95,0.85)', 2 * u)
  ctx.restore()
  ctx.save()
  ctx.beginPath()
  ctx.roundRect(x, y, s, s, 8 * u)
  ctx.clip()
  if (fill > 0) {
    ctx.fillStyle = rgba(rgb, 0.35)
    ctx.fillRect(x, y + s * (1 - fill), s, s * fill)
  }
  if (frac > 0) {
    ctx.fillStyle = 'rgba(0,0,0,0.62)'
    ctx.beginPath()
    ctx.moveTo(x + s / 2, y + s / 2)
    ctx.arc(x + s / 2, y + s / 2, s, -Math.PI / 2, -Math.PI / 2 + TAU * frac)
    ctx.closePath()
    ctx.fill()
  }
  ctx.restore()
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillStyle = ready ? '#ffffff' : '#8a94a6'
  glyph(ctx, label, x + s / 2, y + s / 2 - (sub ? 5 * u : 0), u)
  if (sub) {
    font(ctx, 9, u, 700, MONO)
    ctx.fillStyle = '#e6ebf2'
    ctx.fillText(sub, x + s / 2, y + s / 2 + 12 * u)
  }
  ctx.textBaseline = 'top'
  font(ctx, 9, u, 700)
  ctx.fillStyle = ready ? rgba(TEAM_LIGHT[0]) : '#6d7789'
  ctx.fillText(name, x + s / 2, y + s + 4 * u)
}

function abilities(ctx, m, L, u, now) {
  const s = 46 * u
  const gap = 10 * u
  const total = 6 * s + 5 * gap
  const x0 = L.w / 2 - total / 2
  const y = L.h - 24 * u - s
  rrect(ctx, x0 - 14 * u, y - 40 * u, total + 28 * u, s + 68 * u, 12 * u, 'rgba(10,13,19,0.82)', 'rgba(140,155,180,0.25)', 1.5 * u)
  const over = m.overheat > 0
  const locked = over || m.buffs.jam > 0
  const hotAt = CORES[m.loadout.core].hotAt ?? HEAT.hot
  const hot = m.heat >= hotAt
  ctx.textAlign = 'left'
  ctx.textBaseline = 'bottom'
  font(ctx, 9.5, u, 800)
  ctx.fillStyle = over || m.buffs.jam > 0 ? '#ff5a3c' : m.buffs.slow > 0 ? '#9d8cff' : hot ? '#ff9a3c' : '#8b95a6'
  const heatLabel = over ? t('overheat') : m.buffs.jam > 0 ? t('empLocked') : m.buffs.slow > 0 ? t('slowed') : hot ? t('hot') : t('heat')
  ctx.fillText(heatLabel, x0, y - 22 * u)
  const left = x0 + ctx.measureText(heatLabel).width + 12 * u
  ctx.textAlign = 'right'
  let cx = x0 + total
  for (const [b, item] of [['speed', 'speed'], ['power', 'power'], ['cool', 'coolant'], ['bubble', 'shield']]) {
    if (m.buffs[b] <= 0 || (b === 'bubble' && (m.buffs.bubbleHp <= 0 || ultOf(m.loadout) === 'bubble'))) continue
    const label = `${t(`i_${item}`).toUpperCase()} ${(m.buffs[b] / TICKS).toFixed(1)}`
    if (cx - ctx.measureText(label).width < left) break
    ctx.fillStyle = rgba(ITEM_C[item])
    ctx.fillText(label, cx, y - 22 * u)
    cx -= ctx.measureText(label).width + 12 * u
  }
  const by = y - 18 * u
  rrect(ctx, x0, by, total, 8 * u, 4 * u, 'rgba(255,255,255,0.07)')
  ctx.fillStyle = 'rgba(255,90,40,0.12)'
  ctx.fillRect(x0 + total * (hotAt / HEAT.max), by, total * (1 - hotAt / HEAT.max), 8 * u)
  let hg = ctx.createLinearGradient(x0, 0, x0 + total, 0)
  hg.addColorStop(0, '#e8c060')
  hg.addColorStop(0.6, '#ff8a2a')
  hg.addColorStop(1, '#ff3b2f')
  if (over) {
    hg = ctx.createLinearGradient(x0, 0, x0 + total, 0)
    hg.addColorStop(0, '#dff4ff')
    hg.addColorStop(1, rgba(VENT_C))
  }
  if (m.heat > 0) rrect(ctx, x0, by, Math.max(8 * u, total * (m.heat / HEAT.max)), 8 * u, 4 * u, hg)
  ctx.fillStyle = 'rgba(255,255,255,0.85)'
  ctx.fillRect(x0 + total * (hotAt / HEAT.max) - 0.75 * u, by - 2 * u, 1.5 * u, 12 * u)
  const move = LEG_PARTS[m.loadout.legs].move
  const most = DASH_MOVES[move].charges ?? 1
  const slots = [['lmb', 'left', t(`s_${m.loadout.left}`)], ['rmb', 'right', t(`s_${m.loadout.right}`)], ['Q', 'shield', t('sShield')], ['E', 'hook', t('sHook')], ['space', 'dash', most > 1 ? t('dashCharges', { name: t(`dm_${move}`), n: m.dashes }) : t(`dm_${move}`)]]
  slots.forEach(([label, c, name], i) => {
    const left = c === 'dash' && m.dashes > 0 ? 0 : m.cd[c]
    const key = `slot${c}`
    if (left === 0) cdMax.delete(key)
    else if (left > (cdMax.get(key) ?? 0)) cdMax.set(key, left)
    slot(ctx, x0 + i * (s + gap), y, s, label, name, left === 0 && !locked, left > 0 ? left / cdMax.get(key) : 0, left > 0 ? (left / TICKS).toFixed(1) : '', TEAM[0], u)
  })
  const full = m.surge >= SURGE.max
  const buff = Math.max(m.buffs.overdrive, m.buffs.berserk, m.buffs.bubbleHp > 0 && ultOf(m.loadout) === 'bubble' ? m.buffs.bubble : 0)
  if (full || buff > 0) glow(ctx, x0 + 5 * (s + gap) + s / 2, y + s / 2, s * (0.9 + 0.1 * Math.sin(now / 120)), SURGE_C, 0.35)
  slot(ctx, x0 + 5 * (s + gap), y, s, 'R', t(`u_${ultOf(m.loadout)}`), full && !locked, 0, buff > 0 ? (buff / TICKS).toFixed(1) : full ? '' : `${Math.floor(m.surge)}%`, SURGE_C, u, m.surge / SURGE.max)
  if (!over) return
  for (let i = 0; i < 6; i++) rrect(ctx, x0 + i * (s + gap), y, s, s, 8 * u, rgba(VENT_C, 0.22 + 0.1 * Math.sin(now / 70)))
  heatGauge(ctx, x0 + s / 2, y + s / 2, s * 0.26, m.overheat / HEAT.overheat, u, now)
}

function footer(ctx, ui, L, u) {
  ctx.textBaseline = 'bottom'
  font(ctx, 10, u, 600)
  ctx.textAlign = 'left'
  ctx.fillStyle = '#6d7789'
  ctx.fillText(t('rival', { name: ui.mode === 'bot' ? t('bot') : t(ui.mode) }), 16 * u, L.h - 12 * u)
  ctx.textAlign = 'right'
  const state = [ui.muted ? t('muted') : '', !ui.music && !ui.muted ? t('musicOff') : ''].filter(Boolean)
  ctx.fillText([...state, t('miniHelp')].join(' · '), L.w - 16 * u, L.h - 12 * u)
}

function shout(ctx, text, x, y, px, color, glowColor, u, scale = 1, alpha = 1) {
  ctx.save()
  ctx.globalAlpha = alpha
  ctx.translate(x, y)
  ctx.scale(scale, scale)
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  font(ctx, px, u, 900)
  ctx.shadowColor = glowColor
  ctx.shadowBlur = 28 * u
  ctx.lineWidth = 6 * u
  ctx.strokeStyle = 'rgba(0,0,0,0.75)'
  ctx.strokeText(text, 0, 0)
  ctx.fillStyle = color
  ctx.fillText(text, 0, 0)
  ctx.restore()
}

function banner(ctx, state, ui, L, u, now) {
  const cx = L.w / 2
  const cy = L.cy
  if (state.phase === 'countdown' && state.timer > 0) {
    const n = Math.ceil(state.timer / TICKS)
    const p = (state.timer % TICKS) / TICKS
    shout(ctx, String(n), cx, cy - 20 * u, 96, '#ffffff', 'rgba(255,200,120,0.9)', u, 1 + 0.5 * p, Math.min(1, 0.4 + p))
    return
  }
  for (const [k, size] of [['closing', 56], ['ventsOn', 40]]) {
    const f = state.fx.find(f => f.k === k)
    if (f) shout(ctx, t(k), cx, cy - 20 * u, size, '#ff7a4a', 'rgba(255,60,40,0.9)', u, 1 + 0.3 * (f.t / 90), Math.min(1, f.t / 30))
  }
  const fight = state.fx.find(f => f.k === 'fight')
  if (fight) shout(ctx, t('go'), cx, cy - 20 * u, 84, '#ffd27a', 'rgba(255,170,60,0.95)', u, 1 + 0.4 * (fight.t / 50), Math.min(1, fight.t / 20))
  if (state.phase === 'ko') {
    const timeUp = state.fx.some(f => f.k === 'time')
    const k = Math.min(1, (MATCH.ko - state.timer) / 12)
    shout(ctx, t(timeUp ? 'timeUp' : 'ko'), cx, cy - 30 * u, 92, '#ff5a3c', 'rgba(255,60,40,0.95)', u, 1.6 - 0.6 * k)
    const who = state.winner === 0 ? 'youWin' : state.winner === 1 ? (ui.mode === 'bot' ? 'rivalWins' : 'dummyWins') : 'draw'
    shout(ctx, t(who), cx, cy + 40 * u, 22, state.winner >= 0 ? rgba(TEAM_LIGHT[state.winner]) : '#c9d1dc', 'rgba(0,0,0,0)', u)
  }
  if (state.phase === 'over') {
    ctx.fillStyle = 'rgba(0,0,0,0.5)'
    ctx.fillRect(0, 0, L.w, L.h)
    const won = state.score[0] > state.score[1]
    shout(ctx, t(won ? 'victory' : 'defeat'), cx, cy - 40 * u, 88, won ? '#ffd27a' : '#9fb4d8', won ? 'rgba(255,170,60,0.9)' : 'rgba(80,140,255,0.8)', u)
    shout(ctx, `${state.score[0]} - ${state.score[1]}`, cx, cy + 30 * u, 40, '#e6ebf2', 'rgba(0,0,0,0)', u)
    if (Math.floor(now / 500) % 2) shout(ctx, t('rematch'), cx, cy + 80 * u, 16, '#c9d1dc', 'rgba(0,0,0,0)', u)
  }
}

const controlRows = () => [
  ['WASD', t('cMove')],
  [t('kMouse'), t('cAim')],
  [t('kLmb'), t('cLeft')],
  [t('kRmb'), t('cRight')],
  ['Q', t('cShield')],
  ['E', t('cHook')],
  [t('kSpace'), t('cDash')],
  ['R', t('cUlt')],
]

function controlsWidth(ctx, u) {
  font(ctx, 11, u, 600)
  return Math.min(720 * u, Math.max(...controlRows().map(([, a]) => ctx.measureText(a).width)) + 150 * u)
}

function controls(ctx, L, u, y, cx = L.w / 2, room = Infinity) {
  const rows = controlRows()
  const w = Math.min(room, controlsWidth(ctx, u))
  const rh = 24 * u
  const h = rows.length * rh + 22 * u
  const x = cx - w / 2
  plate(ctx, x, y, w, h, 14 * u, 'rgba(8,22,46,0.94)', UI_C.line, 1.5 * u)
  ctx.fillStyle = rgba(HOLO, 0.8)
  ctx.fillRect(x + 18 * u, y, 90 * u, 2 * u)
  rows.forEach(([k, action], i) => {
    const ry = y + 11 * u + i * rh + rh / 2
    if (i) {
      ctx.fillStyle = 'rgba(80,150,230,0.12)'
      ctx.fillRect(x + 16 * u, ry - rh / 2, w - 32 * u, u)
    }
    ctx.textBaseline = 'middle'
    ctx.textAlign = 'center'
    font(ctx, 10, u, 800)
    const kw = Math.max(26 * u, ctx.measureText(k).width + 14 * u)
    rrect(ctx, x + 110 * u - kw, ry - 9 * u, kw, 18 * u, 4 * u, 'rgba(26,66,124,0.9)', UI_C.hi, u)
    ctx.fillStyle = '#ffffff'
    ctx.fillText(k, x + 110 * u - kw / 2, ry + 0.5 * u)
    ctx.textAlign = 'left'
    fitFont(ctx, action, 11, u, 600, w - 140 * u)
    ctx.fillStyle = UI_C.text
    ctx.fillText(action, x + 124 * u, ry + 0.5 * u)
  })
}

export function cursor(ctx, { x, y }, u, pointer, m, now) {
  const c = rgba(TEAM_LIGHT[0], 0.95)
  if (pointer) {
    ctx.beginPath()
    ctx.moveTo(x, y)
    ctx.lineTo(x, y + 18 * u)
    ctx.lineTo(x + 5 * u, y + 13 * u)
    ctx.lineTo(x + 12 * u, y + 13 * u)
    ctx.closePath()
    ctx.fillStyle = '#ffffff'
    ctx.fill()
    ctx.strokeStyle = 'rgba(0,0,0,0.8)'
    ctx.lineWidth = 1.5 * u
    ctx.stroke()
    return
  }
  if (m?.overheat > 0) {
    ctx.save()
    const r = rgba(VENT_C)
    circle(ctx, x, y, 8 * u, 'rgba(40,8,6,0.5)', r, 2 * u)
    ctx.strokeStyle = r
    ctx.lineWidth = 2.4 * u
    ctx.beginPath()
    ctx.moveTo(x - 5.5 * u, y - 5.5 * u)
    ctx.lineTo(x + 5.5 * u, y + 5.5 * u)
    ctx.stroke()
    ctx.strokeStyle = 'rgba(220,240,255,0.95)'
    ctx.lineWidth = 2.6 * u
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.arc(x, y, 14 * u, -Math.PI / 2, -Math.PI / 2 + TAU * (m.overheat / HEAT.overheat))
    ctx.stroke()
    ctx.restore()
    glow(ctx, x, y, 22 * u, VENT_C, 0.25 + 0.15 * Math.sin(now / 70))
    return
  }
  circle(ctx, x, y, 7 * u, null, c, 1.6 * u)
  ctx.strokeStyle = c
  ctx.beginPath()
  for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    ctx.moveTo(x + dx * 10 * u, y + dy * 10 * u)
    ctx.lineTo(x + dx * 15 * u, y + dy * 15 * u)
  }
  ctx.stroke()
  circle(ctx, x, y, 1.5 * u, c)
}
