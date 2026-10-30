extends RefCounted

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const S = preload("res://src/siege_state.gd")

const RUN := {
	"first": 10 * Sim.TICKS, "build": 25 * Sim.TICKS, "warn": 8 * Sim.TICKS, "cap": 90 * Sim.TICKS, "gap": 30,
	"respawn": 8 * Sim.TICKS, "respawnWave": 30, "repairDelay": Sim.TICKS, "repair": 25.0 / Sim.TICKS,
	"buildLate": 15 * Sim.TICKS, "gateSoak": 0.5, "late": 20, "ranged": 5 * Sim.TICKS, "call": 2, "clear": 0.2,
	"scrap": 5, "aggro": 6.0, "post": 21.0, "leash": 14.0, "corpse": 90, "spawnRing": 7.0, "players": 0.4,
}
const MODULE := {"pad": 4.0, "gate": 4.5, "wall": {"hp": 800, "depth": 1.0, "len": 6.0}, "mine": {"n": 4, "spread": 2.5, "dmg": 60, "arm": 30},
	"laser": {"every": 180, "warn": 60, "dmg": 80, "half": 0.6}, "post": {"dmg": 120, "cd": 240, "reach": 2.0, "range": 40.0, "half": 0.5},
	"turret": {"cost": 180, "hp": 600, "depth": 1.6, "len": 1.6, "range": 22.0, "dmg": 6, "every": 12, "muzzle": 2.5}}
const SHOP := {"gate": 40, "rebuild": 120, "ring": 200, "wall": 60, "mine": 80, "laser": 150, "post": 120, "turret": MODULE.turret.cost, "garrison": 0}
const WHEEL := {"square": ["wall", "mine", "laser", "post", "turret"], "gate": ["gate", "rebuild"], "plaza": ["ring", "garrison"]}
const WALLET := {"kit": 40, "coolant": 20, "surge": 60, "reinforce": 100, "revive": 50}
const TIER := {
	"base": {"left": 40, "right": 40, "head": 35, "arms": 35, "legs": 35, "booster": 30, "core": 45},
	"hand": {"dmg": 0.25, "cd": -0.06}, "head": {"armor": 0.15, "surge": 0.08}, "arms": {"armor": 0.15, "handling": -0.04},
	"legs": {"armor": 0.15, "top": 0.05}, "booster": {"dashCd": -0.1}, "core": {"surgeGain": 0.15, "dmg": 0.06},
	"wallet": 120, "surge": 50,
}
const AI_SHOP := {"order": ["left", "right", "arms", "head", "legs", "booster", "core"], "recallAt": 0.35, "kitAt": 0.6, "rich": 300}
const SWAP := {"light": 60, "standard": 150, "heavy": 300, "loads": [14, 18]}
const YARD := {"wake": 8.0, "leash": 18.0, "wakeTime": 30, "elite": 5, "raidFrom": 15, "raid": ["scoutPack", "ambush"],
	"reinforce": 1.15, "crush": {"every": 360, "warn": 60, "dmg": 60}, "emp": {"every": 480, "on": 120, "tick": 30, "dmg": 10, "slow": 40},
	"farmLeash": 22.0, "raidAt": [72.0, 48.0]}
const SQUADS := {
	"scoutPack": [["scout", 4]], "swarmCloud": [["swarm", 2]], "raiders": [["scout", 2], ["flyer", 1]], "ambush": [["spider", 3]],
	"firebase": [["turret", 1], ["swarm", 2]], "airWing": [["flyer", 3]], "lineBreakers": [["walker", 2]], "ram": [["jugg", 1], ["scout", 3]],
	"sniperNest": [["tripod", 1], ["turret", 1], ["spider", 2]], "shieldWall": [["heavy", 1], ["turret", 2]],
	"barrage": [["quadheavy", 1], ["tripod", 1], ["swarm", 2]], "titanPush": [["heavy", 1], ["jugg", 1], ["walker", 1]],
}
const DIVISIONS := {
	"vanguard": ["scoutPack", "raiders", "ambush"], "swarm": ["swarmCloud", "firebase"], "air": ["airWing", "raiders"],
	"armor": ["lineBreakers", "shieldWall"], "siege": ["barrage", "sniperNest", "scoutPack"], "shock": ["ram", "titanPush"],
}
const WAVES := [
	{"lanes": 1, "pool": ["scoutPack"]},
	{"lanes": 1, "pool": ["scoutPack", "swarmCloud"]},
	{"lanes": 2, "pool": ["scoutPack", "swarmCloud"]},
	{"lanes": 2, "pool": ["scoutPack", "ambush"], "must": ["ambush"]},
	{"lanes": 2, "pool": ["ambush", "swarmCloud", "scoutPack"]},
	{"lanes": 3, "pool": ["raiders", "scoutPack", "ambush"], "must": ["raiders"]},
	{"lanes": 4, "pool": ["raiders", "ambush", "swarmCloud"]},
	{"lanes": 4, "pool": ["firebase", "scoutPack", "ambush"], "must": ["firebase"]},
	{"lanes": 4, "pool": ["lineBreakers", "firebase", "raiders"], "must": ["lineBreakers"]},
	{"lanes": 4, "pool": ["scoutPack", "swarmCloud"], "must": ["shieldWall"], "boss": true},
	{"lanes": 4, "pool": ["lineBreakers", "firebase", "ambush", "raiders"]},
	{"lanes": 4, "pool": ["lineBreakers", "firebase", "ambush", "raiders"], "must": ["sniperNest"]},
	{"lanes": 4, "pool": ["lineBreakers", "firebase", "sniperNest", "raiders"], "must": ["airWing"]},
	{"lanes": 4, "pool": ["lineBreakers", "firebase", "sniperNest", "airWing", "ambush"]},
	{"lanes": 4, "pool": ["scoutPack"], "must": ["ram"], "boss": true},
	{"lanes": 4, "pool": ["lineBreakers", "sniperNest", "airWing", "firebase", "shieldWall"]},
	{"lanes": 4, "pool": ["lineBreakers", "sniperNest", "airWing", "firebase"], "must": ["barrage"]},
	{"lanes": 4, "pool": ["lineBreakers", "sniperNest", "airWing", "barrage", "shieldWall"]},
	{"lanes": 4, "pool": ["lineBreakers", "sniperNest", "airWing", "barrage", "shieldWall", "ram"]},
	{"lanes": 4, "pool": ["scoutPack", "swarmCloud"], "must": ["barrage", "barrage", "sniperNest"], "boss": true},
]
const LATE := {"lanes": 4, "pool": ["raiders", "ambush", "firebase", "airWing", "lineBreakers", "ram", "sniperNest", "shieldWall", "barrage", "titanPush"], "mk": 2}
const LAST := {"lanes": 4, "pool": [], "must": ["titanPush", "shieldWall", "shieldWall", "airWing", "barrage", "sniperNest", "ram", "lineBreakers", "ambush", "swarmCloud", "raiders"], "mk": 2, "boss": true}
const ENDLESS := {"lanes": 4, "pool": ["raiders", "ambush", "firebase", "airWing", "lineBreakers", "ram", "sniperNest", "shieldWall", "barrage", "titanPush"], "mk": 3}
const GARRISON := {
	"cost": [150, 400, 900, 2000, 4500], "leash": 14.0, "retreat": 0.3, "respawn": 20 * Sim.TICKS, "ult": 4,
	"tiers": [
		{"head": "rookie", "core": "furnace", "arms": "wire", "legs": "greaves", "booster": "flicker", "left": "rivet", "right": "bash", "lv": 1},
		{"head": "rookie", "core": "furnace", "arms": "brace", "legs": "treads", "booster": "flicker", "left": "rivet", "right": "bash", "lv": 2},
		{"head": "rookie", "core": "furnace", "arms": "brace", "legs": "treads", "booster": "thruster", "left": "rivet", "right": "gatling", "lv": 2},
		{"head": "rookie", "core": "reactor", "arms": "brace", "legs": "treads", "booster": "thruster", "left": "rivet", "right": "gatling", "lv": 3},
		{"head": "demon", "core": "aegis", "arms": "anvil", "legs": "stompers", "booster": "rocket", "left": "gatling", "right": "missiles", "lv": 3},
	],
}
const MILESTONES := [10, 20, 30]
const MUTATORS := ["overclock", "plated", "volatile", "airRaid", "hive", "ironRain"]
const MUTATE := {"first": 31, "every": 5, "speed": 1.15, "hp": 1.3, "boom": {"dmg": 30, "r": 2.0}, "rain": 3}
const DIRECTOR := {"every": Sim.TICKS, "window": 5, "core": 0.05, "gate": 0.1, "breach": 3.0, "w": [0.30, 0.25, 0.20, 0.15, 0.10],
	"speed": 15.0, "weights": [0.5, 0.3, 0.2], "swing": 15.0, "dial": 50.0, "budget": 0.15, "streak": 20.0, "teach": 3,
	"rise": 3, "riseCap": 10, "cap": 90, "rest": 15 * Sim.TICKS, "near": 8.0, "retry": 2 * Sim.TICKS, "call": 180}
