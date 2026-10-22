export const TAU = Math.PI * 2
export const TEAM = [[255, 122, 47], [79, 157, 255]]
export const TEAM_LIGHT = [[255, 196, 150], [170, 210, 255]]
export const TEAM_DARK = [[110, 40, 10], [20, 55, 115]]
export const SURGE_C = [197, 139, 255]
export const VENT_C = [255, 70, 50]
export const HOLO = [95, 180, 255]
export const UI_C = { card: 'rgba(10,28,58,0.92)', hov: 'rgba(18,46,90,0.95)', sel: 'rgba(26,66,124,0.97)', line: 'rgba(80,150,230,0.45)', hi: 'rgba(160,215,255,0.95)', text: '#e8f2ff', dim: '#7fa6d6', label: '#5d84b8' }
export const BOOST_C = { arc: [150, 205, 255], flame: [255, 150, 60], frost: [170, 240, 255], smoke: [190, 190, 200], magnet: [205, 125, 255], clean: [255, 232, 170] }
export const ITEM_C = { repair: [90, 255, 150], shield: [110, 170, 255], speed: [255, 220, 70], power: [255, 80, 60], coolant: [110, 235, 255], surge: SURGE_C }
export const STEEL = [[178, 188, 204], [216, 176, 74], [224, 96, 63], [46, 50, 58]]
export const HP_C = ['#6fd38a', '#d8b04a', '#e0603f', '#3a3f48']
export const SANS = "'Segoe UI', system-ui, sans-serif"
export const MONO = 'ui-monospace, Consolas, monospace'
export const PARTS = ['head', 'rarm', 'larm', 'legs']

export const rgba = (c, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`
export const shade = (c, k) => c.map(v => Math.min(255, Math.round(v * k)))
export const health = (m, part) => {
  const f = m.armor[part] / m.max[part]
  return f <= 0 ? 3 : f > 0.5 ? 0 : f > 0.25 ? 1 : 2
}

export function tileHash(i, j) {
  let h = (Math.imul(i + 11, 73856093) ^ Math.imul(j + 7, 19349663)) >>> 0
  h = Math.imul(h ^ (h >>> 13), 0x5bd1e995) >>> 0
  return (h ^ (h >>> 15)) >>> 0
}

export function font(ctx, px, u, weight = 600, family = SANS) {
  ctx.font = `${weight} ${Math.round(px * u)}px ${family}`
}

export function circle(ctx, x, y, r, fill, stroke, lw = 1) {
  ctx.beginPath()
  ctx.arc(x, y, Math.max(0, r), 0, TAU)
  if (fill) {
    ctx.fillStyle = fill
    ctx.fill()
  }
  if (stroke) {
    ctx.strokeStyle = stroke
    ctx.lineWidth = lw
    ctx.stroke()
  }
}

export function rrect(ctx, x, y, w, h, r, fill, stroke, lw = 1) {
  ctx.beginPath()
  ctx.roundRect(x, y, w, h, r)
  if (fill) {
    ctx.fillStyle = fill
    ctx.fill()
  }
  if (stroke) {
    ctx.strokeStyle = stroke
    ctx.lineWidth = lw
    ctx.stroke()
  }
}

export function heatGauge(ctx, x, y, r, frac, u, now) {
  const pulse = 0.65 + 0.35 * Math.sin(now / 70)
  glow(ctx, x, y, r * 2.2, VENT_C, 0.35 * pulse)
  ctx.save()
  circle(ctx, x, y, r * 1.3, 'rgba(14,6,6,0.88)', rgba(VENT_C, pulse), 1.6 * u)
  ctx.lineCap = 'round'
  ctx.strokeStyle = 'rgba(220,240,255,0.95)'
  ctx.lineWidth = r * 0.26
  ctx.beginPath()
  ctx.arc(x, y, r, -Math.PI / 2, -Math.PI / 2 + TAU * frac)
  ctx.stroke()
  const h = r * 1.15
  const w = r * 0.34
  rrect(ctx, x - w / 2, y - h * 0.62, w, h, w / 2, '#e8edf3')
  rrect(ctx, x - w * 0.22, y - h * 0.62 + h * (1 - frac) * 0.85, w * 0.44, h * (0.15 + 0.85 * frac), w * 0.22, rgba(VENT_C))
  circle(ctx, x, y + h * 0.42, w * 0.85, rgba(VENT_C), '#e8edf3', 1.2 * u)
  ctx.restore()
}

export function glow(ctx, x, y, r, rgb, a) {
  if (r <= 0 || a <= 0) return
  const g = ctx.createRadialGradient(x, y, 0, x, y, r)
  g.addColorStop(0, rgba(rgb, a))
  g.addColorStop(1, rgba(rgb, 0))
  ctx.save()
  ctx.globalCompositeOperation = 'lighter'
  ctx.fillStyle = g
  ctx.beginPath()
  ctx.arc(x, y, r, 0, TAU)
  ctx.fill()
  ctx.restore()
}

export function plate(ctx, x, y, w, h, c, fill, stroke, lw) {
  ctx.beginPath()
  ctx.moveTo(x + c, y)
  ctx.lineTo(x + w, y)
  ctx.lineTo(x + w, y + h - c)
  ctx.lineTo(x + w - c, y + h)
  ctx.lineTo(x, y + h)
  ctx.lineTo(x, y + c)
  ctx.closePath()
  if (fill) {
    ctx.fillStyle = fill
    ctx.fill()
  }
  if (stroke) {
    ctx.strokeStyle = stroke
    ctx.lineWidth = lw
    ctx.stroke()
  }
}
