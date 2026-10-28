extends RefCounted

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const S = preload("res://src/siege_state.gd")

const RUN := {
	"first": 10 * Sim.TICKS, "build": 25 * Sim.TICKS, "warn": 8 * Sim.TICKS, "cap": 90 * Sim.TICKS, "gap": 30,
	"respawn": 8 * Sim.TICKS, "respawnWave": 30, "repairDelay": Sim.TICKS, "repair": 25.0 / Sim.TICKS,
	"scrap": 5, "aggro": 6.0, "post": 21.0, "leash": 14.0, "corpse": 90, "spawnRing": 7.0, "players": 0.4, "frame": 24.0,
}
const MK := [{"hp": 1.0, "dmg": 1.0, "speed": 1.0}, {"hp": 1.5, "dmg": 1.25, "speed": 1.0}, {"hp": 2.2, "dmg": 1.5, "speed": 1.1}]
const BOTS := {
	"scout": {"cost": 1, "hp": 60, "speed": 7.5, "r": 0.6, "poise": 1, "attack": "bolt", "range": 12.0, "dmg": 10, "impact": 0, "cd": 60, "windup": 12, "shot": {"speed": 30, "radius": 0.25, "range": 14}, "dodge": 0.35},
	"swarm": {"cost": 2, "pack": 3, "hp": 40, "speed": 6.5, "r": 0.4, "poise": 0, "attack": "bite", "range": 1.0, "dmg": 6, "impact": 0, "cd": 40, "windup": 8, "boom": {"dmg": 40, "r": 2.5}},
	"spider": {"cost": 2, "hp": 170, "speed": 6.5, "r": 0.7, "poise": 1, "attack": "lunge", "range": 4.5, "dmg": 25, "impact": 2, "cd": 90, "windup": 18, "lunge": 5.0, "hunt": 30.0, "vent": true},
	"flyer": {"cost": 3, "hp": 170, "speed": 7.0, "r": 0.6, "poise": 1, "attack": "bolt", "range": 10.0, "dmg": 15, "impact": 0, "cd": 30, "windup": 6, "shot": {"speed": 34, "radius": 0.25, "range": 12}, "fly": true, "first": "mech", "halt": false},
	"turret": {"cost": 4, "hp": 480, "speed": 3.5, "r": 1.0, "poise": 3, "attack": "bolt", "range": 22.0, "dmg": 30, "impact": 1, "cd": 90, "windup": 20, "shot": {"speed": 36, "radius": 0.35, "range": 24}, "plant": 45, "first": "mech"},
	"walker": {"cost": 5, "hp": 670, "speed": 4.0, "r": 1.2, "poise": 3, "attack": "claw", "range": 2.4, "dmg": 45, "impact": 2, "cd": 70, "windup": 16, "gun": {"range": 12.0, "dmg": 20, "cd": 80, "impact": 0, "shot": {"speed": 32, "radius": 0.3, "range": 14}}},
	"tripod": {"cost": 5, "hp": 310, "speed": 3.5, "r": 1.0, "poise": 2, "attack": "rail", "range": 34.0, "dmg": 90, "impact": 2, "cd": 180, "windup": 120, "lock": 30, "hunt": 40.0, "keep": 24.0, "first": "mech"},
	"quadheavy": {"cost": 8, "hp": 1110, "speed": 3.0, "r": 1.5, "poise": 4, "attack": "salvo", "range": 45.0, "dmg": 35, "impact": 1, "cd": 300, "windup": 40, "shells": 4, "spread": 2.5, "splash": 2.0, "delay": 90, "first": "core"},
	"heavy": {"cost": 9, "hp": 1620, "speed": 2.8, "r": 1.6, "poise": 5, "attack": "cannon", "range": 18.0, "dmg": 80, "impact": 3, "cd": 150, "windup": 30, "splash": 2.5, "delay": 30, "first": "mech"},
	"jugg": {"cost": 9, "hp": 1360, "speed": 3.0, "r": 1.4, "poise": 5, "attack": "ram", "range": 2.4, "dmg": 120, "impact": 4, "cd": 0, "windup": 40, "roll": 11.0, "rollTime": 480, "exposed": 240, "push": 6.0, "gateK": 3},
}


static func budget(n: int, team: int) -> float:
	return (3 + 2.5 * n + 0.18 * n * n) * (1 + RUN.players * (team - 1))


