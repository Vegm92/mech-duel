extends RefCounted

const Sim = preload("res://src/sim.gd")

const SKILL := {"skilled": {"aimError": 0.3, "reaction": 0.15, "dodge": 0.5}, "average": {"aimError": 0.9, "reaction": 0.3, "dodge": 0.25}, "weak": {"aimError": 1.6, "reaction": 0.5, "dodge": 0.1}}
const BOT := {"aimError": 0.9, "guard": 0.35, "dodge": 0.25, "reaction": 0.3, "jukeMin": 18, "jukeMax": 70, "close": [1.6, 2.6], "heatCap": 82, "rhythm": 18, "healAt": 0.6, "grab": 14, "stick": 1.3}


static func create_brain(seed := 1) -> Dictionary:
	return {"seed": seed & 0xFFFFFFFF, "side": 1, "nextJuke": 0, "lastFlip": 0, "guard": 0, "threat": 0, "guardRoll": false, "dodgeRoll": false, "nextShot": {"left": 0, "right": 0}}


static func melee_ready(m) -> bool:
	for h in Sim.HANDS:
		if not Sim.is_gun(Sim.weapon(m, h)) and m.cd[h] == 0:
			return true
	return false


static func random_loadout(brain) -> Dictionary:
	var out := {}
	for slot in Sim.CATALOG:
		var k: Array = Sim.CATALOG[slot].keys()
		out[slot] = k[int(floor(Sim.rng(brain) * k.size()))]
	return out


static func clear_line(x0: float, y0: float, x1: float, y1: float, pillars: Array = Sim.PILLARS) -> bool:
	for p in pillars:
		if Sim.seg_dist(x0, y0, x1, y1, p.x, p.y) <= p.r + 0.3:
			return false
	return true


static func open_line(state, x0: float, y0: float, x1: float, y1: float, team := -1) -> bool:
	var g: Dictionary = Sim.geo(state)
	var rings: Array = g.get("rings", [])
	var boxes: Array = g.get("boxes", [])
	if rings.is_empty() and boxes.is_empty():
		return true
	var n := int(ceil(Sim.hypot(x1 - x0, y1 - y0) / 2.0))
	for i in range(1, n):
		var x: float = lerpf(x0, x1, i / float(n))
		var y: float = lerpf(y0, y1, i / float(n))
		var d := Sim.hypot(x, y)
		for r in rings:
			if d > r.r0 and d < r.r1 and not Sim.in_gap(r, x, y, 0.0):
				return false
		for bx in boxes:
			if bx.get("hp", 1) > 0 and (team < 0 or bx.get("only", team) == team) and x > bx.x0 and x < bx.x1 and y > bx.y0 and y < bx.y1:
				return false
	return true


static func health(m) -> float:
	var s := 0.0
	for p in m.armor:
		s += maxf(0, m.armor[p]) / float(m.max[p])
	return s / 4.0


static func ally(state, m, id) -> bool:
	return state.mechs[id].team == m.team


static func dist(a, b) -> float:
	return Sim.hypot(b.x - a.x, b.y - a.y)


static func pick(state, brain, m):
	var lst := Sim.foes(state, m.id)
	if brain.get("lanes_only", false):
		lst = lst.filter(func(t): return t.team != 2)
	var near = null
	for t in lst:
		if near == null or dist(m, t) < dist(m, near):
			near = t
	var cur = null
	for t in lst:
		if t.id == brain.get("target", -1):
			cur = t
			break
	if cur != null and dist(m, cur) < dist(m, near) * BOT.stick + 2:
		return cur
	if near != null:
		brain.target = near.id
		return near
	for t in state.mechs:
		if t.team != m.team and not (brain.get("lanes_only", false) and t.team == 2):
			return t
	return m


static func incoming(state, m, react: float = BOT.reaction):
	var best = null
	for s in state.shots:
		if ally(state, m, s.owner):
			continue
		var t: float = ((m.x - s.x) * s.vx + (m.y - s.y) * s.vy) / float(s.vx * s.vx + s.vy * s.vy)
		if t <= 0 or t > react:
			continue
		var miss := Sim.hypot(s.x + s.vx * t - m.x, s.y + s.vy * t - m.y)
		if miss < Sim.MECH_R + s.r + 0.35 and (best == null or t < best.t):
			best = {"t": t, "s": s}
	return best