const BEAT := [
	{"id": "warmup", "target": 40, "mult": 0.9, "tier": 0},
	{"id": "build", "target": 55, "mult": 1.0, "tier": 1},
	{"id": "peak", "target": 70, "mult": 1.1, "tier": 2},
	{"id": "breather", "target": 30, "mult": 0.7, "tier": 0},
	{"id": "push", "target": 85, "mult": 1.15, "tier": 2},
]
const TACTICS := {
	"probe": {"tier": 1, "from": 4, "team": 1, "need": [["scoutPack", "raiders"]], "probe": 20 * Sim.TICKS, "call": 0},
	"ambush": {"tier": 1, "from": 4, "team": 1, "need": [["ambush"]], "vent": 25 * Sim.TICKS, "call": 25 * Sim.TICKS},
	"pincer": {"tier": 1, "from": 6, "team": 1, "need": [], "pincer": true, "call": 0},
	"airdrop": {"tier": 2, "from": 7, "team": 1, "need": [["airWing", "raiders"]], "air": 20 * Sim.TICKS, "call": 20 * Sim.TICKS},
	"feint": {"tier": 2, "from": 8, "team": 1, "need": [], "feint": 15 * Sim.TICKS, "call": 15 * Sim.TICKS},
	"siege": {"tier": 2, "from": 12, "team": 1, "need": [["firebase", "sniperNest", "barrage", "shieldWall"]], "siege": 12 * Sim.TICKS, "call": 0},
	"hammer": {"tier": 3, "from": 15, "team": 2, "need": [["ambush"], ["airWing", "raiders"]], "pincer": true, "vent": 25 * Sim.TICKS, "air": 20 * Sim.TICKS, "call": 0},
}
const FILL := {"lane": 6, "mix": 3, "budget": 1.0}
const TANKS := ["heavy", "jugg", "walker"]
const RANGED := ["turret", "tripod", "quadheavy"]
const MK := [{"hp": 1.0, "dmg": 1.0, "speed": 1.0}, {"hp": 1.5, "dmg": 1.25, "speed": 1.0}, {"hp": 2.2, "dmg": 1.5, "speed": 1.1}]
const BOTS := {
	"scout": {"cost": 1, "hp": 40, "speed": 7.5, "r": 0.6, "poise": 1, "attack": "bolt", "range": 12.0, "dmg": 10, "impact": 0, "cd": 60, "windup": 12, "shot": {"speed": 30, "radius": 0.25, "range": 14}, "dodge": 0.35},
	"swarm": {"cost": 2, "pack": 3, "hp": 25, "speed": 6.5, "r": 0.4, "poise": 0, "attack": "bite", "range": 1.0, "dmg": 6, "impact": 0, "cd": 40, "windup": 8, "boom": {"dmg": 40, "r": 2.5}},
	"spider": {"cost": 2, "hp": 84, "speed": 6.5, "r": 0.7, "poise": 1, "attack": "lunge", "range": 4.5, "dmg": 25, "impact": 2, "cd": 90, "windup": 18, "lunge": 5.0, "hunt": 30.0, "vent": true},
	"flyer": {"cost": 3, "hp": 80, "speed": 7.0, "r": 0.6, "poise": 1, "attack": "bolt", "range": 10.0, "dmg": 10, "impact": 0, "cd": 40, "windup": 6, "shot": {"speed": 34, "radius": 0.25, "range": 12}, "fly": true, "first": "mech", "halt": false},
	"turret": {"cost": 4, "hp": 210, "speed": 3.5, "r": 1.0, "poise": 3, "attack": "bolt", "range": 22.0, "dmg": 24, "impact": 1, "cd": 90, "windup": 20, "shot": {"speed": 36, "radius": 0.35, "range": 24}, "plant": 45, "first": "mech"},
	"walker": {"cost": 5, "hp": 275, "speed": 4.0, "r": 1.2, "poise": 3, "attack": "claw", "range": 2.4, "dmg": 35, "impact": 2, "cd": 70, "windup": 16, "gun": {"range": 12.0, "dmg": 20, "cd": 80, "impact": 0, "shot": {"speed": 32, "radius": 0.3, "range": 14}}},
	"tripod": {"cost": 5, "hp": 155, "speed": 3.5, "r": 1.0, "poise": 2, "attack": "rail", "range": 34.0, "dmg": 90, "impact": 2, "cd": 180, "windup": 120, "lock": 30, "hunt": 40.0, "keep": 24.0, "first": "mech"},
	"quadheavy": {"cost": 8, "hp": 520, "speed": 3.0, "r": 1.5, "poise": 4, "attack": "salvo", "range": 45.0, "dmg": 35, "impact": 1, "cd": 300, "windup": 40, "shells": 4, "spread": 2.5, "splash": 2.0, "delay": 90, "first": "core"},
	"heavy": {"cost": 9, "hp": 750, "speed": 2.8, "r": 1.6, "poise": 5, "attack": "cannon", "range": 18.0, "dmg": 80, "impact": 3, "cd": 150, "windup": 30, "splash": 2.5, "delay": 30, "first": "mech"},
	"jugg": {"cost": 9, "hp": 650, "speed": 3.0, "r": 1.4, "poise": 5, "attack": "ram", "range": 2.4, "dmg": 120, "impact": 4, "cd": 0, "windup": 40, "roll": 11.0, "rollTime": 480, "exposed": 240, "push": 6.0, "gateK": 3},
}


static func budget(n: int, team: int) -> float:
	return (2.7 + 1.98 * n + 0.144 * n * n) * FILL.budget * (1 + RUN.players * (team - 1))


static func bodies(key: String) -> int:
	var n := 0
	for u in SQUADS[key]:
		n += u[1] * BOTS[u[0]].get("pack", 1)
	return n


static func kinds(chosen: Array) -> Array:
	var out := []
	for key in chosen:
		for u in SQUADS[key]:
			if not out.has(u[0]):
				out.append(u[0])
	return out


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
	var boxes := []
	var holes: Array = S.OPENINGS.map(func(o): return [o.d - o.half, o.d + o.half]) + [[h, h]]
	for lane in 4:
		for side in [-1, 1]:
			var r: float = S.BLOCK
			for hole in holes:
				if hole[0] > r:
					var a := S.at(lane, r, side * w)
					var z := S.at(lane, hole[0], side * (w + S.LANE_WALL))
					boxes.append(box(a.x, a.y, z.x, z.y))
				r = hole[1]
	for q in S.QUADS.size():
		var wp := S.yard_at(q, S.WRECK.a, S.WRECK.b)
		var wreck := {"x": wp.x, "y": wp.y, "r": S.WRECK.r}
		pillars.append(wreck)
		solids.append(wreck)
		for hp in S.HEAPS:
			var p := S.yard_at(q, hp.a, hp.b)
			var heap := {"x": p.x, "y": p.y, "r": hp.r}
			pillars.append(heap)
			solids.append(heap)
	var steam := []
	for q in S.QUADS.size():
		for st in S.STEAM:
			var p := S.yard_at(q, st.a, st.b)
			steam.append({"x": p.x, "y": p.y, "r": st.r})
	for g in sg.gates:
		boxes.append(g)
	var gaps := []
	for l in S.LANES:
		gaps.append({"dx": l.dx, "dy": l.dy})
	var arches := gaps.duplicate()
	for Q in S.QUADS:
		arches.append({"dx": Q.sx * Sim.Q, "dy": Q.sy * Sim.Q, "half": S.ARCH / 2.0})
	var rings := [{"r0": S.RING_IN, "r1": S.RING_OUT, "half": w, "gaps": gaps}, {"r0": S.BLOCK, "r1": S.YARD_IN, "half": w, "gaps": arches}]
	return {"walls": walls, "pillars": pillars, "solids": solids, "boxes": boxes, "rings": rings, "steam": steam}


static func box(xa: float, ya: float, xb: float, yb: float) -> Dictionary:
	return {"x0": minf(xa, xb), "y0": minf(ya, yb), "x1": maxf(xa, xb), "y1": maxf(ya, yb)}


static func gate_box(lane: int) -> Dictionary:
	var g := S.gate(lane)
	var l: Dictionary = S.LANES[lane]
	var half: float = S.LANE_W / 2.0
	var depth: float = (S.RING_OUT - S.RING_IN) / 2.0
	var a := box(g.x - l.dy * half - l.dx * depth, g.y + l.dx * half - l.dy * depth, g.x + l.dy * half + l.dx * depth, g.y - l.dx * half + l.dy * depth)
	return g.merged(a).merged({"only": 1, "soak": RUN.gateSoak})


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
	state.mechs.append(guard_body(state.mechs.size(), 1))
	state.mechs[-1].ko = true
	state.mechs[-1].absent = true
	var gates := []
	for lane in 4:
		gates.append(gate_box(lane))
	var core := {"x": 0.0, "y": 0.0, "r": S.CORE.r, "hp": float(S.CORE.hp), "max": S.CORE.hp, "rings": S.ring_hp(4), "repairing": false, "only": 1, "broken": 0}
	state.siege = {
		"tick": 0, "wave": {"n": 0, "next_in": RUN.first, "lanes_open": [false, false, false, false], "live": false},
		"core": core, "gates": gates, "pads": S.pads(), "enemies": [], "queue": [], "next": 0,
		"lost": false, "down": {}, "calm": {}, "was": {}, "team": loadouts.size(), "earned": 0, "mutators": [],
		"yards": S.yards(), "wallets": [], "tokens": [], "boost": [], "opening": {}, "raid": -1,
		"garrison": S.garrison(), "guard": loadouts.size(), "gbrain": Bot.create_brain(seed + 99), "buys": 0, "kills": 0,
		"director": {"on": true, "dial": 0.0, "strain": 0.0, "scores": [], "pressure": 0.0, "sum": 0.0, "samples": 0, "hist": [],
			"easy": 0, "hard": 0, "top": false, "pity": false, "tactic": "straight", "scored": 0, "log": {}},
	}
	state.siege.tiers = []
	state.siege.recall = []
	state.siege.shop_open = []
	state.siege.recall_cd = []
	state.siege.owned = []
	for i in loadouts.size():
		state.siege.wallets.append(TIER.wallet)
		state.siege.tokens.append(0)
		state.siege.boost.append(0)
		state.siege.tiers.append(S.tiers())
		state.siege.shop_open.append(false)
		state.siege.recall_cd.append(0)
		state.siege.owned.append(null)
	state.geo = geo_of(state.siege)
	for q in S.QUADS.size():
		for i in S.CAMPS.size():
			camp_up(state, q, i)
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
	state.hitstop = 0
	if state.phase == "over":
		return state
	for i in team:
		var m = state.mechs[i]
		if not m.ko:
			Sim.think(state, m, inputs[i] if i < inputs.size() and inputs[i] != null else Sim.IDLE)
	var gm = state.mechs[sg.guard]
	if not gm.ko:
		Sim.think(state, gm, guard_input(state, sg))
	for i in team:
		var inp = inputs[i] if i < inputs.size() and inputs[i] != null else Sim.IDLE
		if not state.mechs[i].ko:
			if inp.get("buy", "") != "":
				buy(state, sg, inp.buy, state.mechs[i])
			if inp.get("post", false):
				fire_post(state, sg, state.mechs[i])
			use(state, sg, i, inp.get("use", false))
		recall(state, sg, i, inp.get("recall", false))
		sg.shop_open[i] = inp.get("shop", false)
		if inp.get("call", false):
			call_wave(state, sg, i)
	modules(state, sg)
	hazards(state, sg)
	for e in sg.enemies:
		if e.act != "die":
			drive(state, sg, e, state.mechs[e.m])
	shell_land(state, sg)
	Sim.world(state)
	var live := []
	for m in state.mechs:
		if not m.ko and not m.get("fly", false) and not m.get("sleep", false):
			Sim.collide(m, 0.0, state.geo)
			live.append(m)
	for i in live.size():
		for j in range(i + 1, live.size()):
			Sim.separate(live[i], live[j])
	settle(state, sg)
	sense(state, sg)
	direct(state, sg)
	return state