static func geo_of(sg: Dictionary) -> Dictionary:
	var h: float = S.HALF
	var walls := [{"nx": 0.0, "ny": -1.0, "d": h}, {"nx": 1.0, "ny": 0.0, "d": h}, {"nx": 0.0, "ny": 1.0, "d": h}, {"nx": -1.0, "ny": 0.0, "d": h}]
	var pillars := []
	var solids := [sg.core]
	for lane in 4:
		for d in S.CHOKES:
			for side in [-1, 1]:
				var p := S.at(lane, d, side * S.LANE_W / 2.0)
				var pil := {"x": p.x, "y": p.y, "r": S.CHOKE_R}
				pillars.append(pil)
				solids.append(pil)
		for side in [-1, 1]:
			var p := S.at(lane, (S.RING_IN + S.RING_OUT) / 2.0, side * S.LANE_W / 2.0)
			solids.append({"x": p.x, "y": p.y, "r": (S.RING_OUT - S.RING_IN) / 2.0})
	pillars.append(sg.core)
	var w: float = S.LANE_W / 2.0
	var b: float = S.BLOCK
	var boxes := []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			boxes.append(box(sx * w, sy * b, sx * h, sy * h))
			boxes.append(box(sx * b, sy * w, sx * h, sy * b))
	for g in sg.gates:
		boxes.append(g)
	var gaps := []
	for l in S.LANES:
		gaps.append({"dx": l.dx, "dy": l.dy})
	var rings := [{"r0": S.RING_IN, "r1": S.RING_OUT, "half": w, "gaps": gaps}, {"r0": S.BLOCK, "r1": h * 2.0, "half": w, "gaps": gaps}]
	return {"walls": walls, "pillars": pillars, "solids": solids, "boxes": boxes, "rings": rings}


static func box(xa: float, ya: float, xb: float, yb: float) -> Dictionary:
	return {"x0": minf(xa, xb), "y0": minf(ya, yb), "x1": maxf(xa, xb), "y1": maxf(ya, yb)}


static func gate_box(lane: int) -> Dictionary:
	var g := S.gate(lane)
	var l: Dictionary = S.LANES[lane]
	var half: float = S.LANE_W / 2.0
	var depth: float = (S.RING_OUT - S.RING_IN) / 2.0
	var a := box(g.x - l.dy * half - l.dx * depth, g.y + l.dx * half - l.dy * depth, g.x + l.dy * half + l.dx * depth, g.y - l.dx * half + l.dy * depth)
	return g.merged(a).merged({"only": 1})


static func create(loadouts: Array, seed := 1) -> Dictionary:
	var teams := []
	for i in loadouts.size():
		teams.append(0)
	var state := Sim.create_state(loadouts, teams)
	state.seed = seed & 0xFFFFFFFF
	state.phase = "fight"
	state.timer = 0
	for m in state.mechs:
		place(m, m.id)
	var gates := []
	for lane in 4:
		gates.append(gate_box(lane))
	var core := {"x": 0.0, "y": 0.0, "r": S.CORE.r, "hp": float(S.CORE.hp), "max": S.CORE.hp, "rings": S.ring_hp(4), "repairing": false, "only": 1, "broken": 0}
	state.siege = {
		"tick": 0, "wave": {"n": 0, "next_in": RUN.first, "lanes_open": [false, false, false, false], "live": false},
		"core": core, "gates": gates, "pads": S.pads(), "enemies": [], "queue": [], "scrap": 0, "next": 0,
		"lost": false, "down": {}, "calm": {}, "was": {}, "team": loadouts.size(),
	}
	state.geo = geo_of(state.siege)
	return state


static func place(m: Dictionary, i: int) -> void:
	var a := -PI / 2.0 + i * PI / 2.0
	m.x = cos(a) * RUN.spawnRing
	m.y = sin(a) * RUN.spawnRing
	m.tx = m.x
	m.ty = m.y
	m.aim = a


