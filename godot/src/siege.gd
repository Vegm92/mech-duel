extends RefCounted

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const S = preload("res://src/siege_state.gd")

const RUN := {
	"first": 10 * Sim.TICKS, "build": 25 * Sim.TICKS, "warn": 8 * Sim.TICKS, "cap": 90 * Sim.TICKS, "gap": 30,
	"respawn": 8 * Sim.TICKS, "respawnWave": 30, "repairDelay": Sim.TICKS, "repair": 25.0 / Sim.TICKS,
	"scrap": 5, "aggro": 6.0, "post": 21.0, "leash": 14.0, "corpse": 90, "spawnRing": 7.0, "players": 0.4, "frame": 24.0,
}
const BOTS := {
	"scout": {"cost": 1, "hp": 60, "speed": 7.5, "poise": 1, "range": 12.0, "dmg": 10, "impact": 0, "cd": 60, "windup": 12, "shot": {"speed": 30, "radius": 0.25, "range": 14}, "dodge": 0.35},
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
	Sim.world(state)
	var live := []
	for m in state.mechs:
		if not m.ko:
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
	var inp := {"mx": 0.0, "my": 0.0}
	var tgt := target(state, sg, e, b, k)
	var dest := route(sg, e, b, k)
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
		var threat = Bot.incoming(state, b)
		if threat != null and threat.s.cast != e.seen:
			e.seen = threat.s.cast
			if Sim.rng(state) < k.dodge:
				var sp := Sim.hypot(threat.s.vx, threat.s.vy)
				var side := 1.0 if (b.x - threat.s.x) * -threat.s.vy + (b.y - threat.s.y) * threat.s.vx > 0 else -1.0
				e.jx = -threat.s.vy / sp * side
				e.jy = threat.s.vx / sp * side
				e.juke = 12
	var busy: bool = b.stagger > 0 or b.buffs.root > 0
	if tgt.is_empty() or busy:
		e.wind = 0
	else:
		b.aim = atan2(tgt.y - b.y, tgt.x - b.x)
		var reach: float = Sim.hypot(tgt.x - b.x, tgt.y - b.y) - tgt.r
		if reach <= k.range:
			inp.mx = 0.0
			inp.my = 0.0
			if e.wind > 0:
				e.wind -= 1
				if e.wind == 0:
					fire(state, e, b, k, tgt)
			elif e.cd == 0:
				e.wind = k.windup
	Sim.move(state, b, inp)
	var v := Sim.hypot(b.vx, b.vy)
	if v > 0.5 and e.wind == 0:
		b.aim = atan2(b.vy, b.vx)
	act(e, "hit" if busy else ("windup" if e.wind > 0 else ("attack" if e.cd > k.cd - 10 else ("walk" if v > 0.5 else "idle"))))


static func act(e: Dictionary, a: String) -> void:
	if e.act != a:
		e.act = a
		e.t = 0
	else:
		e.t += 1


static func target(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary) -> Dictionary:
	var near = null
	for i in sg.team:
		var m = state.mechs[i]
		if m.ko or Sim.hidden(state, m):
			continue
		var d := Sim.hypot(m.x - b.x, m.y - b.y)
		if d <= RUN.aggro and (near == null or d < Sim.hypot(near.x - b.x, near.y - b.y)):
			near = m
	if near != null:
		return {"x": near.x, "y": near.y, "r": Sim.MECH_R}
	var g: Dictionary = sg.gates[e.lane]
	if g.hp > 0 and outside(b, e.lane):
		return {"x": g.x, "y": g.y, "r": 0.8}
	var c: Dictionary = sg.core
	return {"x": c.x, "y": c.y, "r": c.r}


static func outside(b: Dictionary, lane: int) -> bool:
	var l: Dictionary = S.LANES[lane]
	return b.x * l.dx + b.y * l.dy > S.RING_OUT


static func route(sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary) -> Dictionary:
	if outside(b, e.lane):
		if sg.gates[e.lane].hp > 0:
			return S.at(e.lane, S.RING_OUT + k.range * 0.8, e.side)
		return S.at(e.lane, S.RING_IN - 2.0, clampf(e.side, -3.0, 3.0))
	var c: Dictionary = sg.core
	var d := Sim.hypot(b.x - c.x, b.y - c.y)
	var want: float = c.r + k.range * 0.8
	if d <= want:
		return {"x": b.x, "y": b.y}
	return {"x": c.x + (b.x - c.x) / d * want, "y": c.y + (b.y - c.y) / d * want}


static func fire(state, e: Dictionary, b: Dictionary, k: Dictionary, tgt: Dictionary) -> void:
	e.cd = k.cd
	var a := atan2(tgt.y - b.y, tgt.x - b.x)
	Sim.spawn_shot(state, b, Sim.next_cast(state), b.x + cos(a) * 0.9, b.y + sin(a) * 0.9, a, k.shot, k.dmg, k.impact, "bolt")


static func spawn(state, kind: String, lane: int, side: float) -> Dictionary:
	var sg: Dictionary = state.siege
	var k: Dictionary = BOTS[kind]
	var p := S.at(lane, S.SPAWN, side)
	var l: Dictionary = S.LANES[lane]
	var slot: int = state.mechs.size()
	for i in range(sg.team, state.mechs.size()):
		if state.mechs[i].get("gone", false):
			slot = i
			break
	var b := Sim.make_mech(slot, Sim.DEFAULT_LOADOUT, 1, {"x": p.x, "y": p.y, "aim": atan2(-l.dy, -l.dx)})
	var rows := {}
	for s in Sim.DEFAULT_LOADOUT:
		rows[s] = Sim.CATALOG[s][Sim.DEFAULT_LOADOUT[s]]
	rows.legs = rows.legs.merged({"top": k.speed / Sim.MOVE.jammed, "poise": k.poise}, true)
	b.rows = rows
	b.bot = kind
	b.armor = {"head": k.hp, "rarm": 0, "larm": 0, "legs": 0}
	b.max = b.armor.duplicate()
	if slot == state.mechs.size():
		state.mechs.append(b)
	else:
		state.mechs[slot] = b
	var e := {"id": sg.next, "kind": kind, "lane": lane, "x": p.x, "y": p.y, "face": b.aim, "hp": k.hp, "max": k.hp, "act": "walk", "t": 0, "mk": 1,
		"m": slot, "side": side, "cd": 0, "wind": 0, "juke": 0, "jx": 0.0, "jy": 0.0, "seen": -1}
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
			sg.scrap += BOTS[e.kind].cost * RUN.scrap
			state.fx.append({"k": "scrap", "x": b.x, "y": b.y, "n": BOTS[e.kind].cost * RUN.scrap, "t": 40})
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