static func ally_input(state, brain, id: int) -> Dictionary:
	var farmer: bool = brain.get("farm", id == 1 and state.siege.team >= 2)
	brain.lanes_only = not farmer
	var inp := Bot.bot_input(state, brain, id)
	var m = state.mechs[id]
	if m.ko:
		return inp
	var open := []
	for lane in 4:
		if state.siege.wave.lanes_open[lane]:
			open.append(lane)
	var sg: Dictionary = state.siege
	var c: Dictionary = sg.core
	var post := S.at(open[id % open.size()] if open.size() else id % 4, RUN.post)
	var leash: float = RUN.leash
	if Sim.foes(state, id).any(func(t): return Sim.hypot(t.x, t.y) < S.RING_OUT + 2.0):
		post = {"x": c.x, "y": c.y}
		leash = S.RING_OUT + 4.0
	var mend: bool = not sg.wave.live and c.hp < c.max * (4 - c.broken) / 4.0
	if mend or (not sg.wave.live and next_buy(sg, m) != ""):
		post = S.at(id % 4, S.CORE.repair - 1.5)
	var chore := chore_for(sg, m)
	if not chore.is_empty():
		post = chore.at
		mend = true
	var o = Bot.pick(state, brain, m)
	if farmer and not mend and not Sim.foes(state, id).any(func(t): return t.team == 1 and Sim.hypot(t.x, t.y) < S.RING_OUT + 2.0):
		var f := farm(state, sg, m, o, inp)
		ai_wallet(state, sg, m, f)
		return f
	var camp_bot: bool = o.team == 2 or o.team == m.team
	if mend or camp_bot or o.ko or o.team == m.team or Sim.hypot(o.x - post.x, o.y - post.y) > leash or not open_line(state, m.x, m.y, o.x, o.y):
		var dx: float = post.x - m.x
		var dy: float = post.y - m.y
		var d := Sim.hypot(dx, dy)
		inp.mx = dx / d if d > 1.5 else 0.0
		inp.my = dy / d if d > 1.5 else 0.0
		inp.dash = false
		if mend or camp_bot:
			for k in ["left", "right", "hook", "shield", "ult"]:
				inp[k] = false
	ai_wallet(state, sg, m, inp)
	if not chore.is_empty() and Sim.hypot(chore.at.x - m.x, chore.at.y - m.y) <= 2.0:
		inp.buy = chore.item
	elif not sg.wave.live and c.broken > 0 and sg.wallets[id] >= SHOP.ring:
		inp.buy = "ring"
	return inp


static func chore_for(sg: Dictionary, m: Dictionary) -> Dictionary:
	if sg.wave.live:
		return {}
	for item in ["rebuild", "gate"]:
		for g in sg.gates:
			if sg.wallets[m.id] >= SHOP[item] and (g.hp <= 0 if item == "rebuild" else g.hp > 0 and g.hp < g.max * 0.6):
				return {"item": item, "at": {"x": g.x, "y": g.y}}
	return {}


static func ai_wallet(state, sg: Dictionary, m: Dictionary, inp: Dictionary) -> void:
	var i: int = m.id
	var home: bool = Sim.hypot(m.x - sg.core.x, m.y - sg.core.y) <= S.PLAZA
	var hurt: bool = Sim.total_armor(m) < Sim.total_armor({"armor": m.max}) * AI_SHOP.recallAt
	if not home and (hurt or sg.wallets[i] > AI_SHOP.rich) and sg.recall_cd[i] == 0:
		inp.recall = true
		if sg.recall.any(func(c): return c.player == i):
			for k in ["mx", "my"]:
				inp[k] = 0.0
			for k in ["left", "right", "hook", "shield", "ult", "dash"]:
				inp[k] = false
		return
	if not home or sg.wave.live:
		return
	if Sim.total_armor(m) < Sim.total_armor({"armor": m.max}) * AI_SHOP.kitAt and sg.wallets[i] >= WALLET.kit:
		inp.buy = "kit"
		return
	var want := next_buy(sg, m)
	if want != "":
		inp.buy = want


static func next_buy(sg: Dictionary, m: Dictionary) -> String:
	var i: int = m.id
	var best := ""
	for slot in AI_SHOP.order:
		if sg.tiers[i][slot] < S.RUN_TIERS and (best == "" or sg.tiers[i][slot] < sg.tiers[i][best]):
			best = slot
	if best == "":
		return ""
	var price := price_of(sg, m, "tier:" + best)
	if price <= sg.wallets[i] and (sg.core.broken == 0 or sg.wallets[i] - price >= SHOP.ring):
		return "tier:" + best
	return ""


static func farm(state, sg: Dictionary, m: Dictionary, o, inp: Dictionary) -> Dictionary:
	var goal = null
	var hold := false
	if sg.wave.live or sg.wallets[m.id] < AI_SHOP.rich:
		for y in sg.yards:
			for c in y.camps:
				if c.alive and (goal == null or Sim.hypot(c.x - m.x, c.y - m.y) < Sim.hypot(goal.x - m.x, goal.y - m.y)):
					goal = c
		if goal == null:
			for y in sg.yards:
				for c in y.crates:
					if not c.taken and (goal == null or Sim.hypot(c.x - m.x, c.y - m.y) < Sim.hypot(goal.x - m.x, goal.y - m.y)):
						goal = c
						hold = true
	if goal == null:
		return inp
	var near: bool = Sim.hypot(goal.x - m.x, goal.y - m.y) < (1.2 if hold else YARD.wake + 4.0)
	var fight: bool = not o.ko and o.team != m.team and Sim.hypot(o.x - m.x, o.y - m.y) < 12.0 and open_line(state, m.x, m.y, o.x, o.y)
	if fight and not hold:
		return inp
	if near and hold:
		for k in ["mx", "my"]:
			inp[k] = 0.0
		for k in ["left", "right", "hook", "shield", "ult", "dash"]:
			inp[k] = false
		inp.use = true
		return inp
	if near:
		return inp
	var wp := waypoint(m, goal)
	var dx: float = wp.x - m.x
	var dy: float = wp.y - m.y
	var d: float = maxf(0.1, Sim.hypot(dx, dy))
	inp.mx = dx / d
	inp.my = dy / d
	inp.dash = false
	return inp


static func quad_of(p: Dictionary) -> int:
	for q in S.QUADS.size():
		if signf(p.x) == S.QUADS[q].sx and signf(p.y) == S.QUADS[q].sy:
			return q
	return 0


static func lane_near(p: Dictionary) -> int:
	if absf(p.y) >= absf(p.x):
		return 0 if p.y < 0 else 2
	return 1 if p.x > 0 else 3


static func in_lane(p: Dictionary) -> bool:
	return Sim.hypot(p.x, p.y) > S.BLOCK and minf(absf(p.x), absf(p.y)) < S.LANE_W / 2.0 + S.LANE_WALL


static func in_yard(p: Dictionary) -> bool:
	return Sim.hypot(p.x, p.y) > S.BLOCK and not in_lane(p)


static func dist(a: Dictionary, b: Dictionary) -> float:
	return Sim.hypot(a.x - b.x, a.y - b.y)


static func route_len(pts: Array) -> float:
	var t := 0.0
	for i in pts.size() - 1:
		t += dist(pts[i], pts[i + 1])
	return t


static func door_way(m: Dictionary, goal: Dictionary) -> Dictionary:
	var qb := quad_of(goal)
	var inner_b := S.yard_at(qb, 15.0, 15.0)
	var outer_b := S.yard_at(qb, 22.0, 22.0)
	var into := S.doors(qb)
	if in_lane(m):
		var lane := lane_near(m)
		var best := {}
		var best_len := route_len([m, S.at(lane, 21.0), inner_b, outer_b, goal])
		for d in into:
			var cost := route_len([m, d.lp, d.yp, goal])
			if d.lane == lane and cost < best_len:
				best = d
				best_len = cost
		if best.is_empty():
			return {}
		var perp: float = absf(m.x) if lane % 2 == 0 else absf(m.y)
		return best.yp if perp >= S.LANE_W / 2.0 - 0.5 or absf(along(m, lane) - best.d) < 1.2 else best.lp
	var qa := quad_of(m)
	var A: Dictionary = S.QUADS[qa]
	var B: Dictionary = S.QUADS[qb]
	if (A.sx == B.sx) == (A.sy == B.sy):
		return {}
	var shared := (1 if A.sx > 0 else 3) if A.sx == B.sx else (2 if A.sy > 0 else 0)
	var inner_a := S.yard_at(qa, 15.0, 15.0)
	var outer_a := S.yard_at(qa, 22.0, 22.0)
	var out := {}
	var out_len := route_len([m, outer_a, inner_a, inner_b, outer_b, goal])
	for da in S.doors(qa):
		for db in into:
			var cost := route_len([m, da.yp, da.lp, db.lp, db.yp, goal])
			if da.lane == shared and db.lane == shared and cost < out_len:
				out = da
				out_len = cost
	if out.is_empty():
		return {}
	var shared_perp: float = absf(m.x) if shared % 2 == 0 else absf(m.y)
	return out.lp if shared_perp < S.OPENING_YARD + 0.5 and absf(along(m, shared) - out.d) < 1.5 else out.yp