static func step(state, inputs: Array):
	state.tick += 1
	var sg: Dictionary = state.siege
	sg.tick = state.tick
	Sim.age_fx(state)
	var team: int = sg.team
	if state.hitstop > 0:
		state.hitstop -= 1
		for i in team:
			Sim.read_buttons(state.mechs[i], inputs[i] if i < inputs.size() else Sim.IDLE, false)
		return state
	if state.phase == "over":
		return state
	for i in team:
		var m = state.mechs[i]
		if not m.ko:
			Sim.think(state, m, inputs[i] if i < inputs.size() and inputs[i] != null else Sim.IDLE)
	for e in sg.enemies:
		if e.act != "die":
			drive(state, sg, e, state.mechs[e.m])
	shell_land(state, sg)
	Sim.world(state)
	var live := []
	for m in state.mechs:
		if not m.ko and not m.get("fly", false):
			Sim.collide(m, 0.0, state.geo)
			live.append(m)
	for i in live.size():
		for j in range(i + 1, live.size()):
			Sim.separate(live[i], live[j])
	settle(state, sg)
	direct(state, sg)
	return state


static func ally_input(state, brain, id: int) -> Dictionary:
	var inp := Bot.bot_input(state, brain, id)
	var m = state.mechs[id]
	if m.ko:
		return inp
	var open := []
	for lane in 4:
		if state.siege.wave.lanes_open[lane]:
			open.append(lane)
	var post := S.at(open[id % open.size()] if open.size() else id % 4, RUN.post)
	var o = Bot.pick(state, brain, m)
	if o.ko or o.team == m.team or Sim.hypot(o.x - post.x, o.y - post.y) > RUN.leash:
		var dx: float = post.x - m.x
		var dy: float = post.y - m.y
		var d := Sim.hypot(dx, dy)
		inp.mx = dx / d if d > 1.5 else 0.0
		inp.my = dy / d if d > 1.5 else 0.0
		inp.dash = false
	return inp


static func drive(state, sg: Dictionary, e: Dictionary, b: Dictionary) -> void:
	var k: Dictionary = BOTS[e.kind]
	Sim.tick_timers(b)
	e.cd = maxi(0, e.cd - 1)
	e.cd2 = maxi(0, e.cd2 - 1)
	if e.kind == "jugg":
		ram(state, sg, e, b, k)
		return
	var busy: bool = b.stagger > 0 or b.buffs.root > 0
	if e.dash > 0:
		e.dash -= 1
		b.vx = e.jx * k.lunge / 0.35
		b.vy = e.jy * k.lunge / 0.35
		b.x += b.vx * Sim.DT
		b.y += b.vy * Sim.DT
		var t = state.mechs[e.prey] if e.prey >= 0 else null
		if t != null and not e.bit and not t.ko and Sim.hypot(t.x - b.x, t.y - b.y) <= Sim.rad(t) + k.r + 0.4:
			e.bit = true
			Sim.hit(state, b, t, scaled(e, k.dmg), "LEGS", k.impact, atan2(b.y - t.y, b.x - t.x), Sim.next_cast(state))
		act(e, "attack")
		return
	var tgt := target(state, sg, e, b, k)
	var dest := route(state, sg, e, b, k, tgt)
	var inp := {"mx": 0.0, "my": 0.0}
	var dx: float = dest.x - b.x
	var dy: float = dest.y - b.y
	var dd := Sim.hypot(dx, dy)
	if dd > 0.4:
		inp.mx = dx / dd
		inp.my = dy / dd
	if e.juke > 0:
		e.juke -= 1
		inp.mx = e.jx
		inp.my = e.jy
	elif k.has("dodge"):
		dodge(state, e, b, k)
	var planted := false
	if k.has("plant"):
		e.rooted = e.rooted + 1 if dd <= 0.4 and not busy else 0
		planted = e.rooted >= k.plant
		b.buffs.brace = 2 if planted else 0
		if e.rooted > 0:
			inp.mx = 0.0
			inp.my = 0.0
	if busy or tgt.is_empty() or (k.has("plant") and not planted):
		e.wind = 0
	else:
		var reach: float = Sim.hypot(tgt.x - b.x, tgt.y - b.y) - tgt.r
		var gun = k.get("gun")
		if gun != null and reach > k.range and reach <= gun.range and e.cd2 == 0 and e.wind == 0:
			e.cd2 = gun.cd
			shoot(state, e, b, gun, tgt)
		if reach <= k.range or e.wind > 0:
			b.aim = atan2(tgt.y - b.y, tgt.x - b.x)
			if k.get("halt", true):
				inp.mx = 0.0
				inp.my = 0.0
			if e.wind > 0:
				if e.wind > k.get("lock", 0):
					e.aim = b.aim
				e.wind -= 1
				if e.wind == 0:
					strike(state, sg, e, b, k, tgt)
			elif e.cd == 0:
				e.wind = k.windup
				e.aim = b.aim
				if k.attack == "rail":
					state.fx.append({"k": "sight", "id": e.id, "x1": b.x, "y1": b.y, "x2": tgt.x, "y2": tgt.y, "t": k.windup})
	if k.get("fly", false):
		b.vx = inp.mx * k.speed
		b.vy = inp.my * k.speed
		b.x += b.vx * Sim.DT
		b.y += b.vy * Sim.DT
	else:
		Sim.move(state, b, inp)
	if e.wind > 0:
		b.aim = e.aim
	elif Sim.hypot(b.vx, b.vy) > 0.5:
		b.aim = atan2(b.vy, b.vx)
	var moving := Sim.hypot(b.vx, b.vy) > 0.5
	act(e, "hit" if busy else ("windup" if e.wind > 0 else ("attack" if e.cd > k.cd - 12 else ("plant" if e.rooted > 0 else ("walk" if moving else "idle")))))