static func away(acc: Array, m, hx: float, hy: float, r: float) -> void:
	var d := Sim.hypot(m.x - hx, m.y - hy)
	if d == 0:
		d = 1
	if d > r:
		return
	acc[0] += (m.x - hx) / d
	acc[1] += (m.y - hy) / d


static func hazards(state, m) -> Dictionary:
	var acc := [0.0, 0.0]
	for l in state.lobs:
		if not ally(state, m, l.owner) and l.t < 40:
			away(acc, m, l.x, l.y, l.r + Sim.MECH_R + 0.6)
	for mi in state.mines:
		if not ally(state, m, mi.owner):
			away(acc, m, mi.x, mi.y, 2.2)
	for f in state.fields:
		if not ally(state, m, f.owner):
			away(acc, m, f.x, f.y, f.r + 0.5)
	for tr in state.trails:
		if ally(state, m, tr.owner) or tr.kind == "smoke":
			continue
		var dx: float = tr.x2 - tr.x1
		var dy: float = tr.y2 - tr.y1
		var den := dx * dx + dy * dy
		if den == 0:
			den = 1
		var k := clampf(((m.x - tr.x1) * dx + (m.y - tr.y1) * dy) / den, 0, 1)
		away(acc, m, tr.x1 + dx * k, tr.y1 + dy * k, Sim.TRAILS[tr.kind].width + Sim.MECH_R + 0.4)
	if state.has("geo"):
		return {"x": acc[0], "y": acc[1]}
	var C = Sim.TRAPS.crush
	for i in C.at.size():
		if Sim.until_slam(state, i) < C.warn + 20:
			away(acc, m, C.at[i].x, C.at[i].y, C.half * 1.42 + Sim.MECH_R + 0.4)
	var Z = Sim.TRAPS.tesla
	for i in Z.at.size():
		if Sim.until_zap(state, i) < Z.warn + 20:
			away(acc, m, Z.at[i].x, Z.at[i].y, Z.reach + Sim.MECH_R + 0.5)
	var v = Sim.vent_phase(state)
	if v != null and (v.warn or v.burn):
		var r := Sim.HAZARDS.reach / 2.0
		for g in Sim.vents(state.shrink):
			if g.wall % 2 == v["set"]:
				away(acc, m, g.x + g.dx * r, g.y + g.dy * r, r + Sim.HAZARDS.half + Sim.MECH_R + 0.4)
	return {"x": acc[0], "y": acc[1]}


static func wants_item(kind: String, m) -> bool:
	if kind == "repair":
		return health(m) < 0.85
	if kind == "coolant":
		return m.heat > 40
	if kind == "surge":
		return m.surge < Sim.SURGE.max - 20
	return true


static func goal(state, m, o):
	if state.heal.ready and health(m) < BOT.healAt:
		return Sim.HEAL
	var best = null
	for i in state.pads.size():
		var kind = state.pads[i]
		var p = Sim.PADS[i]
		if kind == null or not wants_item(kind, m):
			continue
		var blocked := false
		for w in Sim.geo(state).walls:
			if p.x * w.nx + p.y * w.ny > w.d - state.shrink - Sim.MECH_R:
				blocked = true
				break
		if blocked:
			continue
		var d := Sim.hypot(p.x - m.x, p.y - m.y)
		if d < BOT.grab and d < Sim.hypot(p.x - o.x, p.y - o.y) + 2 and (best == null or d < best.d):
			best = {"x": p.x, "y": p.y, "d": d}
	return best


static func wants_e(e: String, m, o, d: float, sight: bool, threat, g, shooter, melees: Array) -> bool:
	match e:
		"brace":
			return threat != null or d < 5
		"cleanse":
			return m.buffs.slow > 0 or m.buffs.jam > 0 or m.buffs.root > 0 or m.pull != null
		"focus":
			return g != null and sight and m.cd[shooter] == 0 and d > 5 and d < g.range * 0.4
		"pulse":
			return health(m) < 0.7 and threat == null and d > 8
		"xray":
			return g != null and not sight and m.cd[shooter] == 0 and d < g.range
		"frost":
			return sight and d > 4 and d < 9
		"arcwall":
			return threat != null
		"trap":
			return d > 2.5 and d < 8
		"lunge":
			return not melees.is_empty() and sight and o.pull == null and d > 3 and d < 7.5
	return false