static func waypoint(m: Dictionary, goal: Dictionary) -> Dictionary:
	var rm := Sim.hypot(m.x, m.y)
	var rg := Sim.hypot(goal.x, goal.y)
	var yard_goal: bool = rg > S.YARD_IN and not in_lane(goal)
	var yard_me: bool = rm > S.YARD_IN - 0.5 and not in_lane(m)
	if yard_goal and yard_me and quad_of(m) == quad_of(goal):
		return goal
	if yard_goal and (yard_me or in_lane(m)):
		var door := door_way(m, goal)
		if not door.is_empty():
			return door
	var lined: bool = absf(absf(m.x) - absf(m.y)) < S.ARCH / 2.0
	if yard_me:
		var q := quad_of(m)
		return S.yard_at(q, 15.0, 15.0) if lined else S.yard_at(q, 22.0, 22.0)
	if in_lane(m):
		return S.at(lane_near(m), 21.0)
	if rm < (S.RING_IN + S.RING_OUT) / 2.0:
		if rg < S.RING_IN:
			return goal
		var lane := lane_near(goal)
		var side: float = absf(m.x) if lane % 2 == 0 else absf(m.y)
		return S.at(lane, 12.0) if side > 3.0 else S.at(lane, 21.0)
	if rg < S.RING_OUT:
		var lane := lane_near(m)
		var side: float = absf(m.x) if lane % 2 == 0 else absf(m.y)
		return S.at(lane, 12.0) if side < 3.0 else S.at(lane, 21.0)
	if yard_goal:
		var q := quad_of(goal)
		return S.yard_at(q, 22.0, 22.0) if lined and quad_of(m) == q else S.yard_at(q, 15.0, 15.0)
	return goal


static func drive(state, sg: Dictionary, e: Dictionary, b: Dictionary) -> void:
	var k: Dictionary = BOTS[e.kind]
	if e.neutral and not awake(state, sg, e, b):
		return
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
	if e.neutral and tgt.is_empty() and Sim.hypot(b.x - e.home.x, b.y - e.home.y) < 0.8:
		b.armor.head = b.max.head
		b.vx = 0.0
		b.vy = 0.0
		b.sleep = true
		act(e, "dormant")
		return
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
	if e.neutral:
		var prey = null
		for i in sg.team:
			var m = state.mechs[i]
			if not m.ko and not Sim.hidden(state, m) and Sim.hypot(m.x - e.home.x, m.y - e.home.y) <= YARD.leash and (prey == null or Sim.hypot(m.x - b.x, m.y - b.y) < Sim.hypot(prey.x - b.x, prey.y - b.y)):
				prey = m
		return {} if prey == null else {"x": prey.x, "y": prey.y, "r": Sim.rad(prey), "mech": prey}
	var reach: float = k.get("hunt", RUN.aggro if k.get("first", "") != "mech" else k.range)
	var near = null
	var nd := 0.0
	for i in sg.team + 1:
		var m = state.mechs[i]
		if m.ko or Sim.hidden(state, m) or (not k.get("fly", false) and in_yard(m) and not in_yard(b)):
			continue
		var d := Sim.hypot(m.x - b.x, m.y - b.y)
		if d <= reach and (near == null or d < nd) and (d <= RUN.aggro or k.get("fly", false) or open_line(state, b.x, b.y, m.x, m.y)):
			near = m
			nd = d
	if near != null:
		return {"x": near.x, "y": near.y, "r": Sim.rad(near), "mech": near}
	if outside(b, e.lane) and not k.get("fly", false) and k.get("first", "") != "core":
		var mine := along(b, e.lane)
		var wall = null
		for pd in sg.pads:
			if pd.lane == e.lane and pd.module in ["wall", "turret"] and pd.hp > 0 and along(pd, e.lane) < mine and (wall == null or along(pd, e.lane) > along(wall, e.lane)):
				wall = pd
		if wall != null:
			var half: float = MODULE[wall.module].depth / 2.0
			return {"x": wall.x, "y": wall.y, "r": half, "hit": wall, "face": along(wall, e.lane) + half, "side": 0.0 if wall.module == "turret" else e.side}
		var g: Dictionary = sg.gates[e.lane]
		if g.hp > 0:
			return {"x": g.x, "y": g.y, "r": (S.RING_OUT - S.RING_IN) / 2.0, "hit": g, "face": S.RING_OUT}
	var c: Dictionary = sg.core
	return {"x": c.x, "y": c.y, "r": c.r, "hit": c}


static func open_line(state, x0: float, y0: float, x1: float, y1: float) -> bool:
	var g: Dictionary = state.geo
	var n := int(ceil(Sim.hypot(x1 - x0, y1 - y0) / 2.0))
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


static func along(p: Dictionary, lane: int) -> float:
	var l: Dictionary = S.LANES[lane]
	return p.x * l.dx + p.y * l.dy


static func outside(b: Dictionary, lane: int) -> bool:
	return along(b, lane) > S.RING_OUT


static func route(state, sg: Dictionary, e: Dictionary, b: Dictionary, k: Dictionary, tgt: Dictionary) -> Dictionary:
	var stand: float = k.range * 0.8
	if e.neutral and (tgt.is_empty() or Sim.hypot(b.x - e.home.x, b.y - e.home.y) > YARD.leash):
		return e.home
	if e.raid >= 0 and not tgt.has("mech"):
		return raid_route(state, sg, e, b)
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
		if tgt.has("face"):
			return S.at(e.lane, tgt.face + (k.r + 0.1 if k.range < 5.0 else maxf(stand, k.r + 0.6)), tgt.get("side", e.side))
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
	s.hp = maxf(0.0, s.hp - dmg * s.get("soak", 1.0))
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
		for g in sg.gates + sg.pads:
			if g.get("hp", 0) > 0 and Sim.hypot(g.x - l.x, g.y - l.y) <= l.r + S.LANE_W / 2.0:
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
		var dest := route(state, sg, e, b, k, {} if tgt.has("mech") else tgt)
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
		elif tgt.has("face") and along(b, e.lane) <= tgt.face + k.r + 0.6:
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


static func spawn(state, kind: String, lane: int, side: float, mk := 1, at := {}, team := 1) -> Dictionary:
	var k: Dictionary = BOTS[kind]
	var e := {}
	for i in k.get("pack", 1):
		var off: float = (i - (k.get("pack", 1) - 1) / 2.0) * 1.0
		var p := {} if at.is_empty() else {"x": at.x + off, "y": at.y - off * 0.5}
		e = body(state, kind, lane, side + off, mk, p, team)
	return e


static func spot(kind: String, lane: int, side: float, at := {}) -> Dictionary:
	var k: Dictionary = BOTS[kind]
	if not at.is_empty():
		return at
	if k.get("fly", false):
		return {"x": S.AIR[lane][0] + side * 0.6, "y": S.AIR[lane][1] - side * 0.6}
	if k.get("vent", false):
		return S.at(lane, S.VENTS[0] + side * 0.6, (1.0 if side >= 0 else -1.0) * (S.LANE_W / 2.0 - k.r - 0.1))
	return S.at(lane, S.SPAWN, side)


static func crowded(state, sg: Dictionary, p: Dictionary) -> bool:
	for i in sg.team:
		var m = state.mechs[i]
		if not m.ko and Sim.hypot(m.x - p.x, m.y - p.y) < DIRECTOR.near:
			return true
	return false


static func body(state, kind: String, lane: int, side: float, mk: int, at := {}, team := 1) -> Dictionary:
	var sg: Dictionary = state.siege
	var k: Dictionary = BOTS[kind]
	var p := spot(kind, lane, side, at)
	var slot: int = state.mechs.size()
	for i in range(sg.team, state.mechs.size()):
		if state.mechs[i].get("gone", false):
			slot = i
			break
	var b := Sim.make_mech(slot, Sim.DEFAULT_LOADOUT, team, {"x": p.x, "y": p.y, "aim": atan2(-p.y, -p.x)})
	var rows := {}
	for s in Sim.DEFAULT_LOADOUT:
		rows[s] = Sim.CATALOG[s][Sim.DEFAULT_LOADOUT[s]]
	var fast: float = MUTATE.speed if sg.mutators.has("overclock") else 1.0
	rows.legs = rows.legs.merged({"top": k.speed * MK[mk - 1].speed * fast / Sim.MOVE.jammed, "poise": k.poise}, true)
	b.rows = rows
	b.bot = kind
	b.by = -1
	b.r = k.r
	if k.get("fly", false):
		b.fly = true
	var hp: float = floor(k.hp * MK[mk - 1].hp * (MUTATE.hp if sg.mutators.has("plated") else 1.0))
	b.armor = {"head": hp, "rarm": 0, "larm": 0, "legs": 0}
	b.max = b.armor.duplicate()
	if slot == state.mechs.size():
		state.mechs.append(b)
	else:
		state.mechs[slot] = b
	var e := {"id": sg.next, "kind": kind, "lane": lane, "x": p.x, "y": p.y, "face": b.aim, "hp": hp, "max": hp, "act": "walk", "t": 0, "mk": mk,
		"m": slot, "side": clampf(side, -3.0, 3.0), "cd": 0, "cd2": 0, "wind": 0, "aim": b.aim, "juke": 0, "jx": 0.0, "jy": 0.0, "seen": -1,
		"rooted": 0, "dash": 0, "bit": false, "prey": -1, "mode": "roll" if kind == "jugg" else "", "roll": 0, "blown": false,
		"neutral": team == 2, "camp": -1, "home": {"x": p.x, "y": p.y}, "raid": -1, "leg": 0}
	sg.next += 1
	sg.enemies.append(e)
	return e


static func payee(sg: Dictionary, by: int) -> int:
	if by == sg.guard:
		return sg.garrison.buyer
	return by if by >= 0 and by < sg.team else -1