static func dodge(state, e: Dictionary, b: Dictionary, k: Dictionary) -> void:
	var threat = Bot.incoming(state, b)
	if threat == null or threat.s.cast == e.seen:
		return
	e.seen = threat.s.cast
	if Sim.rng(state) >= k.dodge:
		return
	var sp := Sim.hypot(threat.s.vx, threat.s.vy)
	var side := 1.0 if (b.x - threat.s.x) * -threat.s.vy + (b.y - threat.s.y) * threat.s.vx > 0 else -1.0
	e.jx = -threat.s.vy / sp * side
	e.jy = threat.s.vx / sp * side
	e.juke = 12


static func scaled(e: Dictionary, dmg) -> float:
	return floor(dmg * MK[e.mk - 1].dmg)


static func act(e: Dictionary, a: String) -> void:
	if e.act != a:
		e.act = a
		e.t = 0
	else:
		e.t += 1


static func target(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary) -> Dictionary:
	var reach: float = k.get("hunt", RUN.aggro if k.get("first", "") != "mech" else k.range)
	var near = null
	var nd := 0.0
	for i in sg.team:
		var m = state.mechs[i]
		if m.ko or Sim.hidden(state, m):
			continue
		var d := Sim.hypot(m.x - b.x, m.y - b.y)
		if d <= reach and (near == null or d < nd) and (d <= RUN.aggro or k.get("fly", false) or open_line(state, b.x, b.y, m.x, m.y)):
			near = m
			nd = d
	if near != null:
		return {"x": near.x, "y": near.y, "r": Sim.rad(near), "mech": near}
	var g: Dictionary = sg.gates[e.lane]
	if g.hp > 0 and outside(b, e.lane) and not k.get("fly", false) and k.get("first", "") != "core":
		return {"x": g.x, "y": g.y, "r": (S.RING_OUT - S.RING_IN) / 2.0, "hit": g}
	var c: Dictionary = sg.core
	return {"x": c.x, "y": c.y, "r": c.r, "hit": c}


static func open_line(state, x0: float, y0: float, x1: float, y1: float) -> bool:
	var g: Dictionary = state.geo
	var n := int(ceil(Sim.hypot(x1 - x0, y1 - y0)))
	for i in range(1, n):
		var x: float = lerpf(x0, x1, i / float(n))
		var y: float = lerpf(y0, y1, i / float(n))
		var d := Sim.hypot(x, y)
		for r in g.rings:
			if d > r.r0 and d < r.r1 and not Sim.in_gap(r, x, y, 0.0):
				return false
		for bx in g.boxes:
			if bx.get("hp", 1) > 0 and x > bx.x0 and x < bx.x1 and y > bx.y0 and y < bx.y1:
				return false
	return true


static func outside(b: Dictionary, lane: int) -> bool:
	var l: Dictionary = S.LANES[lane]
	return b.x * l.dx + b.y * l.dy > S.RING_OUT