static func wants_ult(kind: String, d: float, sight: bool, open: bool, hurt: bool, threat, h, heat: float) -> bool:
	match kind:
		"lance":
			return sight and d < Sim.LANCE.length - 1 and (open or d < 6)
		"swarm":
			return d < 18
		"overdrive":
			return d < 9 and sight
		"berserk":
			return d < 6
		"emp":
			return d < h.radius + Sim.MECH_R - 0.5
		"orbital":
			return d < h.range and (open or d > 6)
		"repair":
			return hurt
		"bubble":
			return threat != null or d < 7
		"stasis":
			return d < h.range - 1
		"mines":
			return d < 4
		"blink":
			return d > 10 and d < 24
		"well":
			return d < h.range - 1
		"wall":
			return threat != null or (d > 9 and d < 20)
		"meltdown":
			return d < h.radius + 0.4 and heat > 45
		"deflect":
			return threat != null or d > 7
		"mirror":
			return threat != null
		"rail":
			return d < h.length - 2
		"shroud":
			return hurt or d < 6
	return false


static func flip(brain, tick) -> void:
	brain.side = -brain.side
	brain.lastFlip = tick


static func travel_of(dist_: float, ulting: bool, h, g) -> float:
	if ulting and h.kind == "orbital":
		return (h.delay + h.windup) / float(Sim.TICKS)
	if g != null and g.kind == "lob":
		return (g.delay + g.windup) / float(Sim.TICKS)
	if g != null and g.kind == "bolt" and not g.has("homing"):
		return dist_ / g.speed
	return 0.0