static func settle(state, sg: Dictionary) -> void:
	var keep := []
	for e in sg.enemies:
		var b = state.mechs[e.m]
		if e.act != "die" and b.armor.head <= 0:
			b.ko = true
			b.vx = 0.0
			b.vy = 0.0
			e.prey = -1
			if sg.mutators.has("volatile") and not e.blown:
				blow(state, sg, e, b, {"boom": MUTATE.boom})
				e.blown = false
			if e.neutral:
				act(e, "die")
				camp_down(state, sg, e)
			elif not e.blown:
				var gain := int(ceil(BOTS[e.kind].cost * RUN.scrap / float(BOTS[e.kind].get("pack", 1))))
				var to := payee(sg, b.by)
				sg.earned += gain
				sg.kills += 1
				if to >= 0:
					sg.wallets[to] += gain
					state.fx.append({"k": "scrap", "id": to, "x": b.x, "y": b.y, "n": gain, "t": 40})
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
				outfit(fresh, sg.tiers[i], sg.boost[i])
	guard_settle(state, sg)
	repair(state, sg)
	rings(state, sg)
	for y in sg.yards:
		for c in y.camps:
			c.respawn_in = 0 if c.alive else sg.wave.next_in
	raided(sg)


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
			sg.earned = 0
			sg.director.sum = 0.0
			sg.director.samples = 0
			refill(state, sg, w.n)
			for pd in sg.pads:
				if pd.module == "mine":
					arm(state, pd)
	var queue := []
	for q in sg.queue:
		if q.at > state.tick:
			queue.append(q)
			continue
		if q.has("fx"):
			state.fx.append(q.fx.duplicate())
			if q.fx.k == "warn":
				w.lanes_open[q.fx.lane] = true
			continue
		var at := {} if q.get("raid", -1) < 0 else S.yard_at(q.raid, YARD.raidAt[0] + q.side, YARD.raidAt[1])
		if BOTS[q.kind].get("vent", false) and crowded(state, sg, spot(q.kind, q.lane, q.side, at)):
			q.side = -q.side if q.side != 0.0 else -0.01
		if crowded(state, sg, spot(q.kind, q.lane, q.side, at)):
			q.at = state.tick + DIRECTOR.retry
			queue.append(q)
			continue
		var e := spawn(state, q.kind, q.lane, q.side, q.get("mk", 1), at)
		if q.get("raid", -1) >= 0:
			for r in sg.enemies:
				if r.kind == q.kind and r.id > e.id - BOTS[q.kind].get("pack", 1):
					r.raid = q.raid
	sg.queue = queue
	if w.live and queue.is_empty() and sg.enemies.filter(func(e): return e.act != "die" and not e.neutral).is_empty() and w.next_in > RUN.warn:
		w.live = false
		w.lanes_open = [false, false, false, false]
		var rest := 0
		if sg.director.on and w.n > DIRECTOR.teach and beat(w.n).id == "breather":
			rest = DIRECTOR.rest
			state.fx.append({"k": "tactic", "id": "breather", "lanes": [], "t": DIRECTOR.call})
		if sg.director.scored < w.n:
			score(sg, w.n, RUN.cap - w.next_in)
		w.next_in = mini(w.next_in, (RUN.build if w.n < RUN.late else RUN.buildLate) + rest)
		if w.n in MILESTONES:
			state.fx.append({"k": "milestone", "n": w.n, "t": 60})
		var c: Dictionary = sg.core
		if c.hp >= c.max * 0.75:
			var bonus := int(floor(sg.earned * RUN.clear))
			for i in sg.team:
				if not state.mechs[i].ko:
					sg.wallets[i] += bonus
			state.fx.append({"k": "cleared", "n": bonus, "t": 90})
		else:
			state.fx.append({"k": "cleared", "n": 0, "t": 90})


static func row(n: int) -> Dictionary:
	if n <= WAVES.size():
		return WAVES[n - 1]
	return LATE if n < 30 else (LAST if n == 30 else ENDLESS)


static func cost(squad: String) -> int:
	var c := 0
	for u in SQUADS[squad]:
		c += BOTS[u[0]].cost * u[1]
	return c


static func beat(n: int) -> Dictionary:
	return BEAT[(n - 1) % BEAT.size()]


static func aim_for(n: int) -> float:
	return minf(DIRECTOR.cap, beat(n).target + mini(DIRECTOR.riseCap, floori(n / float(DIRECTOR.rise))))


static func sense(state, sg: Dictionary) -> void:
	var dr: Dictionary = sg.director
	if not sg.wave.live:
		dr.hist = []
		return
	if sg.tick % DIRECTOR.every != 0:
		return
	var c: Dictionary = sg.core
	var gates: Array = sg.gates.map(func(g): return g.hp)
	dr.hist.append({"core": c.hp, "gates": gates})
	if dr.hist.size() > DIRECTOR.window + 1:
		dr.hist.pop_front()
	var old: Dictionary = dr.hist[0]
	var core := clampf((old.core - c.hp) / (DIRECTOR.core * c.max), 0.0, 1.0)
	var gate := 0.0
	for i in gates.size():
		gate = maxf(gate, (old.gates[i] - gates[i]) / (DIRECTOR.gate * sg.gates[i].max))
	var worn := 0.0
	var up := 0
	for i in sg.team:
		var m = state.mechs[i]
		if not m.ko:
			var top := 0.0
			for v in m.max.values():
				top += v
			worn += 1.0 - Sim.total_armor(m) / maxf(1.0, top)
			up += 1
	var breach := 0
	for e in sg.enemies:
		if not e.neutral and e.act != "die" and Sim.hypot(e.x, e.y) < S.RING_OUT:
			breach += 1
	var w: Array = DIRECTOR.w
	var mix: float = w[0] * core + w[1] * (worn / up if up > 0 else 1.0) + w[2] * (sg.team - up) / float(sg.team) + w[3] * minf(1.0, breach / DIRECTOR.breach) + w[4] * minf(1.0, gate)
	dr.pressure = 100.0 * clampf(mix, 0.0, 1.0)
	dr.sum += dr.pressure
	dr.samples += 1


static func score(sg: Dictionary, n: int, clear: int) -> void:
	var dr: Dictionary = sg.director
	var W: float = dr.sum / maxf(1.0, dr.samples)
	if clear >= 0:
		W -= DIRECTOR.speed * (1.0 - clear / float(RUN.cap))
	dr.scored = n
	dr.scores.push_front(W)
	dr.scores.resize(mini(dr.scores.size(), DIRECTOR.weights.size()))
	var raw := 0.0
	var wsum := 0.0
	for i in dr.scores.size():
		raw += DIRECTOR.weights[i] * dr.scores[i]
		wsum += DIRECTOR.weights[i]
	raw /= wsum
	dr.strain = raw if dr.scores.size() == 1 else clampf(raw, dr.strain - DIRECTOR.swing, dr.strain + DIRECTOR.swing)
	var gap: float = aim_for(n) - dr.strain
	if n > DIRECTOR.teach:
		dr.dial = clampf(dr.dial + gap / DIRECTOR.dial, -1.0, 1.0)
		dr.easy = dr.easy + 1 if gap > DIRECTOR.streak else 0
		dr.hard = dr.hard + 1 if gap < -DIRECTOR.streak else 0
		if dr.easy >= 2:
			dr.top = true
			dr.easy = 0
		if dr.hard >= 2:
			dr.pity = true
			dr.hard = 0
	if not dr.log.has(n):
		dr.log[n] = {"n": n}
	dr.log[n].merge({"P": dr.sum / maxf(1.0, dr.samples), "W": W, "S": dr.strain, "D": dr.dial}, true)


static func pick_tactic(state, sg: Dictionary, n: int, r: Dictionary, chosen: Array, pity: bool) -> String:
	var b := beat(n)
	var dr: Dictionary = sg.director
	if dr.get("force", "") != "":
		return dr.force
	if b.id == "breather" or pity:
		return "straight"
	var tier: int = clampi(b.tier + (1 if dr.dial > 0.5 else 0) - (1 if dr.dial < -0.5 else 0), 0, 3)
	if tier == 0:
		return "straight"
	var have: Array = r.pool + chosen
	var ok := []
	for id in TACTICS:
		var tac: Dictionary = TACTICS[id]
		if tac.tier <= tier and n >= tac.from and sg.team >= tac.team and tac.need.all(func(alt): return alt.any(func(q): return have.has(q))):
			ok.append(id)
	if ok.is_empty():
		return "straight"
	if dr.top:
		dr.top = false
		var hi: int = ok.map(func(id): return TACTICS[id].tier).max()
		ok = ok.filter(func(id): return TACTICS[id].tier == hi)
	return ok[int(floor(Sim.rng(state) * ok.size()))]


static func quiet_lane(state, sg: Dictionary, lanes: Array) -> int:
	var best: int = lanes[0]
	var fewest := 1 << 30
	for l in lanes:
		var near := 0
		for i in sg.team:
			if not state.mechs[i].ko and lane_near(state.mechs[i]) == l:
				near += 1
		if near < fewest:
			fewest = near
			best = l
	return best