static func route(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary, tgt: Dictionary) -> Dictionary:
	var stand: float = k.range * 0.8
	if tgt.has("mech"):
		var m = tgt.mech
		var d := Sim.hypot(m.x - b.x, m.y - b.y)
		if k.has("keep"):
			if absf(d - k.keep) < 4.0:
				return {"x": b.x, "y": b.y}
			var away: float = 1.0 if d < k.keep else -1.0
			return {"x": b.x + (b.x - m.x) / maxf(d, 0.1) * away * 4.0, "y": b.y + (b.y - m.y) / maxf(d, 0.1) * away * 4.0}
		if k.has("hunt") or k.get("fly", false) or d > stand:
			if d <= stand:
				return {"x": b.x, "y": b.y}
			return {"x": m.x, "y": m.y}
		return {"x": b.x, "y": b.y}
	var c: Dictionary = sg.core
	if k.get("fly", false):
		return approach(b, c, c.r + stand)
	if outside(b, e.lane):
		if k.get("first", "") == "core":
			return S.at(e.lane, maxf(S.RING_OUT + 4.0, stand), e.side)
		if sg.gates[e.lane].hp > 0:
			return S.at(e.lane, S.RING_OUT + (k.r + 0.1 if k.range < 5.0 else maxf(stand, k.r + 0.6)), e.side)
		return S.at(e.lane, S.RING_IN - 2.0, clampf(e.side, -3.0, 3.0))
	return approach(b, c, c.r + maxf(stand, k.r + 0.6))


static func approach(b: Dictionary, c: Dictionary, want: float) -> Dictionary:
	var d := Sim.hypot(b.x - c.x, b.y - c.y)
	if d <= want:
		return {"x": b.x, "y": b.y}
	return {"x": c.x + (b.x - c.x) / d * want, "y": c.y + (b.y - c.y) / d * want}


static func strike(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary, tgt: Dictionary) -> void:
	e.cd = k.cd
	var dmg := scaled(e, k.dmg)
	var cast := Sim.next_cast(state)
	match k.attack:
		"bolt":
			shoot(state, e, b, k, tgt)
		"bite", "claw":
			if tgt.has("mech"):
				Sim.hit(state, b, tgt.mech, dmg, "LEGS", k.impact, atan2(b.y - tgt.y, b.x - tgt.x), cast)
			elif k.has("boom"):
				blow(state, sg, e, b, k)
			else:
				harm(state, tgt.hit, dmg, b)
		"lunge":
			if tgt.has("mech"):
				var d: float = maxf(0.1, Sim.hypot(tgt.x - b.x, tgt.y - b.y))
				e.jx = (tgt.x - b.x) / d
				e.jy = (tgt.y - b.y) / d
				e.dash = 21
				e.bit = false
				e.prey = tgt.mech.id
			else:
				harm(state, tgt.hit, dmg, b)
		"rail":
			var a: float = e.aim
			var sx: float = b.x + cos(a) * k.r
			var sy: float = b.y + sin(a) * k.r
			Sim.line_attack(state, b, sx, sy, a, k.range, 0.4, dmg, k.impact, "ARMS", cast, "rail", {"perfectCut": 0.5})
			if tgt.has("hit") and Sim.seg_dist(sx, sy, sx + cos(a) * k.range, sy + sin(a) * k.range, tgt.x, tgt.y) <= tgt.r + 0.8:
				harm(state, tgt.hit, dmg, b)
		"salvo", "cannon":
			var n: int = k.get("shells", 1)
			for i in n:
				var ox: float = (Sim.rng(state) - 0.5) * 2.0 * k.get("spread", 0.0)
				var oy: float = (Sim.rng(state) - 0.5) * 2.0 * k.get("spread", 0.0)
				state.lobs.append({"kind": "shell", "owner": b.id, "sx": b.x, "sy": b.y, "x": tgt.x + ox, "y": tgt.y + oy, "t": k.delay, "T": k.delay, "r": k.splash, "dmg": dmg, "impact": k.impact, "cast": cast})


static func shoot(state, e: Dictionary, b: Dictionary, k: Dictionary, tgt: Dictionary) -> void:
	var a := atan2(tgt.y - b.y, tgt.x - b.x)
	var r: float = BOTS[e.kind].r + 0.2
	Sim.spawn_shot(state, b, Sim.next_cast(state), b.x + cos(a) * r, b.y + sin(a) * r, a, k.shot, scaled(e, k.dmg), k.get("impact", 0), "bolt")
	if BOTS[e.kind].get("fly", false):
		state.shots[-1].high = true