static func bot_input(state, brain, me := 1) -> Dictionary:
	var m = state.mechs[me]
	var o = pick(state, brain, m)
	var inp := {"mx": 0.0, "my": 0.0, "ax": o.x, "ay": o.y, "left": false, "right": false, "hook": false, "shield": false, "dash": false, "ult": false}
	if state.phase != "fight" or m.ko or o.ko:
		return inp
	var tick = state.tick
	var guns := []
	var melees := []
	for h in Sim.HANDS:
		if Sim.is_gun(Sim.weapon(m, h)):
			guns.append(h)
		else:
			melees.append(h)
	var shooter = null
	for h in guns:
		if m.cd[h] == 0 and tick >= brain.nextShot[h]:
			shooter = h
			break
	if shooter == null and guns.size():
		shooter = guns[0]
	var g = Sim.weapon(m, shooter) if shooter != null else null
	var dx: float = o.x - m.x
	var dy: float = o.y - m.y
	var d := Sim.hypot(dx, dy)
	if d == 0:
		d = 1
	var ux := dx / d
	var uy := dy / d
	var px := -uy
	var py := ux
	var threat = incoming(state, m, brain.get("reaction", BOT.reaction))
	if threat != null and threat.s.cast != brain.threat:
		brain.threat = threat.s.cast
		brain.guardRoll = Sim.rng(brain) < BOT.guard
		brain.dodgeRoll = Sim.rng(brain) < brain.get("dodge", BOT.dodge)
	var veiled := Sim.hidden(state, o)
	var sight: bool = not veiled and clear_line(m.x, m.y, o.x, o.y, Sim.geo(state).pillars) and open_line(state, m.x, m.y, o.x, o.y, m.team)
	var open: bool = (o.dashes == 0 and o.cd.dash > 40) or o.stagger > 0 or o.overheat > 0
	var aggressive: bool = open or o.armor.head < m.armor.head * 0.6
	var flier: bool = o.get("fly", false)
	var band = BOT.close if (aggressive and not flier) or g == null else g.band
	var lo: float = band[0]
	var hi: float = band[1]
	var target = goal(state, m, o)
	var avoid := hazards(state, m)

	if tick >= brain.nextJuke:
		flip(brain, tick)
		brain.nextJuke = tick + BOT.jukeMin + floor(Sim.rng(brain) * (BOT.jukeMax - BOT.jukeMin))
	if threat != null and not brain.guardRoll and tick - brain.lastFlip > 12:
		flip(brain, tick)
	var wx := 0.0
	var wy := 0.0
	for w in Sim.geo(state).walls:
		if w.d - state.shrink - (m.x * w.nx + m.y * w.ny) > 2.5:
			continue
		wx -= w.nx
		wy -= w.ny
	if (px * wx + py * wy) * brain.side < -0.3 and tick - brain.lastFlip > 12:
		flip(brain, tick)
	if target != null:
		var hx: float = target.x - m.x
		var hy: float = target.y - m.y
		var hd := Sim.hypot(hx, hy)
		if hd == 0:
			hd = 1
		inp.mx = hx / hd + px * brain.side * 0.3
		inp.my = hy / hd + py * brain.side * 0.3
	else:
		var radial := 1 if d > hi else (-1 if d < lo else 0)
		inp.mx = px * brain.side + ux * radial + wx * 0.8
		inp.my = py * brain.side + uy * radial + wy * 0.8
	inp.mx += avoid.x * 1.5
	inp.my += avoid.y * 1.5

	var h = Sim.ult(m)
	var ulting: bool = (m.act != null and m.act.k == "ult") or (m.surge >= Sim.SURGE.max and h.kind == "orbital")
	var tx: float = o.x
	var ty: float = o.y
	for _i in 2:
		var travel := travel_of(Sim.hypot(tx - m.x, ty - m.y), ulting, h, g)
		tx = o.x + o.vx * travel
		ty = o.y + o.vy * travel
	var err: float = (Sim.rng(brain) - 0.5) * 2 * brain.get("aimError", BOT.aimError) * (4 if veiled else 1)
	inp.ax = tx + px * err
	inp.ay = ty + py * err

	if brain.guard > 0:
		brain.guard -= 1
		inp.shield = true
	elif threat != null and brain.guardRoll and m.cd.shield == 0 and threat.t * Sim.TICKS <= Sim.SHIELD.perfect - 2:
		brain.guard = Sim.SHIELD.minHold
		inp.shield = true
	if inp.shield:
		if threat != null:
			inp.ax = threat.s.x
			inp.ay = threat.s.y
		return inp

	var swing = null
	for hand in melees:
		if not flier and m.cd[hand] == 0 and d < Sim.weapon(m, hand).range * 0.75 + Sim.MECH_R:
			swing = hand
			break
	if swing != null and o.pull == null:
		inp[swing] = true
		inp.ax = o.x
		inp.ay = o.y
		return inp
	if o.pull != null and o.pull.by == me:
		return inp

	if m.dashes > 0 and target == null:
		if aggressive and not flier and d > 4 and d < 8.5 and sight:
			inp.dash = true
			inp.mx = ux
			inp.my = uy
		elif not aggressive and d < 3.2 and melee_ready(o):
			inp.dash = true
			inp.mx = -ux + px * brain.side
			inp.my = -uy + py * brain.side
		elif threat != null and brain.dodgeRoll and threat.t < 0.12:
			inp.dash = true
			inp.mx = px * brain.side
			inp.my = py * brain.side
		if inp.dash and Sim.move_of(m).get("toCursor", false) and not (aggressive and d < 8.5):
			inp.ax = m.x + inp.mx * 6
			inp.ay = m.y + inp.my * 6

	if m.cd.hook == 0 and not inp.dash and wants_e(Sim.e_skill(m), m, o, d, sight, threat, g, shooter, melees):
		inp.hook = true
	var facing: bool = o.act != null and o.act.k == "shield" and o.act.ph == "up" and cos(o.act.angle - atan2(-dy, -dx)) > cos(Sim.SHIELD.arc)
	var heat_ok: bool = m.heat < BOT.heatCap or o.armor.head <= (g.get("dmg", 0) if g != null else 0)
	var lob: bool = g != null and g.kind == "lob"
	if m.surge >= Sim.SURGE.max and wants_ult(h.kind, d, sight, open, health(m) < 0.55, threat, h, m.heat):
		inp.ult = true
	elif Sim.e_skill(m) == "hook" and m.cd.hook == 0 and (melees.is_empty() or melee_ready(m)) and sight and not facing and d > 4 and d < Sim.espec(m).range - 1:
		inp.hook = true
		var travel := d / Sim.HOOK.speed
		inp.ax = o.x + o.vx * travel
		inp.ay = o.y + o.vy * travel
	elif g != null and m.cd[shooter] == 0 and (sight or lob or m.buffs.xray > 0) and heat_ok and (not facing or lob) and d > 2 and d < g.range and tick >= brain.nextShot[shooter]:
		inp[shooter] = true
		brain.nextShot[shooter] = tick + g.cd + floor(Sim.rng(brain) * minf(BOT.rhythm, g.cd))
	return inp