static func plan(state, sg: Dictionary, n: int) -> void:
	var r := row(n)
	var dr: Dictionary = sg.director
	if sg.wave.live and dr.scored < sg.wave.n:
		score(sg, sg.wave.n, -1)
	var steer: bool = dr.on and n > DIRECTOR.teach
	var pity: bool = steer and dr.pity
	if steer:
		dr.pity = false
	var mult: float = beat(n).mult * (1.0 + DIRECTOR.budget * (-1.0 if pity else dr.dial)) if steer else 1.0
	var points := budget(n, sg.team) * mult
	var spend := points
	var pick := [0, 1, 2, 3]
	var lanes := []
	while lanes.size() < r.lanes:
		lanes.append(pick.pop_at(int(floor(Sim.rng(state) * pick.size()))))
	if n >= MUTATE.first and (n - MUTATE.first) % MUTATE.every == 0 and sg.mutators.size() < MUTATORS.size():
		var left: Array = MUTATORS.filter(func(x): return not sg.mutators.has(x))
		var picked: String = left[int(floor(Sim.rng(state) * left.size()))]
		sg.mutators.append(picked)
		state.fx.append({"k": "mutator", "id": picked, "t": 150})
	var chosen: Array = r.get("must", []).duplicate()
	for key in chosen:
		points -= cost(key)
	if sg.mutators.has("airRaid"):
		chosen.append("airWing")
	if sg.mutators.has("hive"):
		chosen.append_array(["swarmCloud", "swarmCloud"])
	if sg.mutators.has("ironRain") and n % MUTATE.rain == 0:
		chosen.append("barrage")
	var id := pick_tactic(state, sg, n, r, chosen, pity) if steer else "straight"
	var t: Dictionary = TACTICS.get(id, {})
	for alt in t.get("need", []):
		if not alt.any(func(q): return chosen.has(q)):
			var opts: Array = alt.filter(func(q): return r.pool.has(q))
			if not opts.is_empty():
				chosen.append(opts[0])
				points -= cost(opts[0])
	if t.has("pincer"):
		var pair := int(floor(Sim.rng(state) * 2))
		lanes = [pair, pair + 2]
	var feint := -1
	if t.has("feint"):
		feint = quiet_lane(state, sg, lanes)
		lanes = [lanes.filter(func(l): return l != feint)[0], feint]
	while true:
		var can: Array = r.pool.filter(func(q): return cost(q) <= points)
		if can.is_empty():
			break
		var key: String = can[int(floor(Sim.rng(state) * can.size()))]
		chosen.append(key)
		points -= cost(key)
	var have := 0
	for key in chosen:
		have += bodies(key)
	while have < FILL.lane * lanes.size() and not r.pool.is_empty():
		var key: String = r.pool[int(floor(Sim.rng(state) * r.pool.size()))]
		chosen.append(key)
		have += bodies(key)
	if n >= FILL.mix and kinds(chosen).size() < 2:
		var fresh: Array = r.pool.filter(func(q): return SQUADS[q].any(func(u): return not kinds(chosen).has(u[0])))
		if not fresh.is_empty():
			chosen.append(fresh[int(floor(Sim.rng(state) * fresh.size()))])
	var load := {}
	for lane in lanes:
		load[lane] = 0
	var total := 0
	for key in chosen:
		total += cost(key)
	var lane_of := []
	for key in chosen:
		var lane = lanes[0]
		if feint >= 0:
			lane = lanes[0] if load[lanes[0]] < total / 4.0 else feint
		else:
			for l in lanes:
				if load[l] < load[lane]:
					lane = l
		load[lane] += cost(key)
		lane_of.append(lane)
	var probe := -1
	if t.has("probe"):
		for i in chosen.size():
			if t.need[0].has(chosen[i]):
				probe = i
				break
	var busy: int = lanes[0]
	for l in lanes:
		if load[l] > load[busy]:
			busy = l
	var corner: int = (busy + 1) % 4 if load.get((busy + 1) % 4, 0) >= load.get((busy + 3) % 4, 0) else busy
	var groups := []
	for i in chosen.size():
		var d := 0
		if t.has("vent") and chosen[i] == "ambush":
			d = t.vent
		elif lane_of[i] == feint:
			d = t.feint
		elif probe >= 0 and i != probe and lane_of[i] == lane_of[probe]:
			d = t.probe
		for u in SQUADS[chosen[i]]:
			for j in u[1]:
				var kind: String = u[0]
				var g := {"warn": lane_of[i], "lane": lane_of[i], "d": d}
				if t.has("air") and BOTS[kind].get("fly", false):
					g = {"warn": busy, "lane": corner, "d": t.air}
				if t.has("siege"):
					g.d = 0 if kind in RANGED else t.siege
				var found = null
				for h in groups:
					if h.warn == g.warn and h.lane == g.lane and h.d == g.d:
						found = h
						break
				if found == null:
					g.list = []
					groups.append(g)
					found = g
				found.list.append(kind)
	var mk: int = r.get("mk", 1)
	var start: int = state.tick + RUN.warn
	if n >= YARD.raidFrom:
		var q := int(floor(Sim.rng(state) * S.QUADS.size()))
		var at := start
		for key in YARD.raid:
			for u in SQUADS[key]:
				for i in u[1]:
					sg.queue.append({"at": at, "kind": u[0], "lane": [0, 1, 2, 3][q], "side": (Sim.rng(state) - 0.5) * 4.0, "mk": mk, "raid": q})
					at += RUN.gap
		state.fx.append({"k": "raid", "q": q, "t": RUN.warn})
	for lane in lanes:
		for g in groups:
			if g.warn != lane:
				continue
			var list: Array = g.list
			list.sort_custom(func(a, b): return (0 if a in TANKS else (2 if a in RANGED else 1)) < (0 if b in TANKS else (2 if b in RANGED else 1)))
			var top: String = list[0]
			for kind in list:
				if BOTS[kind].cost > BOTS[top].cost:
					top = kind
			var warn := {"k": "warn", "lane": lane, "kind": top, "n": list.size(), "boss": r.get("boss", false), "t": RUN.warn}
			if g.d == 0:
				sg.wave.lanes_open[lane] = true
				state.fx.append(warn)
			else:
				sg.queue.append({"at": start + g.d - RUN.warn, "fx": warn})
			var at: int = start + g.d
			var w: int = at - RUN.warn
			var late: int = at + (0 if t.has("siege") else RUN.ranged)
			for kind in list:
				var side := (Sim.rng(state) - 0.5) * 6.0
				if kind in RANGED:
					sg.queue.append({"at": late, "kind": kind, "lane": g.lane, "side": side, "mk": mk, "w": w})
					late += RUN.gap
				else:
					sg.queue.append({"at": at, "kind": kind, "lane": g.lane, "side": side, "mk": mk, "w": w})
					at += RUN.gap
	if id != "straight":
		var fx := {"k": "tactic", "id": id, "lanes": [feint] if feint >= 0 else lanes.duplicate(), "t": DIRECTOR.call}
		if t.has("air"):
			fx.corner = corner
		sg.queue.append({"at": start + t.call, "fx": fx})
	dr.tactic = id
	dr.log[n] = {"n": n, "beat": beat(n).id, "target": aim_for(n), "tactic": id, "budget": snappedf(spend, 0.1)}


static func call_wave(state, sg: Dictionary, i := 0) -> void:
	var w: Dictionary = sg.wave
	if w.live or w.next_in <= RUN.warn + 1:
		return
	var bonus: int = RUN.call * int(ceil((w.next_in - RUN.warn) / float(Sim.TICKS)))
	sg.wallets[i] += bonus
	w.next_in = RUN.warn + 1
	state.fx.append({"k": "call", "n": bonus, "t": 60})


static func pad_at(sg: Dictionary, m: Dictionary, reach: float):
	for pd in sg.pads:
		if Sim.hypot(pd.x - m.x, pd.y - m.y) <= reach:
			return pd
	return null


static func gate_at(sg: Dictionary, m: Dictionary):
	for g in sg.gates:
		if Sim.hypot(g.x - m.x, g.y - m.y) <= MODULE.gate:
			return g
	return null


static func where(sg: Dictionary, m: Dictionary) -> String:
	if gate_at(sg, m) != null:
		return "gate"
	if Sim.hypot(m.x - sg.core.x, m.y - sg.core.y) <= S.PLAZA:
		return "plaza"
	return "square" if pad_at(sg, m, MODULE.pad) != null else ""


static func buy(state, sg: Dictionary, item: String, m: Dictionary) -> bool:
	if WALLET.has(item) or item.begins_with("tier:") or item.begins_with("swap:"):
		return spend(state, sg, item, m)
	if item == "garrison":
		return raise_guard(state, sg, m)
	if sg.wave.live or not SHOP.has(item) or sg.wallets[m.id] < SHOP[item]:
		return false
	var c: Dictionary = sg.core
	match item:
		"gate", "rebuild":
			var g = gate_at(sg, m)
			if g == null or (g.hp <= 0 if item == "gate" else g.hp > 0) or (item == "gate" and g.hp >= g.max):
				return false
			g.hp = minf(g.max, g.hp + g.max * 0.2) if item == "gate" else g.max * 0.5
		"ring":
			if c.broken == 0:
				return false
			c.broken -= 1
			c.hp = c.max * (4 - c.broken) / 4.0
		_:
			var pd = pad_at(sg, m, MODULE.pad)
			if pd == null or (pd.module != "" and not (pd.module == item and pd.get("hp", 1) <= 0)):
				return false
			build(state, pd, item, m.id)
	sg.wallets[m.id] -= SHOP[item]
	sg.buys += 1
	state.fx.append({"k": "build", "item": item, "x": m.x, "y": m.y, "t": 30})
	return true


static func spend(state, sg: Dictionary, item: String, m: Dictionary) -> bool:
	var i: int = m.id
	var price := price_of(sg, m, item)
	var token: bool = item == "reinforce" and sg.tokens[i] > 0
	if price < 0 or (not token and sg.wallets[i] < price):
		return false
	if item != "revive" and Sim.hypot(m.x - sg.core.x, m.y - sg.core.y) > S.PLAZA:
		return false
	var bits := item.split(":")
	match bits[0]:
		"tier":
			sg.tiers[i][bits[1]] += 1
			outfit(m, sg.tiers[i], sg.boost[i])
		"swap":
			m.loadout[bits[1]] = bits[2]
			var lv: Dictionary = m.loadout.get("lv", {})
			var n := owned_level(sg, i, bits[1], bits[2])
			if n > 1:
				lv[bits[1]] = n
			else:
				lv.erase(bits[1])
			if lv.is_empty():
				m.loadout.erase("lv")
			else:
				m.loadout.lv = lv
			outfit(m, sg.tiers[i], sg.boost[i])
		"kit":
			if Sim.total_armor(m) >= Sim.total_armor({"armor": m.max}):
				return false
			Sim.repair(m, 1e6)
		"coolant":
			if m.heat <= 0 and m.overheat <= 0:
				return false
			m.heat = 0.0
			m.overheat = 0
		"surge":
			if m.surge >= Sim.SURGE.max:
				return false
			m.surge = minf(Sim.SURGE.max, m.surge + TIER.surge)
		"reinforce":
			sg.boost[i] += 1
			outfit(m, sg.tiers[i], sg.boost[i])
		"revive":
			var down := -1
			for d in sg.down:
				if down < 0 or sg.down[d] > sg.down[down]:
					down = d
			if down < 0:
				return false
			sg.down[down] = 1
	if token:
		sg.tokens[i] -= 1
	else:
		sg.wallets[i] -= price
	sg.buys += 1
	state.fx.append({"k": "build", "item": item, "x": m.x, "y": m.y, "t": 30})
	return true


static func price_of(sg: Dictionary, m: Dictionary, item: String) -> int:
	var bits := item.split(":")
	match bits[0]:
		"tier":
			var t: int = sg.tiers[m.id].get(bits[1], S.RUN_TIERS)
			return -1 if t >= S.RUN_TIERS else TIER.base[bits[1]] * (t + 1) * (t + 1)
		"swap":
			if bits.size() != 3 or not Sim.CATALOG.has(bits[1]) or not Sim.CATALOG[bits[1]].has(bits[2]) or m.loadout[bits[1]] == bits[2] or owned_level(sg, m.id, bits[1], bits[2]) == 0:
				return -1
			return swap_price(bits[1], bits[2])
	return WALLET.get(item, -1)