static func harm(state, s: Dictionary, dmg: float, b: Dictionary) -> void:
	s.hp = maxf(0.0, s.hp - dmg)
	state.fx.append({"k": "ping", "x": s.x + (b.x - s.x) * 0.2, "y": s.y + (b.y - s.y) * 0.2, "a": atan2(s.y - b.y, s.x - b.x), "t": 8})


static func blow(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary) -> void:
	var boom: Dictionary = k.boom
	var dmg := scaled(e, boom.dmg)
	var cast := Sim.next_cast(state)
	for t in Sim.near_foes(state, b, b.x, b.y, boom.r):
		Sim.hit(state, b, t, dmg, "LEGS", 1, atan2(b.y - t.y, b.x - t.x), cast)
	for g in sg.gates:
		if g.hp > 0 and Sim.hypot(g.x - b.x, g.y - b.y) <= boom.r + S.LANE_W / 2.0:
			harm(state, g, dmg, b)
	var c: Dictionary = sg.core
	if Sim.hypot(c.x - b.x, c.y - b.y) <= boom.r + c.r:
		harm(state, c, dmg, b)
	state.fx.append({"k": "boom", "x": b.x, "y": b.y, "r": boom.r, "big": false, "t": 22})
	e.blown = true
	b.armor.head = 0


static func shell_land(state, sg: Dictionary) -> void:
	for l in state.lobs:
		if l.t != 1 or state.mechs[l.owner].team == 0:
			continue
		for g in sg.gates:
			if g.hp > 0 and Sim.hypot(g.x - l.x, g.y - l.y) <= l.r + S.LANE_W / 2.0:
				g.hp = maxf(0.0, g.hp - l.dmg)
		var c: Dictionary = sg.core
		if Sim.hypot(c.x - l.x, c.y - l.y) <= l.r + c.r:
			c.hp = maxf(0.0, c.hp - l.dmg)


static func ram(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary) -> void:
	var tgt := target(state, sg, e, b, k)
	if e.mode == "roll":
		e.roll += 1
		b.buffs.bubble = 2
		b.buffs.bubbleHp = 1e9
		var dest := route(state, sg, e, b, k, {} if not tgt.has("hit") else tgt)
		if tgt.has("hit") and not outside(b, e.lane):
			dest = {"x": tgt.x, "y": tgt.y}
		var dx: float = dest.x - b.x
		var dy: float = dest.y - b.y
		var d: float = maxf(0.1, Sim.hypot(dx, dy))
		var sp: float = k.roll * MK[e.mk - 1].speed
		b.vx = dx / d * sp
		b.vy = dy / d * sp
		b.x += b.vx * Sim.DT
		b.y += b.vy * Sim.DT
		b.aim = atan2(dy, dx)
		var hit = null
		for t in Sim.foes(state, b.id):
			if Sim.hypot(t.x - b.x, t.y - b.y) <= Sim.rad(t) + k.r + 0.3:
				hit = t
				break
		var dmg := scaled(e, k.dmg)
		if hit != null:
			var hd: float = maxf(0.1, Sim.hypot(hit.x - b.x, hit.y - b.y))
			Sim.hit(state, b, hit, dmg, "LEGS", k.impact, atan2(b.y - hit.y, b.x - hit.x), Sim.next_cast(state))
			Sim.push(hit, (hit.x - b.x) / hd, (hit.y - b.y) / hd, k.push)
			unroll(e, b)
		elif tgt.has("hit") and tgt.hit.has("lane") and tgt.hit.hp > 0 and b.x * S.LANES[e.lane].dx + b.y * S.LANES[e.lane].dy <= S.RING_OUT + k.r + 0.6:
			harm(state, tgt.hit, dmg * k.gateK, b)
			unroll(e, b)
		elif Sim.hypot(sg.core.x - b.x, sg.core.y - b.y) <= sg.core.r + k.r + 0.6:
			harm(state, sg.core, dmg * k.gateK, b)
			unroll(e, b)
		elif e.roll >= k.rollTime:
			unroll(e, b)
		act(e, "roll")
		return
	b.buffs.bubble = 0
	e.roll += 1
	var inp := {"mx": 0.0, "my": 0.0}
	if e.roll < k.exposed:
		act(e, "hit" if b.stagger > 0 else "idle")
	elif e.roll < k.exposed + k.windup:
		act(e, "windup")
	else:
		e.mode = "roll"
		e.roll = 0
	Sim.move(state, b, inp)