static func swap_price(slot: String, key: String) -> int:
	var row: Dictionary = Sim.CATALOG[slot][key]
	if row.has("series"):
		return SWAP[row.series]
	var load: int = row.get("load", 0)
	return SWAP.light if load <= SWAP.loads[0] else (SWAP.standard if load <= SWAP.loads[1] else SWAP.heavy)


static func owned_level(sg: Dictionary, i: int, slot: String, key: String) -> int:
	var own = sg.owned[i]
	if own == null:
		return 1
	return own.get(slot, {}).get(key, 0)


static func outfit(m: Dictionary, tiers: Dictionary, boost: int) -> void:
	var lo: Dictionary = m.loadout
	var lv: Dictionary = lo.get("lv", {})
	var rows := {}
	for slot in Sim.DEFAULT_LOADOUT:
		var row := Sim.tuned(slot, lo[slot], lv.get(slot, 1)).duplicate()
		var t: int = tiers.get(slot, 0)
		var fx: Dictionary = TIER.hand if Sim.HANDS.has(slot) else TIER[slot]
		for key in fx:
			if key != "armor" and (row.has(key) or key in ["dmg", "surgeGain"]):
				row[key] = row.get(key, 1.0) * (1.0 + fx[key] * t)
		rows[slot] = row
	m.rows = rows
	var mx := Sim.max_armor(lo)
	var grow := {"head": tiers.head * TIER.head.armor, "rarm": tiers.arms * TIER.arms.armor, "larm": tiers.arms * TIER.arms.armor, "legs": tiers.legs * TIER.legs.armor}
	for p in mx:
		var full: float = floor(mx[p] * (1.0 + grow[p]) * pow(YARD.reinforce, boost))
		var frac: float = clampf(m.armor[p] / float(m.max[p]), 0.0, 1.0) if m.max[p] > 0 else 1.0
		m.max[p] = full
		m.armor[p] = floor(full * frac)


static func recall(state, sg: Dictionary, i: int, held: bool) -> void:
	var m = state.mechs[i]
	sg.recall_cd[i] = maxi(0, sg.recall_cd[i] - 1)
	var r = null
	for c in sg.recall:
		if c.player == i:
			r = c
	if r == null:
		if held and not m.ko and sg.recall_cd[i] == 0 and Sim.hypot(m.x - sg.core.x, m.y - sg.core.y) > S.PLAZA:
			sg.recall.append({"player": i, "t": 0, "max": S.RECALL.secs * Sim.TICKS, "x": m.x, "y": m.y, "armor": Sim.total_armor(m)})
		return
	if not held or m.ko or Sim.total_armor(m) < r.armor:
		sg.recall.erase(r)
		if held:
			sg.recall_cd[i] = Sim.TICKS / 2
		return
	r.t += 1
	r.x = m.x
	r.y = m.y
	if r.t < r.max:
		return
	sg.recall.erase(r)
	sg.recall_cd[i] = S.RECALL.cd * Sim.TICKS
	state.fx.append({"k": "recall", "id": i, "x": m.x, "y": m.y, "t": 30})
	place(m, i)
	m.vx = 0.0
	m.vy = 0.0
	m.act = null


static func guard_body(id: int, tier: int) -> Dictionary:
	var spec: Dictionary = GARRISON.tiers[tier - 1].duplicate()
	var lv := {}
	for slot in Sim.DEFAULT_LOADOUT:
		lv[slot] = spec.lv
	spec.lv = lv
	var g := Sim.make_mech(id, spec, 0, {"x": S.GARRISON_DOCK.x, "y": S.GARRISON_DOCK.y, "aim": S.GARRISON_DOCK.face})
	g.guard = tier
	return g


static func next_cost(sg: Dictionary) -> int:
	var t: int = sg.garrison.tier
	return GARRISON.cost[t] if t < GARRISON.cost.size() else -1


static func raise_guard(state, sg: Dictionary, m: Dictionary) -> bool:
	var price := next_cost(sg)
	if sg.wave.live or price < 0 or sg.wallets[m.id] < price:
		return false
	sg.wallets[m.id] -= price
	sg.garrison.buyer = m.id
	sg.buys += 1
	sg.garrison.tier += 1
	var g := guard_body(sg.guard, sg.garrison.tier)
	state.mechs[sg.guard] = g
	sg.garrison.respawn_in = 0
	mirror_guard(sg, g)
	state.fx.append({"k": "build", "item": "garrison", "x": g.x, "y": g.y, "t": 30})
	return true


static func mirror_guard(sg: Dictionary, g: Dictionary) -> void:
	var G: Dictionary = sg.garrison
	G.hp = maxf(0.0, g.armor.head)
	G.max = float(g.max.head)
	G.x = g.x
	G.y = g.y
	G.face = g.aim
	G.act = "die" if g.ko else ("attack" if g.act != null else ("walk" if Sim.hypot(g.vx, g.vy) > 0.5 else "idle"))


static func guard_settle(state, sg: Dictionary) -> void:
	var G: Dictionary = sg.garrison
	var g = state.mechs[sg.guard]
	if G.tier == 0:
		return
	if not g.ko and g.armor.head <= 0:
		g.ko = true
		g.act = null
		g.vx = 0.0
		g.vy = 0.0
		g.pull = null
		G.respawn_in = GARRISON.respawn * G.tier
		state.fx.append({"k": "ko", "id": sg.guard, "x": g.x, "y": g.y, "t": Sim.MATCH.ko})
	elif g.ko:
		G.respawn_in -= 1
		if G.respawn_in <= 0:
			g = guard_body(sg.guard, G.tier)
			state.mechs[sg.guard] = g
			G.respawn_in = 0
	mirror_guard(sg, g)


static func guard_input(state, sg: Dictionary) -> Dictionary:
	var id: int = sg.guard
	var g = state.mechs[id]
	var brain: Dictionary = sg.gbrain
	brain.lanes_only = true
	var inp := Bot.bot_input(state, brain, id)
	var dock: Dictionary = S.GARRISON_DOCK
	var o = Bot.pick(state, brain, g)
	var hurt: bool = g.armor.head < g.max.head * GARRISON.retreat
	var far: bool = o.ko or o.team != 1 or Sim.hypot(o.x, o.y) > GARRISON.leash + S.RING_OUT or not open_line(state, g.x, g.y, o.x, o.y)
	if hurt or far or Sim.hypot(g.x, g.y) > GARRISON.leash:
		var dx: float = dock.x - g.x
		var dy: float = dock.y - g.y
		var d := Sim.hypot(dx, dy)
		inp.mx = dx / d if d > 1.0 else 0.0
		inp.my = dy / d if d > 1.0 else 0.0
		inp.dash = false
		if hurt or o.team != 1:
			for k in ["left", "right", "hook", "ult"]:
				inp[k] = false
	if sg.garrison.tier < GARRISON.ult:
		inp.ult = false
	return inp


static func camp_up(state, q: int, i: int) -> void:
	var sg: Dictionary = state.siege
	var c: Dictionary = sg.yards[q].camps[i]
	var spec: Dictionary = S.CAMPS[i]
	var n := 0
	for u in spec.bots:
		for j in u[1]:
			var at := {"x": c.x + (n % 2) * 1.6 - 0.8 * mini(n, 1), "y": c.y + (n / 2) * 1.6}
			var e := spawn(state, u[0], q, 0.0, 1, at, 2)
			for r in sg.enemies:
				if r.neutral and r.camp < 0:
					r.camp = c.id
					r.home = {"x": state.mechs[r.m].x, "y": state.mechs[r.m].y}
					r.act = "dormant"
					state.mechs[r.m].sleep = true
			n += 1
	c.alive = true


static func camp_down(state, sg: Dictionary, e: Dictionary) -> void:
	if e.camp < 0:
		return
	var c: Dictionary = sg.yards[e.camp / S.CAMPS.size()].camps[e.camp % S.CAMPS.size()]
	if not c.alive or sg.enemies.any(func(r): return r.camp == e.camp and r.act != "die"):
		return
	c.alive = false
	if e.blown:
		return
	var best := payee(sg, state.mechs[e.m].by)
	if best < 0:
		return
	var t: Dictionary = S.CAMP_TIERS[c.tier]
	sg.wallets[best] += t.scrap
	sg.tokens[best] += t.get("token", 0)
	state.fx.append({"k": "loot", "id": best, "n": t.scrap, "x": c.x, "y": c.y, "t": 60})


static func refill(state, sg: Dictionary, n: int) -> void:
	for q in sg.yards.size():
		var y: Dictionary = sg.yards[q]
		for i in y.camps.size():
			if not y.camps[i].alive and (y.camps[i].tier != "elite" or (n - 1) % YARD.elite == 0):
				camp_up(state, q, i)
		for c in y.crates:
			c.taken = false
			c.progress = 0.0


static func use(state, sg: Dictionary, i: int, held: bool) -> void:
	var m = state.mechs[i]
	var still: bool = held and m.act == null and Sim.hypot(m.vx, m.vy) < 0.5
	var key = sg.opening.get(i)
	var crate = null
	if still:
		for y in sg.yards:
			for c in y.crates:
				if not c.taken and Sim.hypot(c.x - m.x, c.y - m.y) <= S.CRATE.reach:
					crate = c
	if crate == null:
		if key != null:
			key.progress = 0.0
			sg.opening.erase(i)
		return
	sg.opening[i] = crate
	crate.progress = minf(1.0, crate.progress + 1.0 / (S.CRATE.secs * Sim.TICKS))
	if crate.progress >= 1.0:
		crate.taken = true
		crate.progress = 0.0
		sg.opening.erase(i)
		sg.wallets[i] += S.CRATE.scrap
		state.fx.append({"k": "loot", "id": i, "n": S.CRATE.scrap, "x": crate.x, "y": crate.y, "t": 60})


static func unowned(m: Dictionary) -> void:
	if m.has("bot"):
		m.by = -1


static func hazards(state, sg: Dictionary) -> void:
	for q in S.QUADS.size():
		for h in S.YARD_HAZARDS:
			var p := S.yard_at(q, h.a, h.b)
			if h.kind == "crush":
				var C: Dictionary = YARD.crush
				var t: int = (state.tick + q * 90) % C.every
				if t == C.every - C.warn:
					state.fx.append({"k": "crushWarn", "x": p.x, "y": p.y, "t": C.warn})
				if t != 0:
					continue
				state.fx.append({"k": "crush", "x": p.x, "y": p.y, "t": 30})
				for m in state.mechs:
					if not m.ko and not m.get("fly", false) and absf(m.x - p.x) < h.half + Sim.rad(m) / 2.0 and absf(m.y - p.y) < h.half + Sim.rad(m) / 2.0:
						Sim.env_hit(state, m, C.dmg, "legs", 3, 0.0)
						unowned(m)
			else:
				var E: Dictionary = YARD.emp
				var t: int = (state.tick + q * 120) % E.every
				if t == 0:
					state.fx.append({"k": "vent", "x": p.x, "y": p.y, "r": h.r, "t": E.on})
				if t >= E.on or t % E.tick != 0:
					continue
				for m in state.mechs:
					if not m.ko and not m.get("fly", false) and Sim.hypot(m.x - p.x, m.y - p.y) < h.r + Sim.rad(m):
						Sim.env_hit(state, m, E.dmg, "legs", 0, 0.0)
						unowned(m)
						m.buffs.slow = maxi(m.buffs.slow, E.slow)


static func awake(state, sg: Dictionary, e: Dictionary, b: Dictionary) -> bool:
	if e.act == "dormant":
		b.vx = 0.0
		b.vy = 0.0
		var near := false
		for i in sg.team:
			var m = state.mechs[i]
			if not m.ko and not Sim.hidden(state, m) and Sim.hypot(m.x - b.x, m.y - b.y) <= YARD.wake:
				near = true
		if not near and b.armor.head >= b.max.head:
			e.t += 1
			return false
		for r in sg.enemies:
			if r.camp == e.camp and r.act == "dormant":
				act(r, "wake")
				state.mechs[r.m].sleep = false
		state.fx.append({"k": "wake", "x": b.x, "y": b.y, "t": 20})
		return false
	if e.act == "wake" and e.t < YARD.wakeTime:
		e.t += 1
		return false
	return true


static func raid_route(state, sg: Dictionary, e: Dictionary, b: Dictionary) -> Dictionary:
	var q: int = e.raid
	var y: Dictionary = sg.yards[q]
	if e.leg == 0:
		var next = null
		for c in y.camps:
			if c.alive and (next == null or Sim.hypot(c.x - b.x, c.y - b.y) < Sim.hypot(next.x - b.x, next.y - b.y)):
				next = c
		if next == null:
			e.leg = 1
		elif Sim.hypot(next.x - b.x, next.y - b.y) <= 3.5:
			wipe(state, sg, next)
		else:
			return next
	var outer := S.yard_at(q, 22.0, 22.0)
	var inner := S.yard_at(q, 15.0, 15.0)
	if e.leg == 1:
		var doors := S.doors(q)
		var door := -1
		var best := route_len([b, outer, inner, S.at(raid_lane(q, inner), S.RING_OUT + 6.0)])
		for i in doors.size():
			var cost := route_len([b, doors[i].yp, doors[i].lp, S.at(doors[i].lane, S.RING_OUT + 6.0)])
			if cost < best:
				door = i
				best = cost
		if door >= 0:
			e.door = door
			e.lane = doors[door].lane
			e.leg = 4
		elif Sim.hypot(outer.x - b.x, outer.y - b.y) < 1.5:
			e.leg = 2
		if e.leg == 1:
			return outer
	if e.leg == 4:
		var yp: Dictionary = S.doors(q)[e.door].yp
		if dist(yp, b) < 1.5:
			e.leg = 5
		return yp
	if e.leg == 5:
		var lp: Dictionary = S.doors(q)[e.door].lp
		if dist(lp, b) < 1.5:
			e.leg = 3
		return lp
	if e.leg == 2:
		if Sim.hypot(inner.x - b.x, inner.y - b.y) < 1.5:
			e.leg = 3
			e.lane = raid_lane(q, b)
		return inner
	var stand := S.at(e.lane, S.RING_OUT + 6.0, 0.0)
	if Sim.hypot(stand.x - b.x, stand.y - b.y) < 2.0:
		e.raid = -1
	return stand


static func raid_lane(q: int, b: Dictionary) -> int:
	var Q: Dictionary = S.QUADS[q]
	return 0 if (Q.sy < 0 and absf(b.y) >= absf(b.x)) else (1 if Q.sx > 0 and absf(b.x) > absf(b.y) else (2 if Q.sy > 0 and absf(b.y) >= absf(b.x) else 3))


static func raided(sg: Dictionary) -> void:
	for y in sg.yards:
		y.raided = 0.0
	for e in sg.enemies:
		if e.raid >= 0 and e.act != "die":
			var y: Dictionary = sg.yards[e.raid]
			y.raided = maxf(y.raided, 1.0 - y.camps.filter(func(c): return c.alive).size() / float(y.camps.size()) * 0.5)


static func wipe(state, sg: Dictionary, c: Dictionary) -> void:
	for r in sg.enemies:
		if r.camp == c.id and r.act != "die":
			r.blown = true
			state.mechs[r.m].armor.head = 0
	for y in sg.yards:
		for cr in y.crates:
			if Sim.hypot(cr.x - c.x, cr.y - c.y) < 16.0:
				cr.taken = true
	c.alive = false
	state.fx.append({"k": "boom", "x": c.x, "y": c.y, "r": 2.5, "big": true, "t": 22})


static func build(state, pd: Dictionary, item: String, owner := 0) -> void:
	pd.module = item
	pd.owner = owner
	match item:
		"wall", "turret":
			var W: Dictionary = MODULE[item]
			var d := along(pd, pd.lane)
			var half: float = W.depth / 2.0
			var a := S.at(pd.lane, d - half, -W.len / 2.0)
			var z := S.at(pd.lane, d + half, W.len / 2.0)
			pd.merge(box(a.x, a.y, z.x, z.y), true)
			pd.only = 1
			pd.hp = float(W.hp)
			pd.max = W.hp
			pd.cd = 0
			pd.aim = atan2(S.LANES[pd.lane].dy, S.LANES[pd.lane].dx)
			if not state.geo.boxes.has(pd):
				state.geo.boxes.append(pd)
		"mine":
			arm(state, pd)
		"laser":
			pd.t = 0
		"post":
			pd.cd = 0


static func arm(state, pd: Dictionary) -> void:
	var M: Dictionary = MODULE.mine
	state.mines = state.mines.filter(func(mi): return mi.get("pad", -1) != pd.x * 1000 + pd.y)
	for i in M.n:
		var p := S.at(pd.lane, along(pd, pd.lane), (i - (M.n - 1) / 2.0) * M.spread)
		state.mines.append({"owner": pd.get("owner", 0), "x": p.x, "y": p.y, "arm": M.arm, "life": 1 << 30, "dmg": M.dmg, "cast": Sim.next_cast(state), "pad": pd.x * 1000 + pd.y})


static func modules(state, sg: Dictionary) -> void:
	var L: Dictionary = MODULE.laser
	for pd in sg.pads:
		if pd.module == "post":
			pd.cd = maxi(0, pd.cd - 1)
		if pd.module == "turret" and pd.hp > 0:
			gun(state, sg, pd)
		if pd.module != "laser" or not sg.wave.live:
			continue
		pd.t += 1
		var d := along(pd, pd.lane)
		var a := S.at(pd.lane, d, -S.LANE_W / 2.0)
		var z := S.at(pd.lane, d, S.LANE_W / 2.0)
		if pd.t % L.every == L.every - L.warn:
			state.fx.append({"k": "laserWarn", "x1": a.x, "y1": a.y, "x2": z.x, "y2": z.y, "x": pd.x, "y": pd.y, "t": L.warn})
		if pd.t % L.every != 0:
			continue
		var cast := Sim.next_cast(state)
		var ang := atan2(z.y - a.y, z.x - a.x)
		for t in state.mechs:
			if t.ko or t.get("fly", false) or Sim.seg_dist(a.x, a.y, z.x, z.y, t.x, t.y) > L.half + Sim.rad(t):
				continue
			if t.has("bot"):
				Sim.hit(state, state.mechs[0], t, L.dmg, "LEGS", 1, ang, cast)
				t.by = pd.get("owner", 0)
			else:
				Sim.env_hit(state, t, L.dmg, "legs", 1, ang)
		state.fx.append({"k": "zap", "kind": "laser", "x1": a.x, "y1": a.y, "x2": z.x, "y2": z.y, "t": 10})
		state.fx.append({"k": "laneLaser", "x": pd.x, "y": pd.y, "t": 10})


static func gun(state, sg: Dictionary, pd: Dictionary) -> void:
	var T: Dictionary = MODULE.turret
	pd.cd = maxi(0, pd.cd - 1)
	if pd.cd > 0:
		return
	var best = null
	var near := 0.0
	for e in sg.enemies:
		if e.act == "die" or e.neutral:
			continue
		var b = state.mechs[e.m]
		var d := Sim.hypot(b.x - pd.x, b.y - pd.y)
		if not b.ko and d <= T.range and (best == null or d < near):
			best = b
			near = d
	if best == null:
		return
	pd.cd = T.every
	pd.aim = atan2(best.y - pd.y, best.x - pd.x)
	Sim.hit(state, state.mechs[0], best, T.dmg, "LEGS", 0, pd.aim + PI, Sim.next_cast(state))
	best.by = pd.get("owner", 0)
	state.fx.append({"k": "zap", "kind": "laser", "x1": pd.x + cos(pd.aim) * T.muzzle, "y1": pd.y + sin(pd.aim) * T.muzzle, "x2": best.x, "y2": best.y, "t": 4})


static func fire_post(state, sg: Dictionary, m: Dictionary) -> void:
	var P: Dictionary = MODULE.post
	var pd = pad_at(sg, m, P.reach)
	if pd == null or pd.module != "post" or pd.cd > 0:
		return
	pd.cd = P.cd
	var before := {}
	for e in sg.enemies:
		before[e.m] = state.mechs[e.m].armor.head
	Sim.line_attack(state, m, pd.x, pd.y, m.aim, P.range, P.half, P.dmg, 2, "ARMS", Sim.next_cast(state), "rail", {"perfectCut": 0.5})
	for k in before:
		if state.mechs[k].armor.head < before[k]:
			state.mechs[k].by = pd.get("owner", m.id)