static func unroll(e: Dictionary, b: Dictionary) -> void:
	e.mode = "open"
	e.roll = 0
	b.buffs.bubble = 0
	b.vx = 0.0
	b.vy = 0.0


static func look(state, kind: String) -> void:
	state.siege.wave.next_in = 1 << 30
	for i in 3:
		var e := spawn(state, kind, 0, (i - 1) * 2.5)
		for r in state.siege.enemies:
			var b = state.mechs[r.m]
			if r.id >= e.id - BOTS[kind].get("pack", 1) + 1 and r.id <= e.id and not BOTS[kind].has("vent"):
				var p := S.at(0, 44.0, r.side * 1.5)
				b.x = p.x
				b.y = p.y


static func spawn(state, kind: String, lane: int, side: float, mk := 1) -> Dictionary:
	var k: Dictionary = BOTS[kind]
	var e := {}
	for i in k.get("pack", 1):
		e = body(state, kind, lane, side + (i - (k.get("pack", 1) - 1) / 2.0) * 1.0, mk)
	return e


static func body(state, kind: String, lane: int, side: float, mk: int) -> Dictionary:
	var sg: Dictionary = state.siege
	var k: Dictionary = BOTS[kind]
	var p: Dictionary
	if k.get("fly", false):
		p = {"x": S.AIR[lane][0] + side * 0.6, "y": S.AIR[lane][1] - side * 0.6}
	elif k.get("vent", false):
		p = S.at(lane, S.VENTS[0] + side * 0.6, (1.0 if side >= 0 else -1.0) * (S.LANE_W / 2.0 - k.r - 0.1))
	else:
		p = S.at(lane, S.SPAWN, side)
	var slot: int = state.mechs.size()
	for i in range(sg.team, state.mechs.size()):
		if state.mechs[i].get("gone", false):
			slot = i
			break
	var b := Sim.make_mech(slot, Sim.DEFAULT_LOADOUT, 1, {"x": p.x, "y": p.y, "aim": atan2(-p.y, -p.x)})
	var rows := {}
	for s in Sim.DEFAULT_LOADOUT:
		rows[s] = Sim.CATALOG[s][Sim.DEFAULT_LOADOUT[s]]
	rows.legs = rows.legs.merged({"top": k.speed * MK[mk - 1].speed / Sim.MOVE.jammed, "poise": k.poise}, true)
	b.rows = rows
	b.bot = kind
	b.r = k.r
	if k.get("fly", false):
		b.fly = true
	var hp: float = floor(k.hp * MK[mk - 1].hp)
	b.armor = {"head": hp, "rarm": 0, "larm": 0, "legs": 0}
	b.max = b.armor.duplicate()
	if slot == state.mechs.size():
		state.mechs.append(b)
	else:
		state.mechs[slot] = b
	var e := {"id": sg.next, "kind": kind, "lane": lane, "x": p.x, "y": p.y, "face": b.aim, "hp": hp, "max": hp, "act": "walk", "t": 0, "mk": mk,
		"m": slot, "side": clampf(side, -3.0, 3.0), "cd": 0, "cd2": 0, "wind": 0, "aim": b.aim, "juke": 0, "jx": 0.0, "jy": 0.0, "seen": -1,
		"rooted": 0, "dash": 0, "bit": false, "prey": -1, "mode": "roll" if kind == "jugg" else "", "roll": 0, "blown": false}
	sg.next += 1
	sg.enemies.append(e)
	return e


static func settle(state, sg: Dictionary) -> void:
	var keep := []
	for e in sg.enemies:
		var b = state.mechs[e.m]
		if e.act != "die" and b.armor.head <= 0:
			b.ko = true
			b.vx = 0.0
			b.vy = 0.0
			e.prey = -1
			if not e.blown:
				var gain := int(ceil(BOTS[e.kind].cost * RUN.scrap / float(BOTS[e.kind].get("pack", 1))))
				sg.scrap += gain
				state.fx.append({"k": "scrap", "x": b.x, "y": b.y, "n": gain, "t": 40})
			act(e, "die")
		elif e.act == "die":
			e.t += 1
		e.x = b.x
		e.y = b.y
		e.face = b.aim
		e.hp = maxf(0, b.armor.head)
		if e.act == "die" and e.t > RUN.corpse:
			b.gone = true
		else:
			keep.append(e)
	sg.enemies = keep
	for i in sg.team:
		var m = state.mechs[i]
		if not m.ko and m.armor.head <= 0:
			m.ko = true
			m.act = null
			m.vx = 0.0
			m.vy = 0.0
			m.pull = null
			sg.down[i] = RUN.respawn + RUN.respawnWave * sg.wave.n
			state.fx.append({"k": "ko", "id": i, "x": m.x, "y": m.y, "t": Sim.MATCH.ko})
		elif m.ko and sg.down.has(i):
			sg.down[i] -= 1
			if sg.down[i] <= 0:
				sg.down.erase(i)
				var fresh := Sim.make_mech(i, m.loadout, 0, {"x": 0, "y": 0, "aim": 0})
				fresh.held = m.held
				place(fresh, i)
				state.mechs[i] = fresh
	repair(state, sg)
	rings(state, sg)


static func repair(state, sg: Dictionary) -> void:
	var c: Dictionary = sg.core
	c.repairing = false
	for i in sg.team:
		var m = state.mechs[i]
		var armor := Sim.total_armor(m)
		var calm: int = sg.calm.get(i, 0)
		if m.ko or m.act != null or armor < sg.was.get(i, armor) or Sim.hypot(m.x - c.x, m.y - c.y) > S.CORE.repair:
			calm = 0
		else:
			calm += 1
		sg.calm[i] = calm
		sg.was[i] = armor
		if calm >= RUN.repairDelay:
			var cap: float = c.max * (4 - c.broken) / 4.0
			if c.hp < cap:
				c.hp = minf(cap, c.hp + RUN.repair)
				c.repairing = true


static func rings(state, sg: Dictionary) -> void:
	var c: Dictionary = sg.core
	var q: float = c.max / 4.0
	var broken := maxi(c.broken, 4 - ceili(c.hp / q))
	for i in range(c.broken, broken):
		state.fx.append({"k": "ring", "i": i, "x": c.x, "y": c.y, "t": 60})
	c.broken = broken
	for i in 4:
		c.rings[i] = 0.0 if i < broken else clampf(c.hp - (3 - i) * q, 0.0, q)
	if c.hp <= 0 and not sg.lost:
		sg.lost = true
		state.phase = "over"
		state.fx.append({"k": "coreDown", "x": c.x, "y": c.y, "t": 120})


static func direct(state, sg: Dictionary) -> void:
	var w: Dictionary = sg.wave
	if w.next_in > 0:
		w.next_in -= 1
		if w.next_in == RUN.warn:
			plan(state, sg, w.n + 1)
		if w.next_in == 0:
			w.n += 1
			w.live = true
			w.next_in = RUN.cap
	var queue := []
	for q in sg.queue:
		if q.at <= state.tick:
			spawn(state, q.kind, q.lane, q.side)
		else:
			queue.append(q)
	sg.queue = queue
	if w.live and queue.is_empty() and sg.enemies.filter(func(e): return e.act != "die").is_empty() and w.next_in > RUN.warn:
		w.live = false
		w.lanes_open = [false, false, false, false]
		w.next_in = mini(w.next_in, RUN.build)


static func plan(state, sg: Dictionary, n: int) -> void:
	var points := budget(n, sg.team)
	var lanes := []
	var want := 1 if n < 3 else (2 if n < 6 else (3 if n < 7 else 4))
	var pick := [0, 1, 2, 3]
	while lanes.size() < want:
		lanes.append(pick.pop_at(int(floor(Sim.rng(state) * pick.size()))))
	var start: int = state.tick + RUN.warn
	var at := []
	for lane in lanes:
		at.append(start)
		sg.wave.lanes_open[lane] = true
		state.fx.append({"k": "warn", "lane": lane, "kind": "scout", "t": RUN.warn})
	var i := 0
	while points >= BOTS.scout.cost:
		var lane: int = i % lanes.size()
		var side := (Sim.rng(state) - 0.5) * 6.0
		sg.queue.append({"at": at[lane], "kind": "scout", "lane": lanes[lane], "side": side})
		at[lane] += RUN.gap
		points -= BOTS.scout.cost
		i += 1
